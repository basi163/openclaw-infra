#!/usr/bin/env python3
import json
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWARM = ROOT / ".clawdbot"
TASKS_FILE = SWARM / "active-tasks.json"


def sh(cmd):
    return subprocess.run(cmd, text=True, capture_output=True)


def notify(text: str):
    subprocess.run(["openclaw", "system", "event", "--text", text, "--mode", "now"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def has_tmux(session: str) -> bool:
    return sh(["tmux", "has-session", "-t", session]).returncode == 0


def pr_for_branch(branch: str):
    p = sh(["gh", "pr", "list", "--head", branch, "--state", "open", "--json", "number,url,isDraft,statusCheckRollup", "--limit", "1"])
    if p.returncode != 0:
        return None
    try:
        arr = json.loads(p.stdout or "[]")
    except Exception:
        return None
    return arr[0] if arr else None


def ci_passed(rollup):
    if not rollup:
        return False
    ok = {"SUCCESS", "NEUTRAL", "SKIPPED"}
    for item in rollup:
        c = (item.get("conclusion") or "").upper()
        s = (item.get("status") or "").upper()
        if s and s not in {"COMPLETED"}:
            return False
        if c and c not in ok:
            return False
        if not c:
            return False
    return True


def respawn_task(t: dict) -> bool:
    session = t.get("tmuxSession")
    worktree = t.get("worktree")
    agent = t.get("agent", "codex")
    model = t.get("model", "gpt-5.3-codex")
    reasoning = t.get("reasoning", "high")
    prompt_file = t.get("promptFile")
    log_file = t.get("logFile", str(SWARM / "logs" / f"{t.get('id','task')}.log"))

    if not (session and worktree and prompt_file):
        return False

    subprocess.run(["tmux", "kill-session", "-t", session], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    cmd = f"cd '{worktree}' && '{SWARM / 'run-agent.sh'}' '{agent}' '{model}' '{reasoning}' '{prompt_file}' >>'{log_file}' 2>&1"
    p = sh(["tmux", "new-session", "-d", "-s", session, cmd])
    return p.returncode == 0


def load_tasks():
    if not TASKS_FILE.exists():
        return []
    try:
        return json.loads(TASKS_FILE.read_text(encoding="utf-8"))
    except Exception:
        return []


def save_tasks(tasks):
    TASKS_FILE.write_text(json.dumps(tasks, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    tasks = load_tasks()
    changed = False
    now = int(time.time() * 1000)

    for t in tasks:
        status = t.get("status")
        if status in {"done", "failed"}:
            continue

        session = t.get("tmuxSession", "")
        branch = t.get("branch", "")
        pr = pr_for_branch(branch) if branch else None
        alive = has_tmux(session) if session else False

        if pr:
            t["pr"] = pr.get("number")
            t["prUrl"] = pr.get("url")
            checks = {
                "prCreated": True,
                "ciPassed": ci_passed(pr.get("statusCheckRollup") or []),
            }
            t["checks"] = checks

            if (not pr.get("isDraft")) and checks["ciPassed"]:
                if t.get("status") != "ready_for_review":
                    t["status"] = "ready_for_review"
                    t["completedAt"] = now
                    if t.get("notifyOnComplete", True):
                        notify(f"✅ PR #{t['pr']} ready for review: {t.get('id')}")
                changed = True
            else:
                if t.get("status") != "waiting_checks":
                    t["status"] = "waiting_checks"
                    changed = True
            continue

        if alive:
            if t.get("status") != "running":
                t["status"] = "running"
                changed = True
            continue

        # no PR and no live session => retry with respawn
        retries = int(t.get("retries", 0))
        max_retries = int(t.get("maxRetries", 3))
        if retries < max_retries:
            t["retries"] = retries + 1
            ok = respawn_task(t)
            t["status"] = "running" if ok else "needs_retry"
            changed = True
            notify(f"⚠️ Agent stopped for {t.get('id')} (retry {t['retries']}/{max_retries})")
        else:
            t["status"] = "failed"
            t["completedAt"] = now
            changed = True
            notify(f"❌ Task failed after retries: {t.get('id')}")

    if changed:
        save_tasks(tasks)


if __name__ == "__main__":
    main()
