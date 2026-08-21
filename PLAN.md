# Davart App — Master Plan

> Единый документ планирования и разработки.  
> Обновляется по мере прогресса. Текущий статус — в конце файла.

**Версия:** 2.0  
**Дата:** 2026-08-17  
**Платформы:** iOS / Android + CRM Web  
**Тип:** Экосистема (mobile + CRM) · комплектация и логистика дизайн-студии

**Источники требований:**
- v1.0–1.1 — mobile MVP (Sprint 0–13) ✅  
- v2.0 — ТЗ «Мобильное приложение и CRM» (экосистема) → [§18](#18-экосистема-mobile--crm-тз-v20)

---

## Содержание

1. [Концепция](#1-концепция)
2. [Ограничения и решения](#2-ограничения-и-решения)
3. [Технологический стек](#3-технологический-стек)
4. [Структура репозитория](#4-структура-репозитория)
5. [Архитектура](#5-архитектура)
6. [Навигация приложения](#6-навигация-приложения)
7. [Модули и scope MVP](#7-модули-и-scope-mvp)
8. [Фазы и спринты](#8-фазы-и-спринты)
9. [API-контракты (высокий уровень)](#9-api-контракты-высокий-уровень)
10. [Модель данных](#10-модель-данных)
11. [Интеграции](#11-интеграции)
12. [Нефункциональные требования](#12-нефункциональные-требования)
13. [Риски](#13-риски)
14. [Метрики успеха](#14-метрики-успеха)
15. [Текущий статус](#15-текущий-статус)
16. [Спринты по правкам (post-audit)](#16-спринты-по-правкам-post-audit)
17. [Клиент vs сотрудник (mobile)](#17-клиент-vs-сотрудник-mobile) — *переходная модель Sprint 13*
18. [Экосистема Mobile + CRM (ТЗ v2.0)](#18-экосистема-mobile--crm-тз-v20)

---

## 1. Концепция

Единая цифровая экосистема дизайн-студии: **замкнутый контур** от первичного брифа до отгрузки товаров — mobile для клиента/поля + CRM для комплектации.

- интернет-магазин / каталог комплектации;
- проекты и брифы;
- мессенджер (личные и проектные чаты);
- корзина и заказы **без онлайн-оплаты** (сопровождение комплектатором);
- документы и медиа проекта;
- CRM web (Master-Detail) для комплектаторов и администрации.

**Стресс-тест процессов:** партнёр «Геометрика» (отдельное юрлицо) — обкатка на малых оборотах до масштабирования бренда студии.

**Главный экран клиента:** Каталог (с выбором активного проекта).  
**Главный экран поля (дизайнер/комплектатор):** Чаты.  
**Главный экран CRM:** таблица клиентов (Master) + детализация (Detail).

**Целевые роли (ТЗ v2.0 → Sprint 14+):**

| Роль | Код | Права (кратко) |
|------|-----|----------------|
| Клиент | `client` | [FR-01] Свои проекты, мессенджер, каталог, наполнение корзины проекта |
| Дизайнер | `designer` | [FR-02] «Мои проекты», корзины закреплённых клиентов, документы, чат |
| Комплектатор / Менеджер | `complectator` | [FR-03] Участники проектов, товарная база, заказы, поставщики, логистика |
| Администратор (Artur Mode) | `admin` | [FR-04] Полный доступ, назначение ролей, все БД, аналитика |

Один телефон = одна роль. Регистрация по OTP → всегда `client`; повышение — только админом в CRM.

**Переходная модель в коде сейчас:** `client` \| `staff` ([§17](#17-клиент-vs-сотрудник-mobile)) — будет разложена на роли выше в Sprint 14.

Подробности экосистемы: [§18](#18-экосистема-mobile--crm-тз-v20).

---

## 2. Ограничения и решения

| # | Решение | Обоснование |
|---|---------|-------------|
| 1 | Авторизация **только по телефону** (OTP, SMS.ru) | Простота, нет OAuth / Sign in with Apple |
| 2 | **Нет платежей** в приложении | Заказ = заявка; оплата офлайн (счёт, договор) |
| 3 | Mobile + CRM на **одной БД/API** | Единый контур, без дублирования |
| 4 | Хостинг в РФ | 152-ФЗ; CRM — Reg.ru / домен 3-го уровня зоны DA art |
| 5 | Modular Monolith на старте | Быстрый TTM; выделение сервисов при росте |
| 6 | Одно Flutter-приложение, shell по роли | Не два стора; ACL на API |
| 7 | Один номер телефона → одна роль | Нет путаницы ролей на одном аккаунте |
| 8 | Default role = `client`; elevate вручную | Анти-abuse; Artur Mode назначает привилегии |
| 9 | Чат «Davart» у клиента — **общий inbox** команды | Не персональный менеджер на старте (§17) |
| 10 | **[ARCH-01] Корзина привязана к Проекту**, не к Клиенту | Нет смешивания закупок разных объектов |
| 11 | **Client ↔ Project = M2M** | Несколько объектов у клиента; несколько клиентов у проекта (семья) |
| 12 | Онлайн-оплата / AI / комнаты в корзине / полная аналитика | **v2 Phase 2** (после Sprint 21) |
| 13 | Геометрика как стресс-тест процессов | Малые обороты → меньше репутационный риск студии |

---

## 3. Технологический стек

| Слой | Технология | Версия |
|------|------------|--------|
| Mobile | Flutter | 3.x |
| State management | Riverpod | latest |
| Routing | go_router | latest |
| Backend | NestJS (TypeScript) | 10.x |
| ORM | Prisma | latest |
| БД | PostgreSQL | 16 |
| Кэш / OTP | Redis | 7 |
| Поиск | Meilisearch | latest |
| Файлы | S3-compatible (Yandex Object Storage) | — |
| Real-time | WebSocket (NestJS) | — |
| Push | Firebase Cloud Messaging | — |
| SMS OTP | SMS.ru / SMSC.ru | — |
| Admin Web | Next.js + TypeScript | 14+ |
| CI/CD | GitHub Actions + Fastlane | — |
| Мониторинг | Sentry | — |
| Аналитика | AppMetrica | post-MVP |

---

## 4. Структура репозитория

```
davartapp/
├── PLAN.md                  # этот файл
├── README.md
├── apps/
│   ├── mobile/              # Flutter (iOS + Android)
│   ├── api/                 # NestJS backend
│   └── admin/               # Next.js (дизайнеры/менеджеры)
├── packages/
│   └── shared/              # общие типы, константы (опционально)
├── infra/
│   ├── docker-compose.yml   # локальная среда
│   └── .env.example
└── docs/
    └── adr/                 # Architecture Decision Records
```

---

## 5. Архитектура

### 5.1. Высокоуровневая схема

```
┌─────────────────────────────────────────────────────────┐
│                    Mobile App (Flutter)                  │
│  Каталог │ Проекты │ Чат │ Профиль │ Корзина │ Избранное│
└────────────────────────┬────────────────────────────────┘
                         │ REST + WebSocket
┌────────────────────────▼────────────────────────────────┐
│                   NestJS API (BFF)                       │
│  auth │ catalog │ orders │ projects │ chat │ documents  │
│  users │ notifications │ favorites                      │
└──┬──────┬──────┬──────┬──────┬──────┬───────────────────┘
   │      │      │      │      │      │
   ▼      ▼      ▼      ▼      ▼      ▼
  PG   Redis  Meili  S3    FCM   SMS.ru
```

### 5.2. Bounded contexts (модули backend)

| Модуль | Ответственность |
|--------|-----------------|
| `auth` | OTP, JWT, refresh tokens, rate limiting |
| `users` | Профиль, адреса, настройки |
| `catalog` | Категории, товары, атрибуты, поиск, фильтры |
| `commerce` | Корзина, заказы (без оплаты), статусы |
| `projects` | Проекты, брифы, статусы, lock брифа |
| `documents` | Загрузка/скачивание файлов проекта |
| `messaging` | Чаты, сообщения, вложения, WebSocket |
| `notifications` | Push, in-app уведомления |
| `favorites` | Избранные товары |

### 5.3. Mobile (Clean Architecture)

```
apps/mobile/lib/
├── core/           # DI, router, theme, constants, utils
├── features/       # feature-first модули
│   ├── auth/
│   ├── catalog/
│   ├── cart/
│   ├── favorites/
│   ├── projects/
│   ├── chat/
│   ├── orders/
│   └── profile/
└── shared/         # общие виджеты, extensions
```

Каждый feature:

```
feature/
├── data/           # repositories impl, API, DTO
├── domain/         # entities, use cases, repo interfaces
└── presentation/ # screens, widgets, providers
```

### 5.4. Auth flow (телефон)

```
1. Пользователь вводит номер телефона (+7...)
2. POST /auth/send-otp → SMS через SMS.ru
3. OTP сохраняется в Redis (TTL 5 мин, max 3 попытки)
4. Пользователь вводит код
5. POST /auth/verify-otp → JWT access (15 мин) + refresh (30 дней)
6. При 401 → POST /auth/refresh
```

---

## 6. Навигация приложения

### Client shell (5 tabs) — как сейчас

| Tab | Экран |
|-----|--------|
| Каталог | Категории, товары |
| Проекты | Свои проекты + showcase |
| Чаты | Список; всегда закреплён общий чат «Davart» |
| Корзина | Своя корзина |
| Профиль | ЛК, адреса объектов, заказы, настройки |

### Staff shell (черновик tabs)

| Tab | Экран |
|-----|--------|
| Чаты | Общий inbox + чаты с клиентами (главный вход) |
| Клиенты | Все клиенты (поиск по имени/телефону) |
| Каталог | Тот же каталог; add → корзина **выбранного** клиента |
| Профиль | Профиль сотрудника |

### Общие stack-экраны

- Поиск, фильтры, PDP, избранное (client)
- Корзина клиента (staff: в контексте клиента)
- Оформление заказа (client сам / staff от имени клиента)
- Детали проекта → Бриф → Документы
- Экран чата → **Профиль клиента** (staff entry point)

---

## 7. Модули и scope

### ✅ Mobile MVP (v1.0) — реализовано Sprint 0–13

- [x] Авторизация по телефону (OTP)
- [x] Каталог: категории, листинг, карточка товара
- [x] Поиск, фильтрация, сортировка
- [x] Корзина (привязана к проекту, Sprint 16)
- [x] Избранное (товары)
- [x] Оформление заказа (без оплаты)
- [x] История заказов со статусами
- [x] Проекты: список, детали
- [x] Бриф: просмотр, редактирование, lock, PDF
- [x] Документы проекта: просмотр, скачивание
- [x] Чат: проектный, личный, поддержка
- [x] Вложения в чат: текст, фото, файлы, товар
- [x] Профиль: данные, адреса, настройки
- [x] Dual shell client/staff + audit (переходная модель §17)
- [ ] Push на реальном FCM (сейчас mock/synthetic)

### 🚀 Экосистема (v2.0) — ТЗ → Sprint 14–21

См. чеклисты [§18.5](#185-roadmap-sprint-14–21). Кратко:

- [x] 4 роли + Artur Mode
- [x] Client↔Project M2M
- [x] Корзина на проект + Project Picker
- [x] Частичный заказ + Telegram-алерты
- [x] Мессенджер: вкладки + Chat Info
- [x] Парсер Italon (~631 керамогранит)
- [x] CRM web Master-Detail (Reg.ru заготовка)
- [ ] SMS.ru real, Mango Office, лиды сайт/Avito

### 🔮 Phase 2 (после Sprint 21)

- [ ] AI-Assistant в мессенджере
- [ ] Разбивка корзины по помещениям
- [ ] Аналитические дашборды (маржа, комплектаторы, объёмы)
- [ ] Расширение парсинга (сантехника, мебель)
- [ ] Программа лояльности / CAD-BIM / СДЭК (из старого v1.1 backlog)

---

## 8. Фазы и спринты

> Спринт = 2 недели.  
> Отмечай `[x]` по завершении задачи.

---

### Sprint 0 — Foundation

**Цель:** скелет проекта, инфра, дизайн-система.  
**Срок:** недели 1–2

#### Инфраструктура
- [x] Инициализация monorepo структуры
- [x] `docker-compose.yml`: PostgreSQL, Redis, Meilisearch, MinIO
- [x] `.env.example` с переменными
- [x] GitHub Actions: lint + test на PR
- [x] README с инструкцией запуска

#### Backend
- [x] Инициализация NestJS (`apps/api`)
- [x] Prisma schema v0 (User)
- [x] Health check endpoint (`GET /api/health`)
- [ ] OpenAPI / Swagger setup

#### Mobile
- [x] Инициализация Flutter (`apps/mobile`)
- [x] Настройка go_router + 4 таба
- [x] Theme (light), design tokens
- [x] Splash screen
- [ ] Riverpod (Sprint 1)

#### Docs
- [x] ADR-001: выбор стека
- [x] ADR-002: auth по телефону
- [x] ADR-003: заказы без оплаты

**DoD:** `docker compose up` поднимает все сервисы; Flutter и API запускаются локально.

---

### Sprint 1 — Auth + Navigation Shell

**Цель:** вход по телефону, каркас приложения.  
**Срок:** недели 3–4

#### Backend
- [x] `POST /auth/send-otp` (SMS.ru mock в dev)
- [x] `POST /auth/verify-otp`
- [x] `POST /auth/refresh`
- [x] `POST /auth/logout`
- [x] JWT middleware, rate limiting
- [x] `GET /users/me`

#### Mobile
- [x] Экран ввода телефона
- [x] Экран ввода OTP (таймер, повторная отправка)
- [x] Secure storage для токенов
- [x] Auto-refresh токена
- [x] Bottom navigation (4 таба)
- [x] Placeholder-экраны табов
- [x] Auth guard в роутере
- [x] Logout в профиле

**DoD:** регистрация/вход → 4 таба; сессия сохраняется после перезапуска.

---

### Sprint 2 — Catalog Core

**Цель:** рабочий каталог — главный экран.  
**Срок:** недели 5–6

#### Backend
- [x] Модели: Category, Product, ProductAttribute, Brand
- [x] `GET /catalog/categories`
- [x] `GET /catalog/products` (пагинация, по categoryId)
- [x] `GET /catalog/products/:id`
- [x] Seed: 12 категорий + 264 тестовых товара
- [x] Индексация в Meilisearch (`POST /catalog/reindex` в dev)

#### Mobile
- [x] Экран каталога (сетка товаров)
- [x] Горизонтальный скролл категорий
- [x] Карточка товара в списке
- [x] Экран детали товара (фото, описание, характеристики)
- [x] Pull-to-refresh, infinite scroll
- [x] Skeleton loaders

**DoD:** каталог открывается первым; листинг + детальная карточка работают.

---

### Sprint 3 — Search, Filters, Sort

**Цель:** полноценный поиск и фильтрация.  
**Срок:** недели 7–8

#### Backend
- [x] `GET /catalog/search?q=...`
- [x] Faceted filters API (цена, бренд, материал, цвет, наличие)
- [x] Sort: popular, price_asc, price_desc, new, discount, stock
- [x] Meilisearch: настройка атрибутов и фильтруемых полей
- [x] `GET /catalog/filters`

#### Mobile
- [x] Строка поиска (с экрана каталога)
- [x] Экран результатов поиска
- [x] Bottom sheet фильтров
- [x] Chips активных фильтров
- [x] Dropdown сортировки
- [x] Пустое состояние «ничего не найдено»

**DoD:** поиск «белая плитка» + фильтр по цене возвращает релевантные товары.

---

### Sprint 4 — Cart, Favorites, Orders

**Цель:** путь от товара до заказа (без оплаты).  
**Срок:** недели 9–10

#### Backend
- [x] Cart: add, update qty, remove, clear
- [x] `GET /cart`, `POST /cart/items`, `PATCH /cart/items/:id`, `DELETE /cart/items/:id`
- [x] Favorites: add, remove, list
- [x] Order: create from cart, list, detail
- [x] Order statuses: `created → confirmed → assembling → shipping → delivered`
- [x] OrderStatusHistory

#### Mobile
- [x] Кнопки «В корзину» / «В избранное» на карточке товара
- [x] Экран корзины (список, qty, итог)
- [x] Экран избранного
- [x] Оформление заказа (адрес, комментарий, подтверждение)
- [x] История заказов в профиле
- [x] Детали заказа со статусом

**DoD:** товар → корзина → заказ со статусом «оформлен»; избранное сохраняется.

---

### Sprint 5 — Projects + Brief

**Цель:** управление дизайн-проектами.  
**Срок:** недели 11–12

#### Backend
- [x] Project CRUD (привязка к user)
- [x] Brief: create, update, get, lock
- [x] Brief lock: после `status = in_progress` редактирование запрещено
- [x] `GET /projects/:id/brief/pdf` — генерация PDF
- [x] Назначение дизайнера (поле `designerId`)

#### Mobile
- [x] Список проектов
- [x] Карточка проекта (название, адрес, статус, дизайнер)
- [x] Экран брифа (форма: стиль, пожелания, бюджет, помещения...) → **анкета ТЗ** (общие вопросы + комнаты)
- [x] Режим просмотра / редактирования
- [x] Блокировка UI при locked brief
- [x] Скачать PDF

**DoD:** клиент заполняет бриф → статус «в работе» → редактирование заблокировано.

---

### Sprint 6 — Documents

**Цель:** документы проекта.  
**Срок:** недели 13–14

#### Backend
- [x] Upload via presigned URL (S3/MinIO)
- [x] Document types: contract, pdf, dwg, specification, invoice
- [x] `GET /projects/:id/documents`
- [x] `GET /documents/:id/download` (signed URL, TTL 30 мин)
- [x] RBAC: клиент видит только документы своих проектов

#### Mobile
- [x] Список документов в проекте (иконка по типу, название, дата)
- [x] Просмотр PDF in-app
- [x] Скачивание файла
- [x] Push: «Новый документ в проекте»

**DoD:** документ загружен (через admin/seed) → клиент видит и открывает PDF.

---

### Sprint 7 — Chat

**Цель:** коммуникация внутри приложения.  
**Срок:** недели 15–16

#### Backend
- [x] Chat rooms: project, personal, support
- [x] `GET /chats`, `GET /chats/:id/messages` (пагинация)
- [x] `POST /chats/:id/messages` (text, image, file, product)
- [x] WebSocket: new message, typing, read receipts
- [x] Unread counter per chat
- [x] Attachment upload (S3)

#### Mobile
- [x] Список чатов (аватар, последнее сообщение, unread badge)
- [x] Экран чата (bubble UI)
- [x] Отправка текста, фото (галерея/камера), файлов
- [x] Прикрепить товар из каталога
- [x] Real-time получение сообщений
- [x] Badge на табе «Чат»

**DoD:** сообщения доставляются < 2 сек; вложения открываются.

---

### Sprint 8 — Profile, Push, Polish

**Цель:** завершение MVP, подготовка к релизу.  
**Срок:** недели 17–18

#### Backend
- [x] `PATCH /users/me` (имя, email)
- [x] Addresses CRUD
- [x] Settings: notifications on/off
- [x] FCM token registration
- [x] Push triggers: new message, new document, order status change
- [x] FAQ endpoint (статический JSON)
- [x] Support chat (reuse chat module, type=support)

#### Mobile
- [x] Профиль: личные данные
- [x] Адреса доставки
- [x] Настройки (уведомления, тема light/dark/system)
- [x] FAQ
- [x] Чат поддержки
- [x] Push permissions + deep link handling
- [x] Error states, empty states polish
- [x] App icons, splash (Sprint 9)
- [ ] Store screenshots (Sprint 9, вручную перед submission)

**DoD:** push при новом сообщении и смене статуса заказа; приложение готово к beta.

---

### Sprint 9 — Beta & Launch

**Цель:** публикация в сторах.  
**Срок:** недели 19–20

#### API / Infra
- [x] Helmet, rate limiting (`@nestjs/throttler`)
- [x] Sentry (опционально через `SENTRY_DSN`)
- [x] `GET /api/legal/privacy`, `GET /api/legal/terms`
- [x] CORS через `CORS_ORIGIN`

#### Документация и тесты
- [x] Runbook (`docs/runbook.md`)
- [x] OWASP review (`docs/security/owasp-review.md`)
- [x] Privacy Policy + Terms (`docs/legal/`, API)
- [x] Скрипты нагрузочных тестов (`scripts/load/`)
- [ ] Прогон load tests на staging (k6)

#### Mobile
- [x] App icon + splash screen
- [x] Экраны Privacy / Terms в профиле
- [x] Fastlane skeletons (iOS TestFlight, Play Internal)
- [ ] Store screenshots

#### Релиз (вручную)
- [ ] Closed beta (TestFlight + Google Internal Testing) — см. `docs/release/beta-guide.md`
- [ ] Сбор feedback, фикс P0/P1 багов
- [ ] App Store + Google Play submission
- [ ] Uptime monitoring в prod

**DoD:** приложение опубликовано в обоих сторах.

---

## 9. API-контракты (высокий уровень)

### Auth
```
POST   /auth/send-otp        { phone: "+79001234567" }
POST   /auth/verify-otp      { phone, code }
POST   /auth/refresh         { refreshToken }
POST   /auth/logout
```

### Catalog
```
GET    /catalog/categories
GET    /catalog/products     ?categoryId&page&limit&sort&filters
GET    /catalog/products/:id
GET    /catalog/search       ?q&page&limit&filters
```

### Commerce
```
GET    /cart
POST   /cart/items           { productId, quantity }
PATCH  /cart/items/:id       { quantity }
DELETE /cart/items/:id
POST   /orders               { addressId, comment }
GET    /orders
GET    /orders/:id
```

### Favorites
```
GET    /favorites
POST   /favorites            { productId }
DELETE /favorites/:productId
```

### Projects
```
GET    /projects
GET    /projects/:id
GET    /projects/:id/brief
PUT    /projects/:id/brief
GET    /projects/:id/brief/pdf
GET    /projects/:id/documents
POST   /projects/:id/documents/upload-url
GET    /documents/:id/download
```

### Chat
```
GET    /chats
GET    /chats/unread-total
POST   /chats/seed-demo
POST   /chats/attachments/upload-url
GET    /chats/:id/messages   ?page&limit
POST   /chats/:id/messages   { type, content, attachmentKey?, productId? }
POST   /chats/:id/read
WS     /ws                     (auth via token)
```

### Users
```
GET    /users/me
PATCH  /users/me
GET    /users/me/addresses
POST   /users/me/addresses
PATCH  /users/me/addresses/:id
DELETE /users/me/addresses/:id
POST   /users/me/fcm-token    { token }
```

---

## 10. Модель данных

> **Сейчас в коде:** cart per-user, project per single `userId`, roles `client|staff`.  
> **Цель v2.0:** см. дельты [§18.2](#182-целевая-модель-данных-дельты).

### 10.1. Текущая схема (сокращённо)

### Основные сущности

```
User
  id, phone, name, email, createdAt

Address
  id, userId, label, city, street, building, apartment, isDefault

Category
  id, name, slug, icon, sortOrder

Brand
  id, name, slug, logo

Product
  id, categoryId, brandId, name, slug, sku, price, oldPrice,
  description, images[], attributes (JSON), inStock, createdAt

Cart / CartItem
  userId, productId, quantity

Order / OrderItem / OrderStatusHistory
  userId, items[], status, addressId, comment, total, createdAt

Favorite
  userId, productId

Project
  id, userId, designerId, name, address, area, style,
  startDate, status (draft|brief|in_progress|completed)

Brief
  projectId, data (JSON), isLocked, lockedAt, updatedAt

Document
  id, projectId, type, name, url, size, uploadedAt

Chat / ChatParticipant
  id, type (project|personal|support), projectId?

Message
  id, chatId, senderId, type (text|image|file|product),
  content, attachmentUrl?, productId?, createdAt

Notification
  id, userId, type, title, body, data (JSON), read, createdAt
```

---

## 11. Интеграции

| Приоритет | Сервис | Спринт | Статус |
|-----------|--------|--------|--------|
| P0 | SMS.ru (OTP) | 1 → 14/21 | ⬜ mock; real в экосистеме |
| P0 | FCM (Push) | 8 | ✅ mock + legacy API |
| P0 | MinIO / Yandex Object Storage | 0 | ✅ local MinIO; prod Yandex ⬜ |
| P0 | Telegram Bot (алерты заказов) | 17 | ✅ |
| P1 | CRM Web (Reg.ru / DA art) | 20 | ✅ Sprint 20 (live DNS — ops) |
| P1 | Парсер Italon Ceramics | 19 | ✅ Sprint 19 |
| P1 | Mango Office (звонки в карточке) | 21 | ⬜ |
| P1 | Лиды: сайт + Avito → Client | 21 | ⬜ |
| P2 | AppMetrica | Phase 2 | ⬜ |
| P2 | СДЭК | Phase 2 | ⬜ |

---

## 12. Нефункциональные требования

| Параметр | Цель |
|----------|------|
| API response time (p95) | < 300 ms |
| Поиск (p95) | < 200 ms |
| WebSocket latency | < 2 sec |
| Crash-free sessions | > 99.5% |
| OTP delivery | < 30 sec |
| Uptime | 99.9% |
| Мин. iOS | 15.0 |
| Мин. Android | API 24 (Android 7.0) |

---

## 13. Риски

| Риск | Вероятность | Митигация |
|------|-------------|-----------|
| Scope creep | Высокая | Жёсткий MVP-scope, всё остальное в v1.1/v2.0 |
| Сложные фильтры каталога | Средняя | EAV-атрибуты + шаблоны фильтров per category |
| Задержки SMS | Низкая | Fallback провайдер (SMSC.ru), retry |
| Нагрузка на чат | Средняя | Centrifugo при > 1000 concurrent WS |
| Модерация App Store | Низкая | Нет IAP, нет платежей — упрощённый review |

---

## 14. Метрики успеха

| Метрика | Цель (3 мес. после launch) |
|---------|---------------------------|
| Регистрации | 500+ |
| DAU/MAU | > 25% |
| Каталог → корзина | > 5% |
| Корзина → заказ | > 30% |
| Время ответа в чате | < 4 ч (рабочее время) |
| Crash-free | > 99.5% |
| Store rating | > 4.0 |

---

## 15. Текущий статус

| Параметр | Значение |
|----------|----------|
| **Версия плана** | 2.0 (экосистема Mobile + CRM) |
| **Закрыто** | Sprint 0–19 ✅ · **Sprint 20 CRM Web Master-Detail** ✅ |
| **Текущий спринт** | **Sprint 21** — Integrations hardening |
| **Критичный форк** | CRM локально готов; дальше SMS.ru / Mango / лиды |
| **Параллельно** | Store / real SMS key / real FCM / staging HTTPS |
| **Блокеры релиза store** | Apple/Google accounts; SMS.ru / Firebase credentials |

### Лог изменений

| Дата | Событие |
|------|---------|
| 2026-08-18 | Анкета брифа: вопросы из ТЗ студии (общие + кухня/прихожая/спальня/ванная/детская/лоджия) |
| 2026-08-17 | Sprint 20: `apps/admin` Master-Detail, OTP, Telegram deep link, Reg.ru stub |
| 2026-08-17 | Sprint 19: Italon sitemap ingest (керамогранит), collectionSlug, фильтр «Коллекция» |
| 2026-08-17 | Sprint 18: вкладки чатов Все/Проекты, Chat Info (участники, архив, корзина), voice stub |
| 2026-08-17 | Sprint 17: selective cartItemIds checkout, CartItem lock, Telegram alerts (mock), mobile checkboxes |
| 2026-08-17 | Sprint 16: Cart.projectId 1:1, API/mobile project picker, staff working-project cart, e2e isolation |
| 2026-08-17 | Sprint 15: ProjectMember M2M, invite by phone, ACL docs/projects, mobile участники |
| 2026-08-17 | Sprint 14: UserRole designer/complectator/admin, Artur elevate API, SMS.ru scaffold, e2e |
| 2026-08-17 | PLAN v2.0: зафиксировано ТЗ экосистемы → §18; roadmap Sprint 14–21 |
| 2026-08-14 | Staff ACL e2e: client 403, staff scope, brief lock, audit + push hooks |
| 2026-08-14 | Тематические фото каталога → MinIO (`catalog/{slug}/*.jpg`), refresh без wipe |
| 2026-08-14 | Sprint 13E: push клиенту + StaffAuditLog + экран «Активность» |
| 2026-08-14 | Sprint 13D: staff checkout/order API + UI (за клиента) |
| 2026-08-14 | Sprint 13C: staff cart API + working-client context, banner, catalog add-to-cart for client |
| 2026-08-14 | Sprint 13B: staff client profile/addresses/projects/brief RO; chat clientId + profile entry |
| 2026-08-14 | Sprint 13A: User.role + JWT, Davart support chat со всеми staff, GET /staff/clients, mobile client/staff shells |
| 2026-08-14 | PLAN v1.1: роли client/staff в mobile; решения §17 |
| 2026-08-06 | Создан PLAN.md v1.0. Зафиксированы: auth по телефону, без платежей, стек Flutter + NestJS |
| 2026-08-06 | Sprint 0–9: foundation → profile/push/hardening (см. чеклисты §8) |
| 2026-08-08 | Аудит post-MVP → Sprint 10–12 fix pack ✅ |

---

## 16. Спринты по правкам (post-audit)

> Источник: аудит 2026-08-08. Цель — стабильный локальный DX, безопасный auth/chat, единый UI.

**Нижняя навигация (зафиксировано):**  
`Каталог` · `Проекты` · `Чат` · `Корзина` · `Профиль` (5 вкладок, с подписями).

### Sprint 10 — Stability & Auth (P0)

**Цель:** пользователь не «залипает» в битой сессии; локальный запуск предсказуем.

- [x] Mobile: после failed refresh → `signOut` / redirect на телефон (`dio_provider.dart` + `sessionExpiredTickProvider`)
- [x] Mobile: изолировать search state от `catalogProvider` (`search_notifier.dart`)
- [x] Mobile: multicast socket listeners (чат + unread badge)
- [x] API: OTP verify lockout (5 попыток → lock 15 мин)
- [x] API: fail-closed SMS в production (`sms.service.ts`)
- [x] API: `assertParticipant` на WS `join`
- [x] README: Colima → `docker-compose up` → `npm run start:dev` → `flutter run`
- [x] Guard seed `deleteMany` вне production (`ALLOW_PROD_SEED`)

**Done when:** logout после 401; поиск не ломает каталог; чужой чат по WS недоступен; OTP из README воспроизводится за 2 минуты.

### Sprint 11 — Security & API hardening (P0/P1)

**Цель:** закрыть prod-дыры и admin/dev endpoints.

- [x] `ALLOW_DEV_ENDPOINTS` (default deny) вместо «открыто если NODE_ENV пуст»
- [x] CORS + JWT secret validation на старте API
- [x] Ограничить `orders/:id/status` и `projects start-work` (`x-admin-secret` / `ADMIN_API_SECRET`)
- [x] Health: Redis (+ опционально Meili); auth fail если Redis down
- [x] MinIO healthcheck без `mc` (`curl` → `/minio/health/live`)
- [x] E2E: refresh/logout, OTP lockout, WS join ACL
- [x] Mobile: `API_BASE_URL` via `--dart-define` + doc для устройства

**Done when:** без явного allowlist нет seed/reindex/status; e2e на ACL зелёные.

### Sprint 12 — UI polish & product gaps (P1)

**Цель:** единый DS и закрытие UX-дыр из аудита.

- [x] Orders / order detail → DS (`ListItem`, `StatusBadge`, `EmptyState`)
- [x] Settings / addresses / edit profile → DS
- [x] ErrorState на каталоге, избранном, чатах
- [x] Профиль: убрать дубли меню, wire edit profile, убрать пустой bell
- [x] Проекты: статусы фильтров = API enum (`brief_filling` → «Заполнение брифа»)
- [x] Удалить мёртвый `filters_bottom_sheet.dart`
- [x] `POST /projects` + создание из мобилки (кнопка +)
- [x] Тематические изображения товаров (MinIO), не random Picsum

**Done when:** основные secondary-экраны в DS; нет «пустых» экранов без error state.

### Рекомендуемый порядок

1. ~~Sprint 10~~ ✅ (стабильность входа и DX)  
2. ~~Sprint 11~~ ✅ (блокер для внешнего окружения)  
3. ~~Sprint 12~~ ✅ (UI DS + тематические фото каталога в MinIO)
4. ~~Sprint 13~~ ✅ — client/staff dual mode → [§17](#17-клиент-vs-сотрудник-mobile)
5. **Sprint 14+** — экосистема по ТЗ → [§18](#18-экосистема-mobile--crm-тз-v20)

---

## 17. Клиент vs сотрудник (mobile)

> **Переходная модель Sprint 13 (2026-08-14).** В коде: `client` \| `staff`.  
> Целевая модель ролей и архитектуры данных — [§18](#18-экосистема-mobile--crm-тз-v20).  
> Sprint 13A–E и staff ACL e2e **закрыты**; не начинать новый staff-binary scope.

### 17.1. Продуктовые решения

| # | Решение |
|---|---------|
| 1 | Staff видит **всех** клиентов |
| 2 | Staff: бриф **только чтение**; lock уже при старте проекта — клиент не правит бриф во время работы |
| 3 | Staff **может оформлять заказ** от имени клиента |
| 4 | Один номер телефона = одна роль (`client` \| `staff`) |
| 5 | Чат «Davart» у клиента = **общий inbox** команды (все staff в одном support-чате) |

### 17.2. В чём отличие

| | Client | Staff |
|---|--------|--------|
| Цель | Купить / свой ремонт / писать студии | Вести клиентов: подбор, бриф, заказ |
| Корзина | Своя | Любого клиента (через профиль из чата / список клиентов) |
| Бриф | Заполняет до lock | Читает; после lock клиент не редактирует |
| Чат | Всегда есть общий «Davart» | Участники общего inbox + диалоги |
| Каталог | Add → своя корзина | Add → корзина клиента в контексте |
| Заказ | Сам | Может оформить за клиента |

### 17.3. Ключевой staff-flow

```
Чаты / Клиенты
  → чат с покупателем
      → Профиль клиента
          → адреса объектов (просмотр / добавить)
          → корзина (просмотр / правка / add из каталога)
          → проекты → бриф (read-only)
          → оформить заказ от имени клиента
```

Контекст «сейчас клиент X» — глобальный в app; в каталоге баннер: чья корзина.

### 17.4. Backend (обязательный минимум)

- `User.role`: `client` | `staff` (+ claims в JWT / `/auth/me`)
- Staff создаётся только админом / seed (не OTP-саморег в staff)
- При создании клиента: авто-чат `support` «Davart»; все `staff` — участники (или динамическое членство по роли)
- Scoped API, например:
  - `GET /staff/clients` (все)
  - `GET|PATCH /staff/clients/:id/cart` (+ items)
  - `POST /staff/clients/:id/orders`
  - `GET /staff/clients/:id/projects` + brief (read)
  - `GET|POST /staff/clients/:id/addresses`
- ACL: любой `staff` → любой `client` (по решению #1); аудит кто менял корзину / заказ
- Бриф: client `PUT` запрещён при `isLocked` / `in_progress` (уже есть направление; проверить жёстко)

### 17.5. Фазы реализации

**13A — Фундамент** ✅  
Роль + JWT · `/users/me` + role · client: авто-чат Davart · staff shell (Чаты first) · список всех клиентов.

**13B — Профиль клиента из чата** ✅  
Карточка клиента · адреса (просмотр/добавление) · проекты · бриф read-only.

**13C — Корзина и каталог в контексте** ✅  
Чужая корзина CRUD · баннер контекста (весь staff shell) · add-to-cart за клиента (каталог / PDP / избранное) · контекст из чата + быстрый вход в корзину.

**13D — Заказ от имени клиента** ✅  
Checkout staff → `POST .../orders` от clientId · клиент видит заказ у себя.

**13E — Полировка** ✅  
Пуши клиенту при add-to-cart / заказе staff · audit log (`staff_audit_logs` + экран «Активность»).  
TestFlight flavor — отложено.

### 17.6. Риски

- Утечка между клиентами при баге ACL — e2e на staff endpoints обязательны → **`test/staff-acl.e2e-spec.ts` ✅** (client 403, non-client 404, brief force-lock, cart/order audit + push).
- Путаница «чья корзина» без сильного UI-контекста.
- Общий inbox: шум и ответственность — позже можно назначить «ведущего», не ломая модель.
- Admin Web vs mobile staff: не дублировать управление каталогом в mobile.

---

## 18. Экосистема Mobile + CRM (ТЗ v2.0)

> Зафиксировано 2026-08-17 по ТЗ «Экосистема: мобильное приложение и CRM».  
> MVP Sprint 0–13 **не выбрасываем** — перебазируем на project membership + project cart.

### 18.1. Требования из ТЗ

| ID | Требование | Статус vs код |
|----|------------|---------------|
| FR-01 | Клиент: проекты, мессенджер, каталог, корзина | ✅ частично (корзина per-user) |
| FR-02 | Дизайнер: мои проекты, корзины закреплённых, документы, чат | ⬜ роль = `staff` сейчас |
| FR-03 | Комплектатор: участники, товарная база, заказы, логистика | ⬜ |
| FR-04 | Admin / Artur Mode: роли, все БД, аналитика | ⬜ (`ADMIN_API_SECRET` ≠ UI) |
| ARCH-01 | Корзина ↔ **Проект** (не Клиент) | ⬜ BREAKING |
| ARCH-02 | Client ↔ Project **M2M** | ⬜ BREAKING |
| UI-01 | Переключение проектов как адрес в Самокат/Я.Еда | ⬜ |
| UI-02 | Project Picker при add-to-cart если >1 проекта | ⬜ |
| MSG-01 | Вкладки чатов: «Все» / «Проекты» | ✅ Sprint 18 |
| MSG-02 | Chat Info: участники (по телефону), медиа, файлы, голосовые, ссылки, корзина | ✅ Sprint 18 |
| CAT-01 | Парсинг Italon керамогранит ~631 SKU; коллекция = фильтр | ✅ Sprint 19 |
| ORD-01 | Чекбоксы позиций → заказ; lock выбранных; остальное в корзине | ✅ Sprint 17 |
| ORD-02 | Telegram-бот: список, клиент, deep link в CRM | ✅ Sprint 17 (mock без token) |
| CRM-01 | Web Master-Detail (клиенты → проекты/доки/корзина/история/профиль) | ✅ Sprint 20 |
| CRM-02 | Хостинг Reg.ru, домен 3-го уровня зоны DA art | ✅ заготовка Sprint 20 (live DNS — ops) |
| INT-01 | SMS.ru real | ⬜ mock |
| INT-02 | Mango Office: логи/записи в карточке клиента | ⬜ |
| INT-03 | Лиды сайт + Avito → Client | ⬜ |

### 18.2. Целевая модель данных (дельты)

```
User.role: client | designer | complectator | admin
  (миграция: staff → complectator или designer по seed-правилу)

ProjectMember (M2M)
  projectId, userId, memberRole (owner|member|viewer), createdAt
  @@unique([projectId, userId])

Cart
  id, projectId @unique   // было userId
  items: CartItem[]

CartItem
  + lockedAt? / lockedByOrderId?   // после частичного оформления

Order
  + projectId
  items from selected cart lines only

Product
  + collectionSlug? / supplierSku? / sourceUrl?  // Italon ingest
```

`Project.userId` сохраняем как primary owner до dual-write, затем deprecated.

### 18.3. Мессенджер (целевой UX)

```
Чаты
├── вкладка «Все»      — личные + support
└── вкладка «Проекты»  — ChatType.project

Chat Info (проектный чат)
├── Участники (+ invite по телефону)
├── Медиа / Файлы / Голосовые / Ссылки
└── Корзина → project cart
```

### 18.4. Заказ + Telegram

1. Клиент или дизайнер отмечает чекбоксами позиции корзины проекта.  
2. «Оформить заказ» → выбранные строки **блокируются**, создаётся Order.  
3. Бот → группа менеджеров: позиции, клиент; кнопки «Проект / Корзина / Заказ» подгружают карточку.

### 18.5. Roadmap Sprint 14–21

#### Sprint 14 — Roles & Artur Mode

**Цель:** целевая RBAC без ломки cart schema.

- [x] Расширить `UserRole`: `client | designer | complectator | admin`
- [x] Миграция существующих `staff` → `complectator` (seed phones: designer/complectator/admin)
- [x] JWT / `/users/me` отдают новую роль; mobile shells: studio roles → staff shell
- [x] Artur: `PATCH /admin/users/:id/role` (только `admin`) + `GET /admin/users`
- [x] Обновить RolesGuard матрицу + e2e ACL (`staff-acl`, `admin-roles`)
- [x] SMS.ru: провайдер за `SMS_PROVIDER=smsru` + `SMSRU_API_ID`

**DoD:** OTP создаёт только `client`; admin может повысить роль; старые staff мигрируют → ✅

#### Sprint 15 — Project membership (M2M)

**Цель:** несколько клиентов на проект / несколько проектов на клиента.

- [x] Таблица `ProjectMember` + миграция с `Project.userId` → member `owner`
- [x] ACL проектов/документов/брифа по membership
- [x] API: invite участника по телефону; list members
- [x] Mobile: список участников на проекте
- [x] Staff/designer: studio roles могут manage members; client — только owner

**DoD:** муж+жена на одном проекте видят бриф/чат/документы по ACL → ✅

#### Sprint 16 — Project cart + picker ⚠️ BREAKING

**Цель:** [ARCH-01], [UI-01], [UI-02].

- [x] `Cart.projectId` (1:1); миграция user-cart → cart первого/активного проекта
- [x] API cart scoped by `projectId`; staff context = **working project** (не только client)
- [x] Mobile: переключатель проекта (Самокат-style) в шапке
- [x] Add-to-cart → Project Picker если >1 активного проекта
- [x] Баннер «корзина проекта X»; обновить staff flow Sprint 13
- [x] E2E: cart isolation между проектами одного клиента

**DoD:** два проекта клиента не смешивают позиции в одной корзине. → ✅

#### Sprint 17 — Selective order + Telegram

**Цель:** [ORD-01], [ORD-02].

- [x] Checkout selected `cartItemIds`; lock выбранных; остальные остаются
- [x] `Order.projectId`; статусы без изменения семантики оплаты
- [x] Telegram bot service: сообщение в чат менеджеров + deep link CRM
- [x] Mobile: чекбоксы в корзине проекта + CTA
- [x] E2E: partial checkout + audit

**DoD:** частичный заказ уходит в Telegram; lock не даёт править отправленные строки. → ✅

#### Sprint 18 — Messenger tabs + Chat Info

**Цель:** [MSG-01], [MSG-02] (voice можно stub).

- [x] Вкладки «Все» / «Проекты»
- [x] Chat Info: участники, медиа, файлы, ссылки, вход в корзину проекта
- [x] Invite участника по телефону из Chat Info (связь со Sprint 15)
- [x] Voice messages: тип `voice` + запись (или заглушка UI → Phase 2)

**DoD:** из проектного чата открывается архив файлов и корзина проекта. → ✅

#### Sprint 19 — Italon catalog ingest

**Цель:** [CAT-01].

- [x] Парсер italonceramica.ru (весь RU-каталог из image sitemap: керамогранит + настенная + contract + structured; HTML закрыт SmartCaptcha)
- [x] Позиция = Product; коллекция = filter attribute / `collectionSlug`
- [x] Job/CLI ingest + reindex Meili; идемпотентность по supplier SKU
- [x] Mobile: фильтр «Коллекция»

**DoD:** в каталоге >600 реальных SKU Italon с фильтром коллекции. → ✅ полный RU-каталог из image sitemap (`npm run catalog:ingest-italon`); фото зеркалятся в MinIO `catalog/italon/{sku}`.

#### Sprint 20 — CRM Web (Siebel Master-Detail)

**Цель:** [CRM-01], [CRM-02].

- [x] `apps/admin` (Next.js) на том же API
- [x] Master: таблица клиентов, двухуровневые фильтры
- [x] Detail tabs: Проекты, Документация, Корзина, История, Профиль (+ ДР)
- [x] Deep link targets для Telegram (Sprint 17)
- [x] Деплой-заготовка под Reg.ru / поддомен DA art

**DoD:** комплектатор обрабатывает заказ из Telegram → карточка клиента в CRM. → ✅ `http://localhost:3001/clients/{id}/orders/{orderId}`; Telegram берёт `CRM_WEB_URL`. Live-хостинг — ops.

#### Sprint 21 — Integrations hardening

**Цель:** [INT-01..03] + store prep.

- [ ] SMS.ru production path
- [ ] Mango Office: лог звонков / записи в карточке клиента
- [ ] Lead intake: сайт + Avito → создание Client (+ опционально Project)
- [ ] Real FCM на mobile (если ещё не закрыто параллельно)
- [ ] Staging HTTPS + preflight beta-guide

**DoD:** OTP через SMS.ru; лид с Avito появляется в CRM; звонок виден в карточке.

### 18.6. Порядок и зависимости

```
14 Roles ──► 15 M2M ──► 16 Project cart ──► 17 Orders+TG
                 │              │
                 └──────────────┴──► 18 Messenger Info
16/17 ──► 20 CRM (deep links)
14/19 параллельно после стабилизации schema cart
21 после 20 (Mango/leads в карточке CRM)
```

**Не начинать** тяжёлый CRM UI до Sprint 16: иначе Master-Detail сядет на устаревшую user-cart модель.

### 18.7. Phase 2 (бэклог ТЗ)

1. AI-Assistant в мессенджере  
2. Детализация логистики по помещениям внутри корзины  
3. Аналитический модуль (маржа, эффективность, объёмы)  
4. Парсинг сантехники / мебели сторонних поставщиков  

---

*Обновляй секцию [15. Текущий статус](#15-текущий-статус) и чеклисты спринтов по мере выполнения задач.*
