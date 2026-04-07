// @ts-nocheck
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
  if (req.method === "OPTIONS") return new Response("ok", { status: 204, headers: corsHeaders });
  try {
    if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
    const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return json(500, { error: "missing_supabase_secrets" });
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) return json(500, { error: "missing_razorpay_secrets" });

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
    if (requesterId && orderUserId !== requesterId) return json(403, { error: "forbidden" });
    if (!requesterId && userIdInput && orderUserId !== userIdInput) return json(403, { error: "forbidden" });
    if ((order.payment_method ?? "").toString().toLowerCase().trim() !== "razorpay") return json(400, { error: "not_razorpay_order" });

    const itemsRes = await supabase.from("order_items").select("unit_price, quantity").eq("order_id", orderId);
    if (itemsRes.error || !itemsRes.data || itemsRes.data.length === 0) return json(400, { error: "order_items_missing" });
    const amountPaise = Math.round(
      (itemsRes.data.reduce((s, it) => s + Number(it.unit_price ?? 0) * Number(it.quantity ?? 0), 0) + Number(order.delivery_fee ?? 0)) * 100,
    );

    const auth = basicAuthHeader(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET);
    const getRes = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}`, { method: "GET", headers: { Authorization: auth } });
    const payText = await getRes.text().catch(() => "");
    if (!getRes.ok) return json(400, { error: "payment_lookup_failed", detail: payText.slice(0, 1200) });
    const payment = JSON.parse(payText) as { amount?: number; order_id?: string; status?: string; captured?: boolean };
    if (Number(payment.amount ?? 0) !== amountPaise) return json(409, { error: "amount_mismatch" });

    const captured = payment.captured === true || (payment.status ?? "").toLowerCase().trim() === "captured";
    const guardUserId = requesterId || userIdInput;
    if (!captured) {
      let failedUp = supabase.from("orders").update({ payment_status: "failed", status: "payment_failed", updated_at: new Date().toISOString() }).eq("id", orderId);
      if (guardUserId) failedUp = failedUp.eq("user_id", guardUserId);
      await failedUp;
      return json(400, { error: "payment_not_captured" });
    }

    const dbRzOrder = (order.razorpay_order_id ?? "").toString().trim();
    const payOrderId = (payment.order_id ?? "").toString().trim();
    const rzOrderId = rzOrderIdInput || dbRzOrder || payOrderId;
    if (!rzOrderId || !signature) return json(400, { error: "signature_required" });
    const expected = await hmacSha256Hex(RAZORPAY_KEY_SECRET, `${rzOrderId}|${paymentId}`);
    if (!timingSafeEqualHex(expected, signature)) return json(403, { error: "invalid_signature" });
    if ((payOrderId && payOrderId !== rzOrderId) || (dbRzOrder && dbRzOrder !== rzOrderId)) return json(409, { error: "razorpay_order_mismatch" });

    const nowIso = new Date().toISOString();
    let upQuery = supabase
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
      .eq("id", orderId);
    if (guardUserId) {
      upQuery = upQuery.eq("user_id", guardUserId);
    }
    const { error: upErr } = await upQuery;
    if (upErr) return json(500, { error: "update_failed", detail: upErr.message ?? String(upErr) });

    return json(200, { ok: true, razorpay_payment_id: paymentId });
  } catch (e) {
    return json(500, { error: "verify_payment_failed", detail: e instanceof Error ? e.message : String(e) });
  }
});
