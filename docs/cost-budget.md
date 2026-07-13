# Cost budget & guardrails

Hard monthly cap: **$15 USD**.

Maturity: **Level 1 learning lab** (not multi-tenant SaaS).

| Decision | Choice | Why |
|----------|--------|-----|
| VPS provider | Hetzner (CX22 when Phase 6) | Cheap, simple, good docs |
| Until Phase 6 | Laptop only ($0) | Local Compose → local k3d/kind |
| LLM | Stub in tests/CI; DeepSeek API when `LLM_MODE=deepseek` | Cheap API; no local GPU |
| Registry | GHCR | Free with GitHub |
| Domain | Defer until Phase 9 (Cloudflare free DNS) | No spend until ingress/TLS |

## Non-negotiable

- No GPU instances in the core path
- Prefer GHCR over paid registries
- GitHub Actions: build on `main` + PRs only (no wide OS matrix)
- If pausing cloud > 7 days: destroy the VPS (see checklist)

## Destroy VPS checklist (when pausing)

1. Confirm nothing unique lives only on the box (git + GHCR hold the truth).
2. `cd infrastructure/terraform/environments/hobby && terraform destroy`
3. Remove Cloudflare DNS A/AAAA pointing at the old IP (if any).
4. Cancel calendar reminder or set a new one for the next lab session.
5. Note spend-to-date in this file under **Spend log**.

## Spend log

| Date | Item | Amount | Notes |
|------|------|--------|-------|
| — | — | $0 | Lab not on cloud yet |

## Upgrade path (only if needed)

- Cap feels too tight → bump to $20–40 Comfort tier (larger VPS), still avoid managed K8s.
- Need a second node for HA practice → add one cheap node, not a second provider.
