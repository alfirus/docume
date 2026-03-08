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

  Future<List<DocPage>> readPages(String folderId) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw Exception('Not authenticated with Google Drive');
    }

    final query = "name='pages.json' and '$folderId' in parents and trashed=false";
    final fileList = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id)',
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      return [];
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
      return [];
    }

    final decoded = jsonDecode(content) as List<dynamic>;
    return decoded
        .map((entry) => DocPage.fromMap(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> writePages(String folderId, List<DocPage> pages) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw Exception('Not authenticated with Google Drive');
    }

    final content = jsonEncode(pages.map((page) => page.toMap()).toList());
    final bytes = utf8.encode(content);

    final query = "name='pages.json' and '$folderId' in parents and trashed=false";
    final fileList = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id)',
    );

    final file = drive.File()..name = 'pages.json';

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final fileId = fileList.files!.first.id!;
      await driveApi.files.update(
        file,
        fileId,
        uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      );
    } else {
      file.parents = [folderId];
      await driveApi.files.create(
        file,
        uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      );
    }
  }
}
