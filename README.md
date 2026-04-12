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

## Совместимость gateway после обновлений
На этом сервере gateway запущен как системный `systemd` unit (`openclaw-gateway.service`), поэтому для OpenClaw установлен внешний shim:
```bash
bash scripts/install-openclaw-gateway-compat.sh
```

Он:
- перенаправляет `systemctl --user ... openclaw-gateway.service` на системный unit
- разрешает пользователю `openclaw` выполнять `start|stop|restart` только для `openclaw-gateway.service`
- переживает обновления OpenClaw, потому что не зависит от `node_modules`

Для будущих обновлений используй обертку:
```bash
bash scripts/update-openclaw-safe.sh
```

Она:
- переустанавливает shim
- запускает `openclaw update --yes`
- проверяет `openclaw status --json`
- прогоняет smoke test `openclaw gateway restart`
- печатает хвост `journalctl -u openclaw-gateway.service`

## Важно
- Секреты в git не коммитим
- Конфиг в `state-export/openclaw.json.redacted` уже обезличен
- Для полного аварийного восстановления используй encrypted backup archive из Releases
