const http = require('http');
const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');

const PORT = Number(process.env.PORT || 3030);
const PUBLIC_DIR = path.join(__dirname, 'public');
const FLIGHTWATCH_DIR = '/home/openclaw/.openclaw/agency-agents/flightwatch';
const WORKSPACE_SWARM_FILE = '/home/openclaw/.openclaw/workspace/.clawdbot/active-tasks.json';
const FLIGHTWATCH_SWARM_FILE = '/home/openclaw/.openclaw/agency-agents/flightwatch/.clawdbot/active-tasks.json';

const FALLBACK_PATH = '/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin';
const BIN_CANDIDATES = {
  openclaw: [
    process.env.OPENCLAW_BIN,
    '/home/linuxbrew/.linuxbrew/bin/openclaw',
    '/usr/local/bin/openclaw',
    'openclaw'
  ].filter(Boolean),
  blogwatcher: [
    process.env.BLOGWATCHER_BIN,
    '/home/linuxbrew/.linuxbrew/bin/blogwatcher',
    '/usr/local/bin/blogwatcher',
    'blogwatcher'
  ].filter(Boolean),
  crontab: [process.env.CRONTAB_BIN, '/usr/bin/crontab', 'crontab'].filter(Boolean)
};

function resolveBin(name) {
  const candidates = BIN_CANDIDATES[name] || [name];
  for (const c of candidates) {
    if (c.includes('/')) {
      if (fs.existsSync(c)) return c;
    } else {
      return c;
    }
  }
  return name;
}

const state = {
  status: null,
  sessions: null,
  logs: '',
  flightwatch: null,
  swarm: null,
  cron: '',
  lastRefreshAt: null,
  refreshing: false,
  errors: {}
};

function runCommand(bin, args, { timeout = 15000, maxBuffer = 1024 * 1024 } = {}) {
  return new Promise((resolve, reject) => {
    execFile(bin, args, {
      timeout,
      maxBuffer,
      env: { ...process.env, PATH: process.env.PATH || FALLBACK_PATH }
    }, (error, stdout, stderr) => {
      if (error) return reject(new Error(stderr || error.message));
      resolve((stdout || '').trim());
    });
  });
}

function runOpenclaw(args, { timeout = 15000, maxBuffer = 1024 * 1024 } = {}) {
  return runCommand(resolveBin('openclaw'), args, { timeout, maxBuffer });
}

async function safeStep(name, fn) {
  try {
    await fn();
    state.errors[name] = null;
  } catch (e) {
    state.errors[name] = String(e.message || e);
  }
}

async function refreshCache() {
  if (state.refreshing) return;
  state.refreshing = true;

  await safeStep('status', async () => {
    const raw = await runOpenclaw(['status', '--json'], { timeout: 20000, maxBuffer: 2 * 1024 * 1024 });
    state.status = JSON.parse(raw);
  });

  state.sessions = state.status?.sessions || state.sessions;
  state.errors.sessions = null;

  await safeStep('logs', async () => {
    state.logs = await runOpenclaw(['logs', '--plain', '--limit', '120', '--max-bytes', '120000', '--timeout', '5000'], { timeout: 10000, maxBuffer: 512 * 1024 });
  });

  await safeStep('flightwatch', async () => {
    const routesRaw = fs.readFileSync(path.join(FLIGHTWATCH_DIR, 'routes.json'), 'utf-8');
    const routes = JSON.parse(routesRaw);
    const blogsRaw = await runCommand(resolveBin('blogwatcher'), ['blogs'], { timeout: 10000, maxBuffer: 512 * 1024 });
    state.flightwatch = { routes, blogsRaw };
  });

  await safeStep('swarm', async () => {
    const readTasks = (file) => {
      if (!fs.existsSync(file)) return [];
      return JSON.parse(fs.readFileSync(file, 'utf-8'));
    };

    const workspaceTasks = readTasks(WORKSPACE_SWARM_FILE);
    const flightwatchTasks = readTasks(FLIGHTWATCH_SWARM_FILE);
    const all = [...workspaceTasks, ...flightwatchTasks];

    const byStatus = all.reduce((acc, t) => {
      const s = t.status || 'unknown';
      acc[s] = (acc[s] || 0) + 1;
      return acc;
    }, {});

    state.swarm = {
      total: all.length,
      byStatus,
      tasks: all.slice(0, 100)
    };
  });

  await safeStep('cron', async () => {
    state.cron = await runCommand(resolveBin('crontab'), ['-l'], { timeout: 8000, maxBuffer: 512 * 1024 });
  });

  state.lastRefreshAt = Date.now();
  state.refreshing = false;
}

setInterval(refreshCache, 10000);
refreshCache();

function json(res, status, payload) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(payload));
}

function serveStatic(req, res) {
  const onlyPath = (req.url || '/').split('?')[0];
  const requestedPath = onlyPath === '/' ? '/index.html' : onlyPath;
  const safePath = path.normalize(requestedPath).replace(/^\.\.(\/|\\|$)/, '');
  const filePath = path.join(PUBLIC_DIR, safePath);

  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403);
    return res.end('Forbidden');
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      return res.end('Not found');
    }

    const ext = path.extname(filePath);
    const contentType = ext === '.html'
      ? 'text/html; charset=utf-8'
      : ext === '.css'
        ? 'text/css; charset=utf-8'
        : ext === '.js'
          ? 'application/javascript; charset=utf-8'
          : 'application/octet-stream';

    res.writeHead(200, { 'Content-Type': contentType, 'Cache-Control': 'no-store' });
    res.end(data);
  });
}

const server = http.createServer((req, res) => {
  const onlyPath = (req.url || '/').split('?')[0];

  if (onlyPath === '/api/status') {
    return json(res, 200, {
      ok: Boolean(state.status),
      data: state.status,
      lastRefreshAt: state.lastRefreshAt,
      refreshing: state.refreshing,
      errors: state.errors
    });
  }

  if (onlyPath === '/api/sessions') {
    return json(res, 200, {
      ok: Boolean(state.sessions),
      data: state.sessions,
      lastRefreshAt: state.lastRefreshAt,
      refreshing: state.refreshing,
      errors: state.errors
    });
  }

  if (onlyPath === '/api/logs') {
    return json(res, 200, {
      ok: true,
      data: state.logs || '',
      lastRefreshAt: state.lastRefreshAt,
      refreshing: state.refreshing,
      errors: state.errors
    });
  }

  if (onlyPath === '/api/flightwatch') {
    return json(res, 200, {
      ok: Boolean(state.flightwatch),
      data: state.flightwatch,
      lastRefreshAt: state.lastRefreshAt,
      refreshing: state.refreshing,
      errors: state.errors
    });
  }

  if (onlyPath === '/api/swarm') {
    return json(res, 200, {
      ok: Boolean(state.swarm),
      data: state.swarm,
      lastRefreshAt: state.lastRefreshAt,
      refreshing: state.refreshing,
      errors: state.errors
    });
  }

  if (onlyPath === '/api/cron') {
    return json(res, 200, {
      ok: true,
      data: state.cron || '',
      lastRefreshAt: state.lastRefreshAt,
      refreshing: state.refreshing,
      errors: state.errors
    });
  }

  if (onlyPath === '/api/refresh') {
    refreshCache();
    return json(res, 200, { ok: true, started: true, at: Date.now() });
  }

  return serveStatic(req, res);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Assistant dashboard running on http://0.0.0.0:${PORT}`);
});
