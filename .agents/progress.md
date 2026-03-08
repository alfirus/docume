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
- Expanded backup/import test coverage:
  * Export test now validates multi-page JSON payload contents and metadata fields (`createdAt`, `updatedAt`)
  * Import tests now cover invalid JSON and invalid JSON shape rejection while preserving existing persisted data
  * Added mobile integration coverage for invalid backup import path
  * Test baseline updated to 15 passing tests
- Added iCloud file-based persistence integration:
  * Created `ICloudService` for workspace path resolution and `pages.json` read/write
  * iCloud path mapping on macOS: `icloud:/...` -> `~/Library/Mobile Documents/com~apple~CloudDocs/...`
  * Updated `PageRepository` to route iCloud provider through `ICloudService` with SharedPreferences cache mirroring/fallback
  * Added test-environment guard so widget/integration tests do not depend on host iCloud folders
  * Added iCloud service unit tests (path resolution + read/write roundtrip)
  * Test baseline updated to 19 passing tests
- Added Synology file-based persistence integration:
  * Created `SynologyDriveService` for workspace path resolution and `pages.json` read/write
  * Synology path mapping: `synology:/...` -> `~/SynologyDrive/...`
  * Updated `PageRepository` to route Synology provider through `SynologyDriveService` with SharedPreferences cache mirroring/fallback
  * Added test-environment guard so widget/integration tests do not depend on host Synology folders
  * Added Synology service unit tests (path resolution + read/write roundtrip)
  * Test baseline updated to 23 passing tests
- Added Google Drive offline sync queue:
  * Created `GoogleDriveSyncQueueService` backed by SharedPreferences
  * Failed Google Drive writes now enqueue full page snapshots (up to last 20)
  * Queue flush runs automatically on subsequent Google Drive loads
  * Successful Google Drive writes clear pending queue state
  * Added queue unit tests (enqueue order, truncation, clear behavior)
  * Test baseline updated to 26 passing tests
- Added concurrent edit conflict resolution:
  * Added `ConflictResolutionService` for stale edit detection and deterministic merge behavior
  * Save flow now compares local edit base timestamp against latest stored page version
  * Conflict dialog offers three options: Keep Mine, Keep Remote, Merge
  * Merge mode combines local and remote content with explicit section markers
  * Added conflict resolution unit tests
  * Test baseline updated to 29 passing tests
- Added light/dark theme support:
  * Added persisted theme preference in `WorkspaceService`
  * Added app-level `themeMode` + `darkTheme` wiring in `DocumeApp`
  * Added theme toggle action to page list app bars (mobile + desktop)
  * Added workspace service tests for theme persistence
  * Test baseline updated to 31 passing tests
- **Expanded editor HTML helper toolbar**:
  * Added heading levels: H2 (`<h2>`), H3 (`<h3>`), H4 (`<h4>`), H5 (`<h5>`), H6 (`<h6>`)
  * Added section tag (`<section>`)
  * Added hyperlink button with URL input dialog (`<a href="url">`)
  * Toolbar now supports comprehensive semantic HTML structure markup
  * Added widget tests for all toolbar buttons
  * Test baseline updated to 40 passing tests
- **Improved conflict merge UX**:
  * Created `ConflictMergeDialog` widget with side-by-side comparison
  * Added field-level merge options: Keep Mine / Keep Remote / Merge (separately for title and content)
  * Display visual comparison boxes showing both versions with highlight on selection
  * Show conflict timestamps to help user understand recency
  * Updated `ConflictResolutionService` with `mergeHtmlContent()` method
  * Integrated new dialog into page list screen conflict resolution flow
  * Added unit tests for merge service methods
  * Added widget tests for conflict merge dialog
  * Test baseline updated to 45 passing tests (all passing)
- **Fixed macOS Google Sign-In crash path**:
  * Investigated crash report (`SIGABRT`) in `GIDSignIn signInWithOptions`
  * Added `google_sign_in_factory.dart` with platform preflight check
  * Added guard to prevent invoking native Google Sign-In on macOS when client ID is missing
  * Added user-facing setup error in workspace connector flow instead of app abort
  * Updated README with `--dart-define=GOOGLE_SIGN_IN_CLIENT_ID=...` run instruction
- **Temporarily disabled cloud providers in setup**:
  * Disabled Google Drive, iCloud, and Synology selection in workspace setup UI
  * Workspace setup now exposes Local provider only
  * Added connector-side guard errors if disabled providers are requested
+- **Added WYSIWYG rich text editor mode**:
+  * Integrated `flutter_quill` (v11.5.0) for rich text editing
+  * Added `vsc_quill_delta_to_html` for Delta-to-HTML conversion
+  * Created `QuillHtmlConverterUtil` for bidirectional HTML/Quill conversion
+  * Implemented editor mode toggle (WYSIWYG ↔ HTML) with icon button in app bar
+  * WYSIWYG mode features full toolbar: bold, italic, underline, strikethrough, headings, lists, code blocks, quotes, indentation, links, undo/redo, text alignment
+  * HTML mode retains original toolbar with semantic HTML tag buttons (H1-H6, section, strong, list, link)
+  * Content automatically syncs between modes on toggle
+  * Default editor mode is WYSIWYG for improved authoring experience
+  * Created `test/wysiwyg_editor_test.dart` for editor mode toggle and basic functionality tests
+

## Architecture Notes
- Data model: `lib/models/doc_page.dart`
- Workspace model: `lib/models/workspace_config.dart`
- Storage service: `lib/services/page_repository.dart` (routes to file system, Drive API, or cache based on provider)
- Workspace service: `lib/services/workspace_service.dart` (workspace config + theme preference persistence)
- Workspace connector service: `lib/services/workspace_connector_service.dart`
- Google Drive service: `lib/services/google_drive_service.dart` (Drive API wrapper with folder management and file I/O)
- Google Drive queue service: `lib/services/google_drive_sync_queue_service.dart` (offline pending snapshot queue + retry state)
- Conflict resolution service: `lib/services/conflict_resolution_service.dart` (stale edit detection + merge strategy)
- iCloud service: `lib/services/icloud_service.dart` (iCloud path mapping + `pages.json` file I/O)
- Synology service: `lib/services/synology_drive_service.dart` (Synology path mapping + `pages.json` file I/O)
+- Quill HTML converter: `lib/utils/quill_html_converter.dart` (bidirectional HTML and Quill Delta conversion)
- Screens:
  - `lib/screens/page_list_screen.dart`
  - `lib/screens/page_editor_screen.dart`
  - `lib/screens/page_view_screen.dart`
  - `lib/screens/workspace_setup_screen.dart`

## Suggested Next Steps
1. ~~Add rich text editor (WYSIWYG) mode for better content authoring~~ ✅ COMPLETED
2. Use https://pub.dev/packages/shadcn_flutter as default UI style
3. Implement page templates for faster page creation
4. Add page tagging/categorization system
5. Implement full-text search across all pages and providers
6. Add page versioning/history tracking
7. Implement collaborative editing features (real-time sync)
8. Add export-to-PDF functionality
