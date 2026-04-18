# ─── Build Stage ──────────────────────────────────────────────────────────
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files first (better layer caching)
COPY package*.json ./

# Install all deps including devDependencies
RUN npm ci

# ─── Production Stage ─────────────────────────────────────────────────────
FROM node:18-alpine AS production

# Add non-root user for security (maps to white paper HIPAA requirement)
RUN addgroup -g 1001 -S nodejs && \
    adduser  -S nodeuser -u 1001

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production deps only
RUN npm ci --only=production && \
    npm cache clean --force

# Copy app source from builder
COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/

# Set ownership
RUN chown -R nodeuser:nodejs /app

# Switch to non-root user
USER nodeuser

# Expose app port
EXPOSE 3000

# Health check — Kubernetes uses this for pod readiness
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Environment defaults (overridden by Kubernetes deployment.yaml)
ENV NODE_ENV=production \
    PORT=3000 \
    MAX_SESSIONS=3

CMD ["node", "src/index.js"]