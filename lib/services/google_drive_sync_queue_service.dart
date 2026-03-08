import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/doc_page.dart';

class GoogleDriveQueuedSnapshot {
  const GoogleDriveQueuedSnapshot({
    required this.queuedAt,
    required this.pages,
  });

  final DateTime queuedAt;
  final List<DocPage> pages;
}

class GoogleDriveSyncQueueService {
  GoogleDriveSyncQueueService({required String namespace})
    : _namespace = namespace;

  static const _maxSnapshots = 20;

  final String _namespace;

  String get _queueKey {
    final encoded = base64Url.encode(utf8.encode(_namespace));
    return 'docume_gdrive_queue_$encoded';
  }

  Future<void> enqueuePagesSnapshot(List<DocPage> pages) async {
    final snapshots = await _readSnapshots();
    snapshots.add({
      'queuedAt': DateTime.now().toUtc().toIso8601String(),
      'pages': pages.map((page) => page.toMap()).toList(),
    });

    final bounded = snapshots.length <= _maxSnapshots
        ? snapshots
        : snapshots.sublist(snapshots.length - _maxSnapshots);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(bounded));
  }

  Future<List<GoogleDriveQueuedSnapshot>> getQueuedSnapshots() async {
    final snapshots = await _readSnapshots();
    return snapshots.map((snapshot) {
      final rawPages = snapshot['pages'] as List<dynamic>? ?? const [];
      return GoogleDriveQueuedSnapshot(
        queuedAt: DateTime.parse(snapshot['queuedAt'] as String),
        pages: rawPages
            .map((entry) => DocPage.fromMap(entry as Map<String, dynamic>))
            .toList(),
      );
    }).toList();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  Future<bool> hasPendingSnapshots() async {
    final snapshots = await _readSnapshots();
    return snapshots.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> _readSnapshots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }
}
