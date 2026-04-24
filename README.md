# OpenClaw Infra (disaster recovery + versioning)

Этот репозиторий хранит инфраструктурную сборку OpenClaw для быстрого восстановления на новом сервере.

## Что делает
- Экспортирует настройки OpenClaw и агентов в `state-export/`
- Ведет версионность в GitHub
- Делает автосинхронизацию по cron (в фоне)
- Дает команды backup/restore
- Фиксирует рабочий профиль стабильности для прод-сервера

## Production Baseline (стабильный профиль)
На этом сервере текущая рабочая стабильная версия: `openclaw@2026.4.12`.

Важно:
- `latest stable` не всегда равен операционно стабильной версии в конкретном окружении
- поэтому прод обновляется консервативно: сначала проверка, потом фиксация

Текущие опорные настройки стабильности:
- Канал обновлений: `stable` (только ручные обновления)
- Пин версии для прода: `2026.4.12`
- `gateway.bind=loopback`
- `gateway.reload=hot`
- Один systemd unit для gateway: `openclaw-gateway.service`
- Автовосстановление процесса: `Restart=always`, `RestartSec=5`
- Защита от lock-зависаний: очистка stale lock в `ExecStartPre`
- Отключение внутреннего respawn: `OPENCLAW_NO_RESPAWN=1`
- Node compile cache: `NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache`
- Пост-апдейт проверка: `doctor -> restart -> status --deep -> health retries -> logs`

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
- создает `~openclaw/.config/systemd/user/openclaw-gateway.service` как symlink на системный unit, чтобы новые версии OpenClaw корректно считали сервис установленным
- переживает обновления OpenClaw, потому что не зависит от `node_modules`

## Обновление: безопасный прод-процесс

### 1) Проверить и зафиксировать стабильную версию
```bash
sudo bash scripts/pin-openclaw-stable.sh
```

По умолчанию скрипт ставит `openclaw@2026.4.12`.
Если нужно переопределить:
```bash
sudo OPENCLAW_STABLE_VERSION=2026.4.12 bash scripts/pin-openclaw-stable.sh
```

### 2) Осторожный апдейт с проверками
```bash
sudo bash scripts/update-openclaw-safe.sh
sudo bash scripts/post-update-check.sh
```

`update-openclaw-safe.sh`:
- переустанавливает shim совместимости
- обновляет OpenClaw (по умолчанию до `openclaw@2026.4.12`, через `OPENCLAW_NPM_SPEC` можно переопределить)
- проверяет `openclaw status --json`
- прогоняет smoke test `openclaw gateway restart`
- печатает хвост `journalctl -u openclaw-gateway.service`

`post-update-check.sh`:
- прогоняет `openclaw doctor --deep --non-interactive`
- перезапускает `openclaw-gateway.service`
- снимает `openclaw status --deep --json`
- делает retry для `openclaw health --json`
- печатает свежие логи `journalctl -u openclaw-gateway.service`

### 3) Переход на новую stable-версию
Рекомендуемый порядок:
```bash
# backup перед изменением версии
bash scripts/backup-create.sh

# пробный апдейт на кандидата
sudo OPENCLAW_NPM_SPEC='openclaw@latest' bash scripts/update-openclaw-safe.sh
sudo bash scripts/post-update-check.sh

# если кандидат стабильный в этом окружении — зафиксировать новый пин
sudo OPENCLAW_STABLE_VERSION='<новая-версия>' bash scripts/pin-openclaw-stable.sh
```

Если после апдейта деградация:
- сразу откат на предыдущий пин через `scripts/pin-openclaw-stable.sh`
- `systemctl restart openclaw-gateway.service`
- повторный `scripts/post-update-check.sh`

## Минимальный чеклист стабильности
- Нет дублирующих gateway unit'ов (`systemd --user` и системный не конфликтуют)
- Только один активный процесс gateway
- Нет конфликта порта gateway
- `openclaw status --deep --json` без критических ошибок
- `openclaw health --json` проходит в пределах retry
- Логи `journalctl -u openclaw-gateway.service` без crash-loop

## Важно
- Секреты в git не коммитим
- Конфиг в `state-export/openclaw.json.redacted` уже обезличен
- Для полного аварийного восстановления используй encrypted backup archive из Releases
