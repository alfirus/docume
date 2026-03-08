# Docume MVP

Docume is a Flutter app inspired by Notion, but pages are authored and stored as HTML.
It now supports mobile and desktop installs with adaptive UI.

## MVP Features

- First-run setup requires choosing workspace provider and directory:
	- Local
	- Google Drive
	- iCloud
	- Synology Drive
- Create a page with title and HTML content
- Edit an existing page
- View rendered HTML content
- Delete a page
- Persist pages locally for offline usage
- Search pages by title or HTML content
- Sort pages by newest, oldest, or title
- Export backup JSON (copy to clipboard)
- Import backup JSON (paste into app)
- Insert HTML snippets from editor toolbar (Bold, H1-H6, Section, Link, List)
- Track page metadata (created date, updated date, word count)
- Adaptive UI:
	- Mobile: list-first navigation
	- Desktop: two-pane layout (page list + content preview)
- Concurrent edit conflict handling:
	- Detects stale edits before save
	- Side-by-side conflict comparison
	- Field-level merge options for title/content
	- Resolution options: Keep Mine, Keep Remote, Merge
- Theme mode support:
  - Light and Dark modes
  - Theme toggle in page list app bar
  - Persisted user preference across app restarts

## Workspace Behavior

- App blocks on first launch until workspace is configured.
- Selected provider + directory define workspace namespace for page storage.
- Provider connectors:
	- Local: native directory picker
	- Google Drive: Google sign-in handshake, creates/finds "Docume" folder in Drive
	- iCloud: prefill `icloud:/...` workspace path
	- Synology Drive: prefill `synology:/...` workspace path
- Persistence mode:
  - **Local provider**: stores pages in `<workspace-directory>/pages.json` on file system
  - **Google Drive provider**: stores pages in `pages.json` file in Drive folder via Drive API
	- **iCloud provider**: stores pages in `pages.json` under iCloud Drive path mapping (`icloud:/...` -> `~/Library/Mobile Documents/com~apple~CloudDocs/...` on macOS)
	- **Synology provider**: stores pages in `pages.json` under Synology Drive path mapping (`synology:/...` -> `~/SynologyDrive/...`)

## Current Connector Scope

- **Local**: Full file system integration with `pages.json` storage
- **Google Drive**: Complete integration with Drive API for remote file sync
  - Authentication via Google Sign-In
  - Automatic folder creation/discovery
  - Remote `pages.json` storage in Drive folder
	- Offline queue for failed writes, with automatic retry on subsequent loads
- **iCloud**: File-based integration using iCloud Drive folder path mapping on macOS
- **Synology**: File-based integration using Synology Drive folder path mapping
## Testing

The project includes comprehensive test coverage:
- **Unit tests**: HTML validator (#8 tests)
- **Widget tests**: First-run setup, workspace configuration, backup actions (export/import)  
- **Adaptive layout tests**: Mobile and desktop responsive behavior  
- **Integration tests**: End-to-end CRUD workflows on mobile and desktop  

Run all tests:
```bash
flutter test
```

Current test count: **31 tests**, all passing.

## Google Drive Setup (macOS)

For Google Drive provider on macOS, run with a macOS OAuth Client ID to avoid native Google Sign-In initialization crashes:

```bash
flutter run -d macos --dart-define=GOOGLE_SIGN_IN_CLIENT_ID=YOUR_MACOS_OAUTH_CLIENT_ID.apps.googleusercontent.com
```

If this value is not provided, Docume now shows a setup error and blocks Google Drive connect calls instead of invoking native sign-in.

## Backup & Restore

- Use the top-right menu (`⋮`) on the page list screen.
- **Export JSON** copies a full backup of pages to clipboard.
- **Import JSON** replaces current pages with pasted backup data.
- Import validates JSON format and shows an error if invalid.

## Getting Started

1. Install Flutter (stable channel, 3.41.4+)
2. Fetch packages:

	flutter pub get

3. Run app (auto-select available device):

	flutter run

4. Run specific platforms:

	flutter run -d android
	flutter run -d ios
	flutter run -d macos
	flutter run -d windows
	flutter run -d linux

## Current Scope

This MVP focuses on single-user note management with local and cloud storage.
- ✅ Local file storage
- ✅ Google Drive cloud sync
- ✅ iCloud file-based storage integration
- ✅ Synology file-based storage integration

It does not yet include collaboration, permissions, or version history.
