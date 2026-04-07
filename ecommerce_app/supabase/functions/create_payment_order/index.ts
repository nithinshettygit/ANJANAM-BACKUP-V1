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

    const requesterId = requesterIdFromAuthHeader(req);

    const body = await req.json();
    const userIdInput = optionalString(body["user_id"]);
    const orderId = reqString(body["order_id"], "order_id");

    const { data: order, error: orderErr } = await supabase
      .from("orders")
      .select("id, user_id, payment_method, payment_status, currency, delivery_fee")
      .eq("id", orderId)
      .single();
    if (orderErr || !order) return json(404, { error: "order_not_found" });
    const orderUserId = order.user_id?.toString() ?? "";
    if (requesterId && orderUserId !== requesterId) return json(403, { error: "forbidden" });
    if (!requesterId && userIdInput && orderUserId !== userIdInput) return json(403, { error: "forbidden" });
    if ((order.payment_method ?? "").toString().toLowerCase().trim() !== "razorpay") return json(400, { error: "not_razorpay_order" });
    const ps = (order.payment_status ?? "").toString().toLowerCase().trim();
    if (ps !== "pending" && ps !== "failed") return json(400, { error: "order_not_payable", detail: ps });

    const { data: items, error: itemsErr } = await supabase
      .from("order_items")
      .select("unit_price, quantity")
      .eq("order_id", orderId);
    if (itemsErr || !items || items.length === 0) return json(400, { error: "order_items_missing" });

    let subtotal = 0;
    for (const it of items) subtotal += Number(it.unit_price ?? 0) * Number(it.quantity ?? 0);
    const amountPaise = Math.round((subtotal + Number(order.delivery_fee ?? 0)) * 100);
    if (!(amountPaise >= 100)) return json(400, { error: "invalid_order_amount" });

    const auth = basicAuthHeader(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET);
    const rzpRes = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: { Authorization: auth, "Content-Type": "application/json" },
      body: JSON.stringify({
        amount: amountPaise,
        currency: (order.currency ?? "INR").toString(),
        receipt: orderId.replace(/-/g, "").slice(0, 40),
        notes: { supabase_order_id: orderId },
      }),
    });
    const rzpText = await rzpRes.text().catch(() => "");
    if (!rzpRes.ok) return json(400, { error: "razorpay_order_create_failed", detail: rzpText.slice(0, 2000) });
    const parsed = JSON.parse(rzpText) as { id?: string };
    const razorpayOrderId = (parsed.id ?? "").trim();
    if (!razorpayOrderId) return json(500, { error: "razorpay_order_id_missing" });

    let up = supabase
      .from("orders")
      .update({ razorpay_order_id: razorpayOrderId, updated_at: new Date().toISOString() })
      .eq("id", orderId);
    const guardUserId = requesterId || userIdInput;
    if (guardUserId) up = up.eq("user_id", guardUserId);
    const { error: upErr } = await up;
    if (upErr) return json(500, { error: "order_update_failed", detail: upErr.message ?? String(upErr) });

    return json(200, {
      ok: true,
      razorpay_order_id: razorpayOrderId,
      amount: amountPaise,
      amount_paise: amountPaise,
      currency: (order.currency ?? "INR").toString(),
      key_id: RAZORPAY_KEY_ID,
    });
  } catch (e) {
    return json(500, { error: "create_payment_order_failed", detail: e instanceof Error ? e.message : String(e) });
  }
});
