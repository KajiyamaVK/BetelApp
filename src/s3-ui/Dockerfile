FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
ARG GIT_COMMIT=unknown
RUN echo "$GIT_COMMIT" > .build-hash
COPY . .
# DATABASE_URL is not needed for code generation — only for runtime connections.
# Pass a placeholder so prisma.config.ts can load without throwing PrismaConfigEnvError.
RUN DATABASE_URL=postgresql://x:x@localhost/x npx prisma generate
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["node", "server.js"]

# Dedicated migrator stage — keeps full node_modules so prisma.config.ts loads correctly
FROM node:20-alpine AS migrator
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/prisma.config.ts ./prisma.config.ts
COPY docker-migrator-entrypoint.sh ./
RUN chmod +x docker-migrator-entrypoint.sh
CMD ["./docker-migrator-entrypoint.sh"]
