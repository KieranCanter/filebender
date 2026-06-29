# Filebender — Milestone Roadmap

## Milestone 1: Bare Minimum Directory Browser

*Goal: A window that lists file names and lets you navigate.*

- Application window with GTK4/libadwaita
- GObject-first architecture (custom Application, Window classes)
- `core/` layer: `FbFile`, `FbFileInfo`, `readDirectory()` using OS-native file I/O
- `gui/` layer: FileNode GObject, DirectoryList (gio.ListModel)
- Simple list view showing file names only
- Click a directory entry to navigate into it
- "Go Up" button to navigate to parent
- Start at `$HOME` via XDG resolution
- Basic error handling (permission denied, nonexistent path)

## Milestone 2: Detail View & File Info

*Goal: Show useful information alongside file names.*

- Columns: name, size (human-readable), date modified, file type/kind
- Sort by any column (click column header)
- Directories listed first (configurable)
- File type icons from system icon theme (icon theme spec)
- MIME type detection via shared MIME database (GIO enrichment in gui layer)
- Hidden files toggle (show/hide dotfiles)
- Breadcrumb path bar replacing plain title
- Status bar (item count, total size, selection summary)

## Milestone 3: Basic File Operations

*Goal: Actually manage files, not just browse.*

- Multi-select with Shift/Ctrl (prerequisite for all bulk operations)
- Selection tools (select all, select by extension, invert selection)
- Copy, move, delete (to trash via freedesktop trash spec)
- File conflict resolution dialogs (name collision on copy/move: skip, overwrite, rename)
- Rename (inline editing)
- Create new directory
- Create new file
- Drag and drop within the app
- File operation progress indicator (with cancel/pause)
- Keyboard shortcuts for all operations
- Context menu (right-click) with standard actions
- "Open with default application" via desktop file integration

## Milestone 4: Tabs, Navigation & Configuration

*Goal: Multi-location workflow and user preferences.*

- Tabbed browsing (open, close, reorder tabs)
- Back/forward navigation history per tab
- Middle-click to open directory in new tab
- Restore recently closed tabs
- GoTo bar (Ctrl+L) with path autocompletion
- CLI argument to open specific path
- Config file support ($XDG_CONFIG_HOME/filebender/config.toml)
- Per-directory view settings
- Configurable keybindings foundation

## Milestone 5: Search, Filtering & Live Refresh

*Goal: Find files fast, stay in sync with the filesystem.*

- Directory watcher (inotify/fanotify — live refresh on filesystem changes)
- Recursive search from current directory
- Fuzzy search (FilePilot-inspired)
- Filter by name pattern / extension
- Search results displayed in list view
- Flattened folder view (show all descendants inline — FilePilot-style)
- Search results as virtual folder
- Optional ripgrep integration for content search (optional dep)

## Milestone 6: Preview & Properties

*Goal: Inspect files without leaving the app.*

- Quick preview panel (toggle sidebar showing file contents)
- Text file preview (first N lines, syntax highlighted)
- Image preview (thumbnails, freedesktop thumbnail spec)
- Properties dialog (size, permissions, timestamps, MIME, path)
- Permissions editing (chmod)
- Folder size calculation (async)
- Checksum display/verification (MD5, SHA256)

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
- Vim-style keybindings (optional mode)
- Full keybinding customization via config
- Action system (all operations are named, searchable, bindable)

## Milestone 9: Batch Operations & Advanced File Ops

*Goal: Bulk workflow efficiency.*

- Batch rename (patterns, sequential, date-based, regex — FilePilot-inspired)
- Undo/redo for file operations
- Compress/extract archives (zip, tar.gz, tar.xz, tar.zst)
- Create symlinks / hardlinks
- Duplicate files
- Selection predicates (select all matching pattern, select larger than, etc.)

## Milestone 10: Desktop Integration & Polish

*Goal: First-class Linux citizen.*

- .desktop file and AppStream metadata
- D-Bus interface (org.freedesktop.FileManager1)
- Single-instance mode
- Bookmarks sidebar (user-defined + XDG user dirs)
- Mountpoint/volume detection in sidebar
- Drag and drop to/from external apps
- Dark mode / theme following system preference (libadwaita handles this)

## Future Milestones (post-1.0)

- **libfilebender** — extract and stabilize core/ as a standalone C-ABI library for
  third-party file manager implementations (Ghostty/libghostty model)
- Icon/grid view
- Miller columns view
- Tree view sidebar
- Network browsing (SMB, SFTP, FTP, WebDAV)
- MTP device support
- Embedded terminal panel
- File tagging / labels
- Scriptable custom actions (user-defined shell scripts as context menu items)
- Content indexing for instant search
- Git status integration (modified/untracked/ignored markers in file list)
