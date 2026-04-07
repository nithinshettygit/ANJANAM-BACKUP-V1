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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 204, headers: corsHeaders });
  try {
    if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const RAZORPAY_WEBHOOK_SECRET = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") ?? "";
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !RAZORPAY_WEBHOOK_SECRET) return json(500, { error: "missing_secrets" });

    const payload = await req.text();
    const incomingSig = (req.headers.get("x-razorpay-signature") ?? "").trim();
    if (!incomingSig) return json(401, { error: "missing_signature" });
    const expectedSig = await hmacSha256Hex(RAZORPAY_WEBHOOK_SECRET, payload);
    if (!timingSafeEqualHex(expectedSig, incomingSig)) return json(401, { error: "invalid_signature" });

    const body = JSON.parse(payload) as any;
    const event = (body?.event ?? "").toString().trim();
    const entity = body?.payload?.payment?.entity ?? body?.payload?.refund?.entity ?? {};
    const notes = entity?.notes ?? {};
    const orderId = (notes?.supabase_order_id ?? "").toString().trim();
    if (!orderId) return json(200, { ok: true, ignored: true, reason: "missing_supabase_order_id_note" });

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const nowIso = new Date().toISOString();
    if (event === "payment.captured") {
      await supabase
        .from("orders")
        .update({
          payment_status: "paid",
          status: "processing",
          razorpay_payment_id: entity?.id?.toString() ?? null,
          paid_at: nowIso,
          payment_verified_at: nowIso,
          updated_at: nowIso,
        })
        .eq("id", orderId);
    } else if (event === "payment.failed") {
      await supabase
        .from("orders")
        .update({
          payment_status: "failed",
          status: "payment_failed",
          razorpay_payment_id: entity?.id?.toString() ?? null,
          updated_at: nowIso,
        })
        .eq("id", orderId);
    } else if (event === "refund.processed") {
      await supabase
        .from("orders")
        .update({
          payment_status: "refunded",
          updated_at: nowIso,
        })
        .eq("id", orderId);
    }

    return json(200, { ok: true, event });
  } catch (e) {
    return json(500, { error: "webhook_failed", detail: e instanceof Error ? e.message : String(e) });
  }
});
