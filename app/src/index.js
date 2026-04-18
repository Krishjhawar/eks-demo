const express = require('express');
const client = require('prom-client');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const MAX_SESSIONS = parseInt(process.env.MAX_SESSIONS) || 3;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ─── Prometheus Registry ───────────────────────────────────────────────────
const register = new client.Registry();
register.setDefaultLabels({ app: 'eks-demo' });
client.collectDefaultMetrics({ register });

const activeUsersGauge = new client.Gauge({
  name: 'app_active_users',
  help: 'Number of active user sessions',
  registers: [register]
});

const httpRequestCounter = new client.Counter({
  name: 'app_http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register]
});

const cpuStressGauge = new client.Gauge({
  name: 'app_cpu_stress_active',
  help: '1 if CPU stress is currently running, 0 otherwise',
  registers: [register]
});

// ─── Session Store ─────────────────────────────────────────────────────────
const sessions = new Map();

function cleanStaleSessions() {
  const now = Date.now();
  for (const [id, data] of sessions) {
    if (now - data.lastSeen > 120000) { // 2 min idle = expired
      sessions.delete(id);
    }
  }
  activeUsersGauge.set(sessions.size);
}

setInterval(cleanStaleSessions, 15000);

// ─── Session Middleware ────────────────────────────────────────────────────
app.use((req, res, next) => {
  if (req.path === '/metrics') return next(); // skip for prometheus

  let sessionId = req.headers['x-session-id'];

  if (!sessionId || !sessions.has(sessionId)) {
    sessionId = uuidv4();
    sessions.set(sessionId, { createdAt: Date.now(), lastSeen: Date.now() });
  } else {
    sessions.get(sessionId).lastSeen = Date.now();
  }

  activeUsersGauge.set(sessions.size);
  res.setHeader('x-session-id', sessionId);
  next();
});

// ─── Routes ───────────────────────────────────────────────────────────────

// Prometheus scrape endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Status endpoint
app.get('/status', (req, res) => {
  httpRequestCounter.inc({ method: 'GET', route: '/status', status: 200 });
  cleanStaleSessions();

  res.json({
    podName:      process.env.HOSTNAME || 'local',
    activeUsers:  sessions.size,
    maxUsers:     MAX_SESSIONS,
    overloaded:   sessions.size > MAX_SESSIONS,
    nodeVersion:  process.version,
    uptime:       Math.floor(process.uptime()),
    timestamp:    new Date().toISOString()
  });
});

// CPU stress endpoint — triggers HPA
app.post('/stress', (req, res) => {
  httpRequestCounter.inc({ method: 'POST', route: '/stress', status: 200 });
  const duration = Math.min(parseInt(req.body?.duration) || 10, 60); // max 60s

  cpuStressGauge.set(1);
  const end = Date.now() + duration * 1000;

  // Non-blocking CPU burn using setImmediate chunks
  function burnChunk() {
    const chunkEnd = Date.now() + 100;
    while (Date.now() < chunkEnd) {
      Math.sqrt(Math.random() * 999999999);
    }
    if (Date.now() < end) {
      setImmediate(burnChunk);
    } else {
      cpuStressGauge.set(0);
    }
  }

  setImmediate(burnChunk);

  res.json({
    message:   `Stressing CPU for ${duration} seconds`,
    pod:       process.env.HOSTNAME || 'local',
    duration,
    startedAt: new Date().toISOString()
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', pod: process.env.HOSTNAME || 'local' });
});

// ─── Start ─────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`eks-demo app running on port ${PORT}`);
  console.log(`Max sessions threshold: ${MAX_SESSIONS}`);
  console.log(`Pod: ${process.env.HOSTNAME || 'local'}`);
});