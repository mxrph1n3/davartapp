# OWASP Top 10 — Security Review (MVP)

Дата: 2026-08-06  
Статус: **Pre-launch review**

| # | Риск | Статус | Митигация в Davart |
|---|------|--------|-------------------|
| A01 | Broken Access Control | ✅ | JWT guard, RBAC по userId на orders/projects/documents/chats |
| A02 | Cryptographic Failures | ✅ | HTTPS в prod, JWT secret, secure storage на mobile |
| A03 | Injection | ✅ | Prisma ORM, ValidationPipe whitelist |
| A04 | Insecure Design | ⚠️ | OTP mock в dev; prod требует SMS_PROVIDER |
| A05 | Security Misconfiguration | ✅ | helmet, CORS configurable, dev endpoints blocked in prod |
| A06 | Vulnerable Components | ⚠️ | `npm audit` в CI; регулярные обновления |
| A07 | Auth Failures | ✅ | OTP rate limit, refresh tokens, JWT expiry |
| A08 | Data Integrity | ✅ | Prisma transactions для orders/cart |
| A09 | Logging & Monitoring | ✅ | Sentry (optional), structured logs, runbook |
| A10 | SSRF | ✅ | Presigned URLs только для S3; нет user-controlled fetch |

## Дополнительные меры

- Global rate limit: 120 req/min (`@nestjs/throttler`)
- OTP rate limit в Redis (per phone)
- File upload через presigned URL (не через API body)
- WebSocket auth via JWT query token
- Secrets в env, не в репозитории

## Рекомендации перед prod

- [ ] Включить `SENTRY_DSN`
- [ ] Настроить `CORS_ORIGIN`
- [ ] Ротация `JWT_SECRET`
- [ ] WAF / reverse proxy (nginx, Cloudflare)
- [ ] Penetration test перед публичным launch
