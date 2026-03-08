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
- Insert basic HTML snippets (Bold, H1, List) from editor toolbar
- Track page metadata (created date, updated date, word count)
- Adaptive UI:
	- Mobile: list-first navigation
	- Desktop: two-pane layout (page list + content preview)

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
  - **iCloud / Synology**: currently store pages in namespaced local cache (API integration pending)

## Current Connector Scope

- **Local**: Full file system integration with `pages.json` storage
- **Google Drive**: Complete integration with Drive API for remote file sync
  - Authentication via Google Sign-In
  - Automatic folder creation/discovery
  - Remote `pages.json` storage in Drive folder
- **iCloud / Synology**: Path-based workspace setup complete, full API integration pending
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

Current test count: **12 tests**, all passing.

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
- ⏳ iCloud API integration (pending)
- ⏳ Synology Drive API integration (pending)

It does not yet include collaboration, permissions, or version history.
