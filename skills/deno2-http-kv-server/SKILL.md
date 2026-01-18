---
name: deno2-http-kv-server
description: Deno 2 HTTP server with KV database. Set up Deno 2 HTTP servers with built-in KV database. Use when creating web servers with Deno, using Deno.serve, working with Deno KV for persistence, or building APIs with Deno 2.
---

# Deno 2 HTTP Server with KV Database

## Problem Pattern
Setting up an HTTP server in Deno 2 with persistent storage using the built-in KV database.

## Solution

### Basic HTTP Server
```typescript
// Run with: deno run --allow-net server.ts

Deno.serve({ port: 8000 }, (req: Request): Response => {
  const url = new URL(req.url);

  if (url.pathname === "/") {
    return new Response("Hello from Deno 2!");
  }

  if (url.pathname === "/json") {
    return Response.json({ message: "Hello!" });
  }

  return new Response("Not Found", { status: 404 });
});
```

### With KV Database (Persistence)
```typescript
// Run with: deno run --allow-net --unstable-kv server.ts

const kv = await Deno.openKv();

Deno.serve({ port: 8000 }, async (req: Request): Promise<Response> => {
  const url = new URL(req.url);

  if (url.pathname === "/") {
    // Increment counter
    const key = ["visitors", "count"];
    const current = await kv.get<number>(key);
    const newCount = (current.value || 0) + 1;
    await kv.set(key, newCount);

    return new Response(`Visitor #${newCount}`);
  }

  if (url.pathname === "/stats") {
    const key = ["visitors", "count"];
    const current = await kv.get<number>(key);
    return Response.json({ total: current.value || 0 });
  }

  return new Response("Not Found", { status: 404 });
});
```

## Key Insights

- **No framework needed** - `Deno.serve` is built-in and handles HTTP/1.1 and HTTP/2 automatically
- **KV requires flag** - Must use `--unstable-kv` flag to enable Deno KV
- **Keys are arrays** - KV keys are arrays like `["users", "123"]` for hierarchical organization
- **Response.json()** - Built-in helper for JSON responses (no need to set headers manually)
- **Automatic compression** - Deno automatically compresses responses with gzip/brotli
- **Use atomic operations for counters** - Simple get/set has race conditions; use `.sum()` for concurrent-safe increments

## Commands

```bash
# Install Deno (if needed)
curl -fsSL https://deno.land/install.sh | sh

# Run basic server
deno run --allow-net server.ts

# Run with KV database
deno run --allow-net --unstable-kv server.ts

# Run with auto-reload during development
deno run --allow-net --unstable-kv --watch server.ts
```

## Common Flags

| Flag | Purpose |
|------|---------|
| `--allow-net` | Allow network access (required for HTTP server) |
| `--unstable-kv` | Enable Deno KV database |
| `--watch` | Auto-restart on file changes |
| `--allow-read` | Allow file system reads (for static files) |

## KV Operations

```typescript
const kv = await Deno.openKv();

// Set a value
await kv.set(["users", "123"], { name: "Alice" });

// Get a value
const result = await kv.get(["users", "123"]);
console.log(result.value); // { name: "Alice" }

// Delete a value
await kv.delete(["users", "123"]);

// List values with prefix
const entries = kv.list({ prefix: ["users"] });
for await (const entry of entries) {
  console.log(entry.key, entry.value);
}
```

## Atomic Operations (Concurrent-Safe)

> **Updated Jan 2026**: Simple get/set causes race conditions with concurrent requests.
> Use atomic operations for counters and concurrent writes.

### The Problem (Race Condition)
```typescript
// DON'T DO THIS for concurrent operations:
const current = await kv.get<number>(["counter"]);
const newCount = (current.value || 0) + 1;
await kv.set(["counter"], newCount);  // Race condition!
// 20 concurrent requests → only ~11 counted
```

### The Solution (Atomic Sum)
```typescript
// DO THIS: Use atomic sum - conflict-free, no race conditions
// Initialize with KvU64
await kv.set(["counter"], new Deno.KvU64(0n));

// Atomic increment (concurrent-safe)
await kv.atomic()
  .sum(["counter"], 1n)  // Atomically add 1
  .commit();

// Read the value
const current = await kv.get<Deno.KvU64>(["counter"]);
const count = Number(current.value?.value || 0n);
// 20 concurrent requests → exactly 20 counted ✓
```

### Complete Atomic Counter Example
```typescript
const kv = await Deno.openKv();
await kv.set(["visitors"], new Deno.KvU64(0n));

Deno.serve({ port: 8000 }, async (req: Request): Promise<Response> => {
  if (new URL(req.url).pathname === "/") {
    // Atomic increment - safe for concurrent requests
    await kv.atomic().sum(["visitors"], 1n).commit();

    const result = await kv.get<Deno.KvU64>(["visitors"]);
    const count = Number(result.value?.value || 0n);
    return new Response(`Visitor #${count}`);
  }
  return new Response("Not Found", { status: 404 });
});
```

### Other Atomic Operations
```typescript
// Atomic set with version check (optimistic locking)
const entry = await kv.get(["key"]);
await kv.atomic()
  .check(entry)  // Only commit if version unchanged
  .set(["key"], "new value")
  .commit();

// Multiple operations in one transaction
await kv.atomic()
  .set(["user", "123"], { name: "Alice" })
  .set(["email", "alice@example.com"], "123")
  .sum(["stats", "users"], 1n)
  .commit();
```

## Context
- **Environment**: Deno 2.x (tested with 2.6.4)
- **Original Error**: `AddrInUse: Address already in use` if port is occupied
- **Root Cause**: Previous server still running on same port

## Troubleshooting

### Deno command not found after install
After fresh install, the shell may not have the updated PATH:
```bash
# Either restart your shell, or use full path:
~/.deno/bin/deno run --allow-net --unstable-kv server.ts

# Or reload PATH:
source ~/.zshrc  # or ~/.bashrc
```

### Port already in use
```bash
# Kill process on port 8000
lsof -ti:8000 | xargs kill -9
```

### KV not working
Make sure you're using the `--unstable-kv` flag:
```bash
deno run --allow-net --unstable-kv server.ts
```

### Counter/data inconsistency with concurrent requests
**Symptom**: Counter shows wrong values, data gets overwritten unexpectedly
**Cause**: Race condition with simple get/set pattern
**Fix**: Use atomic operations (see "Atomic Operations" section above)
```typescript
// Use this instead of get/set for counters:
await kv.atomic().sum(["counter"], 1n).commit();
```

## When NOT to Use
- Need SQL database features (use PostgreSQL/SQLite instead)
- Complex queries required (KV is key-based only)
- Need to share database across multiple machines (use Deno Deploy for hosted KV)

## Sources
- [Deno HTTP Server Docs](https://docs.deno.com/runtime/fundamentals/http_server/)
- [Deno KV Quick Start](https://docs.deno.com/deploy/kv/)
