# Mobile (Flutter)

## iPhone одной командой (staging VPS)

Локальный `.env` не нужен — API по умолчанию `http://217.198.6.88:3000/api`.

```bash
cd ~/davartapp && git pull origin main && bash scripts/run-ios-device.sh
```

Откроет Xcode → выбери iPhone → ⌘R.

Клон с нуля:

```bash
git clone https://github.com/mxrph1n3/davartapp.git ~/davartapp && cd ~/davartapp && bash scripts/run-ios-device.sh
```
