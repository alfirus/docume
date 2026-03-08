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
+- **Integrated shadcn_flutter UI design system (v0.0.52)**:
+  * Added `shadcn_flutter` package for modern, consistent UI components
+  * Wrapped app with `ShadcnApp` providing shadcn theming and design system
+  * Applied zinc color scheme with light/dark theme support
+  * Replaced key Material widgets with shadcn equivalents:
+    - PrimaryButton and OutlineButton for actions
+    - TextField for form inputs (in workspace setup screen)
+  * Maintained Material components for structural elements (Scaffold, AppBar, etc.) for compatibility
+  * App now uses shadcn's clean, modern design language while preserving full functionality
+
- **Fixed light/dark theme toggle behavior**:
  * Root cause: `ShadcnApp` theme mode switched shadcn components, but Material/Cupertino widgets remained on static light theme
  * Added active Material/Cupertino theme bridging in `lib/main.dart` based on selected light/dark mode
  * Added widget regression test covering toggle UI update and persisted `theme_mode` preference
  * Test baseline updated to 45 passing tests
- **Added page tagging/categorization system**:
  * Extended `DocPage` model with `tags` field (List<String>)
  * Added tag management UI in page editor:
    - Tag input field with "Add" button
    - Tag chips display with delete functionality
    - Prevents duplicate tag entries
  * Added tag filtering in page list screen:
    - "All" filter chip to show all pages
    - Individual filter chips for each tag
    - Horizontal scrollable tag filter bar (mobile + desktop)
  * Tag display in page list items:
    - Tags shown as colored chips below page metadata
    - Uses theme's primaryContainer color scheme
  * Tags persist through JSON serialization (toMap/fromMap)
  * Backwards compatible: missing tags field defaults to empty list
  * Created `test/tagging_test.dart` with 7 unit tests:
    - Tag creation, serialization, deserialization tests
    - JSON roundtrip preservation test
    - copyWith updates test
  * Test baseline updated to 52 passing tests (45 existing + 7 new)
- **Added hierarchical sub-page support**:
  * Extended `DocPage` model with `parentId` field (String?) for parent-child relationships
  * Added parent selection dropdown in page editor:
    - Optional parent page picker shown below title input
    - Lists all valid parent candidates (excludes page itself and its descendants to prevent cycles)
    - Default option: "No parent (top-level page)"
  * Implemented hierarchical page list rendering:
    - Visual indentation and arrow icons for sub-pages
    - Shows "Sub-page of [Parent]" label in metadata
    - Parent info displayed in desktop preview pane
  * Added "New sub-page" quick action button on each page row
  * Implemented cascading delete: deleting a page also removes its descendants
  * Backward compatible: existing pages without `parentId` are treated as top-level
  * `copyWith` uses sentinel object pattern to allow clearing parent link
  * All 52 tests passing
- **Converted page list to interactive tree view**:
  * Added expand/collapse controls for parent pages
  * Tree icons (chevron right/down) show expand/collapse state
  * Child pages only visible when parent is expanded
  * Each parent page can be independently expanded or collapsed
  * Maintains tree state during navigation and operations
  * Clean visual hierarchy with proper indentation
- **Improved desktop sidebar tree UX**:
  * Replaced manual indented list look with recursive `ExpansionTile` tree nodes
  * Parent nodes now use native expand/collapse behavior with persistent state
  * Tree rows are visually cleaner and easier to scan
  * Kept per-node quick actions (new sub-page, delete) and selection behavior
  * Added depth guide lines and compact node styling for stronger hierarchy readability
  * Added selected-node surface highlight and border for clearer active context
  * Reduced visual noise by removing default tile dividers inside expanded branches
- **Added Settings reset flow**:
  * Added Settings button in app bars (mobile + desktop) on page list screen
  * Added Settings dialog with "Reset App" action in a danger zone section
  * Added destructive confirmation dialog before reset is executed
  * Reset now clears current pages, removes workspace config, clears cached page/queue keys, and returns user to workspace setup (first-time flow)
  * Test baseline remains 52 passing tests
  * Relocated light/dark theme toggle from app bar to Settings dialog
  * Updated widget regression test to toggle theme via Settings dialog flow
