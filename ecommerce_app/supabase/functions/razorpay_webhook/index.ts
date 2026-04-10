// @ts-nocheck
import { createClient } from "npm:@supabase/supabase-js";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-razorpay-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
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

function timingSafeEqualHex(a: string, b: string): boolean {
  const aa = a.toLowerCase();
  const bb = b.toLowerCase();
  if (aa.length !== bb.length) return false;
  let out = 0;
  for (let i = 0; i < aa.length; i++) out |= aa.charCodeAt(i) ^ bb.charCodeAt(i);
  return out === 0;
}

function basicAuthHeader(keyId: string, keySecret: string): string {
  return `Basic ${btoa(`${keyId}:${keySecret}`)}`;
}

function str(v: unknown): string {
  if (v == null) return "";
  return String(v).trim();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const RAZORPAY_WEBHOOK_SECRET = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") ?? "";
    const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
    const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !RAZORPAY_WEBHOOK_SECRET) {
      return json(500, { error: "missing_secrets" });
    }

    const payloadText = await req.text();
    const incomingSig = str(req.headers.get("x-razorpay-signature"));
    if (!incomingSig) return json(401, { error: "missing_signature" });
    const expectedSig = await hmacSha256Hex(RAZORPAY_WEBHOOK_SECRET, payloadText);
    if (!timingSafeEqualHex(expectedSig, incomingSig)) {
      return json(401, { error: "invalid_signature" });
    }

    const payload = JSON.parse(payloadText) as any;
    const event = str(payload?.event).toLowerCase();
    const eventId = str(payload?.id || payload?.event_id);
    const paymentEntity = payload?.payload?.payment?.entity ?? {};
    const refundEntity = payload?.payload?.refund?.entity ?? {};

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: { headers: { "Content-Type": "application/json" } },
    });

    async function logWebhook(kind: string, orderId?: string, paymentId?: string, message?: string) {
      try {
        await supabase.from("system_error_logs").insert({
          error_type: `webhook_${kind}`,
          order_id: orderId ?? null,
          payment_id: paymentId ?? null,
          error_message: (message ?? "").slice(0, 2000),
          stack_trace: payloadText.slice(0, 12000),
        });
      } catch (_) {}
    }

    // Atomic dedupe guard: single INSERT protected by unique(event_id).
    // This is race-safe for concurrent webhook deliveries.
    if (!eventId) {
      await logWebhook("missing_event_id", undefined, undefined, "webhook payload has no event id");
      return json(400, { error: "missing_event_id" });
    }
    const dedupeInsert = await supabase
      .from("webhook_events")
      .insert({
        event_id: eventId,
        event_type: event,
        payload: payload,
      });
    if (dedupeInsert.error) {
      const msg = str(dedupeInsert.error.message).toLowerCase();
      if (msg.includes("duplicate key") || msg.includes("webhook_events_event_id_key")) {
        return json(200, { ok: true, duplicate: true, event_id: eventId });
      }
      await logWebhook("dedupe_insert_failed", undefined, undefined, dedupeInsert.error.message);
      return json(500, { error: "webhook_dedupe_failed" });
    }

    async function pushTimeline(orderId: string, status: string, notes: string) {
      try {
        await supabase.from("order_status_history").insert({
          order_id: orderId,
          status,
          notes,
          created_at: new Date().toISOString(),
        });
      } catch (_) {}
    }

    async function findOrderByPayment(paymentId: string, razorpayOrderId: string, noteOrderId: string) {
      if (noteOrderId) {
        const byNote = await supabase.from("orders").select("*").eq("id", noteOrderId).maybeSingle();
        if (byNote.data) return byNote.data;
      }
      if (paymentId) {
        const byPid = await supabase.from("orders").select("*").eq("razorpay_payment_id", paymentId).maybeSingle();
        if (byPid.data) return byPid.data;
      }
      if (razorpayOrderId) {
        const byOid = await supabase.from("orders").select("*").eq("razorpay_order_id", razorpayOrderId).maybeSingle();
        if (byOid.data) return byOid.data;
      }
      return null;
    }

    async function triggerAutoRefund(paymentId: string, amountPaise: number, orderId?: string) {
      if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET || !paymentId || amountPaise <= 0) return;
      const auth = basicAuthHeader(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET);
      const res = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}/refund`, {
        method: "POST",
        headers: { Authorization: auth, "Content-Type": "application/json" },
        body: JSON.stringify({ amount: amountPaise }),
      });
      if (!res.ok) {
        const txt = await res.text().catch(() => "");
        await logWebhook("refund_failed", orderId, paymentId, txt || "webhook_refund_failed");
      }
    }

    if (event === "payment.captured") {
      const paymentId = str(paymentEntity?.id);
      const razorpayOrderId = str(paymentEntity?.order_id);
      const noteOrderId = str(paymentEntity?.notes?.supabase_order_id);
      const order = await findOrderByPayment(paymentId, razorpayOrderId, noteOrderId);
      if (!order) {
        await logWebhook("payment_captured_missing_order", undefined, paymentId, "order_not_found");
        return json(200, { ok: true, ignored: true, reason: "order_not_found", event_id: eventId });
      }

      const paymentStatus = str(order.payment_status).toLowerCase();
      if (paymentStatus === "paid") {
        await logWebhook("payment_captured_idempotent", order.id, paymentId, "already_paid");
        return json(200, { ok: true, idempotent: true, event_id: eventId });
      }

      // Trigger converts reservation in DB trigger when status moves to processing.
      const nowIso = new Date().toISOString();
      const up = await supabase
        .from("orders")
        .update({
          payment_status: "paid",
          status: "processing",
          razorpay_payment_id: paymentId || order.razorpay_payment_id,
          razorpay_order_id: razorpayOrderId || order.razorpay_order_id,
          paid_at: nowIso,
          payment_verified_at: nowIso,
          updated_at: nowIso,
        })
        .eq("id", order.id);

      if (up.error) {
        const message = up.error.message ?? "inventory_reservation_convert_failed";
        const normalized = message.toLowerCase();
        const failureStatus = normalized.includes("insufficient") || normalized.includes("stock")
          ? "out_of_stock_after_payment"
          : "payment_failed_inventory";

        await logWebhook("payment_captured_conversion_failed", order.id, paymentId, message);
        await triggerAutoRefund(paymentId || str(order.razorpay_payment_id), Number(paymentEntity?.amount ?? 0), order.id);
        await supabase
          .from("orders")
          .update({
            status: failureStatus,
            payment_status: "paid",
            refund_status: "processing",
            refund_amount: Number(paymentEntity?.amount ?? 0) || null,
            refund_requested_at: nowIso,
            updated_at: nowIso,
          })
          .eq("id", order.id);

        await pushTimeline(order.id, "payment_received", "Payment received at gateway.");
        await pushTimeline(order.id, "inventory_error_detected", "Inventory conversion failed in webhook flow.");
        await pushTimeline(order.id, "automatic_refund_initiated", "Automatic refund initiated by webhook fallback.");
        return json(200, { ok: true, recovered: true, status: failureStatus, event_id: eventId });
      }

      await pushTimeline(order.id, "payment_verified_webhook", "Payment confirmed by Razorpay webhook.");
      await logWebhook("payment_captured_processed", order.id, paymentId, "marked_paid");
      return json(200, { ok: true, event: "payment.captured", event_id: eventId });
    }

    if (event === "payment.failed") {
      const paymentId = str(paymentEntity?.id);
      const razorpayOrderId = str(paymentEntity?.order_id);
      const noteOrderId = str(paymentEntity?.notes?.supabase_order_id);
      const order = await findOrderByPayment(paymentId, razorpayOrderId, noteOrderId);
      if (!order) {
        await logWebhook("payment_failed_missing_order", undefined, paymentId, "order_not_found");
        return json(200, { ok: true, ignored: true, event_id: eventId });
      }
      await supabase
        .from("orders")
        .update({
          payment_status: "failed",
          status: "payment_failed",
          razorpay_payment_id: paymentId || order.razorpay_payment_id,
          updated_at: new Date().toISOString(),
        })
        .eq("id", order.id);
      await pushTimeline(order.id, "payment_failed_gateway", "Payment marked failed by Razorpay gateway.");
      await logWebhook("payment_failed_processed", order.id, paymentId, "marked_failed");
      return json(200, { ok: true, event: "payment.failed", event_id: eventId });
    }

    if (event === "refund.processed") {
      const refundPaymentId = str(refundEntity?.payment_id);
      const amount = Number(refundEntity?.amount ?? 0);
      const order = await findOrderByPayment(refundPaymentId, "", "");
      if (!order) {
        await logWebhook("refund_processed_missing_order", undefined, refundPaymentId, "order_not_found");
        return json(200, { ok: true, ignored: true, event_id: eventId });
      }
      await supabase
        .from("orders")
        .update({
          refund_status: "refunded",
          refund_amount: amount > 0 ? amount : order.refund_amount,
          refund_processed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", order.id);
      await pushTimeline(order.id, "refund_completed_gateway", "Refund processed at Razorpay gateway.");
      await logWebhook("refund_processed", order.id, refundPaymentId, "refund_marked_refunded");
      return json(200, { ok: true, event: "refund.processed", event_id: eventId });
    }

    await logWebhook("ignored_event", undefined, undefined, `ignored:${event}`);
    return json(200, { ok: true, ignored: true, event, event_id: eventId });
  } catch (e) {
    return json(500, { error: "webhook_failed" });
  }
});
