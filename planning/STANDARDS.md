# Filebender — Standards, Specifications & Distribution

See ARCHITECTURE.md for threading model, library API, and internal design.

---

## Freedesktop Specifications

### Must implement (core functionality)

| Spec | What it governs | Where used | Reference |
|---|---|---|---|
| XDG Base Directory Spec | Config/data/cache/state paths | Config storage, cache, thumbnails | specifications.freedesktop.org/basedir-spec |
| Freedesktop Trash Spec | Trash operations, metadata, restore | Delete-to-trash, trash view, restore | specifications.freedesktop.org/trash-spec |
| Shared MIME Database Spec | File type detection from magic/extension/glob | MIME detection, icon selection, "Open With" | specifications.freedesktop.org/shared-mime-info-spec |
| Icon Theme Spec | Locating icons by name from installed themes | File type icons, folder icons, action icons | specifications.freedesktop.org/icon-theme-spec |
| Icon Naming Spec | Standardized icon names | Consistent icon lookup across themes | specifications.freedesktop.org/icon-naming-spec |
| Desktop Entry Spec (.desktop files) | Application metadata, MIME associations | "Open With" menu, default app launch | specifications.freedesktop.org/desktop-entry-spec |
| Desktop File Install Locations | Where .desktop files live | Finding installed applications | XDG data dirs + applications/ |
| MIME Apps Spec (mimeapps.list) | Default/preferred app per MIME type | "Open With Default", "Open With..." | specifications.freedesktop.org/mime-apps-spec |
| Freedesktop Thumbnail Spec | Thumbnail storage, sizing, naming | Image previews, folder thumbnails | specifications.freedesktop.org/thumbnail-spec |
| File Manager D-Bus Interface | org.freedesktop.FileManager1 | External apps requesting "show file" | specifications.freedesktop.org/file-manager-interface |
| XDG User Dirs | ~/Documents, ~/Downloads, etc. | Sidebar shortcuts, default locations | freedesktop.org/wiki/Software/xdg-user-dirs |
| Drag and Drop (X11/Wayland) | Inter-app drag and drop | Dragging files to/from other apps | GTK handles protocol, we provide data |
| Clipboard (X11/Wayland) | Copy/paste file URIs between apps | Ctrl+C/V between file managers | `x-special/gnome-copied-files` format |
| Desktop Notifications Spec | Notifications via D-Bus | Operation complete, errors | org.freedesktop.Notifications |

### Should implement (polish / good citizen)

