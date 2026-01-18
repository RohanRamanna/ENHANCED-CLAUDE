---
name: hono-bun-sqlite-api
description: REST API with Hono, Bun and SQLite. Build REST APIs with Hono framework, Bun runtime, and SQLite database. Use when creating web APIs with Bun, using Hono framework, working with bun:sqlite, or building CRUD applications.
---

# Hono + Bun + SQLite API

## Problem Pattern
Building a REST API with Bun runtime using Hono web framework and SQLite for persistence.

## Solution

### Quick Setup
```bash
# Create project
mkdir my-api && cd my-api
bun init -y
bun add hono
```

### Complete CRUD Example
```typescript
// index.ts
import { Hono } from "hono";
import { Database } from "bun:sqlite";

// Initialize database (creates file if not exists)
const db = new Database("data.db");

// Create table
db.run(`
  CREATE TABLE IF NOT EXISTS items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
  )
`);

const app = new Hono();

// LIST all
app.get("/items", (c) => {
  const items = db.query("SELECT * FROM items").all();
  return c.json(items);
});

// GET one
app.get("/items/:id", (c) => {
  const id = c.req.param("id");
  const item = db.query("SELECT * FROM items WHERE id = ?").get(id);
  if (!item) return c.json({ error: "Not found" }, 404);
  return c.json(item);
});

// CREATE
app.post("/items", async (c) => {
  const { name } = await c.req.json();
  if (!name) return c.json({ error: "Name required" }, 400);

  const result = db.run("INSERT INTO items (name) VALUES (?)", [name]);
  const newItem = db.query("SELECT * FROM items WHERE id = ?").get(result.lastInsertRowid);
  return c.json(newItem, 201);
});

// UPDATE
app.put("/items/:id", async (c) => {
  const id = c.req.param("id");
  const { name } = await c.req.json();

  const existing = db.query("SELECT * FROM items WHERE id = ?").get(id);
  if (!existing) return c.json({ error: "Not found" }, 404);

  db.run("UPDATE items SET name = ? WHERE id = ?", [name, id]);
  const updated = db.query("SELECT * FROM items WHERE id = ?").get(id);
  return c.json(updated);
});

// DELETE
app.delete("/items/:id", (c) => {
  const id = c.req.param("id");

  const existing = db.query("SELECT * FROM items WHERE id = ?").get(id);
  if (!existing) return c.json({ error: "Not found" }, 404);

  db.run("DELETE FROM items WHERE id = ?", [id]);
  return c.json({ message: "Deleted" });
});

// Export for Bun
export default {
  port: 3000,
  fetch: app.fetch,
};
```

### Run the Server
```bash
bun run index.ts

# Or with hot reload
bun --hot run index.ts
```

## Key Insights

- **No npm package for SQLite** - Use `bun:sqlite` built-in module (3-6x faster than better-sqlite3)
- **Synchronous API** - Unlike Node.js, bun:sqlite is synchronous (no async/await needed for queries)
- **Export pattern** - Bun expects `export default { port, fetch }` format
- **Database file** - `new Database("file.db")` creates persistent file; `new Database(":memory:")` for in-memory
- **Hono context** - Use `c.json()` for JSON responses, `c.req.json()` for body parsing

## Commands

```bash
# Install Bun (if needed)
curl -fsSL https://bun.sh/install | bash

# Create project
bun init -y
bun add hono

# Run server
bun run index.ts

# Run with hot reload
bun --hot run index.ts
```

## SQLite Operations

```typescript
import { Database } from "bun:sqlite";

const db = new Database("mydb.db");

// Run (INSERT, UPDATE, DELETE, CREATE)
const result = db.run("INSERT INTO users (name) VALUES (?)", ["Alice"]);
console.log(result.lastInsertRowid); // Get inserted ID

// Query single row
const user = db.query("SELECT * FROM users WHERE id = ?").get(1);

// Query multiple rows
const users = db.query("SELECT * FROM users").all();

// Prepared statements (reusable, faster)
const stmt = db.prepare("SELECT * FROM users WHERE id = ?");
const user1 = stmt.get(1);
const user2 = stmt.get(2);
```

## Hono Patterns

```typescript
import { Hono } from "hono";

const app = new Hono();

// Route parameters
app.get("/users/:id", (c) => {
  const id = c.req.param("id");
  return c.json({ id });
});

// Query parameters
app.get("/search", (c) => {
  const q = c.req.query("q");
  return c.json({ query: q });
});

// JSON body
app.post("/users", async (c) => {
  const body = await c.req.json();
  return c.json(body, 201);
});

// Set status code
return c.json({ error: "Not found" }, 404);

// Text response
return c.text("Hello!");

// HTML response
return c.html("<h1>Hello</h1>");
```

## Troubleshooting

### Bun command not found after install
After fresh install, the shell may not have the updated PATH:
```bash
# Either restart your shell, or use full path:
~/.bun/bin/bun run index.ts

# Or reload PATH:
source ~/.zshrc  # or ~/.bashrc
```

### Port already in use
```bash
# Kill process on port 3000
lsof -ti:3000 | xargs kill -9
```

### Database locked
SQLite allows only one writer at a time. For concurrent writes, use WAL mode:
```typescript
db.run("PRAGMA journal_mode=WAL");
```

## Context
- **Environment**: Bun 1.x+, Hono 4.x
- **Performance**: bun:sqlite is 3-6x faster than better-sqlite3
- **Use case**: REST APIs, CRUD apps, prototypes, small-medium apps

## When NOT to Use
- Need real-time features → Add WebSocket support
- High concurrent writes → Consider PostgreSQL
- Complex queries/joins → Consider an ORM like Drizzle

## Sources
- [Hono + Bun Docs](https://hono.dev/docs/getting-started/bun)
- [Bun SQLite Docs](https://bun.sh/docs/api/sqlite)
