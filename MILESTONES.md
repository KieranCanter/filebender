# Filebender — Milestone Roadmap

## Milestone 1: Bare Minimum Directory Browser

*Goal: A window that lists file names and lets you navigate.*

- AdwApplication with zig-gobject bindings on Zig 0.16
- GObject-first architecture (custom Application, Window classes)
- `core/` layer: `FbFile`, `FbFileInfo`, `readDirectory()` using `std.Io`
- `gui/` layer: FileNode GObject, DirectoryList (gio.ListModel)
- Simple list view showing file names only
- Click a directory entry to navigate into it
- `../` entry (or "Go Up" button) to navigate to parent
- Start at `$HOME` via XDG resolution
- Basic error handling (permission denied, nonexistent path)

## Milestone 2: Detail View & File Info

*Goal: Show useful information alongside file names.*

- Columns: name, size (human-readable), date modified, file type/kind
- Sort by any column (click column header)
- Directories listed first
- File type icons from system icon theme (icon theme spec)
- MIME type detection via shared MIME database (GIO enrichment in gui layer)
- Hidden files toggle (show/hide dotfiles)
- Breadcrumb path bar replacing plain title

## Milestone 3: Basic File Operations

*Goal: Actually manage files, not just browse.*

- Copy, move, delete (to trash via freedesktop trash spec)
- Rename (inline editing)
- Create new directory
- Create new file
- Drag and drop within the app
- File operation progress indicator
- Keyboard shortcuts for all operations
- Context menu (right-click) with standard actions
- "Open with default application" via desktop file integration

## Milestone 4: Tabs & Navigation History

*Goal: Multi-location workflow.*

- Tabbed browsing (open, close, reorder tabs)
- Back/forward navigation history per tab
- Middle-click to open directory in new tab
- Restore recently closed tabs
- GoTo bar (Ctrl+L) with path autocompletion
- CLI argument to open specific path

## Milestone 5: Search & Filtering

*Goal: Find files fast.*

- Recursive search from current directory
- Filter by name pattern / extension
- Search results displayed in list view
- Flattened folder view (show all descendants inline — FilePilot-style)
- Optional ripgrep integration for content search (optional dep)

## Milestone 6: Preview & Properties

*Goal: Inspect files without leaving the app.*

- Quick preview panel (toggle sidebar showing file contents)
- Text file preview (first N lines)
- Image preview (thumbnails, freedesktop thumbnail spec)
- Properties dialog (size, permissions, timestamps, MIME, path)
- Permissions editing (chmod)
- Folder size calculation (async)

## Milestone 7: Dual Pane & Split Layout

*Goal: Power user spatial workflow.*

- Split view (horizontal/vertical)
- Drag and drop between panes
- Copy/move between panes
- Independent navigation per pane
- Layout persistence across sessions

## Milestone 8: Command Palette & Keybindings

*Goal: Keyboard-first power user experience.*

- Command palette (Ctrl+Shift+P) — search all actions
- Configurable keybindings
- Config file support ($XDG_CONFIG_HOME/filebender/config.toml)
- Per-directory view settings

## Milestone 9: Batch Operations & Advanced File Ops

*Goal: Bulk workflow efficiency.*

- Multi-select with Shift/Ctrl
- Batch rename (patterns, sequential, date-based)
- Undo/redo for file operations
- Compress/extract archives
- Create symlinks
- Duplicate files

## Milestone 10: Desktop Integration & Polish

*Goal: First-class Linux citizen.*

- .desktop file and AppStream metadata
- D-Bus interface (org.freedesktop.FileManager1)
- Single-instance mode
- Directory watcher (inotify — live refresh)
- Bookmarks sidebar (user-defined + XDG user dirs)
- Mountpoint/volume detection in sidebar
- Drag and drop to/from external apps
- Dark mode / theme following system preference (libadwaita handles this)

## Future Milestones (post-1.0)

- Icon/grid view
- Miller columns view
- Tree view sidebar
- Network browsing (SMB, SFTP, FTP, WebDAV)
- MTP device support
- Embedded terminal panel
- File tagging / labels
- Scriptable custom actions
- Content indexing for instant search
