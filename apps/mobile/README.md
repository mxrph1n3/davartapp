# Mobile (Flutter)

## iPhone одной командой (staging VPS)

```bash
# из корня репозитория
git pull
bash scripts/run-ios-device.sh
```

Нужны: Flutter, Xcode, CocoaPods, iPhone по USB, Developer Mode, Team в Signing.

Через Xcode:

```bash
bash scripts/run-ios-device.sh --xcode
# затем ⌘R на выбранном iPhone
```

API по умолчанию: `http://217.198.6.88:3000/api` (файл `dart_defines.device.json`).
