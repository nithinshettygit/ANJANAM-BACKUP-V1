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

function optionalString(v: unknown): string {
  if (v == null || typeof v !== "string") return "";
  return v.trim();
}

async function triggerOrderConfirmedNotification(params: {
  supabaseUrl: string;
  internalSecret: string;
  userId: string;
  orderId: string;
}) {
  const { supabaseUrl, internalSecret, userId, orderId } = params;
  if (!internalSecret.trim()) return;
  try {
    await fetch(`${supabaseUrl}/functions/v1/send-notification`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-internal-secret": internalSecret,
      },
      body: JSON.stringify({
        user_id: userId,
        order_id: orderId,
        title: "Order Confirmed",
        body: "Your order has been placed successfully",
        type: "order",
      }),
    });
  } catch (_) {
    // Notification failures must not fail payment verification.
  }
}

function basicAuthHeader(keyId: string, keySecret: string): string {
  return `Basic ${btoa(`${keyId}:${keySecret}`)}`;
}

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const buf = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  return Array.from(new Uint8Array(buf)).map((x) => x.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqualHex(a: string, b: string): boolean {
  const aa = a.toLowerCase();
  const bb = b.toLowerCase();
  if (aa.length !== bb.length) return false;
  let out = 0;
  for (let i = 0; i < aa.length; i++) out |= aa.charCodeAt(i) ^ bb.charCodeAt(i);
  return out === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  try {
    if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
    const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
    const INTERNAL_FUNCTION_SECRET = Deno.env.get("INTERNAL_FUNCTION_SECRET") ?? "";
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return json(500, { error: "missing_supabase_secrets" });
    }
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) return json(500, { error: "missing_razorpay_secrets" });

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: { headers: { "Content-Type": "application/json" } },
    });

    const body = await req.json();
    const authResult = await resolveRequesterIdentity(req, {
      supabaseUrl: SUPABASE_URL,
      supabaseAnonKey: SUPABASE_ANON_KEY,
    });
    if (!authResult.ok) {
      return json(authResult.code, { error: authResult.error });
    }
    const requesterId = authResult.userId;
    devLog(`auth_ok user_id=${requesterId}`);
    const orderId = reqString(body["order_id"], "order_id");
    const paymentId = reqString(body["razorpay_payment_id"], "razorpay_payment_id");
    const rzOrderIdInput = optionalString(body["razorpay_order_id"]);
    const signature = optionalString(body["razorpay_signature"]);

    const { data: order, error: orderErr } = await supabase
      .from("orders")
      .select("id, user_id, payment_method, payment_status, currency, delivery_fee, razorpay_order_id")
      .eq("id", orderId)
      .single();
    if (orderErr || !order) return json(404, { error: "order_not_found" });
    const orderUserId = order.user_id?.toString().trim() ?? "";
    if (orderUserId !== requesterId) return json(403, { error: "forbidden" });

    if ((order.payment_method ?? "").toString().toLowerCase().trim() !== "razorpay") {
      return json(400, { error: "not_razorpay_order" });
    }

    const orderPaymentStatus = (order.payment_status ?? "").toString().toLowerCase().trim();
    if (orderPaymentStatus === "paid") {
      return json(200, { ok: true, already_verified: true, razorpay_payment_id: paymentId });
    }

    const itemsRes = await supabase.from("order_items").select("unit_price, quantity").eq("order_id", orderId);
    if (itemsRes.error || !itemsRes.data || itemsRes.data.length === 0) return json(400, { error: "order_items_missing" });
    const amountPaise = Math.round(
      (itemsRes.data.reduce((s, it) => s + Number(it.unit_price ?? 0) * Number(it.quantity ?? 0), 0) + Number(order.delivery_fee ?? 0)) * 100,
    );

    const razorpayAuth = basicAuthHeader(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET);
    const getRes = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}`, { method: "GET", headers: { Authorization: razorpayAuth } });
    const payText = await getRes.text().catch(() => "");
    if (!getRes.ok) return json(400, { error: "payment_lookup_failed", detail: payText.slice(0, 1200) });
    let payment: { amount?: number; order_id?: string; status?: string; captured?: boolean } = {};
    try {
      payment = JSON.parse(payText) as { amount?: number; order_id?: string; status?: string; captured?: boolean };
    } catch {
      return json(502, { error: "razorpay_invalid_json" });
    }
    if (Number(payment.amount ?? 0) !== amountPaise) return json(409, { error: "amount_mismatch" });

    const captured = payment.captured === true || (payment.status ?? "").toLowerCase().trim() === "captured";
    if (!captured) {
      // UPI collect / QR can be authorized first and captured asynchronously.
      // Do NOT mark failed here; keep order pending and let webhook/poller converge.
      return json(202, { ok: false, status: "pending", error: "payment_not_captured_yet" });
    }

    const dbRzOrder = (order.razorpay_order_id ?? "").toString().trim();
    const payOrderId = (payment.order_id ?? "").toString().trim();
    const rzOrderId = rzOrderIdInput || dbRzOrder || payOrderId;
    if (!rzOrderId || !signature) return json(400, { error: "signature_required" });
    const expected = await hmacSha256Hex(RAZORPAY_KEY_SECRET, `${rzOrderId}|${paymentId}`);
    if (!timingSafeEqualHex(expected, signature)) return json(403, { error: "invalid_signature" });
    if ((payOrderId && payOrderId !== rzOrderId) || (dbRzOrder && dbRzOrder !== rzOrderId)) return json(409, { error: "razorpay_order_mismatch" });

    async function logSystemError(params: {
      errorType: string;
      errorMessage: string;
      stackTrace?: string;
    }) {
      try {
        await supabase.from("system_error_logs").insert({
          error_type: params.errorType,
          order_id: orderId,
          payment_id: paymentId,
          error_message: params.errorMessage.slice(0, 4000),
          stack_trace: (params.stackTrace ?? "").slice(0, 12000),
        });
      } catch (_) {
        // Never break payment recovery if logs table is unavailable.
      }
    }

    async function triggerAutoRefund(refundAmountPaise: number) {
      const refundRes = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}/refund`, {
        method: "POST",
        headers: {
          Authorization: razorpayAuth,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ amount: refundAmountPaise }),
      });
      const refundText = await refundRes.text().catch(() => "");
      if (!refundRes.ok) {
        await logSystemError({
          errorType: "automatic_refund_failed",
          errorMessage: refundText || "automatic_refund_failed",
        });
      }
      return refundText;
    }

    async function markFailureAndRefund(statusCode: "payment_failed_inventory" | "out_of_stock_after_payment", reason: string, stack?: string) {
      const nowIso = new Date().toISOString();
      await logSystemError({
        errorType: statusCode,
        errorMessage: reason,
        stackTrace: stack,
      });
      await triggerAutoRefund(amountPaise);
      const failUpdate = supabase
        .from("orders")
        .update({
          status: statusCode,
          payment_status: "paid",
          refund_status: "processing",
          refund_amount: amountPaise,
          refund_requested_at: nowIso,
          refund_reason: "Automatic refund due to post-payment inventory issue",
          updated_at: nowIso,
        })
        .eq("id", orderId)
        .eq("user_id", orderUserId);
      await failUpdate;

      await supabase.from("order_status_history").insert([
        {
          order_id: orderId,
          status: "payment_received",
          updated_by: requesterId,
          notes: "Payment received and verified with Razorpay.",
          created_at: nowIso,
        },
        {
          order_id: orderId,
          status: "inventory_error_detected",
          updated_by: requesterId,
          notes: "Inventory conversion failed after payment verification.",
          created_at: nowIso,
        },
        {
          order_id: orderId,
          status: "automatic_refund_initiated",
          updated_by: requesterId,
          notes: "Automatic refund initiated by system.",
          created_at: nowIso,
        },
      ]);

      return json(200, {
        ok: false,
        auto_refund_initiated: true,
        order_status: statusCode,
        message:
          "Payment received, but the item became unavailable. Your payment is being refunded automatically. Refund will reflect within 5–7 business days.",
        razorpay_payment_id: paymentId,
      });
    }

    // Pre-conversion safety check to avoid race-condition status update attempts.
    try {
      const stockRows = await supabase
        .from("order_items")
        .select("product_id, quantity, products!order_items_product_id_fkey(inventory_count)")
        .eq("order_id", orderId);
      if (!stockRows.error && stockRows.data) {
        let insufficient = false;
        for (const row of stockRows.data) {
          const qty = Number((row as any).quantity ?? 0);
          const product = (row as any).products;
          const inv = Number((product?.inventory_count) ?? 0);
          if (!Number.isFinite(inv) || inv < qty) {
            insufficient = true;
            break;
          }
        }
        if (insufficient) {
          try {
            await supabase.rpc("release_inventory_reservation_for_order", { p_order_id: orderId });
          } catch (_) {}
          return await markFailureAndRefund(
            "out_of_stock_after_payment",
            "Stock insufficient before reservation conversion.",
          );
        }
      }
    } catch (stockErr) {
      await logSystemError({
        errorType: "stock_recheck_failed",
        errorMessage: stockErr instanceof Error ? stockErr.message : String(stockErr),
      });
    }

    // Reservation conversion + order update can fail from DB trigger; recover automatically.
    try {
      const nowIso = new Date().toISOString();
      const upQuery = supabase
        .from("orders")
        .update({
          payment_status: "paid",
          status: "processing",
          razorpay_payment_id: paymentId,
          razorpay_order_id: rzOrderId,
          razorpay_signature: signature,
          payment_signature: signature,
          payment_verified_at: nowIso,
          paid_at: nowIso,
          updated_at: nowIso,
        })
        .eq("id", orderId)
        .eq("user_id", orderUserId);
      const { error: upErr } = await upQuery;
      if (upErr) {
        throw upErr;
      }
      await triggerOrderConfirmedNotification({
        supabaseUrl: SUPABASE_URL,
        internalSecret: INTERNAL_FUNCTION_SECRET,
        userId: requesterId,
        orderId,
      });
      return json(200, { ok: true, razorpay_payment_id: paymentId });
    } catch (convErr) {
      const msg = convErr instanceof Error ? convErr.message : String(convErr);
      if (msg.toLowerCase().includes("inventory_reservation_convert_failed")) {
        return await markFailureAndRefund("payment_failed_inventory", msg);
      }
      return await markFailureAndRefund("payment_failed_inventory", msg);
    }
  } catch (_) {
    // Never leak internal diagnostics to client.
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (supabaseUrl && serviceRole) {
      try {
        const sb = createClient(supabaseUrl, serviceRole);
        await sb.from("system_error_logs").insert({
          error_type: "verify_payment_unhandled",
          error_message: "verify_payment_unhandled",
          stack_trace: "",
        });
      } catch (_) {}
    }
    return json(500, { error: "verify_payment_failed" });
  }
});
