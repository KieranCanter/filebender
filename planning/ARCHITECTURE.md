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

## Library API

Everything is async internally (io_uring). No separate sync/async APIs — `filebender_wait()`
is how you opt into blocking.

```
// Lifecycle
engine = filebender_create()
filebender_destroy(engine)
fd = filebender_get_fd(engine)              // eventfd — fires when completions are ready

// Submit (always non-blocking, returns immediately)
op = filebender_copy(engine, src, dst, .{
    .on_complete = fn(op, userdata),        // one-time: fires during dispatch()
    .on_conflict = fn(op, info, userdata) -> .skip | .overwrite | .rename,
    .userdata = ptr,
    .conflict_policy = .ask,                // or .overwrite / .skip / .rename (bypasses callback)
})
op = filebender_move(engine, src, dst, opts)
op = filebender_delete(engine, path, opts)
op = filebender_list_dir(engine, path, opts)

// Receive completions (callbacks fire HERE, on THIS thread)
filebender_dispatch(engine)                 // drain all pending completions, invoke callbacks

// Pull state (non-blocking, call anytime — reads atomics)
filebender_status(op)                       // .running | .done | .error | .paused | .cancelled
filebender_progress(op)                     // { bytes_done, bytes_total, items_done, items_total }

// Control
filebender_cancel(op)                       // atomic bool, engine stops submitting for this op
filebender_wait(op)                         // futex sleep until op completes (no polling)

// Cleanup
filebender_op_destroy(op)                   // free the handle after reading result
```

### Design principles

- **Callbacks for one-time events** (complete, conflict) — fired during `dispatch()` on the
  caller's thread. Consumer controls when and where.
- **Pull for continuous state** (progress, status) — consumer reads at their framerate, not
  at the library's pace. No interval decision needed.
- **fd is a doorbell** — tells the consumer "call dispatch() now, there are completions."
  Consumer plugs it into their event loop (GSource, epoll, QSocketNotifier, or just poll()).
- **wait() uses futex** — kernel sleep/wake, not a spin loop. Internally calls dispatch()
  so other ops' callbacks still fire while waiting.
- **No `_sync` wrappers** — blocking is `filebender_wait(filebender_copy(engine, ...))`.
- **No `_async` prefix** — everything is async by default.
- **`filebender_` prefix** on all exported C-ABI symbols.

### Integration patterns

```
// CLI tool (blocking):
engine = filebender_create()
result = filebender_wait(filebender_copy(engine, src, dst, .{}))

// GTK app (event loop):
engine = filebender_create()
fd = filebender_get_fd(engine)
// Create GSource watching fd → on ready: filebender_dispatch(engine)
// On frame tick: read filebender_progress(op) for progress bars

// Any event loop:
// Add fd to your epoll/kqueue/io_uring/select.
// When readable → filebender_dispatch(engine)
```

### Filesystem watching

```
watch = filebender_watch(engine, path, .{
    .on_created = fn(path, userdata),
    .on_deleted = fn(path, userdata),
    .on_modified = fn(path, userdata),
    .userdata = ptr,
})
// Callbacks fire during filebender_dispatch() like everything else.
// Internally uses inotify, events batched/deduplicated by the engine.
filebender_unwatch(watch)
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
