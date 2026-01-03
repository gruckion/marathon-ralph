# SQLite Skill for better-t-stack

## Overview

SQLite database implementation using LibSQL client and Drizzle ORM. This skill covers local development, Turso cloud, and Cloudflare D1 deployments.

---

## CRITICAL WARNING

**NEVER use `bun:sqlite` with Next.js applications.**

Next.js runs on Node.js, not Bun runtime. Using `bun:sqlite` causes:

```markdown
Cannot find module 'bun:sqlite'
```

**Always use `@libsql/client`** - it works in both Node.js and Bun environments.

---

## Library Stack

| Package | Version | Purpose |
|---------|---------|---------|
| `@libsql/client` | 0.15.15 | LibSQL database client |
| `libsql` | 0.5.22 | Native LibSQL bindings |
| `drizzle-orm` | ^0.45.1 | ORM with type-safe queries |
| `drizzle-kit` | ^0.31.8 | Migrations and studio |

---

## Setup Modes

### 1. Local Development (Recommended for Dev)

Uses Turso CLI to run local SQLite file.

**Environment:**

```env
DATABASE_URL=file:local.db
```

**Start local database:**

```bash
turso dev --db-file local.db
```

### 2. Turso Cloud (Production)

Distributed SQLite hosted on Turso.

**Environment:**

```env
DATABASE_URL=libsql://your-db-name-org.turso.io
DATABASE_AUTH_TOKEN=your-auth-token
```

### 3. Cloudflare D1 (Workers Only)

Serverless SQLite on Cloudflare Workers.

**Note:** Requires Workers runtime and different driver configuration.

---

## Installation

```bash
ni @libsql/client libsql drizzle-orm drizzle-kit
```

---

## Database Client Setup

### File: `packages/db/src/index.ts`

```typescript
import { createClient } from "@libsql/client";
import { drizzle } from "drizzle-orm/libsql";
import * as schema from "./schema";

// Environment validation
const env = {
  DATABASE_URL: process.env.DATABASE_URL,
  DATABASE_AUTH_TOKEN: process.env.DATABASE_AUTH_TOKEN,
};

if (!env.DATABASE_URL) {
  throw new Error("DATABASE_URL is required");
}

// Create LibSQL client
const client = createClient({
  url: env.DATABASE_URL,
  authToken: env.DATABASE_AUTH_TOKEN, // Optional for local, required for Turso
});

// Export Drizzle instance with schema
export const db = drizzle({ client, schema });

// Re-export schema for convenience
export * from "./schema";
```

---

## Drizzle Configuration

### File: `drizzle.config.ts`

```typescript
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: "./src/schema",
  out: "./src/migrations",
  dialect: "turso",
  dbCredentials: {
    url: process.env.DATABASE_URL || "",
    authToken: process.env.DATABASE_AUTH_TOKEN,
  },
});
```

### For Cloudflare D1

```typescript
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: "./src/schema",
  out: "./src/migrations",
  dialect: "sqlite",
  driver: "d1-http",
  dbCredentials: {
    accountId: process.env.CLOUDFLARE_ACCOUNT_ID!,
    databaseId: process.env.CLOUDFLARE_D1_ID!,
    token: process.env.CLOUDFLARE_API_TOKEN!,
  },
});
```

---

## Schema Patterns

### File: `packages/db/src/schema/index.ts`

```typescript
import { sql } from "drizzle-orm";
import {
  sqliteTable,
  text,
  integer,
  index,
  primaryKey,
} from "drizzle-orm/sqlite-core";

// Basic table with common patterns
export const users = sqliteTable(
  "users",
  {
    id: text("id").primaryKey(),
    email: text("email").notNull().unique(),
    name: text("name"),
    createdAt: integer("created_at", { mode: "timestamp_ms" })
      .default(sql`(unixepoch() * 1000)`)
      .notNull(),
    updatedAt: integer("updated_at", { mode: "timestamp_ms" })
      .default(sql`(unixepoch() * 1000)`)
      .notNull(),
  },
  (table) => [
    index("users_email_idx").on(table.email),
  ]
);

// Boolean columns (SQLite uses integers)
export const todos = sqliteTable("todos", {
  id: text("id").primaryKey(),
  title: text("title").notNull(),
  completed: integer("completed", { mode: "boolean" }).default(false),
  userId: text("user_id").references(() => users.id, { onDelete: "cascade" }),
  createdAt: integer("created_at", { mode: "timestamp_ms" })
    .default(sql`(unixepoch() * 1000)`),
});

// Composite primary key
export const userRoles = sqliteTable(
  "user_roles",
  {
    userId: text("user_id").notNull().references(() => users.id),
    role: text("role").notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.userId, table.role] }),
  ]
);
```

### SQLite Column Type Reference

| TypeScript Type | SQLite Column | Drizzle Definition |
|-----------------|---------------|-------------------|
| `string` | TEXT | `text("column")` |
| `number` | INTEGER | `integer("column")` |
| `boolean` | INTEGER | `integer("column", { mode: "boolean" })` |
| `Date` | INTEGER | `integer("column", { mode: "timestamp_ms" })` |
| `object` | TEXT | `text("column", { mode: "json" })` |

---

## Query Examples

### Basic CRUD Operations

