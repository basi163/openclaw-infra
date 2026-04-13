# MEMORY

## System
- OpenClaw exec policy was switched to YOLO on 2026-04-12 to remove `allowlist-miss` blocks for host exec.
- The live workspace uses an Obsidian-oriented memory layout: `memory/`, `MEMORY.md`, `second-brain/`, and `directives/`.
- Dashboard project is tracked in GitHub: `basi163/assistant-dashboard`.
- Infra recovery project is tracked in GitHub: `basi163/openclaw-infra`.
- Infra auto-sync to GitHub is enabled on schedule (cron), with owner-approved exception for this network action.
- AgentMail is configured via `openclaw agentmail setup`; always verify send/receive with a real test before calling mail setup done.
- Daily morning briefing delivery is scheduled for 09:00 Europe/Samara to Telegram (`morning-briefing-vasiliy`).

## User Preferences
- Communication style: direct, concise, dry, without fluff.
- Ask before external sends and deletions.
- Before network requests, ask first, except scheduled GitHub sync/backup flows already approved.
- Do not claim completion without final validation.
- VPN usage is on-demand only; ask first before enabling.
- Stop after 3 failed attempts on the same task.
- Default time budget is 10 minutes unless the user expands it.
