# Filebender — Comprehensive Feature List

A native, feature-rich Linux file manager built in Zig with GTK4/libadwaita.
Inspired by Ghostty's native approach, competing with Nautilus/Thunar/Nemo/Dolphin,
drawing feature inspiration from FilePilot on Windows.

## Core Navigation & Browsing

- Directory listing (list/detail view)
- Directory navigation (click into, go up/parent)
- Icon/grid view
- Miller columns view
- Tree view sidebar
- Breadcrumb path bar with editable text mode
- GoTo bar with autocompletion (FilePilot-inspired)
- Back/forward navigation history
- Tabs (open, close, reorder, drag between panels, restore recently closed)
- Dual/split pane layout (arbitrary panel arrangements, FilePilot-inspired)
- Bookmarks / favorites / pinned locations
- Recent locations
- Home, Desktop, Downloads, Trash quick access
- Mountpoint / volume sidebar (USB drives, network mounts)
- Hidden files toggle
- Sorting (name, size, date modified, type — ascending/descending)
- Grouping (by type, date, size range)
- Filtering by file type / extension

## File Operations

- Copy, move, paste, cut
- Delete (to trash, permanent delete)
- Rename (inline)
- Batch rename (patterns, sequential numbering, date-based — FilePilot-inspired)
- Create new file / directory
- Create symlink
- Drag and drop (within app, between panes, from/to external apps)
- File operation progress (with cancel/pause)
- Undo / redo file operations
- Duplicate file
- Compress / extract archives (zip, tar.gz, etc.)

## Search

- Recursive directory search
- Fuzzy search (FilePilot-inspired)
- Flattened folder view (show all files in hierarchy — FilePilot's killer feature)
- Filter by extension during search
- Search results as virtual folder
- Optional ripgrep backend for content search (optional dependency)

## Preview & Inspection

- File inspector / quick preview panel (text, images, folders — FilePilot-inspired)
- Thumbnail generation (freedesktop thumbnail spec)
- File properties dialog (size, permissions, timestamps, MIME type)
- Permissions editing (owner, group, mode)
- Disk usage / folder size display (usage columns, FilePilot-inspired)

## Command & Keyboard

- Command palette (search all actions, assign hotkeys — FilePilot-inspired)
- Comprehensive keyboard shortcuts (vim-style optional)
- Configurable keybindings
- CLI arguments (open path, new tab, new window)

## Desktop Integration (freedesktop / Linux standards)

- XDG base directory spec ($HOME, $XDG_CONFIG_HOME, $XDG_DATA_HOME, $XDG_CACHE_HOME)
- Shared MIME database (content type detection)
- Icon theme spec (file/folder icons from system theme)
- Freedesktop thumbnail spec (~/.cache/thumbnails/)
- Freedesktop trash spec (~/.local/share/Trash/)
- Desktop file integration (open with default app, "Open With" menu)
- D-Bus interface (for external control, single-instance)
- .desktop file and AppStream metadata for distribution
- Drag and drop protocol (X11/Wayland)
- File manager D-Bus interface (org.freedesktop.FileManager1)

## Customization & Appearance

- Color themes / dark mode (via libadwaita)
- Font size and spacing controls
- Configurable columns in detail view
- Layout persistence (remember panel arrangement, tab state)
- Per-directory view settings
- Disable animations toggle
- Config file ($XDG_CONFIG_HOME/filebender/config.toml or similar)

## Network & Remote

- SMB/CIFS network shares
- FTP/SFTP browsing
- MTP device support (Android phones, cameras)
- WebDAV

## Advanced / Power User

- Terminal integration (open terminal at current directory)
- Embedded terminal panel
- Scriptable actions / custom commands
- Context menu customization (pin actions, search actions — FilePilot-inspired)
- File tagging / labels
- Directory watcher (live refresh on filesystem changes)
- Hardlink detection (via inode)
- Symlink resolution and display