```typescript
import { db, users, todos } from "@repo/db";
import { eq, and, desc, like } from "drizzle-orm";
import { nanoid } from "nanoid";

// CREATE
const newUser = await db.insert(users).values({
  id: nanoid(),
  email: "user@example.com",
  name: "John Doe",
}).returning();

// READ - Single
const user = await db.query.users.findFirst({
  where: eq(users.email, "user@example.com"),
});

// READ - Multiple with filters
const activeTodos = await db.query.todos.findMany({
  where: and(
    eq(todos.userId, userId),
    eq(todos.completed, false)
  ),
  orderBy: desc(todos.createdAt),
  limit: 10,
});

// UPDATE
await db.update(todos)
  .set({ completed: true })
  .where(eq(todos.id, todoId));

// DELETE
await db.delete(todos)
  .where(eq(todos.id, todoId));
```

### Relations Query

```typescript
// Define relations in schema
import { relations } from "drizzle-orm";

export const usersRelations = relations(users, ({ many }) => ({
  todos: many(todos),
}));

export const todosRelations = relations(todos, ({ one }) => ({
  user: one(users, {
    fields: [todos.userId],
    references: [users.id],
  }),
}));

// Query with relations
const userWithTodos = await db.query.users.findFirst({
  where: eq(users.id, userId),
  with: {
    todos: {
      where: eq(todos.completed, false),
      orderBy: desc(todos.createdAt),
    },
  },
});
```

---

## Package.json Scripts

```json
{
  "scripts": {
    "db:local": "turso dev --db-file local.db",
    "db:push": "drizzle-kit push",
    "db:generate": "drizzle-kit generate",
    "db:migrate": "drizzle-kit migrate",
    "db:studio": "drizzle-kit studio"
  }
}
```

### Script Usage

| Command | Purpose |
|---------|---------|
| `nr db:local` | Start local SQLite server |
| `nr db:push` | Push schema changes directly (dev) |
| `nr db:generate` | Generate migration files |
| `nr db:migrate` | Run pending migrations |
| `nr db:studio` | Open Drizzle Studio GUI |

---

## Environment Setup

### Local Development

```env
# .env.local
DATABASE_URL=file:local.db
```

### Turso Production

```env
# .env.production
DATABASE_URL=libsql://your-db-name-org.turso.io
DATABASE_AUTH_TOKEN=eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9...
```

### Create Turso Database

```bash
# Install Turso CLI
curl -sSfL https://get.tur.so/install.sh | bash

# Login
turso auth login

# Create database
turso db create my-app-db

# Get connection URL
turso db show my-app-db --url

# Create auth token
turso db tokens create my-app-db
```

---

## Migration Workflow

### Development (Push)

For rapid iteration, use push to sync schema directly:

```bash
nr db:push
```

### Production (Migrations)

Generate and apply migration files:

```bash
# 1. Generate migration from schema changes
nr db:generate

# 2. Review generated SQL in src/migrations/

# 3. Apply migrations
nr db:migrate
```

---

## Common Patterns

### ID Generation

```typescript
import { nanoid } from "nanoid";

// In insert operations
await db.insert(users).values({
  id: nanoid(), // Generates: "V1StGXR8_Z5jdHi6B-myT"
  // ...
});
```

### Timestamps

```typescript
// Auto-set on insert via default
createdAt: integer("created_at", { mode: "timestamp_ms" })
  .default(sql`(unixepoch() * 1000)`)
  .notNull(),

// Manual update for updatedAt
await db.update(users)
  .set({
    name: "New Name",
    updatedAt: new Date(),
  })
  .where(eq(users.id, userId));
```

### Transactions

```typescript
await db.transaction(async (tx) => {
  const [user] = await tx.insert(users).values({
    id: nanoid(),
    email: "user@example.com",
  }).returning();

  await tx.insert(todos).values({
    id: nanoid(),
    title: "Welcome todo",
    userId: user.id,
  });
});
```

---

## Troubleshooting

### Error: Cannot find module 'bun:sqlite'

**Cause:** Using `bun:sqlite` in a Node.js environment (Next.js).

**Solution:** Use `@libsql/client` instead:

```typescript
// WRONG
import { Database } from "bun:sqlite";

// CORRECT
import { createClient } from "@libsql/client";
```

### Error: SQLITE_BUSY

**Cause:** Multiple connections attempting writes.

**Solution:** Use WAL mode or connection pooling:

```typescript
const client = createClient({
  url: env.DATABASE_URL,
  // Enable connection reuse
  syncUrl: env.DATABASE_URL,
});
```

### Error: No such table

**Cause:** Migrations not applied.

**Solution:**

```bash
nr db:push  # For dev
# or
nr db:migrate  # For production
```

---

## File Structure

```
packages/db/
  src/
    index.ts          # Database client export
    schema/
      index.ts        # All table definitions
      users.ts        # User table (optional split)
      todos.ts        # Todo table (optional split)
    migrations/       # Generated migration files
  drizzle.config.ts   # Drizzle Kit configuration
  package.json
```

---

## Quick Reference

```typescript
// Import everything you need
import { db, users, todos } from "@repo/db";
import { eq, and, or, desc, asc, like, sql } from "drizzle-orm";

// Insert
await db.insert(users).values({ ... }).returning();

// Select
await db.query.users.findFirst({ where: eq(users.id, id) });
await db.query.users.findMany({ limit: 10, orderBy: desc(users.createdAt) });

// Update
await db.update(users).set({ ... }).where(eq(users.id, id));

// Delete
await db.delete(users).where(eq(users.id, id));

// Raw SQL
await db.run(sql`VACUUM`);
```
