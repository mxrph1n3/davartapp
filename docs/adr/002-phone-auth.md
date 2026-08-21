# ADR-002: Авторизация только по телефону

**Статус:** Принято  
**Дата:** 2026-08-06

## Контекст

В MVP нужна простая и привычная для российских пользователей авторизация без сложных OAuth-интеграций.

## Решение

Единственный способ входа — **телефон + OTP (SMS)**.

### Flow

```
1. POST /api/auth/send-otp   { phone: "+79001234567" }
2. SMS с 4–6 значным кодом (TTL 5 мин, Redis)
3. POST /api/auth/verify-otp { phone, code }
4. Ответ: { accessToken, refreshToken }
5. POST /api/auth/refresh    { refreshToken }
```

### Безопасность

- Rate limit: 3 SMS на номер за 15 минут
- OTP: 4 цифры, одноразовый
- JWT access: 15 мин, refresh: 30 дней
- Refresh token в secure storage (mobile)

### SMS-провайдер

- Dev: mock (код в логах)
- Prod: SMS.ru или SMSC.ru

## Отклонённые варианты

- Email, Apple ID, Google, VK, Telegram — отложены за пределы MVP.

## Последствия

- Не требуется Sign in with Apple (единственный способ — телефон).
- Упрощённая auth-модель: User.phone — уникальный идентификатор.
- Зависимость от SMS-провайдера и его стоимости.
