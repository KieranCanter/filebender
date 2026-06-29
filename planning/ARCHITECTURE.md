# Filebender — Architecture

## Two-Layer Split

- `core/` — Pure language code, stdlib only. Filesystem I/O, data types, operation planning.
- `gui/` — All GLib/GTK/libadwaita C FFI code. GObject wrappers, widgets, app lifecycle.

**Rule:** `gui/` imports from `core/`. `core/` never imports from `gui/` or any GLib/GTK module.

The library (libfilebender, post-1.0) is an extraction of `core/` with a stable C-ABI.
Until then, the boundary is architectural — not a public contract.

---

## Threading Model

| Thread | Role | Lifetime |
|---|---|---|
| Main thread | GTK4 event loop, all UI, dispatch callbacks | App lifetime |
| Engine thread | io_uring ring: submit SQEs, reap CQEs, signal completions | Created with engine |
| Worker threads | CPU-bound work (search, checksums, compression) | Per-operation |

No thread per tab/window/pane. All UI is one thread. GTK requires this.

### What runs where

| Operation | Where | Why |
|---|---|---|
| Directory listing (<1k) | Main thread (sync) | Fast enough, <5ms |
| Directory listing (10k+) | Engine thread (io_uring) | Would block UI |
| File copy/move | Engine thread (io_uring) | Batched syscalls |
| Recursive search | Worker thread + its own io_uring | CPU (matching) + I/O |
| Folder size calculation | Worker thread | Recursive stat |
| Checksums | Worker thread | CPU-bound |
| Thumbnail generation | Worker thread | CPU-bound (image decode) |

---

## Synchronization

| Shared state | Mechanism |
|---|---|
| Operation status/progress | Atomic load/store |
| Operation cancellation | Atomic bool |
| Blocking wait (filebender_wait) | Futex |
| Submission queue (main → engine) | Lock-free MPSC ring buffer |
| Completion queue (engine → main) | Lock-free SPSC ring buffer |
| Directory model (read-heavy) | RwLock or copy-on-write pointer swap |
| Operation registry | RwLock |
| Undo stack | Mutex |
| Thumbnail/MIME cache | RwLock |
| Clipboard source paths | Reference counted |

No mutexes on the hot path (submission → completion).

---

## Error Handling

Every function returns `fb_error_code`. Created objects are passed back via out-param.
Same pattern as Vulkan/SQLite — no NULL checks, one consistent shape.

```c
typedef enum {
    FB_OK = 0,
    FB_ERR_OUT_OF_MEMORY,
    FB_ERR_IO,
    FB_ERR_PERMISSION,
    FB_ERR_NOT_FOUND,
    FB_ERR_NOT_A_DIRECTORY,
    FB_ERR_RING_SETUP,          // io_uring init failed
    FB_ERR_INOTIFY_LIMIT,
    FB_ERR_CANCELLED,
    FB_ERR_DISK_FULL,
    FB_ERR_NAME_CONFLICT,
} fb_error_code;

typedef struct {
    fb_error_code code;
    const char* message;        // human-readable, library-owned (valid until op_destroy)
    const char* path;           // which path caused it (NULL if not path-related)
} fb_error;
```

### Immediate errors (submission failed)

```c
fb_engine* engine;
fb_error_code err = filebender_create(&engine);
if (err != FB_OK) { /* engine not created, err tells you why */ }

fb_op* op;
err = filebender_copy(engine, src, dst, opts, &op);
if (err != FB_OK) { /* op not created — OOM or invalid args */ }
```

### Async errors (operation failed during execution)

```c
filebender_wait(op);
if (filebender_status(op) == FB_STATUS_ERROR) {
    fb_error err = filebender_error(op);
    // err.code, err.message, err.path
}
```

### Two failure classes, same error type

| When | How you learn | Example |
|---|---|---|
| Submission (immediate) | Return code from the function call | OOM, invalid path, bad args |
| Execution (async) | `filebender_status(op) == ERROR` + `filebender_error(op)` | Permission denied, disk full, conflict |

Same `fb_error_code` enum in both cases. Same `fb_error` struct for detail.