- **Improved workspace directory picker UX**:
  * `Choose Directory` now seeds OS directory browser using current input value (when valid absolute path)
  * After user picks a folder, Workspace Directory input is updated immediately with selected path
  * Added macOS sandbox entitlement `com.apple.security.files.user-selected.read-write` (DebugProfile + Release) to allow OS directory panel access
- **Migrated storage architecture from single file to file-per-page structure**:
  * Changed from single `pages.json` to individual page files in `pages/` directory
  * Each page stored as `<page-id>.json` containing single page JSON object
  * Updated all storage providers (Local, Google Drive, iCloud, Synology) to support new structure
  * Added automatic migration logic in all services:
    - Detects old `pages.json` file on first read
    - Converts all pages to individual files
    - Deletes old `pages.json` after successful migration
  * Google Drive creates `pages/` subfolder in workspace folder
  * Local, iCloud, and Synology providers create `pages/` directory in workspace path
  * Write operations now handle individual file updates and cleanup of deleted pages
  * Benefits: better scalability, easier version control, clearer structure for hierarchical pages
  * All 52 tests passing with new storage architecture
- **Fixed page loss after app relaunch for Local workspace**:
  * Root cause: local workspace setup default path (`/DocumeWorkspace`) can be unwritable on macOS, causing local file writes to fail.
  * Updated setup default to `$HOME/DocumeWorkspace` and proactively creates the folder during setup.
  * Updated local repository flow to keep SharedPreferences cache in sync for every local save.
  * On load, if local storage is empty/unavailable but cache has pages, app restores from cache and mirrors back to local files as best effort.
  * Regression check: `flutter test` still passes (52/52).
- **Changed page title source to editor first line**:
  * Removed dedicated Title field from New/Edit page form.
  * Title is now derived from the first non-empty line of editor content on save (WYSIWYG and HTML modes).
  * Existing pages are initialized so the editor starts with title content in the first line for smoother editing.
  * Updated WYSIWYG and integration tests to use first-line title flow.
- **Fixed HTML line-break collapse on save**:
  * Root cause: `<br/>` tags were ignored in HTML -> Quill document conversion.
  * Updated `QuillHtmlConverterUtil` to map `<br>` to newline and normalize text with trailing newline for Quill.
  * Added regression tests in `test/quill_html_converter_test.dart` to verify lines are not concatenated after conversion/roundtrip.
  * Regression check: `flutter test` passes (54/54).
- **Implemented page templates (faster page creation)**:
  * Added `PageTemplate` model (`lib/models/page_template.dart`) and `PageTemplateService` (`lib/services/page_template_service.dart`).
  * Added built-in templates: Meeting Notes, Product Spec, Journal Entry.
  * Added create-page chooser in page list: Blank page or From template (mobile + desktop).
  * Added template picker dialog and wired selected template HTML into new page editor flow.
  * Added editor action `Save as template` (stores custom templates per workspace namespace).
  * Added tests:
    - `test/page_template_service_test.dart` for template CRUD and built-in behavior.
    - Updated `test/integration_test.dart` for new create chooser and create-from-template flow.
  * Regression check: `flutter test` passes (58/58).
- **Added multi-format export functionality (PDF, DOCX, EPUB)**:
  * Added export dependencies: `pdf` (v3.11.1), `printing` (v5.13.2), `archive` (v3.6.1), `path_provider` (v2.1.4).
  * Created `ExportService` (`lib/services/export_service.dart`) with methods for exporting single pages and multiple pages.
  * PDF export: Uses `pdf` package to generate formatted PDFs with page title, metadata (created/updated dates), tags, and content.
  * EPUB export: Generates valid EPUB 3.0 archives with proper structure (mimetype, container.xml, content.opf, toc.ncx, chapters, CSS).
  * DOCX export: Generates basic Word-compatible documents using OpenXML structure with title, metadata, tags, and formatted content.
  * Added export menu to page list screen:
    - Bulk export options: Export All to PDF, Export All to DOCX, Export All to EPUB
    - Integrated with existing backup menu (Export JSON, Import JSON)
  * Added export menu to page editor screen:
    - Single page export options: Export to PDF, Export to DOCX, Export to EPUB
    - Export button appears in app bar when editing existing pages
  * File picker integration: Uses `file_selector` package to save exported files with suggested filenames.
  * Added comprehensive export tests (`test/export_service_test.dart`):
    - File format validation (PDF header, EPUB/DOCX ZIP structure)
    - Single page and multi-page export tests
    - Filename sanitization tests
    - Edge case handling (empty content, special characters, line breaks)
  * Regression check: `flutter test` passes (72/72 - added 14 new tests).
