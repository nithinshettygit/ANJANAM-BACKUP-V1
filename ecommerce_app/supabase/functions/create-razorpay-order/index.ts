// @ts-nocheck
import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js";

/** Required for Flutter Web / browser: preflight + cross-origin POST with Authorization. */
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

function reqString(v: unknown, name: string): string {
  if (typeof v !== "string") throw new Error(`missing_${name}`);
  const s = v.trim();
  if (!s) throw new Error(`missing_${name}`);
  return s;
}

function basicAuthHeader(keyId: string, keySecret: string): string {
  return `Basic ${btoa(`${keyId}:${keySecret}`)}`;
}

serve(async (req) => {
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

    const h = authHeader(req)?.trim() ?? "";
    const tokenPart = h.split(/\s+/).filter(Boolean).pop() ?? "";
    const accessToken = tokenPart.replace(/^Bearer$/i, "").trim();
    if (!accessToken || !accessToken.includes(".")) {
      return json(401, { error: "missing_auth", detail: "Authorization Bearer JWT required." });
    }

    const { data: authData, error: authErr } = await supabase.auth.getUser(accessToken);
    if (authErr || !authData?.user?.id) {
      return json(401, { error: "invalid_auth", detail: authErr?.message ?? "invalid_token" });
    }
    const requesterId = authData.user.id;

    const body = await req.json();
    const orderId = reqString(body["order_id"], "order_id");

    const { data: order, error: orderErr } = await supabase
      .from("orders")
      .select("id, user_id, payment_method, payment_status, currency, delivery_fee")
      .eq("id", orderId)
      .single();
    if (orderErr || !order) return json(404, { error: "order_not_found" });

    if (order.user_id?.toString() !== requesterId) {
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

    const receipt = orderId.replace(/-/g, "").slice(0, 40);
    const auth = basicAuthHeader(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET);

    const rzpRes = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        Authorization: auth,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: amountPaise,
        currency: (order.currency ?? "INR").toString(),
        receipt,
        notes: { supabase_order_id: orderId },
      }),
    });

    const rzpText = await rzpRes.text().catch(() => "");
    if (!rzpRes.ok) {
      return json(400, {
        error: "razorpay_order_create_failed",
        detail: rzpText.slice(0, 2000),
      });
    }

    let parsed: { id?: string } = {};
    try {
      parsed = JSON.parse(rzpText) as { id?: string };
    } catch {
      return json(500, { error: "razorpay_invalid_json" });
    }
    const razorpayOrderId = (parsed.id ?? "").trim();
    if (!razorpayOrderId) {
      return json(500, { error: "razorpay_order_id_missing" });
    }

    return json(200, {
      ok: true,
      razorpay_order_id: razorpayOrderId,
      amount_paise: amountPaise,
    });
  } catch (e) {
    const detail = e instanceof Error ? e.message : String(e);
    return json(500, { error: "create_razorpay_order_failed", detail });
  }
});
