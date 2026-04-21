// @ts-nocheck
import { createClient } from "npm:@supabase/supabase-js";
import { resolveRequesterIdentity } from "../_shared/auth.ts";
import { devLog } from "../_shared/dev_log.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version, prefer",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  /** Browsers cache preflight; reduces OPTIONS spam. */
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

function basicAuthHeader(keyId: string, keySecret: string): string {
  return `Basic ${btoa(`${keyId}:${keySecret}`)}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  let lockCtx: { supabase: ReturnType<typeof createClient>; orderId: string; requesterId: string } | null = null;
  try {
    if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
    const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
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

    const { data: order, error: orderErr } = await supabase
      .from("orders")
      .select("id, user_id, payment_method, payment_status, currency, delivery_fee, razorpay_order_id")
      .eq("id", orderId)
      .single();
    if (orderErr || !order) return json(404, { error: "order_not_found" });
    const orderUserId = order.user_id?.toString().trim() ?? "";
    if (orderUserId !== requesterId) return json(403, { error: "forbidden" });
    if ((order.payment_method ?? "").toString().toLowerCase().trim() !== "razorpay") return json(400, { error: "not_razorpay_order" });
    const ps = (order.payment_status ?? "").toString().toLowerCase().trim();
    if (ps !== "pending" && ps !== "failed") return json(400, { error: "order_not_payable", detail: ps });
    const existingRazorpayOrderId = optionalString((order as { razorpay_order_id?: unknown }).razorpay_order_id);

    const { data: items, error: itemsErr } = await supabase
      .from("order_items")
      .select("unit_price, quantity")
      .eq("order_id", orderId);
    if (itemsErr || !items || items.length === 0) return json(400, { error: "order_items_missing" });

    let subtotal = 0;
    for (const it of items) subtotal += Number(it.unit_price ?? 0) * Number(it.quantity ?? 0);
    const amountPaise = Math.round((subtotal + Number(order.delivery_fee ?? 0)) * 100);
    if (!(amountPaise >= 100)) return json(400, { error: "invalid_order_amount" });
    if (ps === "pending" && existingRazorpayOrderId.length > 0) {
      return json(200, {
        ok: true,
        razorpay_order_id: existingRazorpayOrderId,
        amount: amountPaise,
        amount_paise: amountPaise,
        currency: (order.currency ?? "INR").toString(),
        key_id: RAZORPAY_KEY_ID,
        reused: true,
      });
    }

    const claimLock = await supabase.rpc("claim_payment_order_creation_lock", {
      p_order_id: orderId,
      p_user_id: requesterId,
      p_lock_seconds: 30,
    });
    if (claimLock.error) return json(500, { error: "order_lock_failed" });
    const lockClaimed = claimLock.data === true;
    if (!lockClaimed) {
      const { data: latestOrder, error: latestOrderErr } = await supabase
        .from("orders")
        .select("razorpay_order_id")
        .eq("id", orderId)
        .eq("user_id", requesterId)
        .maybeSingle();
      if (latestOrderErr) return json(500, { error: "order_fetch_failed" });
      const latestRazorpayOrderId = optionalString((latestOrder as { razorpay_order_id?: unknown } | null)?.razorpay_order_id);
      if (latestRazorpayOrderId.length > 0) {
        return json(200, {
          ok: true,
          razorpay_order_id: latestRazorpayOrderId,
          amount: amountPaise,
          amount_paise: amountPaise,
          currency: (order.currency ?? "INR").toString(),
          key_id: RAZORPAY_KEY_ID,
          reused: true,
        });
      }
      return json(409, { error: "payment_order_creation_in_progress" });
    }
    lockCtx = { supabase, orderId, requesterId };

    const razorpayAuth = basicAuthHeader(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET);
    const rzpRes = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: { Authorization: razorpayAuth, "Content-Type": "application/json" },
      body: JSON.stringify({
        amount: amountPaise,
        currency: (order.currency ?? "INR").toString(),
        receipt: orderId.replace(/-/g, "").slice(0, 40),
        notes: { supabase_order_id: orderId },
      }),
    });
    const rzpText = await rzpRes.text().catch(() => "");
    if (!rzpRes.ok) {
      await supabase.rpc("release_payment_order_creation_lock", {
        p_order_id: orderId,
        p_user_id: requesterId,
      });
      return json(400, { error: "razorpay_order_create_failed", detail: rzpText.slice(0, 2000) });
    }
    let parsed: { id?: string } = {};
    try {
      parsed = JSON.parse(rzpText) as { id?: string };
    } catch {
      return json(502, { error: "razorpay_invalid_json" });
    }
    const razorpayOrderId = (parsed.id ?? "").trim();
    if (!razorpayOrderId) {
      await supabase.rpc("release_payment_order_creation_lock", {
        p_order_id: orderId,
        p_user_id: requesterId,
      });
      return json(500, { error: "razorpay_order_id_missing" });
    }

    const finalize = await supabase.rpc("finalize_payment_order_creation", {
      p_order_id: orderId,
      p_user_id: requesterId,
      p_razorpay_order_id: razorpayOrderId,
    });
    if (finalize.error || !finalize.data) {
      await supabase.rpc("release_payment_order_creation_lock", {
        p_order_id: orderId,
        p_user_id: requesterId,
      });
      return json(500, { error: "order_update_failed", detail: finalize.error?.message ?? "finalize_failed" });
    }
    const finalizeRow = Array.isArray(finalize.data) ? finalize.data[0] : finalize.data;
    const finalRazorpayOrderId = optionalString(finalizeRow?.razorpay_order_id);
    if (!finalRazorpayOrderId) {
      await supabase.rpc("release_payment_order_creation_lock", {
        p_order_id: orderId,
        p_user_id: requesterId,
      });
      return json(500, { error: "order_update_failed", detail: "missing_final_razorpay_order_id" });
    }
    lockCtx = null;

    return json(200, {
      ok: true,
      razorpay_order_id: finalRazorpayOrderId,
      amount: amountPaise,
      amount_paise: amountPaise,
      currency: (order.currency ?? "INR").toString(),
      key_id: RAZORPAY_KEY_ID,
      reused: finalizeRow?.created === false,
    });
  } catch (_) {
    if (lockCtx) {
      await lockCtx.supabase.rpc("release_payment_order_creation_lock", {
        p_order_id: lockCtx.orderId,
        p_user_id: lockCtx.requesterId,
      });
    }
    return json(500, { error: "create_payment_order_failed" });
  }
});