### Internal language mapping

| Language | Internal pattern | C-ABI wrapper |
|---|---|---|
| Zig | Error unions (`!T`) | Catch error → return fb_error_code, write out-param on success |
| Odin | Multiple return `(T, Error)` | Check error → return fb_error_code, write out-param on success |

---

## Library API

Everything is async internally (io_uring). No separate sync/async APIs — `filebender_wait()`
is how you opt into blocking.

```c
// Lifecycle
fb_engine* engine;
fb_error_code err = filebender_create(&engine);
filebender_destroy(engine);

int fd = filebender_get_fd(engine);         // eventfd — fires when completions are ready

// Submit (always non-blocking, returns immediately)
fb_op* op;
err = filebender_copy(engine, src, dst, &(fb_copy_opts){
    .on_complete = my_complete_fn,          // one-time: fires during dispatch()
    .on_conflict = my_conflict_fn,          // returns .skip | .overwrite | .rename
    .userdata = ptr,
    .conflict_policy = FB_CONFLICT_ASK,     // or OVERWRITE / SKIP / RENAME (bypasses callback)
}, &op);

err = filebender_move(engine, src, dst, opts, &op);
err = filebender_delete(engine, path, opts, &op);
err = filebender_list_dir(engine, path, opts, &op);

// Receive completions (callbacks fire HERE, on THIS thread)
filebender_dispatch(engine);                // drain all pending completions, invoke callbacks

// Pull state (non-blocking, call anytime — reads atomics)
filebender_status(op);                      // FB_STATUS_RUNNING | DONE | ERROR | PAUSED | CANCELLED
filebender_progress(op);                    // { bytes_done, bytes_total, items_done, items_total }

// Control
filebender_cancel(op);                      // atomic bool, engine stops submitting for this op
filebender_wait(op);                        // futex sleep until op completes (no polling)

// Cleanup
filebender_op_destroy(op);                  // free the handle + associated memory
```

### Design principles

- **Error code + out-param** on every function (Vulkan/SQLite pattern).
- **Callbacks for one-time events** (complete, conflict) — fired during `dispatch()` on the
  caller's thread. Consumer controls when and where.
- **Pull for continuous state** (progress, status) — consumer reads at their framerate, not
  at the library's pace. No interval decision needed.
- **fd is a doorbell** — tells the consumer "call dispatch() now, there are completions."
  Consumer plugs it into their event loop (GSource, epoll, QSocketNotifier, or just poll()).
- **wait() uses futex** — kernel sleep/wake, not a spin loop. Internally calls dispatch()
  so other ops' callbacks still fire while waiting.
- **No `_sync` wrappers** — blocking is: submit, then `filebender_wait(op)`.
- **No `_async` prefix** — everything is async by default.
- **`filebender_` prefix** on all exported C-ABI symbols.

### Integration patterns

```c
// CLI tool (blocking):
fb_engine* engine;
filebender_create(&engine);
fb_op* op;
filebender_copy(engine, src, dst, NULL, &op);
filebender_wait(op);
if (filebender_status(op) == FB_STATUS_ERROR) { /* handle */ }
filebender_op_destroy(op);

// GTK app (event loop):
filebender_create(&engine);
int fd = filebender_get_fd(engine);
// Create GSource watching fd → on ready: filebender_dispatch(engine)
// On frame tick: read filebender_progress(op) for progress bars

// Any event loop:
// Add fd to your epoll/kqueue/io_uring/select.
// When readable → filebender_dispatch(engine)
```

### Filesystem watching

```c
fb_watch* w;
fb_error_code err = filebender_watch(engine, path, &(fb_watch_opts){
    .on_created = my_created_fn,
    .on_deleted = my_deleted_fn,
    .on_modified = my_modified_fn,
    .userdata = ptr,
}, &w);
// Callbacks fire during filebender_dispatch() like everything else.
// Internally uses inotify, events batched/deduplicated by the engine.
filebender_unwatch(w);
```

---

## Internal Data Flow

