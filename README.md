# property-api-gateway

> Single entry point: authentication filter, routing and rate limiting

Part of the **Pms_Property** distributed system, Grupo 2. Governance and
documentation live in [`property-docs`](https://github.com/code-corhuila/property-docs).

The only door into the system (norm 5.6, Annex F), and the only service that
publishes a port to the host: `http://localhost:8080` in `develop`. It is NGINX
**configuration, not code**: no business rule and no database. The routing table
is the one of `07-api/contracts/openapi/api-gateway.yaml`.

```
nginx/nginx.conf                       global settings, JSON access log with correlationId
nginx/conf.d/00-resolver.conf          per-request DNS: a service that is down does not take the gateway down
nginx/conf.d/10-security.conf          rate-limit zones (general and login), correlation id, the credential filter
nginx/templates/15-cors.conf.template  the CORS origin, from CORS_ALLOWED_ORIGIN at start-up
nginx/conf.d/20-server.conf            the server on 8080, the gateway's own errors, every route file
nginx/snippets/headers.conf            headers every response carries (CORS, security, X-Correlation-Id)
nginx/snippets/protected.conf          the credential filter of a protected route
nginx/snippets/public.conf             the preflight of a public route
nginx/routes/<domain>.conf             ONE file per domain
tests/smoke.sh                         the checks the gateway must pass
```

## Routing table

| Public path | Routed to | Credential filter |
|---|---|---|
| `/api/v1/sagas` | `workflow:3006` | required |
| `/api/v1/reservas` | `booking-api:3001` | required |
| `/api/v1/pagos` | `payment-api:3003` | required |
| `/api/v1/propiedades` | `catalog-api:3002` | none — public |
| `/api/v1/register`, `/api/v1/login`, `/api/v1/refresh`, `/api/v1/jwks` | `identity-api:3004` | none — public |
| `/api/v1/logout`, `/api/v1/users` | `identity-api:3004` | required |
| `/api/v1/preferencias` | `notification-api:3005` | required |
| `/health` | the gateway itself | none |

## What the gateway does — and what it does not

| Responsibility | Where |
|---|---|
| Route each path to the service that owns it | here |
| Reject a protected request that carries **no** `Authorization` header: `401 UNAUTHORIZED` | here (cheap filter) |
| **Validate** the token (signature, expiry, claims) | **each service**, never here |
| Rate limit: 10 requests/s per client; `POST /api/v1/login` 10 attempts per IP in 5 minutes (A07) → `429` with `Retry-After` | here |
| CORS: only `CORS_ALLOWED_ORIGIN` (the origin of `property-front`, `http://localhost:4200` by default) | here |
| Reuse or create `X-Correlation-Id`, pass it to the service, return it, log it | here |
| Its own errors with the common envelope: `401`, `404`, `429`, `503` (only on the route whose service is down) | here |
| Business rules | never here |

## Run

```bash
docker network create platform              # once per machine
docker compose -f deploy/compose.yml up -d --build
./tests/smoke.sh http://localhost:8080
```

The image and its checks, as the CI runs them:

```bash
docker build -f deploy/Dockerfile -t gateway .
docker run --rm gateway nginx -t
```

## Adding a domain

1. Add `nginx/routes/<domain>.conf` with its `location` blocks, using a variable
   in `proxy_pass`, and `include` `snippets/protected.conf` or `snippets/public.conf`.
2. Add its rows to the routing table of `api-gateway.yaml` and of this README.
3. Run `tests/smoke.sh`.

## Branching

Three permanent branches. **None of them accepts a direct commit** — you enter through a child
branch and leave through a Pull Request.

```
develop  <--PR--  feat/... fix/... chore/...
qa       <--PR--  hu-<story>-qa
main     <--PR--  release/...  hotfix/...
```

Promotion happens **by re-application** (`git cherry-pick -x`), never by merging one permanent
branch into another: `merge develop -> qa` and `merge qa -> main` do not exist in this model.

`main` requires **1 approval from `ariel5253`**. On `develop` and `qa` the team sets its own review
rule.

Full policy: `00-governance/branching-policy.md` and `00-governance/git-conventions.md` in
`property-docs`.
