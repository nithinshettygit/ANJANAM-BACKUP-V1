// @ts-nocheck
/**
 * Verifies Razorpay payment on the server (HMAC signature when order_id is present;
 * otherwise fetches payment from Razorpay API and checks amount), then marks the order paid.
 *
 * Body: { order_id, razorpay_payment_id, razorpay_order_id?, razorpay_signature? }
 */
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

function basicAuthHeader(keyId: string, keySecret: string): string {
  return `Basic ${btoa(`${keyId}:${keySecret}`)}`;
}

function reqString(v: unknown, name: string): string {
  if (typeof v !== "string") throw new Error(`missing_${name}`);
  const s = v.trim();
  if (!s) throw new Error(`missing_${name}`);
  return s;
}

function optionalString(v: unknown): string {
  if (v == null) return "";
  if (typeof v !== "string") return "";
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

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const buf = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  return Array.from(new Uint8Array(buf))
    .map((x) => x.toString(16).padStart(2, "0"))
    .join("");
}

/** Constant-time compare for equal-length hex strings. */
function timingSafeEqualHex(a: string, b: string): boolean {
  const aa = a.toLowerCase();
  const bb = b.toLowerCase();
  if (aa.length !== bb.length) return false;
  let out = 0;
  for (let i = 0; i < aa.length; i++) {
    out |= aa.charCodeAt(i) ^ bb.charCodeAt(i);
  }
  return out === 0;
}

type RzpPayment = {
  id?: string;
  order_id?: string;
  amount?: number;
  currency?: string;
  status?: string;
  captured?: boolean;
};

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
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
      return json(500, { error: "missing_razorpay_secrets" });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: { headers: { "Content-Type": "application/json" } },
    });

    const body = await req.json();
    const authResult = await resolveRequesterIdentity(req, {
      supabaseUrl: SUPABASE_URL,
      supabaseAnonKey: SUPABASE_ANON_KEY,
    });
    if (!authResult.ok) return json(authResult.code, { error: authResult.error });
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
    if (orderUserId !== requesterId) {
      return json(403, { error: "forbidden" });
    }
    const pm = (order.payment_method ?? "").toString().toLowerCase().trim();
    if (pm !== "razorpay") {
      return json(400, { error: "not_razorpay_order" });
    }
    const ps = (order.payment_status ?? "").toString().toLowerCase().trim();
    if (ps !== "pending" && ps !== "failed") {
      return json(400, { error: "order_not_payable", detail: ps });
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
    const amountPaise = Math.round((subtotal + deliveryFee) * 100);
    if (!(amountPaise >= 100)) {
      return json(400, { error: "invalid_order_amount", detail: "minimum_one_inr" });
    }

    const razorpayAuth = basicAuthHeader(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET);
    const getRes = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}`, {
      method: "GET",
      headers: { Authorization: razorpayAuth },
    });
    const payText = await getRes.text().catch(() => "");
    if (!getRes.ok) {
      return json(400, {
        error: "payment_lookup_failed",
        detail: payText.slice(0, 1200),
      });
    }
    let payment: RzpPayment = {};
    try {
      payment = JSON.parse(payText) as RzpPayment;
    } catch {
      return json(500, { error: "razorpay_invalid_json" });
    }

    const payAmount = Number(payment.amount ?? 0);
    if (payAmount !== amountPaise) {
      return json(409, {
        error: "amount_mismatch",
        detail: "Payment amount does not match order total.",
        expected_paise: amountPaise,
        payment_paise: payAmount,
      });
    }

    const payOrderId = (payment.order_id ?? "").toString().trim();
    const payStatus = (payment.status ?? "").toString().toLowerCase().trim();
    const captured = payment.captured === true || payStatus === "captured";
    if (!captured) {
      // UPI collect / QR can complete capture asynchronously after checkout callback.
      // Keep order pending; polling + webhook will finalize to paid/failed.
      return json(202, {
        ok: false,
        status: "pending",
        error: "payment_not_captured_yet",
        detail: payStatus || "unknown",
      });
    }

    const dbRzOrder = (order.razorpay_order_id ?? "").toString().trim();
    const rzOrderId = rzOrderIdInput.length > 0 ? rzOrderIdInput : dbRzOrder;
    if (rzOrderId.length < 1 || signature.length < 1 || dbRzOrder.length < 1) {
      return json(400, {
        error: "strict_verification_required",
        detail: "razorpay_order_id and razorpay_signature are required.",
      });
    }
    const expected = await hmacSha256Hex(RAZORPAY_KEY_SECRET, `${rzOrderId}|${paymentId}`);
    if (!timingSafeEqualHex(expected, signature)) {
      return json(403, { error: "invalid_signature" });
    }
    if (payOrderId.length < 1 || payOrderId !== rzOrderId || dbRzOrder !== rzOrderId) {
      return json(409, {
        error: "razorpay_order_mismatch",
        detail: "Payment is not linked to this checkout session.",
      });
    }

    const nowIso = new Date().toISOString();
    const upQuery = supabase
      .from("orders")
      .update({
        payment_status: "paid",
        status: "processing",
        razorpay_payment_id: paymentId,
        razorpay_order_id: rzOrderId.length > 0 ? rzOrderId : null,
        razorpay_signature: signature.length > 0 ? signature : null,
        payment_signature: signature.length > 0 ? signature : null,
        payment_verified_at: nowIso,
        paid_at: nowIso,
        updated_at: nowIso,
      })
      .eq("id", orderId)
      .eq("user_id", orderUserId);
    const { error: upErr } = await upQuery;

    if (upErr) {
      return json(500, { error: "update_failed", detail: upErr.message ?? String(upErr) });
    }
    await triggerOrderConfirmedNotification({
      supabaseUrl: SUPABASE_URL,
      internalSecret: INTERNAL_FUNCTION_SECRET,
      userId: requesterId,
      orderId,
    });

    return json(200, { ok: true, razorpay_payment_id: paymentId });
  } catch (_) {
    return json(500, { error: "verify_razorpay_payment_failed" });
  }
});
