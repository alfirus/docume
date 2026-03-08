import 'package:docume/models/doc_page.dart';
import 'package:docume/services/google_drive_sync_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GoogleDriveSyncQueueService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('enqueues and reads snapshots in FIFO order', () async {
      final service = GoogleDriveSyncQueueService(
        namespace: 'google_drive|ns1',
      );

      final firstPages = [
        DocPage(
          id: 'a',
          title: 'First',
          htmlContent: '<p>first</p>',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
      ];
      final secondPages = [
        DocPage(
          id: 'b',
          title: 'Second',
          htmlContent: '<p>second</p>',
          createdAt: DateTime(2026, 3, 2),
          updatedAt: DateTime(2026, 3, 2),
        ),
      ];

      await service.enqueuePagesSnapshot(firstPages);
      await service.enqueuePagesSnapshot(secondPages);

      final queued = await service.getQueuedSnapshots();
      expect(queued.length, 2);
      expect(queued.first.pages.first.id, 'a');
      expect(queued.last.pages.first.id, 'b');
    });

    test('keeps only latest 20 snapshots', () async {
      final service = GoogleDriveSyncQueueService(
        namespace: 'google_drive|ns2',
      );

      for (var i = 0; i < 25; i++) {
        await service.enqueuePagesSnapshot([
          DocPage(
            id: 'id-$i',
            title: 'Title $i',
            htmlContent: '<p>$i</p>',
            createdAt: DateTime(2026, 3, 1),
            updatedAt: DateTime(2026, 3, 1),
          ),
        ]);
      }

      final queued = await service.getQueuedSnapshots();
      expect(queued.length, 20);
      expect(queued.first.pages.first.id, 'id-5');
      expect(queued.last.pages.first.id, 'id-24');
    });

    test('clear removes all pending snapshots', () async {
      final service = GoogleDriveSyncQueueService(
        namespace: 'google_drive|ns3',
      );

      await service.enqueuePagesSnapshot([
        DocPage(
          id: 'x',
          title: 'X',
          htmlContent: '<p>x</p>',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
      ]);

      expect(await service.hasPendingSnapshots(), isTrue);
      await service.clear();
      expect(await service.hasPendingSnapshots(), isFalse);
      expect((await service.getQueuedSnapshots()).isEmpty, isTrue);
    });
  });
}
