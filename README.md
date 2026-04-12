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

## Бэкап и проверка
```bash
bash scripts/backup-create.sh
# или
openclaw backup create --output ~/openclaw-backups --verify
```

## Важно
- Репозиторий приватный по умолчанию
- Секреты редактируются (redact) перед коммитом
- Для полного аварийного восстановления используй также backup archive