- **Added global error logging to error.log in workspace**:
  * Created `ErrorLoggingService` (`lib/services/error_logging_service.dart`) to capture and log errors to file.
  * Integrated with Flutter error handlers in `lib/main.dart`:
    - `FlutterError.onError` for Flutter framework errors
    - `PlatformDispatcher.instance.onError` for platform-specific errors
    - `runZonedGuarded` to catch unhandled async errors
  * Error log features:
    - Writes to `error.log` file in workspace directory
    - Supports different workspace providers (Local, Google Drive, iCloud, Synology)
    - Includes timestamps, error messages, stack traces, and optional context
    - Supports logging info/warning messages
    - Automatic log rotation when file exceeds 5MB or 1000 lines
    - Can clear logs and read current logs
  * Service initialized on app startup with workspace path.
  * Added comprehensive tests (`test/error_logging_service_test.dart`):
    - Error logging with and without stack traces
    - Message logging with custom levels
    - Flutter error details logging
    - Log file creation and management
    - Log rotation
    - Edge cases (uninitialized state, invalid paths)
  * Fixed export failure logging gap: caught export exceptions (PDF/DOCX/EPUB, single + bulk) now explicitly call `ErrorLoggingService().logError(...)` so failures are persisted to `error.log`.
  * Added regression tests (`test/export_error_logging_test.dart`) to verify caught PDF export failures are written/appended to `error.log`.
  * Regression check: `flutter test` passes (89/89).

## Architecture Notes
- Data model: `lib/models/doc_page.dart`
- Workspace model: `lib/models/workspace_config.dart`
- Storage service: `lib/services/page_repository.dart` (routes to file system, Drive API, or cache based on provider; manages individual page files in `pages/` directory)
- Workspace service: `lib/services/workspace_service.dart` (workspace config + theme preference persistence)
- Template service: `lib/services/page_template_service.dart` (built-in + custom template persistence per workspace namespace)
- Workspace connector service: `lib/services/workspace_connector_service.dart`
- Google Drive service: `lib/services/google_drive_service.dart` (Drive API wrapper with folder management and individual page file I/O in `pages/` folder)
- Google Drive queue service: `lib/services/google_drive_sync_queue_service.dart` (offline pending snapshot queue + retry state)
- Conflict resolution service: `lib/services/conflict_resolution_service.dart` (stale edit detection + merge strategy)
- iCloud service: `lib/services/icloud_service.dart` (iCloud path mapping + individual page file I/O in `pages/` directory)
- Synology service: `lib/services/synology_drive_service.dart` (Synology path mapping + individual page file I/O in `pages/` directory)
- Export service: `lib/services/export_service.dart` (PDF, DOCX, and EPUB export for single pages and bulk export)
- Error logging service: `lib/services/error_logging_service.dart` (captures all errors and logs to `error.log` in workspace directory)
- Quill HTML converter: `lib/utils/quill_html_converter.dart` (bidirectional HTML and Quill Delta conversion)
- Screens:
  - `lib/screens/page_list_screen.dart`
  - `lib/screens/page_editor_screen.dart`
  - `lib/screens/page_view_screen.dart`
  - `lib/screens/workspace_setup_screen.dart`

## Suggested Next Steps
1. ~~Add rich text editor (WYSIWYG) mode for better content authoring~~ ✅ COMPLETED
2. ~~Use https://pub.dev/packages/shadcn_flutter as default UI style~~ ✅ COMPLETED
3. ~~Fix remaining failing tests~~ ✅ COMPLETED
4. ~~Add page tagging/categorization system~~ ✅ COMPLETED (all 52 tests passing)
5. ~~Make page can be structure as sub page~~ ✅ COMPLETED
6. ~~Implement page templates for faster page creation~~ ✅ COMPLETED
7. ~~Add export-to-PDF, export-to-DOCX, export-to-EPUB functionality~~ ✅ COMPLETED (all 72 tests passing)
8. Implement full-text search across all pages and providers
9. Add page versioning/history tracking
10. Implement collaborative editing features (real-time sync)
