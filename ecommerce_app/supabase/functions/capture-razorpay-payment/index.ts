// @ts-nocheck
import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js";
import { resolveRequesterIdentity } from "../_shared/auth.ts";
import { devLog } from "../_shared/dev_log.ts";

/** Required for Flutter Web / browser: preflight + cross-origin POST with Authorization. */
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

function basicAuthHeader(keyId: string, keySecret: string): string {
  const raw = `${keyId}:${keySecret}`;
  const encoded = btoa(raw);
  return `Basic ${encoded}`;
}

type RazorpayPayment = {
  id: string;
  status?: string;
  captured?: boolean;
  amount?: number;
  currency?: string;
  order_id?: string;
};

serve(async (req) => {
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
    const auth = basicAuthHeader(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET);

    const orderId = reqString(body["order_id"], "order_id");
    const paymentIdInput = reqString(body["razorpay_payment_id"], "razorpay_payment_id");

    const { data: order, error: orderErr } = await supabase
      .from("orders")
      .select(
        "id, user_id, payment_method, payment_status, razorpay_payment_id, razorpay_order_id, currency, delivery_fee",
      )
      .eq("id", orderId)
      .single();
    if (orderErr || !order) return json(404, { error: "order_not_found" });

    const { data: isAdminData } = await supabase.rpc("is_admin", { uid: requesterId });
    const isAdmin = Boolean(isAdminData);
    if (!isAdmin && order.user_id?.toString() !== requesterId) {
      return json(403, { error: "forbidden" });
    }
    if ((order.payment_method ?? "").toString().toLowerCase() !== "razorpay") {
      return json(400, { error: "not_razorpay_order" });
    }

    const orderPaymentId = (order.razorpay_payment_id ?? "").toString().trim();
    if (orderPaymentId && orderPaymentId !== paymentIdInput) {
      return json(409, { error: "payment_id_mismatch" });
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
      const price = Number((it as any).unit_price ?? 0);
      const qty = Number((it as any).quantity ?? 0);
      subtotal += price * qty;
    }
    const deliveryFee = Number(order.delivery_fee ?? 0);
    const amountPaise = Math.round((subtotal + deliveryFee) * 100);
    if (!(amountPaise > 0)) return json(400, { error: "invalid_capture_amount" });

    const getRes = await fetch(`https://api.razorpay.com/v1/payments/${paymentIdInput}`, {
      method: "GET",
      headers: { Authorization: auth },
    });
    if (!getRes.ok) {
      const detail = await getRes.text().catch(() => "");
      return json(400, {
        error: "payment_lookup_failed",
        detail,
        payment_id: paymentIdInput,
      });
    }
    const payment = (await getRes.json()) as RazorpayPayment;
    const expectedRzOrder = (order.razorpay_order_id ?? "").toString().trim();
    if (expectedRzOrder.length > 0) {
      const payOrderId = (payment.order_id ?? "").toString().trim();
      if (payOrderId !== expectedRzOrder) {
        return json(409, {
          error: "razorpay_order_mismatch",
          detail: "Payment is not linked to the checkout order for this purchase.",
          expected_order_id: expectedRzOrder,
          payment_order_id: payOrderId || null,
        });
      }
    }
    const alreadyCaptured = payment.captured === true || payment.status === "captured";
    if (alreadyCaptured) {
      return json(200, {
        ok: true,
        capture_status: "already_captured",
        payment_status: payment.status ?? "captured",
      });
    }

    const capRes = await fetch(`https://api.razorpay.com/v1/payments/${paymentIdInput}/capture`, {
      method: "POST",
      headers: {
        Authorization: auth,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        amount: String(amountPaise),
        currency: (order.currency ?? "INR").toString(),
      }),
    });
    if (!capRes.ok) {
      const detail = await capRes.text().catch(() => "");
      return json(400, {
        error: "payment_capture_failed",
        detail,
        payment_id: paymentIdInput,
        expected_amount_paise: amountPaise,
      });
    }
    const cap = (await capRes.json()) as RazorpayPayment;
    const capturedNow = cap.captured === true || cap.status === "captured";
    if (!capturedNow) {
      return json(400, { error: "payment_capture_unconfirmed" });
    }
    return json(200, {
      ok: true,
      capture_status: "captured_now",
      payment_status: cap.status ?? "captured",
    });
  } catch (_) {
    return json(500, { error: "capture_payment_failed" });
  }
});

