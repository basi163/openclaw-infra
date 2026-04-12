# Agent Swarm (.clawdbot)

Минимальная оркестрация swarm для Codex/Claude через worktree + tmux + cron.

## Что есть
- `spawn-agent.sh` — создаёт worktree, запускает агента в tmux, регистрирует задачу.
- `check-agents.py` — проверка задач (tmux/PR/CI) + автоуведомление.
- `run-agent.sh` — запуск Codex/Claude с логированием.
- `cleanup.sh` — безопасная уборка старых завершённых worktree.
- `install-cron.sh` — ставит cron-петли (каждые 10 мин + ежедневная уборка).
- `active-tasks.json` — реестр задач.

## Быстрый старт
```bash
cd /path/to/your/repo

# 1) Запустить задачу
./.clawdbot/spawn-agent.sh \
  --id feat-my-task \
  --agent codex \
  --model gpt-5.3-codex \
  --reasoning high \
  --prompt "Реализуй фичу X, добавь тесты, закоммить и открой PR"

# 2) Проверить вручную
python3 ./.clawdbot/check-agents.py

# 3) Включить cron-мониторинг
./.clawdbot/install-cron.sh
```

## Формат done
Задача получает `ready_for_review`, если:
- есть PR по ветке задачи,
- PR не draft,
- все checks в success/neutral/skipped.

## Уведомления
Скрипт шлёт локальное событие:
```bash
openclaw system event --text "..." --mode now
```
Если команда недоступна, проверка всё равно продолжится.
