# Mobile (Flutter)

## iPhone одной командой (staging VPS)

```bash
cd ~/davartapp && git pull origin main && bash scripts/run-ios-device.sh
```

Скрипт повторяет рабочий пайплайн: SPM off → clean → pub get → сброс Pods → `pod install --repo-update` → `flutter run` на телефон с `API_BASE_URL=http://217.198.6.88:3000/api`.

Через Xcode:

```bash
cd ~/davartapp && git pull origin main && bash scripts/run-ios-device.sh --xcode
```

Клон с нуля:

```bash
git clone https://github.com/mxrph1n3/davartapp.git ~/davartapp && cd ~/davartapp && bash scripts/run-ios-device.sh
```
