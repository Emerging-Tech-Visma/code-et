---
context: fork
allowed-tools: Bash(bun:*), Bash(bunx:*), Bash(mkdir:*), Bash(git:*), Write, Read
description: Initialize a new Bun + Next.js + Shadcn/UI project
argument-hint: <project-name>
---

# Initialize Bun + Next.js + Shadcn/UI Project

Project: $ARGUMENTS

Creates a new full-stack project with:

- Bun 1.3.8 runtime
- Next.js 14+ with App Router
- Shadcn/UI components
- TypeScript
- Tailwind CSS
- Docker setup
- Testing with Bun's test runner

## Step 1: Validate Arguments

```bash
PROJECT_NAME="$ARGUMENTS"
if [ -z "$PROJECT_NAME" ]; then
  echo "Error: Project name required"
  echo "Usage: /code:bun-init <project-name>"
  exit 1
fi

if [ -d "$PROJECT_NAME" ]; then
  echo "Error: Directory '$PROJECT_NAME' already exists"
  exit 1
fi
```

## Step 2: Create Next.js Project

```bash
bun create next-app $PROJECT_NAME --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
```

## Step 3: Initialize Shadcn/UI

```bash
cd $PROJECT_NAME
bunx shadcn@latest init -y
```

## Step 4: Add Common Components

```bash
cd $PROJECT_NAME
bunx shadcn@latest add button card input form dialog toast table -y
```

## Step 5: Add Test Dependencies

```bash
cd $PROJECT_NAME
bun add -d @testing-library/react @testing-library/jest-dom happy-dom
```

## Step 6: Create Dockerfile

Write `Dockerfile` with Bun 1.3.8:

```dockerfile
FROM oven/bun:1.3.8-alpine AS deps
WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

FROM oven/bun:1.3.8-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN bun run build

FROM oven/bun:1.3.8-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production PORT=8080 HOSTNAME="0.0.0.0"
RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 8080
CMD ["bun", "run", "server.js"]
```

## Step 7: Create docker-compose.yml

```yaml
version: "3.8"
services:
  app:
    build: .
    ports:
      - "3000:8080"
    environment:
      - NODE_ENV=development
```

## Step 8: Create .env.example

```bash
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

## Step 9: Update next.config.ts

Ensure standalone output for Docker:

```typescript
import type { NextConfig } from "next";
const nextConfig: NextConfig = { output: "standalone" };
export default nextConfig;
```

## Step 10: Create Example Test

Create `__tests__/example.test.ts`:

```typescript
import { describe, it, expect } from "bun:test";
describe("Example", () => {
  it("works", () => expect(1 + 1).toBe(2));
});
```

## Done

Project initialized! Next steps:

```bash
cd $PROJECT_NAME
bun run dev        # Start development
bun test           # Run tests
docker-compose up  # Test Docker build
```
