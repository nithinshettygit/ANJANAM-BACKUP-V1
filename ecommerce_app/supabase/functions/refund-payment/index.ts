// @ts-nocheck
import { createClient } from "npm:@supabase/supabase-js";
import { resolveRequesterIdentity } from "../_shared/auth.ts";
import { devLog } from "../_shared/dev_log.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version, prefer",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function reqString(v: unknown, name: string): string {
  if (typeof v !== "string") throw new Error(`missing_${name}`);
  const s = v.trim();
  if (!s) throw new Error(`missing_${name}`);
  return s;
}

function toPositiveIntOrNull(v: unknown): number | null {
  if (v == null) return null;
  const n = Number(v);
  if (!Number.isFinite(n)) return null;
  const i = Math.round(n);
  return i > 0 ? i : null;
}

function basicAuthHeader(keyId: string, keySecret: string): string {
  return `Basic ${btoa(`${keyId}:${keySecret}`)}`;
}

async function parseBody(req: Request): Promise<Record<string, unknown>> {
  try {
    return (await req.json()) as Record<string, unknown>;
  } catch {
    const raw = await req.text();
    if (!raw || !raw.trim()) return {};
    try {
      return JSON.parse(raw) as Record<string, unknown>;
    } catch {
      return {};
    }
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
    const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";

    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return json(500, { error: "missing_supabase_secrets" });
    }
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
      return json(500, { error: "missing_razorpay_secrets" });
    }

    const authData = await resolveRequesterIdentity(req, {
      supabaseUrl: SUPABASE_URL,
      supabaseAnonKey: SUPABASE_ANON_KEY,
    });
    if (!authData.ok) return json(authData.code, { error: authData.error });
    const requesterId = authData.userId;
    devLog(`auth_ok user_id=${requesterId}`);

    const body = await parseBody(req);
    const orderIdValue = body["order_id"];
    if (typeof orderIdValue !== "string" || !orderIdValue.trim()) {
      return json(400, { error: "missing_order_id" });
    }
    const orderId = orderIdValue.trim();

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: { headers: { "Content-Type": "application/json" } },
    });

    const { data: isAdminData, error: isAdminErr } = await supabase.rpc("is_admin", {
      uid: requesterId,
    });
    if (isAdminErr || !isAdminData) {
      return json(403, { error: "forbidden_admin_only" });
    }

    const { data: order, error: orderErr } = await supabase
      .from("orders")
      .select(
        "id, user_id, status, payment_method, payment_status, razorpay_payment_id, delivery_fee, refund_status, refund_amount, refund_id",
      )
      .eq("id", orderId)
      .single();
    if (orderErr || !order) return json(404, { error: "order_not_found" });

    const paymentMethod = (order.payment_method ?? "").toString().toLowerCase().trim();
    const paymentStatus = (order.payment_status ?? "").toString().toLowerCase().trim();
    const refundStatus = (order.refund_status ?? "none").toString().toLowerCase().trim();
    const orderStatus = (order.status ?? "").toString().toLowerCase().trim();
    const paymentId = (order.razorpay_payment_id ?? "").toString().trim();

    if (paymentMethod !== "razorpay") return json(400, { error: "not_razorpay_order" });
    if (paymentStatus !== "paid") return json(400, { error: "order_not_paid" });
    if (!paymentId) return json(400, { error: "missing_payment_id" });
    if (
      refundStatus !== "none" ||
      refundStatus === "processing" ||
      refundStatus === "refunded" ||
      (order.refund_id ?? "").toString().trim().length > 0
    ) {
      return json(409, { error: "Refund already processed" });
    }

    // Enforce refund eligibility: only cancelled orders or return flow with warehouse-received item.
    if (orderStatus !== "cancelled") {
      const { data: eligibleReturn, error: eligibleReturnErr } = await supabase
        .from("returns")
        .select("id")
        .eq("order_id", orderId)
        .eq("return_status", "returned")
        .limit(1)
        .maybeSingle();
      if (eligibleReturnErr) {
        return json(500, { error: "refund_eligibility_check_failed" });
      }
      if (!eligibleReturn) {
        return json(409, { error: "refund_not_eligible_return_not_received" });
      }
    }

    const { data: items, error: itemsErr } = await supabase
      .from("order_items")
      .select("unit_price, quantity")
      .eq("order_id", orderId);
    if (itemsErr || !items || items.length === 0) {
      return json(400, { error: "order_items_missing" });
    }

    let subtotal = 0;
    for (const it of items) {
      const price = Number((it as { unit_price?: unknown }).unit_price ?? 0);
      const qty = Number((it as { quantity?: unknown }).quantity ?? 0);
      subtotal += price * qty;
    }
    const deliveryFee = Number(order.delivery_fee ?? 0);
    const computedPaise = Math.round((subtotal + deliveryFee) * 100);
    const requestedAmount = toPositiveIntOrNull(body["refund_amount"]);
    const dbRefundAmount = toPositiveIntOrNull(order.refund_amount);
    const refundAmount = requestedAmount ?? dbRefundAmount ?? computedPaise;
    if (!refundAmount || refundAmount <= 0) {
      return json(400, { error: "invalid_refund_amount" });
    }
    if (refundAmount > computedPaise) {
      return json(400, {
        error: "refund_amount_exceeds_order_total",
        expected_max_amount: computedPaise,
      });
    }

    const nowIso = new Date().toISOString();
    const initiatedBy = authData.user.email?.trim() || requesterId;
    const refundReason =
      typeof body["refund_reason"] === "string" && body["refund_reason"].trim().length > 0
        ? body["refund_reason"].trim()
        : "Admin approved refund";

    await supabase
      .from("orders")
      .update({
        refund_status: "approved",
        refund_amount: refundAmount,
        refund_requested_at: nowIso,
        refund_initiated_by: initiatedBy,
        refund_initiated_at: nowIso,
        refund_reason: refundReason,
        updated_at: nowIso,
      })
      .eq("id", orderId);
    await supabase.from("order_status_history").insert({
      order_id: orderId,
      status: "refund_initiated",
      updated_by: requesterId,
      notes: `Refund initiated by admin (${initiatedBy})`,
      created_at: nowIso,
    });
    await supabase
      .from("orders")
      .update({
        refund_status: "processing",
        updated_at: nowIso,
      })
      .eq("id", orderId);

    const auth = basicAuthHeader(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET);
    const rzRes = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}/refund`, {
      method: "POST",
      headers: {
        Authorization: auth,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ amount: refundAmount }),
    });
    const rzText = await rzRes.text().catch(() => "");

    if (!rzRes.ok) {
      await supabase
        .from("orders")
        .update({
          refund_status: "rejected",
          updated_at: new Date().toISOString(),
        })
        .eq("id", orderId);
      return json(400, {
        error: "razorpay_refund_failed",
        detail: rzText.slice(0, 1200),
      });
    }

    let rz: Record<string, unknown> = {};
    try {
      rz = JSON.parse(rzText) as Record<string, unknown>;
    } catch {
      await supabase
        .from("orders")
        .update({
          refund_status: "rejected",
          updated_at: new Date().toISOString(),
        })
        .eq("id", orderId);
      return json(502, { error: "invalid_razorpay_response" });
    }

    const refundId = (rz["id"] ?? "").toString().trim();
    const gatewayStatus = (rz["status"] ?? "").toString().trim();
    if (!refundId) {
      await supabase
        .from("orders")
        .update({
          refund_status: "rejected",
          updated_at: new Date().toISOString(),
        })
        .eq("id", orderId);
      return json(502, { error: "missing_refund_id_from_gateway" });
    }

    const processedAt = new Date().toISOString();
    const { error: upErr } = await supabase
      .from("orders")
      .update({
        refund_status: "refunded",
        refund_id: refundId,
        refund_processed_at: processedAt,
        refund_amount: refundAmount,
        updated_at: processedAt,
      })
      .eq("id", orderId);
    if (upErr) {
      return json(500, { error: "order_update_failed" });
    }
    await supabase.from("order_status_history").insert({
      order_id: orderId,
      status: "refund_completed",
      updated_by: requesterId,
      notes: "Refund completed - Razorpay",
      created_at: processedAt,
    });

    // Optional customer notification; failures are non-fatal for refund flow.
    try {
      const userId = (order.user_id ?? "").toString().trim();
      if (userId) {
        await supabase.from("user_notifications").insert({
          user_id: userId,
          kind: "return_refund",
          title: "Refund initiated",
          body: "Your refund has been initiated. It may take 3–7 business days.",
          order_id: orderId,
        });
      }
    } catch (_) {}

    return json(200, {
      success: true,
      refund_id: refundId,
      status: gatewayStatus || "processed",
    });
  } catch (_) {
    return json(500, { error: "refund_payment_failed" });
  }
});
