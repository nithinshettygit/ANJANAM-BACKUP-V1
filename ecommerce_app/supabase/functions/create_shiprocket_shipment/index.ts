// @ts-nocheck
/**
 * Admin-only: create Shiprocket adhoc order, persist shipment metadata on `orders`.
 * Secrets: SHIPROCKET_EMAIL, SHIPROCKET_PASSWORD (Supabase Edge secrets).
 * Optional: SHIPROCKET_PICKUP_LOCATION default used only when client omits pickup_location.
 */
import { createClient } from "npm:@supabase/supabase-js";
import { resolveRequesterIdentity } from "../_shared/auth.ts";
import { devLog } from "../_shared/dev_log.ts";

const SHIPROCKET_BASE = "https://apiv2.shiprocket.in";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version, prefer",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  /** Browsers cache preflight; 204 must have no body (RFC 7231) or some stacks strip CORS. */
  "Access-Control-Max-Age": "86400",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function sanitizeChannelOrderId(uuid: string): string {
  const compact = uuid.replace(/-/g, "");
  return compact.length <= 50 ? compact : compact.slice(0, 50);
}

function parseDimensionsCm(raw: string | null | undefined): { l: number; b: number; h: number } {
  const d = (raw ?? "").trim();
  if (!d) return { l: 20, b: 15, h: 10 };
  const parts = d.split(/[x×]/i).map((s) => parseFloat(s.trim())).filter((n) => !Number.isNaN(n));
  if (parts.length >= 3) return { l: parts[0], b: parts[1], h: parts[2] };
  if (parts.length === 1) return { l: parts[0], b: parts[0], h: parts[0] };
  return { l: 20, b: 15, h: 10 };
}

function splitCustomerName(full: string): { first: string; last: string } {
  const t = full.trim();
  if (!t) return { first: "Customer", last: "." };
  const sp = t.indexOf(" ");
  if (sp <= 0) return { first: t.slice(0, 80), last: "." };
  return { first: t.slice(0, sp).trim() || "Customer", last: t.slice(sp + 1).trim() || "." };
}

