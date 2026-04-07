// @ts-nocheck
/**
 * Verifies Razorpay payment on the server (HMAC signature when order_id is present;
 * otherwise fetches payment from Razorpay API and checks amount), then marks the order paid.
 *
 * Body: { order_id, razorpay_payment_id, razorpay_order_id?, razorpay_signature? }
 */
import { createClient } from "npm:@supabase/supabase-js";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version, prefer",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function authHeader(req: Request): string | null {
  return req.headers.get("authorization") ?? req.headers.get("Authorization");
}

function requesterIdFromAuthHeader(req: Request): string | null {
  const directUser =
    req.headers.get("x-supabase-auth-user") ??
    req.headers.get("x-supabase-user-id") ??
    req.headers.get("x-sb-auth-user");
  if (directUser && directUser.trim().length > 0) return directUser.trim();

  const h = authHeader(req)?.trim() ?? "";
  const token = h.replace(/^Bearer\s+/i, "").trim();
  if (!token || !token.includes(".")) return null;
  const parts = token.split(".");
  if (parts.length < 2) return null;
  const payloadB64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
  const padded = payloadB64 + "=".repeat((4 - (payloadB64.length % 4)) % 4);
  try {
    const payload = JSON.parse(atob(padded)) as { sub?: unknown };
    const sub = typeof payload.sub === "string" ? payload.sub.trim() : "";
    return sub.length > 0 ? sub : null;
  } catch {
    return null;
  }
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
    return new Response("ok", { status: 204, headers: corsHeaders });
  }
  try {
    if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
    const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return json(500, { error: "missing_supabase_secrets" });
    }
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
      return json(500, { error: "missing_razorpay_secrets" });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: { headers: { "Content-Type": "application/json" } },
    });

    const body = await req.json();
    const requesterId = requesterIdFromAuthHeader(req);
    const userIdInput = optionalString(body["user_id"]);
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

    const orderUserId = order.user_id?.toString() ?? "";
    if (requesterId && orderUserId !== requesterId) {
      return json(403, { error: "forbidden" });
    }
    if (!requesterId && userIdInput && orderUserId !== userIdInput) {
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

    const auth = basicAuthHeader(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET);
    const getRes = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}`, {
      method: "GET",
      headers: { Authorization: auth },
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
      await supabase
        .from("orders")
        .update({
          payment_status: "failed",
          status: "payment_failed",
          updated_at: new Date().toISOString(),
        })
        .eq("id", orderId)
        .eq("user_id", requesterId);
      return json(400, {
        error: "payment_not_captured",
        detail: payStatus || "unknown",
      });
    }

    const dbRzOrder = (order.razorpay_order_id ?? "").toString().trim();
    // Prefer client → DB → Razorpay payment object so Orders checkouts always verify HMAC.
    const rzOrderId =
      rzOrderIdInput.length > 0 ? rzOrderIdInput : dbRzOrder.length > 0 ? dbRzOrder : payOrderId;

    if (rzOrderId.length > 0) {
      if (signature.length < 1) {
        return json(400, {
          error: "signature_required",
          detail: "razorpay_signature is required for Razorpay Orders checkout.",
        });
      }
      const expected = await hmacSha256Hex(RAZORPAY_KEY_SECRET, `${rzOrderId}|${paymentId}`);
      if (!timingSafeEqualHex(expected, signature)) {
        return json(403, { error: "invalid_signature" });
      }
      if (payOrderId.length > 0 && payOrderId !== rzOrderId) {
        return json(409, {
          error: "razorpay_order_mismatch",
          detail: "Payment is not linked to the stated Razorpay order.",
        });
      }
      if (dbRzOrder.length > 0 && dbRzOrder !== rzOrderId) {
        return json(409, {
          error: "checkout_order_mismatch",
          detail: "Razorpay order does not match this checkout session.",
        });
      }
    }
    // Legacy: no Razorpay order id on payment path — amount + capture verified via API only.

    const nowIso = new Date().toISOString();
    const guardUserId = requesterId || userIdInput;
    let upQuery = supabase
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
      .eq("id", orderId);
    if (guardUserId) {
      upQuery = upQuery.eq("user_id", guardUserId);
    }
    const { error: upErr } = await upQuery;

    if (upErr) {
      return json(500, { error: "update_failed", detail: upErr.message ?? String(upErr) });
    }

    return json(200, { ok: true, razorpay_payment_id: paymentId });
  } catch (e) {
    const detail = e instanceof Error ? e.message : String(e);
    return json(500, { error: "verify_razorpay_payment_failed", detail });
  }
});
