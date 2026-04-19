// @ts-nocheck
import { createClient } from "npm:@supabase/supabase-js";
import { resolveRequesterIdentity } from "../_shared/auth.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version, prefer",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function normalizePaymentStatus(params: { paymentStatus: string; orderStatus: string }): "pending" | "paid" | "failed" {
  const paymentStatus = params.paymentStatus.toLowerCase().trim();
  const orderStatus = params.orderStatus.toLowerCase().trim();
  if (paymentStatus === "paid" || orderStatus === "paid" || orderStatus === "processing") {
    return "paid";
  }
  if (
    paymentStatus === "failed" ||
    orderStatus === "payment_failed" ||
    orderStatus === "payment_failed_inventory" ||
    orderStatus === "out_of_stock_after_payment"
  ) {
    return "failed";
  }
  return "pending";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  try {
    if (req.method !== "GET") {
      return json(405, { error: "method_not_allowed" });
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return json(500, { error: "missing_supabase_secrets" });
    }

    const authResult = await resolveRequesterIdentity(req, {
      supabaseUrl: SUPABASE_URL,
      supabaseAnonKey: SUPABASE_ANON_KEY,
    });
    if (!authResult.ok) {
      return json(authResult.code, { error: authResult.error });
    }
    const requesterId = authResult.userId;

    const url = new URL(req.url);
    const orderId = (url.searchParams.get("order_id") ?? "").trim();
    if (!orderId) {
      return json(400, { error: "missing_order_id" });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: { headers: { "Content-Type": "application/json" } },
    });

    const { data: order, error: orderErr } = await supabase
      .from("orders")
      .select("id, user_id, payment_method, payment_status, status")
      .eq("id", orderId)
      .single();
    if (orderErr || !order) {
      return json(404, { error: "order_not_found" });
    }

    const orderUserId = (order.user_id ?? "").toString().trim();
    if (orderUserId !== requesterId) {
      return json(403, { error: "forbidden" });
    }
    if ((order.payment_method ?? "").toString().toLowerCase().trim() !== "razorpay") {
      return json(400, { error: "not_razorpay_order" });
    }

    const status = normalizePaymentStatus({
      paymentStatus: (order.payment_status ?? "").toString(),
      orderStatus: (order.status ?? "").toString(),
    });
    return json(200, { status });
  } catch (_) {
    return json(500, { error: "check_payment_status_failed" });
  }
});
