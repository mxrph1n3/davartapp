# Beta Release Guide

## Предварительные требования

- Apple Developer Program ($99/год)
- Google Play Console ($25 one-time)
- Production/staging API с HTTPS **в РФ** (чат без VPN)
- Push на экране блокировки: RuStore / APNs, не Firebase

## Версионирование

В `apps/mobile/pubspec.yaml`:

```yaml
version: 1.0.0+1  # name+build
```

Увеличивайте build number (`+N`) для каждой загрузки в сторы.

## iOS — TestFlight

1. Настройте signing в Xcode (Team, Bundle ID: `com.davart.app`)
2. Создайте App Store Connect запись
3. Соберите:

```bash
cd apps/mobile
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.davart.ru/api
```

4. Загрузите через Transporter или Fastlane:

```bash
cd apps/mobile/ios
fastlane beta
```

5. В App Store Connect → TestFlight → добавьте internal testers

## Android — Internal Testing

1. Создайте приложение в Play Console
2. Настройте signing key (`android/key.properties`)
3. Соберите:

```bash
cd apps/mobile
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.davart.ru/api
```

4. Загрузите AAB в Play Console → Internal testing
5. Добавьте тестировщиков по email

## Fastlane

```bash
# iOS
cd apps/mobile/ios && bundle install && fastlane beta

# Android
cd apps/mobile/android && bundle install && fastlane internal
```

Секреты через env:
- `APP_STORE_CONNECT_API_KEY`
- `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`

## Чеклист перед beta

- [ ] API health green на staging/prod
- [ ] Миграции применены (`prisma migrate deploy`)
- [ ] Seed каталога / Meilisearch index
- [ ] Privacy Policy и Terms доступны (`/api/legal/*`)
- [ ] Push токены регистрируются
- [ ] Smoke test: auth → catalog → cart → order → project → chat

## Сбор feedback

- TestFlight / Play Console feedback
- Чат поддержки в приложении
- Email: beta@davart.ru
