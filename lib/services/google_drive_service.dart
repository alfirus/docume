import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../models/doc_page.dart';

class GoogleDriveAuthClient extends http.BaseClient {
  GoogleDriveAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  GoogleDriveService({required GoogleSignIn googleSignIn})
      : _googleSignIn = googleSignIn;

  final GoogleSignIn _googleSignIn;

  Future<drive.DriveApi?> _getDriveApi() async {
    final account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) {
      return null;
    }

    final authHeaders = await account.authHeaders;
    final client = GoogleDriveAuthClient(authHeaders);
    return drive.DriveApi(client);
  }

  Future<String> getOrCreateFolder(String folderName) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw Exception('Not authenticated with Google Drive');
    }

    final query = "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed=false";
    final fileList = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id!;
    }

    final folder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final createdFolder = await driveApi.files.create(folder);
    return createdFolder.id!;
  }

  Future<void> _migrateFromOldFormat(String folderId) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        return;
      }

      // Check if old pages.json exists
      final query = "name='pages.json' and '$folderId' in parents and trashed=false";
      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id)',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        return;
      }

      final fileId = fileList.files!.first.id!;
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final dataBytes = <int>[];
      await for (final chunk in media.stream) {
        dataBytes.addAll(chunk);
      }

      final content = utf8.decode(dataBytes);
      if (content.trim().isEmpty) {
        await driveApi.files.delete(fileId);
        return;
      }

      final decoded = jsonDecode(content) as List<dynamic>;
      final pages = decoded
          .map((entry) => DocPage.fromMap(entry as Map<String, dynamic>))
          .toList();

      // Create pages folder if it doesn't exist
      final pagesFolderId = await _getOrCreatePagesFolder(folderId);

      // Write each page as individual file
      for (final page in pages) {
        final pageContent = jsonEncode(page.toMap());
        final bytes = utf8.encode(pageContent);
        final file = drive.File()
          ..name = '${page.id}.json'
          ..parents = [pagesFolderId];
        await driveApi.files.create(
          file,
          uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
        );
      }

      // Delete old pages.json after successful migration
      await driveApi.files.delete(fileId);
    } catch (_) {
      // Migration failed, old file will be retried next time
    }
  }

  Future<String> _getOrCreatePagesFolder(String parentFolderId) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw Exception('Not authenticated with Google Drive');
    }

    final query = "mimeType='application/vnd.google-apps.folder' and name='pages' and '$parentFolderId' in parents and trashed=false";
    final fileList = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id!;
    }

    final folder = drive.File()
      ..name = 'pages'
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [parentFolderId];

    final createdFolder = await driveApi.files.create(folder);
    return createdFolder.id!;
  }

  Future<List<DocPage>> readPages(String folderId) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw Exception('Not authenticated with Google Drive');
    }

    // Check and migrate from old format if needed
    await _migrateFromOldFormat(folderId);

    // Get or create pages folder
    final pagesFolderId = await _getOrCreatePagesFolder(folderId);

    // List all .json files in pages folder
    final query = "'$pagesFolderId' in parents and trashed=false and name contains '.json'";
    final fileList = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      return [];
    }

    final pages = <DocPage>[];
    for (final file in fileList.files!) {
      try {
        final fileId = file.id!;
        final media = await driveApi.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;

        final dataBytes = <int>[];
        await for (final chunk in media.stream) {
          dataBytes.addAll(chunk);
        }

        final content = utf8.decode(dataBytes);
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          pages.add(DocPage.fromMap(decoded));
        }
      } catch (_) {
        // Skip corrupted page files
        continue;
      }
    }

    return pages;
  }

  Future<void> writePages(String folderId, List<DocPage> pages) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw Exception('Not authenticated with Google Drive');
    }

    // Get or create pages folder
    final pagesFolderId = await _getOrCreatePagesFolder(folderId);

    // Get existing page files
    final query = "'$pagesFolderId' in parents and trashed=false and name contains '.json'";
    final fileList = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    final existingFiles = <String, String>{};
    if (fileList.files != null) {
      for (final file in fileList.files!) {
        final fileName = file.name!;
        final pageId = fileName.substring(0, fileName.length - 5);
        existingFiles[pageId] = file.id!;
      }
    }

    // Write each page as individual file
    final newIds = <String>{};
    for (final page in pages) {
      newIds.add(page.id);
      final pageContent = jsonEncode(page.toMap());
      final bytes = utf8.encode(pageContent);
      final file = drive.File()..name = '${page.id}.json';

      if (existingFiles.containsKey(page.id)) {
        // Update existing file
        await driveApi.files.update(
          file,
          existingFiles[page.id]!,
          uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
        );
      } else {
        // Create new file
        file.parents = [pagesFolderId];
        await driveApi.files.create(
          file,
          uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
        );
      }
    }

    // Delete page files that no longer exist
    for (final entry in existingFiles.entries) {
      if (!newIds.contains(entry.key)) {
        await driveApi.files.delete(entry.value);
      }
    }
  }
}
