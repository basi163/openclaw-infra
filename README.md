# OpenClaw Infra (disaster recovery + versioning)

Этот репозиторий хранит инфраструктурную сборку OpenClaw для быстрого восстановления на новом сервере.

## Что делает
- Экспортирует настройки OpenClaw и агентов в `state-export/`
- Ведет версионность в GitHub
- Делает автосинхронизацию по cron (в фоне)
- Дает команды backup/restore

## Быстрый запуск на новом сервере
```bash
git clone https://github.com/basi163/openclaw-infra.git ~/openclaw-infra
cd ~/openclaw-infra
bash scripts/bootstrap.sh
```

## Ручной export/sync
```bash
bash scripts/export-config.sh
bash scripts/sync-to-github.sh
```

## Автосинк
Установка cron-задач:
```bash
bash scripts/install-autosync.sh
```

По умолчанию:
- `auto-sync.sh` запускается при старте сервера и каждые 5 минут
- `backup-release.sh` запускается ежедневно в `03:35 UTC`

Опционально можно переопределить расписание и пути логов:
```bash
AUTO_SYNC_SCHEDULE='*/10 * * * *' \
BACKUP_RELEASE_SCHEDULE='15 2 * * *' \
AUTO_SYNC_LOG='/tmp/openclaw-autosync.log' \
BACKUP_RELEASE_LOG='/tmp/openclaw-backup-release.log' \
bash scripts/install-autosync.sh
```

## Бэкап и проверка
```bash
bash scripts/backup-create.sh
# или
openclaw backup create --output ~/openclaw-backups --verify
```

## Encrypted backup в GitHub Releases
1) Создай файл `~/.openclaw/.backup-release.env`:
```bash
OPENCLAW_BACKUP_PASSPHRASE='длинный-секретный-пароль'
GITHUB_BACKUP_REPO='basi163/openclaw-infra'
```
2) Запуск вручную:
```bash
bash scripts/backup-release.sh
```
3) Восстановление:
```bash
bash scripts/restore-from-release.sh <release-tag>
```

## Важно
- Секреты в git не коммитим
- Конфиг в `state-export/openclaw.json.redacted` уже обезличен
- Для полного аварийного восстановления используй encrypted backup archive из Releases
