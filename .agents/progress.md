# Docume Project AI Notes

## Current Status (2026-03-08)

### Completed
- Scaffolded Flutter mobile project (Android + iOS).
- Built MVP CRUD flow for pages:
  - List pages
  - Create page
  - Edit page
  - Delete page
  - View rendered HTML
- Implemented local persistence using `shared_preferences`.
- Added HTML rendering via `flutter_widget_from_html`.
- Added search on page list (title + HTML content).
- Added sort options on page list:
  - Newest
  - Oldest
  - Title A-Z
- Added basic editor HTML helper toolbar:
  - Bold (`<strong>`)
  - H1 (`<h1>`)
  - List (`<ul><li>`)
- Replaced timestamp-based page IDs with UUID v4.
- Added lightweight HTML validation before save:
  - Requires HTML-like tags
  - Blocks `<script>` tags
  - Parses fragment to prevent empty/invalid structure
- Added unit tests for HTML validator.
- Added page metadata support:
  - `createdAt` stored and preserved on edit
  - `wordCount` computed from HTML text content
  - Metadata shown in list and page detail view
- Enabled desktop platform targets:
  - macOS
  - Windows
  - Linux
- Added adaptive UI by screen size:
  - Mobile layout keeps existing list-to-detail flow
  - Desktop layout uses two panes (list + preview/editor actions)
- Added adaptive widget tests:
  - Mobile width test verifies list-to-detail navigation
  - Desktop width test verifies two-pane preview and selection switching
- Added first-run workspace setup flow:
  - User must choose storage provider: Local, Google Drive, iCloud, or Synology Drive
  - User must set workspace directory before entering app
  - Workspace config is persisted and used to namespace page storage
- Added provider connector service:
  - Local provider uses native folder picker
  - Google Drive provider performs Google sign-in handshake and creates/finds "Docume" folder in Drive
  - iCloud and Synology providers prefill provider-specific workspace paths
- Upgraded persistence behavior:
  - **Local provider**: persists pages into `<workspace-directory>/pages.json` on file system
  - **Google Drive provider**: persists pages into `pages.json` file in Drive folder via Drive API
  - **iCloud/Synology providers**: currently use namespaced local cache until remote sync APIs are added
- Added Google Drive API integration:
  - Added `googleapis` and `http` dependencies
  - Created `GoogleDriveService` with Drive API client
  - Implemented folder creation/discovery
  - Implemented remote file read/write for `pages.json`
  - Updated `PageRepository` to route Google Drive provider to Drive API
  - Workspace path format: `gdrive:/<email>/<folderId>`
- Updated README and passing tests/analyze baseline (8 tests passing, zero issues).
- Updated README and passing tests/analyze baseline.
- Added integration tests for CRUD workflows:
  * Mobile: create and delete page flow
  * Desktop: create page flow
  * Tests validate adaptive layout behavior and persistence
  * All 10 tests passing, zero analyzer issues
- Added JSON backup and restore feature:
  * Export JSON via page-list overflow menu (`Export JSON`)
  * Export copies full page backup to clipboard
  * Import JSON via page-list overflow menu (`Import JSON`)
  * Import validates JSON payload, persists via active provider repository, and refreshes UI state
- Added backup action widget tests:
  * Export action accessibility test
  * Import JSON replacement flow test
  * Fixed import dialog lifecycle bug (`TextEditingController` disposal timing issue)
  * Test baseline updated to 12 passing tests with zero analyzer issues

## Architecture Notes
- Data model: `lib/models/doc_page.dart`
- Workspace model: `lib/models/workspace_config.dart`
- Storage service: `lib/services/page_repository.dart` (routes to file system, Drive API, or cache based on provider)
- Workspace service: `lib/services/workspace_service.dart`
- Workspace connector service: `lib/services/workspace_connector_service.dart`
- Google Drive service: `lib/services/google_drive_service.dart` (Drive API wrapper with folder management and file I/O)
- Screens:
  - `lib/screens/page_list_screen.dart`
  - `lib/screens/page_editor_screen.dart`
  - `lib/screens/page_view_screen.dart`
  - `lib/screens/workspace_setup_screen.dart`

## Suggested Next Steps
1. Expand integration tests to include deeper import/export assertions (multi-page payloads + invalid JSON).
2. Add iCloud Drive API integration (similar to Google Drive implementation).
3. Add Synology Drive API integration.
4. Add offline queue for Google Drive sync when network unavailable.
5. Add conflict resolution for concurrent edits.
