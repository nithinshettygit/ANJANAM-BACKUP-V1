#!/usr/bin/env bash
# Build the Flutter web bundle for Firebase Hosting.
# Load tool/web_build.env if present (copy from tool/web_build.env.example).
#
# Usage:
#   ./scripts/build_admin_web.sh
#   BASE_HREF=/admin-app/ ./scripts/build_admin_web.sh
#   DEPLOY=1 ./scripts/build_admin_web.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/tool/web_build.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

: "${SUPABASE_URL:?Set SUPABASE_URL (env or tool/web_build.env)}"
: "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY (env or tool/web_build.env)}"

BASE_HREF="${BASE_HREF:-/}"
DEFINES=(
  "--dart-define=SUPABASE_URL=${SUPABASE_URL}"
  "--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
)
if [[ -n "${SUPABASE_FUNCTIONS_BASE_URL:-}" ]]; then
  DEFINES+=("--dart-define=SUPABASE_FUNCTIONS_BASE_URL=${SUPABASE_FUNCTIONS_BASE_URL}")
fi
if [[ -n "${RAZORPAY_KEY_ID:-}" ]]; then
  DEFINES+=("--dart-define=RAZORPAY_KEY_ID=${RAZORPAY_KEY_ID}")
fi

# HTML renderer: avoids blank page when CanvasKit CDN is blocked. PWA none: fewer stale SW caches.
if ! flutter build web --release --base-href="$BASE_HREF" --web-renderer html --pwa-strategy none "${DEFINES[@]}"; then
  echo "Retrying without --web-renderer / --pwa-strategy (older Flutter)..." >&2
  flutter build web --release --base-href="$BASE_HREF" "${DEFINES[@]}"
fi

if [[ "${DEPLOY:-}" == "1" ]]; then
  firebase deploy --only hosting --project anjanam-app
fi

echo "Output: $ROOT/build/web"
