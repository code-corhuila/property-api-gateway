#!/usr/bin/env sh
# The checks the gateway must pass (Annex F, api-gateway.yaml), with no service
# running behind it. Usage: ./tests/smoke.sh http://localhost:8080 [allowed-origin]
set -u
BASE="${1:-http://localhost:8080}"
ORIGIN="${2:-http://localhost:4200}"
fail=0

check() {  # description, expected status, curl arguments...
  desc="$1"; want="$2"; shift 2
  got=$(curl -s -o /dev/null -w '%{http_code}' "$@")
  if [ "$got" = "$want" ]; then echo "  ok    $desc ($got)"; else echo "  FAIL  $desc: want $want, got $got"; fail=1; fi
}

contains() {  # description, expected text, curl arguments...
  desc="$1"; want="$2"; shift 2
  if curl -s -i "$@" | grep -qi -- "$want"; then echo "  ok    $desc"; else echo "  FAIL  $desc: missing $want"; fail=1; fi
}

absent() {  # description, forbidden text, curl arguments...
  desc="$1"; bad="$2"; shift 2
  if curl -s -i "$@" | grep -qi -- "$bad"; then echo "  FAIL  $desc: found $bad"; fail=1; else echo "  ok    $desc"; fi
}

check    "health answers"                          200 "$BASE/health"
contains "health says ok"                          '"status":"ok"' "$BASE/health"
check    "unknown route is 404"                    404 "$BASE/nope"
contains "404 uses the error envelope"             '"error":"NOT_FOUND"' "$BASE/nope"

for path in /api/v1/sagas/reservar /api/v1/reservas /api/v1/pagos/x /api/v1/preferencias /api/v1/logout /api/v1/users/me; do
  check  "protected $path without a credential is 401" 401 "$BASE$path"
done
contains "401 uses the error envelope"             '"error":"UNAUTHORIZED"' "$BASE/api/v1/reservas"
contains "401 carries the traceId it received"     '"traceId":"smoke-401"' -H 'X-Correlation-Id: smoke-401' "$BASE/api/v1/reservas"

for path in /api/v1/propiedades /api/v1/register /api/v1/refresh /api/v1/jwks; do
  check  "public $path needs no credential (its service is down: 503)" 503 "$BASE$path"
done
check    "a protected route with a credential reaches its service (down: 503)" 503 \
         -H 'Authorization: Bearer x' "$BASE/api/v1/sagas/reservar"
contains "503 uses the error envelope"             '"error":"SERVICE_UNAVAILABLE"' "$BASE/api/v1/propiedades"
check    "with every service down the gateway stays healthy" 200 "$BASE/health"

contains "a correlation id is generated"           'X-Correlation-Id:' "$BASE/api/v1/reservas"
contains "the client's correlation id is kept"     'X-Correlation-Id: smoke-1' -H 'X-Correlation-Id: smoke-1' "$BASE/api/v1/reservas"

check    "preflight is allowed"                    204 -X OPTIONS -H "Origin: $ORIGIN" "$BASE/api/v1/sagas/reservar"
contains "CORS allows the front origin"            "Access-Control-Allow-Origin: $ORIGIN" -X OPTIONS -H "Origin: $ORIGIN" "$BASE/api/v1/sagas/reservar"
contains "CORS allows Idempotency-Key"             'Idempotency-Key' -X OPTIONS -H "Origin: $ORIGIN" "$BASE/api/v1/sagas/reservar"
contains "CORS exposes X-Correlation-Id"           'Access-Control-Expose-Headers: X-Correlation-Id, Location' -H "Origin: $ORIGIN" "$BASE/api/v1/reservas"
absent   "an unknown origin gets no CORS grant"    'Access-Control-Allow-Origin' -H 'Origin: http://evil.example' "$BASE/api/v1/reservas"

# Last: it spends the login budget of this IP. 10 attempts pass, the 11th is limited.
i=0
while [ $i -lt 10 ]; do curl -s -o /dev/null -X POST "$BASE/api/v1/login"; i=$((i + 1)); done
check    "the 11th login attempt in 5 minutes is 429" 429 -X POST "$BASE/api/v1/login"
contains "429 uses the error envelope"             '"error":"TOO_MANY_REQUESTS"' -X POST "$BASE/api/v1/login"
contains "429 says when to retry"                  'Retry-After: 30' -X POST "$BASE/api/v1/login"

exit $fail
