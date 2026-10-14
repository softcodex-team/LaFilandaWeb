# syntax=docker/dockerfile:1
FROM node:22-alpine AS base
RUN apk add --no-cache libc6-compat
RUN corepack enable
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1 COREPACK_ENABLE_DOWNLOAD_PROMPT=0

FROM base AS deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
RUN pnpm install --frozen-lockfile

FROM deps AS builder
COPY . .
# La build non si connette al database; servono solo valori fittizi per partire
ENV NODE_ENV=production \
    DATABASE_URL=postgres://build:build@localhost:5432/build \
    PAYLOAD_SECRET=build-only-secret
ARG SERVER_URL=http://localhost:3000
ENV SERVER_URL=$SERVER_URL
RUN pnpm build

FROM node:22-alpine AS runner
RUN apk add --no-cache libc6-compat
WORKDIR /app
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1 PORT=3000 HOSTNAME=0.0.0.0
RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
RUN mkdir -p media && chown nextjs:nodejs media
USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