async function shiprocketLogin(email: string, password: string): Promise<string> {
  const res = await fetch(`${SHIPROCKET_BASE}/v1/external/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const message = typeof data?.message === "string" ? data.message : "auth_failed";
    console.error("shiprocket_auth_failed", { status: res.status, message });
    throw new Error(`shiprocket_auth_failed:${message}`);
  }
  const token = data?.token ?? data?.data?.token;
  if (typeof token !== "string" || !token.trim()) {
    console.error("shiprocket_auth_missing_token");
    throw new Error("shiprocket_auth_failed:missing_token");
  }
  return token.trim();
}

async function shiprocketCreateAdhoc(
  token: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const res = await fetch(`${SHIPROCKET_BASE}/v1/external/orders/create/adhoc`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(payload),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const message = typeof data?.message === "string" ? data.message : "create_failed";
    const errors = typeof data?.errors === "string"
      ? data.errors
      : Array.isArray(data?.errors)
      ? data.errors.join(", ")
      : "";
    console.error("shiprocket_create_failed", {
      status: res.status,
      message,
      errors,
    });
    const detail = [message, errors]
      .filter((s) => s != null && String(s).trim().length > 0)
      .join(" | ");
    throw new Error(`shiprocket_create_failed:${detail || "create_failed"}`);
  }
  return data as Record<string, unknown>;
}

async function shiprocketTryAssignAwb(
  token: string,
  shipmentId: number,
): Promise<Record<string, unknown> | null> {
  try {
    const res = await fetch(`${SHIPROCKET_BASE}/v1/external/courier/assign/awb`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ shipment_id: shipmentId }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      console.error("shiprocket_assign_awb_skipped", { status: res.status, message: data?.message });
      return null;
    }
    return data as Record<string, unknown>;
  } catch (e) {
    console.error("shiprocket_assign_awb_error", String(e));
    return null;
  }
}

function pickShipmentId(obj: Record<string, unknown>): number | null {
  function toId(v: unknown): number | null {
    if (typeof v === "number" && Number.isFinite(v)) return v;
    if (typeof v === "string" && /^\d+$/.test(v.trim())) return parseInt(v.trim(), 10);
    if (Array.isArray(v)) {
      for (const item of v) {
        const n = toId(item);
        if (n != null) return n;
      }
    }
    if (v && typeof v === "object") {
      const rec = v as Record<string, unknown>;
      const n =
        toId(rec.shipment_id) ??
        toId(rec.shipmentId) ??
        toId(rec.id) ??
        toId(rec.awb_data);
      if (n != null) return n;
    }
    return null;
  }

  const candidates = [
    obj.shipment_id,
    obj.shipmentId,
    obj.shipments,
    obj.data,
    obj.payload,
    obj.response,
    (obj.payload as Record<string, unknown> | undefined)?.shipment_id,
    (obj.payload as Record<string, unknown> | undefined)?.shipments,
    (obj.data as Record<string, unknown> | undefined)?.shipment_id,
    (obj.data as Record<string, unknown> | undefined)?.shipments,
    (obj.response as Record<string, unknown> | undefined)?.shipment_id,
    (obj.response as Record<string, unknown> | undefined)?.shipments,
  ];
  for (const c of candidates) {
    const n = toId(c);
    if (n != null) return n;
  }
  return null;
}

function pickShiprocketOrderRef(obj: Record<string, unknown>): string | null {
  function pick(v: unknown): string | null {
    if (typeof v === "number" && Number.isFinite(v)) return String(v);
    if (typeof v === "string" && v.trim().length > 0) return v.trim();
    if (Array.isArray(v)) {
      for (const x of v) {
        const s = pick(x);
        if (s) return s;
      }
    }
    if (v && typeof v === "object") {
      const r = v as Record<string, unknown>;
      return (
        pick(r.order_id) ??
        pick(r.channel_order_id) ??
        pick(r.id) ??
        pick(r.data) ??
        pick(r.payload) ??
        pick(r.response)
      );
    }
    return null;
  }
  return pick(obj);
}

/** Shiprocket returns HTTP 200 with `message` + `data.data[]` (or `data` as array) listing valid `pickup_location` names when the requested pickup is wrong. */
function extractSuggestedPickupLocations(obj: Record<string, unknown>): string[] {
  const out: string[] = [];
  const root = obj.data;
  if (root == null) return out;
  let rows: unknown[] = [];
  if (Array.isArray(root)) {
    rows = root;
  } else if (typeof root === "object") {
    const inner = (root as Record<string, unknown>).data;
    if (Array.isArray(inner)) rows = inner;
  }
  for (const row of rows) {
    if (row == null || typeof row !== "object") continue;
    const pl = (row as Record<string, unknown>).pickup_location;
    if (typeof pl === "string" && pl.trim().length > 0) out.push(pl.trim());
  }
  return [...new Set(out)];
}

function pickAwbAndCourier(
  createRes: Record<string, unknown>,
  assignRes: Record<string, unknown> | null,
): { awb: string | null; courier: string | null; trackUrl: string | null } {
  const from = { ...createRes, ...(assignRes ?? {}) };
  const awb =
    (typeof from.awb_code === "string" && from.awb_code) ||
    (typeof from.awb === "string" && from.awb) ||
    (typeof (from as { response?: { awb_code?: string } }).response?.awb_code === "string" &&
      (from as { response: { awb_code: string } }).response.awb_code) ||
    null;
  const courier =
    (typeof from.courier_name === "string" && from.courier_name) ||
    (typeof (from as { courier?: string }).courier === "string" && (from as { courier: string }).courier) ||
    null;
  let trackUrl =
    (typeof from.etrack_url === "string" && from.etrack_url) ||
    (typeof from.tracking_url === "string" && from.tracking_url) ||
    null;
  if (!trackUrl && awb) {
    trackUrl = `https://shiprocket.co/tracking/${encodeURIComponent(awb)}`;
  }
  return { awb: awb?.trim() || null, courier: courier?.trim() || null, trackUrl };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  try {
    if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const SHIPROCKET_EMAIL = Deno.env.get("SHIPROCKET_EMAIL") ?? "";
    const SHIPROCKET_PASSWORD = Deno.env.get("SHIPROCKET_PASSWORD") ?? "";
    const DEFAULT_PICKUP = (Deno.env.get("SHIPROCKET_PICKUP_LOCATION") ?? "Primary").trim() || "Primary";

    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return json(500, { error: "missing_supabase_env" });
    }
    if (!SHIPROCKET_EMAIL || !SHIPROCKET_PASSWORD) {
      return json(500, { error: "missing_shiprocket_secrets" });
    }

    const body = await req.json().catch(() => ({}));

    const auth = await resolveRequesterIdentity(req, {
      supabaseUrl: SUPABASE_URL,
      supabaseAnonKey: SUPABASE_ANON_KEY,
    });
    if (!auth.ok) return json(auth.code, { error: auth.error });
    const uid = auth.userId;
    devLog(`auth_ok user_id=${uid}`);

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: isActiveAdmin, error: adminCheckErr } = await adminClient.rpc(
      "is_active_admin",
      { uid },
    );
    if (adminCheckErr || isActiveAdmin !== true) {
      console.error("create_shiprocket_shipment_unauthorized", {
        user_id: uid,
        reason: adminCheckErr?.message ?? "not_active_admin",
      });
      return json(403, { error: "not_admin" });
    }

    const orderId = typeof body?.order_id === "string" ? body.order_id.trim() : "";
    if (!orderId) return json(400, { error: "missing_order_id" });

    let pickupLocation = typeof body?.pickup_location === "string" ? body.pickup_location.trim() : "";
    if (!pickupLocation) pickupLocation = DEFAULT_PICKUP;

    const { data: order, error: orderErr } = await adminClient
      .from("orders")
      .select(
        "id, user_id, status, currency, delivery_fee, payment_method, payment_status, created_at, " +
          "shipping_full_name, shipping_phone, shipping_address_line, shipping_city, shipping_postal_code, shipping_state, " +
          "customer_email, package_weight_kg, package_dimensions_cm, " +
          "shipment_id, delivery_method, delivery_status, tracking_number, courier_name",
      )
      .eq("id", orderId)
      .single();

    if (orderErr || !order) {
      return json(404, { error: "order_not_found" });
    }

    const stateOverride = typeof body?.shipping_state === "string" ? body.shipping_state.trim() : "";
    if (stateOverride.length >= 2) {
      await adminClient.from("orders").update({ shipping_state: stateOverride }).eq("id", orderId);
      order.shipping_state = stateOverride;
    }

    const existingShipment = (order.shipment_id ?? "").toString().trim();
    if (existingShipment.length > 0) {
      return json(409, { error: "shipment_already_exists" });
    }
    const dm = (order.delivery_method ?? "").toString().trim().toLowerCase();
    const priorDelivery = (order.delivery_status ?? "").toString().trim().toLowerCase();
    const shiprocketRedoAfterCancel = dm === "shiprocket_delivery" && priorDelivery === "cancelled";
    if (dm === "shiprocket_delivery" && !shiprocketRedoAfterCancel) {
      return json(409, { error: "shipment_already_exists" });
    }

    const st = (order.status ?? "").toString().trim().toLowerCase();
    const allowedStatus = new Set(["processing", "packed", "shipped", "out_for_delivery"]);
    if (!allowedStatus.has(st)) {
      return json(400, { error: "invalid_order_status", detail: st });
    }

    const pm = (order.payment_method ?? "").toString().trim().toLowerCase();
    const ps = (order.payment_status ?? "").toString().trim().toLowerCase();
    if (pm === "razorpay" && ps !== "paid") {
      return json(400, { error: "payment_not_completed" });
    }

    const { data: items, error: itemsErr } = await adminClient
      .from("order_items")
      .select("title, unit_price, quantity, product_id, variant_id")
      .eq("order_id", orderId);
    if (itemsErr || !items?.length) {
      return json(400, { error: "order_items_missing" });
    }

    const fullName = (order.shipping_full_name ?? "").toString().trim() || "Customer";
    const phone = (order.shipping_phone ?? "").toString().replace(/\D/g, "").slice(-10);
    if (phone.length !== 10) {
      return json(400, { error: "invalid_shipping_phone" });
    }
    const addr = (order.shipping_address_line ?? "").toString().trim();
    const city = (order.shipping_city ?? "").toString().trim();
    const pin = (order.shipping_postal_code ?? "").toString().trim();
    const state = (order.shipping_state ?? "").toString().trim() || city || "India";
    if (addr.length < 3 || city.length < 2 || !/^\d{6}$/.test(pin)) {
      return json(400, { error: "invalid_shipping_address" });
    }

    const emailRaw = (order.customer_email ?? "").toString().trim();
    const email = emailRaw.includes("@") ? emailRaw : `${order.user_id}@orders.local`;

    const productIds = (items as Record<string, unknown>[])
      .map((r) => (r.product_id ?? "").toString().trim())
      .filter((id) => id.length > 0);
    const variantIds = (items as Record<string, unknown>[])
      .map((r) => (r.variant_id ?? "").toString().trim())
      .filter((id) => id.length > 0);
    const weightByProductId = new Map<string, number>();
    const dimsByProductId = new Map<string, string>();
    if (productIds.length > 0) {
      const uniq = [...new Set(productIds)];
      const { data: prodRows } = await adminClient
        .from("products")
        .select("id, weight, dimensions")
        .in("id", uniq);
      for (const p of (prodRows ?? []) as Record<string, unknown>[]) {
        const id = (p.id ?? "").toString().trim();
        if (!id) continue;
        const w = Number(p.weight);
        if (Number.isFinite(w) && w > 0) weightByProductId.set(id, w);
        const d = (p.dimensions ?? "").toString().trim();
        if (d) dimsByProductId.set(id, d);
      }
    }
    const weightByVariantId = new Map<string, number>();
    const dimsByVariantId = new Map<string, string>();
    if (variantIds.length > 0) {
      const uniq = [...new Set(variantIds)];
      const { data: variantRows } = await adminClient
        .from("product_variants")
        .select("id, weight, dimensions")
        .in("id", uniq);
      for (const v of (variantRows ?? []) as Record<string, unknown>[]) {
        const id = (v.id ?? "").toString().trim();
        if (!id) continue;
        const w = Number(v.weight);
        if (Number.isFinite(w) && w > 0) weightByVariantId.set(id, w);
        const d = (v.dimensions ?? "").toString().trim();
        if (d) dimsByVariantId.set(id, d);
      }
    }

    let subTotal = 0;
    let derivedWeight = 0;
    let derivedDimensions = "";
    const orderItems = (items as Record<string, unknown>[]).map((row) => {
      const title = (row.title ?? "Item").toString();
      const qty = Number(row.quantity) || 1;
      const price = Number(row.unit_price) || 0;
      subTotal += price * qty;
      const pid = (row.product_id ?? "").toString().trim();
      const vid = (row.variant_id ?? "").toString().trim();
      const sku = pid.slice(0, 40) || "SKU";
      const pw = (vid ? weightByVariantId.get(vid) : undefined) ?? weightByProductId.get(pid) ?? 0;
      if (pw > 0) derivedWeight += pw * qty;
      const dims =
        ((vid ? dimsByVariantId.get(vid) : undefined) ?? dimsByProductId.get(pid) ?? "").trim();
      if (!derivedDimensions && dims.length > 0) {
        derivedDimensions = dims;
      }
      return {
        name: title.slice(0, 200),
        sku,
        units: qty,
        selling_price: price,
      };
    });
    const fee = Number(order.delivery_fee) || 0;
    subTotal += fee;

    const w = order.package_weight_kg != null ? Number(order.package_weight_kg) : derivedWeight;
    const weight = !Number.isFinite(w) || w <= 0 ? 0.5 : w;
    const dimsSource =
      (order.package_dimensions_cm ?? "").toString().trim() || derivedDimensions || "20x15x10";
    const { l, b, h } = parseDimensionsCm(dimsSource);

    const { first, last } = splitCustomerName(fullName);
    const orderDate = new Date(order.created_at ?? Date.now());
    const orderDateStr = `${orderDate.getFullYear()}-${String(orderDate.getMonth() + 1).padStart(2, "0")}-` +
      `${String(orderDate.getDate()).padStart(2, "0")} ${String(orderDate.getHours()).padStart(2, "0")}:` +
      `${String(orderDate.getMinutes()).padStart(2, "0")}`;

    const paymentMethod = pm === "cod" ? "COD" : "Prepaid";

    const adhocPayload = {
      order_id: sanitizeChannelOrderId(orderId),
      order_date: orderDateStr,
      pickup_location: pickupLocation,
      billing_customer_name: first,
      billing_last_name: last,
      billing_address: addr,
      billing_city: city,
      billing_pincode: pin,
      billing_state: state,
      billing_country: "India",
      billing_email: email,
      billing_phone: phone,
      shipping_is_billing: true,
      order_items: orderItems,
      payment_method: paymentMethod,
      sub_total: Math.round(subTotal * 100) / 100,
      length: l,
      breadth: b,
      height: h,
      weight,
    };

    const srToken = await shiprocketLogin(SHIPROCKET_EMAIL, SHIPROCKET_PASSWORD);
    let created = await shiprocketCreateAdhoc(srToken, adhocPayload);
    let shipmentNum = pickShipmentId(created);

    if (shipmentNum == null) {
      const suggestions = extractSuggestedPickupLocations(created);
      for (const alt of suggestions) {
        if (!alt || alt === pickupLocation) continue;
        try {
          const retryPayload = { ...adhocPayload, pickup_location: alt };
          const createdRetry = await shiprocketCreateAdhoc(srToken, retryPayload);
          const sid = pickShipmentId(createdRetry);
          if (sid != null) {
            devLog("shiprocket_pickup_retry_ok", {
              previous_pickup: pickupLocation,
              used_pickup: alt,
            });
            created = createdRetry;
            shipmentNum = sid;
            break;
          }
        } catch (e) {
          console.error("shiprocket_pickup_retry_error", alt, String(e));
        }
      }
    }

    const shiprocketOrderRef = pickShiprocketOrderRef(created);

    const assignRes = shipmentNum == null ? null : await shiprocketTryAssignAwb(srToken, shipmentNum);
    const { awb, courier, trackUrl } = pickAwbAndCourier(created, assignRes);
    const courierResolved =
      courier ?? (typeof created.courier_name === "string" ? created.courier_name : null);

    const shipmentIdStr = shipmentNum != null ? String(shipmentNum) : "";
    if (!shipmentIdStr) {
      console.error("shiprocket_missing_shipment_id", JSON.stringify(created).slice(0, 900));
      return json(502, {
        error: "shiprocket_unexpected_response",
        detail:
          `Shiprocket did not return shipment_id. Check pickup_location matches a warehouse in Shiprocket (see Edge logs shiprocket_missing_shipment_id). order_ref=${shiprocketOrderRef ?? "none"}, keys=${Object.keys(created).join(", ")}`,
      });
    }
    const updateRow: Record<string, unknown> = {
      delivery_method: "shiprocket_delivery",
      shipping_provider: "Shiprocket",
      shipment_id: shipmentIdStr,
      awb_code: awb,
      tracking_url: trackUrl,
      shipment_status: "shipment_created",
      delivery_status: "created",
      // Do not set shipped_at here — it blocked customer cancel requests while status was still processing/packed.
      tracking_number: awb ?? order.tracking_number,
      courier_name: courierResolved ?? order.courier_name,
    };

    const { error: upErr } = await adminClient.from("orders").update(updateRow).eq("id", orderId);
    if (upErr) {
      console.error("order_update_failed", upErr.message);
      return json(500, { error: "persist_failed" });
    }

    return json(200, {
      shipment_id: shipmentIdStr,
      awb_code: awb,
      courier_name: courierResolved ?? updateRow.courier_name,
      tracking_url: trackUrl,
      shipment_status: "shipment_created",
      warning: null,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "internal_error";
    if (msg.startsWith("shiprocket_auth_failed")) {
      const detail = msg.split(":").slice(1).join(":").trim();
      return json(502, {
        error: "shiprocket_auth_failed",
        detail: detail || "Shiprocket auth failed",
      });
    }
    if (msg.startsWith("shiprocket_create_failed")) {
      const detail = msg.split(":").slice(1).join(":").trim();
      return json(502, {
        error: "shiprocket_create_failed",
        detail: detail || "Shiprocket shipment creation failed",
      });
    }
    console.error("create_shiprocket_shipment_error", String(e));
    return json(500, { error: "internal_error" });
  }
});
