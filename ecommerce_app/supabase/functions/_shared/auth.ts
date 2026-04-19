// @ts-nocheck
// Shared auth helpers for Edge Functions.
import { createClient } from "npm:@supabase/supabase-js";

type JsonRecord = Record<string, unknown>;

export function readBearerToken(req: Request): { ok: true; token: string } | { ok: false; code: number; error: string } {
  const authHeader = req.headers.get("authorization") ?? req.headers.get("Authorization") ?? "";
  const header = authHeader.trim();
  if (!header) return { ok: false, code: 401, error: "missing_authorization" };
  if (!/^Bearer\s+/i.test(header)) {
    return { ok: false, code: 401, error: "invalid_authorization_format" };
  }
  const token = header.replace(/^Bearer\s+/i, "").trim();
  if (!token) return { ok: false, code: 401, error: "missing_token" };
  if (!token.includes(".")) return { ok: false, code: 401, error: "invalid_token" };
  return { ok: true, token };
}

export async function verifyJwtUserId(params: {
  supabaseUrl: string;
  supabaseAnonKey: string;
  token: string;
}): Promise<
  | { ok: true; user: { id: string; email: string | null } }
  | { ok: false; code: number; error: string }
> {
  const { supabaseUrl, supabaseAnonKey, token } = params;

  const client = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: {
        Authorization: `Bearer ${token}`,
        apikey: supabaseAnonKey,
      },
    },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data, error } = await client.auth.getUser(token);
  const uid = (data?.user?.id ?? "").toString().trim();
  if (error || !uid) {
    return { ok: false, code: 401, error: "invalid_token" };
  }
  return { ok: true, user: { id: uid, email: data?.user?.email ?? null } };
}

export async function resolveRequesterIdentity(
  req: Request,
  params: {
  supabaseUrl: string;
  supabaseAnonKey: string;
},
): Promise<
  | { ok: true; user: { id: string; email: string | null }; userId: string }
  | { ok: false; code: number; error: string }
> {
  const { supabaseUrl, supabaseAnonKey } = params;

  const bearer = readBearerToken(req);
  if (!bearer.ok) return bearer;

  const verified = await verifyJwtUserId({ supabaseUrl, supabaseAnonKey, token: bearer.token });
  if (!verified.ok) return verified;
  return { ok: true, user: verified.user, userId: verified.user.id };
}

