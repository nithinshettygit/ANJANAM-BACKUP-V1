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

async function sha256Hex(input: string): Promise<string> {
  const enc = new TextEncoder();
  const digest = await crypto.subtle.digest("SHA-256", enc.encode(input));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Resolve app order: payment notes first, else DB by Razorpay order_id / payment_id. */
async function resolveSupabaseOrderId(
  supabase: ReturnType<typeof createClient>,
  entity: Record<string, unknown>,
): Promise<{ orderId: string; source: "payment_notes" | "razorpay_order_id" | "razorpay_payment_id" } | null> {
  const notes = (entity?.notes ?? {}) as Record<string, unknown>;
  const fromNotes = (notes?.supabase_order_id ?? "").toString().trim();
  if (fromNotes) {
    return { orderId: fromNotes, source: "payment_notes" };
  }

  const rzpOrderId = (entity?.order_id ?? "").toString().trim();
  if (rzpOrderId) {
    const { data, error } = await supabase
      .from("orders")
      .select("id")
      .eq("razorpay_order_id", rzpOrderId)
      .maybeSingle();
    if (!error && data?.id) {
      return { orderId: (data.id as string).toString().trim(), source: "razorpay_order_id" };
    }
  }

  // Refunds usually expose payment_id; payments use entity.id.
  const rzpPaymentId = (entity?.payment_id ?? entity?.id ?? "").toString().trim();
  if (rzpPaymentId) {
    const { data, error } = await supabase
      .from("orders")
      .select("id")
      .eq("razorpay_payment_id", rzpPaymentId)
      .maybeSingle();
    if (!error && data?.id) {
      return { orderId: (data.id as string).toString().trim(), source: "razorpay_payment_id" };
    }
  }

  return null;
}

Deno.serve(async (req) => {
  let dedupIdForFailure: string | null = null;
  if (req.method === "OPTIONS") return new Response("ok", { status: 204, headers: corsHeaders });
  try {
    if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const RAZORPAY_WEBHOOK_SECRET = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") ?? "";
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !RAZORPAY_WEBHOOK_SECRET) return json(500, { error: "missing_secrets" });

    const payload = await req.text();
    const incomingSig = (req.headers.get("x-razorpay-signature") ?? "").trim();
    if (!incomingSig) return json(400, { error: "missing_signature" });
    const expectedSig = await hmacSha256Hex(RAZORPAY_WEBHOOK_SECRET, payload);
    if (!timingSafeEqualHex(expectedSig, incomingSig)) return json(400, { error: "invalid_signature" });

    let body: any = {};
    try {
      body = JSON.parse(payload) as any;
    } catch (_) {
      return json(400, { error: "invalid_payload" });
    }
    const event = (body?.event ?? "").toString().trim();
    const webhookEventId = (body?.payload?.payment?.entity?.id ?? body?.payload?.refund?.entity?.id ?? "").toString().trim();
    const entity = body?.payload?.payment?.entity ?? body?.payload?.refund?.entity ?? {};

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const nowIso = new Date().toISOString();
    const dedupId = webhookEventId.length > 0
      ? `razorpay:${event}:${webhookEventId}`
      : `razorpay:${event}:hash:${await sha256Hex(payload)}`;
    dedupIdForFailure = dedupId;

    const resolved = await resolveSupabaseOrderId(supabase, entity);
    if (!resolved?.orderId) {
      return json(200, { ok: true, ignored: true, reason: "order_unresolved" });
    }
    const orderId = resolved.orderId;

    const { data: existingEvent, error: existingEventErr } = await supabase
      .from("webhook_events")
      .select("id,status,updated_at")
      .eq("event_id", dedupId)
      .maybeSingle();
    if (existingEventErr) return json(500, { error: "webhook_dedup_failed" });
    if (existingEvent && existingEvent.status === "succeeded") {
      return json(200, { ok: true, duplicate: true, event });
    }
    if (existingEvent && existingEvent.status === "processing") {
      const staleThresholdMs = 2 * 60 * 1000;
      const updatedAtMs = Date.parse(String(existingEvent.updated_at ?? ""));
      const isStale = Number.isFinite(updatedAtMs) && (Date.now() - updatedAtMs) > staleThresholdMs;
      if (!isStale) {
        // Never ACK an in-flight dedup event; force upstream retry.
        return json(409, { error: "event_in_progress_retry_later" });
      }
    }
    if (!existingEvent) {
      const ins = await supabase
        .from("webhook_events")
        .insert({
          event_id: dedupId,
          event_type: event,
          payload: body,
          status: "processing",
          last_error: null,
          updated_at: nowIso,
        });
      if (ins.error) return json(500, { error: "webhook_dedup_failed" });
    } else {
      const up = await supabase
        .from("webhook_events")
        .update({ status: "processing", last_error: null, updated_at: nowIso })
        .eq("event_id", dedupId);
      if (up.error) return json(500, { error: "webhook_dedup_failed" });
    }

    const failAndMark = async (code: number, err: string) => {
      await supabase
        .from("webhook_events")
        .update({ status: "failed", last_error: err.slice(0, 1000), updated_at: new Date().toISOString() })
        .eq("event_id", dedupId);
      return json(code, { error: err });
    };

    if (event === "payment.captured") {
      const { data: order, error: orderErr } = await supabase
        .from("orders")
        .select("id,currency,delivery_fee,razorpay_order_id")
        .eq("id", orderId)
        .maybeSingle();
      if (orderErr || !order) return await failAndMark(404, "order_not_found");

      const { data: items, error: itemsErr } = await supabase
        .from("order_items")
        .select("unit_price,quantity")
        .eq("order_id", orderId);
      if (itemsErr || !items || items.length < 1) return await failAndMark(400, "order_items_missing");

      let subtotal = 0;
      for (const it of items) {
        subtotal += Number(it.unit_price ?? 0) * Number(it.quantity ?? 0);
      }
      const expectedPaise = Math.round((subtotal + Number(order.delivery_fee ?? 0)) * 100);
      const payAmount = Number(entity?.amount ?? 0);
      if (!Number.isFinite(payAmount) || payAmount !== expectedPaise) return await failAndMark(409, "amount_mismatch");
      const payCurrency = (entity?.currency ?? "").toString().trim().toUpperCase();
      const orderCurrency = (order.currency ?? "INR").toString().trim().toUpperCase();
      if (!payCurrency || payCurrency !== orderCurrency) return await failAndMark(409, "currency_mismatch");

      const payOrderId = (entity?.order_id ?? "").toString().trim();
      const dbOrderId = (order.razorpay_order_id ?? "").toString().trim();
      // Hard mismatch only when both sides are set and disagree.
      if (payOrderId && dbOrderId && payOrderId !== dbOrderId) {
        return await failAndMark(409, "order_mapping_mismatch");
      }
      // Require at least one Razorpay order id for captured payments.
      if (!payOrderId && !dbOrderId) {
        return await failAndMark(409, "order_mapping_mismatch");
      }

      const patch: Record<string, unknown> = {
        payment_status: "paid",
        status: "processing",
        razorpay_payment_id: entity?.id?.toString() ?? null,
        paid_at: nowIso,
        payment_verified_at: nowIso,
        updated_at: nowIso,
      };
      // Recover linkage if soft-cancel previously cleared DB id (P1) but payment still references order_*.
      if (payOrderId && !dbOrderId) {
        patch.razorpay_order_id = payOrderId;
      }

      const { error: upErr } = await supabase
        .from("orders")
        .update(patch)
        .eq("id", orderId)
        .neq("payment_status", "paid");
      if (upErr) return await failAndMark(500, "order_update_failed");
    } else if (event === "payment.failed") {
      // Do not overwrite orders already marked paid by a successful attempt.
      const { error: upErr } = await supabase
        .from("orders")
        .update({
          payment_status: "failed",
          status: "payment_failed",
          razorpay_payment_id: entity?.id?.toString() ?? null,
          updated_at: nowIso,
        })
        .eq("id", orderId)
        .neq("payment_status", "paid");
      if (upErr) return await failAndMark(500, "order_update_failed");
    } else if (event === "refund.processed") {
      const { error: upErr } = await supabase
        .from("orders")
        .update({
          payment_status: "refunded",
          updated_at: nowIso,
        })
        .eq("id", orderId);
      if (upErr) return await failAndMark(500, "order_update_failed");
    }

    await supabase
      .from("webhook_events")
      .update({ status: "succeeded", last_error: null, updated_at: new Date().toISOString() })
      .eq("event_id", dedupId);

    return json(200, { ok: true, event, resolve_source: resolved.source });
  } catch (e) {
    try {
      const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
      const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY && dedupIdForFailure) {
        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
        await supabase
          .from("webhook_events")
          .update({
            status: "failed",
            last_error: String(e ?? "webhook_failed").slice(0, 1000),
            updated_at: new Date().toISOString(),
          })
          .eq("event_id", dedupIdForFailure);
      }
    } catch (_) {
      // Best-effort only: never mask original webhook failure response.
    }
    return json(500, { error: "webhook_failed" });
  }
});
