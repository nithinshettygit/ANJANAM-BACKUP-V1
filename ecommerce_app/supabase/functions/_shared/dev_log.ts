// @ts-nocheck
/** Non-production diagnostics only; keep production logs minimal (errors use console.error). */
export function devLog(...args: unknown[]): void {
  if (Deno.env.get("ENV") === "production") return;
  console.log(...args);
}