| Spec | What it governs | Where used |
|---|---|---|
| AppStream Metadata | App description for software centers | Distribution, discoverability |
| GApplication / D-Bus activation | Single-instance apps | Prevent multiple instances, open-in-running |
| Autostart Spec | Auto-launching on login | Not needed (we're not a daemon) |
| File URI Spec (RFC 8089) | file:// URI format | Clipboard, drag-drop, D-Bus communication |
| Exec key field codes | %f, %u, %F, %U in .desktop Exec lines | Launching apps with correct arguments |
| Recent Files Spec (recently-used.xbel) | Tracking recently opened files | Recent files in sidebar/bookmarks |
| UDisks2 D-Bus interface | Mount/unmount, volume detection | Sidebar volume list, mount/eject actions |
| GVfs / GIO mount operations | Network mounts, MTP | Remote filesystem access (post-1.0) |

### GTK4/libadwaita handles for us

These specs are implemented by the toolkit — we consume them via GTK/GLib APIs:

- Icon theme lookup (GtkIconTheme)
- MIME type detection (GIO g_content_type_*)
- Clipboard protocol (GdkClipboard)
- DnD protocol (GtkDragSource/GtkDropTarget)
- Dark mode / accent color (AdwStyleManager)
- Wayland/X11 window management (GDK backend)
- Desktop notifications (GNotification)
- D-Bus (GDBusConnection)
- GApplication single-instance

### Must implement ourselves in core/

These cannot rely on GLib/GIO (core/ is pure stdlib):

- XDG Base Directory resolution (trivial — read env vars with fallbacks)
- Trash operations (move to $XDG_DATA_HOME/Trash/, write .trashinfo metadata)
- Thumbnail management (read/write ~/.cache/thumbnails/, respect naming/sizing)
- inotify/fanotify watches (Linux kernel API, no library needed)
- File URI construction (trivial string formatting)

---

## Distribution Files (dist/)

### Required

| File | Spec/Standard | Purpose | Install location |
|---|---|---|---|
| `dev.kicanter.filebender.desktop` | Desktop Entry Spec | Launcher entry, MIME associations, icon | `$PREFIX/share/applications/` |
| `dev.kicanter.filebender.metainfo.xml` | AppStream Metadata | Software center description, screenshots | `$PREFIX/share/metainfo/` |
| `dev.kicanter.filebender.svg` | Icon Theme Spec | Application icon (scalable) | `$PREFIX/share/icons/hicolor/scalable/apps/` |
| `dev.kicanter.filebender.gschema.xml` | GSettings | App preferences stored via GSettings | `$PREFIX/share/glib-2.0/schemas/` |
| `dev.kicanter.filebender.service` | D-Bus Service Spec | D-Bus activation (auto-start on method call) | `$PREFIX/share/dbus-1/services/` |

### Desktop Entry (`dev.kicanter.filebender.desktop`)

```ini
[Desktop Entry]
Type=Application
Name=Filebender
GenericName=File Manager
Comment=A native, feature-rich file manager for Linux
Exec=filebender %U
Icon=dev.kicanter.filebender
Terminal=false
Categories=System;FileTools;FileManager;GTK;
MimeType=inode/directory;
Keywords=file;folder;manager;explorer;
StartupNotify=true
DBusActivatable=true
SingleMainWindow=false
```

### D-Bus Service (`dev.kicanter.filebender.service`)

```ini
[D-Bus Service]
Name=dev.kicanter.filebender
Exec=/usr/bin/filebender --gapplication-service
```

### D-Bus Interface (org.freedesktop.FileManager1)

Methods we must implement:
- `ShowFolders(uris: [string], startup_id: string)` — open folder(s) in window
- `ShowItems(uris: [string], startup_id: string)` — open parent, highlight item(s)
- `ShowItemProperties(uris: [string], startup_id: string)` — open properties dialog

This allows other apps to say "show this file in the file manager."

### AppStream Metadata (`dev.kicanter.filebender.metainfo.xml`)

Required fields:
- `<id>dev.kicanter.filebender</id>`
- `<name>Filebender</name>`
- `<summary>` (one line)
- `<description>` (paragraph)
- `<url type="homepage">`
- `<developer>` name
- `<launchable type="desktop-id">dev.kicanter.filebender.desktop</launchable>`
- `<provides><binary>filebender</binary></provides>`
- `<content_rating type="oars-1.1"/>` (all none for a file manager)
- `<releases>` (version history)
- `<screenshots>` (for software centers)

### NOT needed

| File | Why not |
|---|---|
| systemd service file | We're a GUI app, not a daemon. No background service. |
| systemd user service | Same — not a persistent background process. |
| polkit policy | We don't escalate privileges. No pkexec operations. |
| udev rules | We don't need special device access. |
| bash completion | Nice-to-have eventually, not required. Not a spec. |
| man page | Nice-to-have eventually. Not a freedesktop spec. |

---

## Spec Implementation by Milestone

| Milestone | Specs introduced |
|---|---|
| 1 | XDG Base Directory (home resolution only) |
| 2 | Shared MIME Database, Icon Theme Spec, Icon Naming Spec |
| 3 | Freedesktop Trash Spec, MIME Apps Spec, Desktop Entry Spec (for "Open With"), Clipboard format |
| 4 | XDG Base Directory (full — config file storage), XDG User Dirs |
| 5 | inotify (kernel API, no freedesktop spec) |
| 6 | Freedesktop Thumbnail Spec |
| 7 | — (no new specs) |
| 8 | — (no new specs) |
| 9 | — (no new specs) |
| 10 | File Manager D-Bus Interface, Desktop Notifications, D-Bus Service, .desktop file, AppStream, GApplication activation, Recent Files Spec, UDisks2 |