```
Consumer calls filebender_copy(engine, src, dst, opts)
    │
    │ push to submission queue (lock-free)
    ▼
┌─────────────────────────────────────────────────┐
│  Engine thread                                   │
│                                                  │
│  Pop from submission queue                       │
│  Build copy plan (stat src, enumerate if dir)    │
│  Submit io_uring SQEs:                           │
│    openat(src) → read(buf) → write(dst) → close │
│    (chained, batched, pipelined)                 │
│                                                  │
│  io_uring_wait_cqe() — kernel sleep until I/O    │
│                                                  │
│  On CQE:                                        │
│    Update op.progress (atomic store)             │
│    Submit next batch of SQEs                     │
│    On conflict: set op.status = .paused          │
│    On done: set op.status = .done                │
│                                                  │
│  Signal eventfd (doorbell)                       │
│  Futex wake (if anyone in filebender_wait)       │
└─────────────────────────────────────────────────┘
    │
    │ eventfd fires
    ▼
Consumer's event loop wakes up
    → filebender_dispatch(engine)
    → on_complete callback fires on consumer's thread
```

---

## Memory Management

### Principle: library owns all memory, consumer sees create/destroy

The consumer never passes an allocator or manages library memory. They receive
opaque handles and destroy them when done. Internally, the library uses the right
strategy for each data lifetime.

### Strategies by lifetime

| Data | Lifetime | Strategy |
|---|---|---|
| Directory listing ([]FbFile) | Until navigate away or refresh | Arena — bulk alloc, free_all on leave |
| Copy/move plan | Duration of the operation | Arena tied to op — freed with op_destroy |
| Operation handle + result | Until consumer calls op_destroy | Individual allocation |
| Undo stack entries | Until pruned (max depth) or consumed | Individual alloc/free per entry |
| Caches (MIME, thumbnail) | Until eviction or engine destroy | HashMap with per-entry freeing |
| inotify watch state | Until unwatch or engine destroy | Individual allocation |

### Navigation and arena lifecycle

```
Tab state:
    back_stack:    ["/home/user", "/home/user/Documents"]   // paths only
    forward_stack: ["/home/user/Documents/work"]            // paths only
    current_path:  "/home/user/Downloads"
    listing_arena: Arena     // owns all FbFile data for current view

Navigate (forward, back, or click into child):
    1. Push current_path onto appropriate stack
    2. free_all(listing_arena)
    3. Read new directory into listing_arena
    4. Update current_path
```

Back/forward stacks store only path strings. The directory listing is re-read on
every navigation because the filesystem may have changed. Arenas make this cheap —
one free_all instead of freeing hundreds of individual FbFile allocations.

### Why not arena for undo

Undo entries have independent lifetimes. When the deque exceeds max depth, the oldest
entry is dropped while all others remain. An arena can't free one entry without freeing
all — so undo uses individual alloc/free per entry.

### Consumer API implications

```
engine = filebender_create()           // allocates engine + internal structures
op = filebender_copy(engine, ...)      // allocates op handle + arena for plan
filebender_op_destroy(op)              // frees op handle + its arena
filebender_destroy(engine)             // frees everything (caches, undo, watches)
```

No allocator parameters. No memory ownership transfer. Consumer's only responsibility:
call destroy when done.

---

## Library State

### Owned by the library (core/)

| State | Purpose |
|---|---|
| io_uring ring + engine thread | Execution engine |
| Active operations + status | Track in-flight work |
| Operation history / undo log | Reversible operations |
| inotify watches | Filesystem change notifications |
| Directory cache | Avoid re-reading unchanged dirs (invalidated by inotify) |
| MIME type cache | Extension → type mapping |
| Thumbnail cache | Generated thumbnails keyed by path + mtime |
| Trash state | What's trashed, original paths |

### Owned by the application (gui/)

| State | Purpose |
|---|---|
| Current directory per tab | Navigation state |
| Selection state | UI concern |
| Sort/filter/group settings | View preferences |
| Tab/pane layout | UI arrangement |
| Bookmarks | User favorites |
| Clipboard intent (copy vs cut) | UI decision on paste behavior |
