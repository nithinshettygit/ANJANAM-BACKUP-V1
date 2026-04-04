// @ts-nocheck
import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js";

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
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
    if (!RAZORPAY_KEY_ID.startsWith("rzp_test_")) {
      return json(400, {
        error: "invalid_razorpay_key_mode",
        detail: "RAZORPAY_KEY_ID must be a test key (rzp_test_...) for this flow.",
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: { headers: { "Content-Type": "application/json" } },
    });

    // Auth is required even in test mode to prevent anonymous capture attempts.
    let requesterId: string | null = null;
    const h = authHeader(req);
    const accessTokenRaw = h?.trim() ?? "";
    const tokenPart =
      accessTokenRaw
        .split(/\s+/)
        .filter(Boolean)
        .pop() ?? "";
    const accessToken = tokenPart.replace(/^Bearer$/i, "").trim();
    if (!accessToken || !accessToken.includes(".")) {
      return json(401, {
        error: "missing_auth",
        detail: "Authorization Bearer JWT required.",
      });
    }
    const { data: authData, error: authErr } = await supabase.auth.getUser(accessToken);
    if (authErr || !authData?.user) {
      return json(401, { error: "invalid_auth", detail: authErr?.message ?? "invalid_token" });
    }
    requesterId = authData.user.id;

    const body = await req.json();
    const action = (typeof body["action"] === "string" ? body["action"] : "capture")
      .trim()
      .toLowerCase();

    const auth = basicAuthHeader(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET);

    // Debug mode to quickly validate that this key pair is connected and can read payments.
    if (action === "health") {
      const listRes = await fetch("https://api.razorpay.com/v1/payments?count=3", {
        method: "GET",
        headers: { Authorization: auth },
      });
      const txt = await listRes.text().catch(() => "");
      if (!listRes.ok) {
        return json(400, {
          error: "healthcheck_failed",
          detail: txt.slice(0, 1200),
        });
      }
      let parsed: any = {};
      try {
        parsed = JSON.parse(txt);
      } catch (_) {
        parsed = {};
      }
      const items = Array.isArray(parsed.items) ? parsed.items : [];
      return json(200, {
        ok: true,
        mode: "health",
        payments_seen: items.length,
        sample_payment_ids: items.map((x: any) => x?.id).filter(Boolean),
      });
    }

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
  } catch (e) {
    const detail = e instanceof Error ? e.message : String(e);
    return json(500, { error: "capture_payment_failed", detail });
  }
});

