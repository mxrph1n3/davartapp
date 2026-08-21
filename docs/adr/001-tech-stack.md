# ADR-001: Выбор технологического стека

**Статус:** Принято  
**Дата:** 2026-08-06

## Контекст

Нужен стек для MVP мобильного super app дизайн-студии (каталог, проекты, чат) на iOS и Android с backend API.

## Решение

| Слой | Технология |
|------|------------|
| Mobile | Flutter 3.x |
| Backend | NestJS (TypeScript) |
| БД | PostgreSQL 16 |
| Кэш / OTP | Redis 7 |
| Поиск | Meilisearch |
| Файлы | S3-compatible (MinIO dev, Yandex Object Storage prod) |
| Real-time | WebSocket (NestJS) |
| Push | Firebase Cloud Messaging |
| Admin | Next.js (Sprint 5+) |
| Хостинг | Yandex Cloud / Selectel |

## Обоснование

- **Flutter** — один кодбейс для iOS/Android, сильный UI для каталога.
- **NestJS** — быстрый старт, модульная архитектура, WebSocket из коробки.
- **PostgreSQL** — надёжное хранение транзакционных данных.
- **Meilisearch** — быстрый полнотекстовый поиск по каталогу.

## Альтернативы

- React Native + NestJS — если команда сильнее в TypeScript.
- Kotlin Ktor — если приоритет JVM-экосистема, но медленнее MVP.

## Последствия

- Один mobile-разработчик закрывает обе платформы.
- Backend и admin могут шарить TypeScript-типы в будущем.
