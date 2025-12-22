# Multi-stage Dockerfile for Next.js 16 + Tailwind projects
# - target "dev" for local development (hot reload)
# - target "prod" for production images (optimized, minimal)

# Base image with working dir and common PATH
FROM node:18-alpine AS base
WORKDIR /app
ENV PATH /app/node_modules/.bin:$PATH

# Install all dependencies for development (shared layer to speed up rebuilds)
FROM base AS deps
COPY package.json package-lock.json* yarn.lock* ./
# install nothing here — keep as placeholder if you want a separate deps layer

# Development image: installs dev deps and runs dev server
FROM base AS dev
COPY package.json package-lock.json* yarn.lock* ./
# Use npm ci when lockfile present; otherwise fallback to npm install
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
COPY . .
EXPOSE 3000
# Use Next's dev script (ensure package.json has "dev": "next dev")
CMD ["npm", "run", "dev"]

# Builder: install dependencies and build the Next.js app
FROM base AS builder
COPY package.json package-lock.json* yarn.lock* ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
COPY . .
# Build the Next.js app (ensure package.json has "build": "next build")
RUN npm run build

# Production image: minimal, only runtime deps and built output
FROM node:18-alpine AS prod
WORKDIR /app
ENV NODE_ENV=production
# Copy only what's necessary from builder
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
# Install only production dependencies
RUN if [ -f package-lock.json ]; then npm ci --only=production; else npm install --production; fi
EXPOSE 3000
# Healthcheck (optional)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s CMD wget -qO- http://localhost:3000/_next/static || exit 1
# Start the app (ensure package.json has "start": "next start -p $PORT")
CMD ["npm", "start"]