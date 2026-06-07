import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/cellular_antennas/presentation/notifiers/permits_notifier.dart';
import '../../../../notifiers_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermitsNotifier Tests', () {
    test(
      'initPermitMetadataListener double-buffers collections via streams',
      () async {
        final metadataController =
            StreamController<DocumentSnapshot<Map<String, dynamic>>>();
        final permitsController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();

        AppStateNotifier.isTesting = false;
        final notifier = PermitsNotifier(
          isTesting: false,
          testMetadataStream: metadataController.stream,
          testPermitsStream: permitsController.stream,
        );

        notifier.initPermitMetadataListener();
        expect(notifier.isLoadingPermits, isTrue);

        // Emit metadata snapshot with different collection name
        final metaData = {
          'activeCollection': 'permits_june_2026',
          'status': 'syncing',
        };
        final fakeMetaDoc = FakeDocumentSnapshot(
          'ff398c7e-c522-4ee8-a53a-312b188a573d',
          true,
          metaData,
        );
        metadataController.add(fakeMetaDoc);

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(notifier.permitSyncStatus, 'syncing');

        // Send duplicate metadata snapshot to hit else branch
        metadataController.add(fakeMetaDoc);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Emit permits snapshots
        final permitData = {'siteNumber': 'PT1234B'};
        final fakePermitDoc = FakeQueryDocumentSnapshot('1', permitData);
        final fakePermitsSnapshot = FakeQuerySnapshot([fakePermitDoc]);

        permitsController.add(fakePermitsSnapshot);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(notifier.isLoadingPermits, isFalse);
        expect(notifier.permitRecords.length, 1);
        expect(notifier.permitRecords.first['siteNumber'], 'PT1234B');

        // Emit permits stream error to hit error block
        permitsController.addError('Permits Stream Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.permitSyncStatus, 'error');

        // Emit metadata stream error
        metadataController.addError('Connection error');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(notifier.permitSyncStatus, 'error');

        // Emit metadata empty document
        final emptyMetaDoc = FakeDocumentSnapshot(
          'ff398c7e-c522-4ee8-a53a-312b188a573d',
          false,
          null,
        );
        metadataController.add(emptyMetaDoc);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await metadataController.close();
        await permitsController.close();
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'initPermitMetadataListener fallback when streams are null and firebase is not initialized',
      () {
        AppStateNotifier.isTesting = false;
        final notifier = PermitsNotifier(isTesting: false);
        notifier.initPermitMetadataListener();
        expect(notifier.permitSyncStatus, 'error');
        expect(notifier.isLoadingPermits, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'PermitsNotifier handles real Firestore streams and error paths',
      () async {
        final permitMetadataController =
            StreamController<
              DocumentSnapshot<Map<String, dynamic>>
            >.broadcast();
        final permitsController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

        final mockFirestore = FakeFirebaseFirestore((path) {
          if (path == 'dataset_metadata') {
            return FakeCollectionReference(
              docBuilder: (docId) {
                if (docId == 'ff398c7e-c522-4ee8-a53a-312b188a573d') {
                  return FakeDocumentReference(
                    snapshotStream: permitMetadataController.stream,
                  );
                }
                return FakeDocumentReference();
              },
            );
          }
          return FakeCollectionReference(stream: permitsController.stream);
        });

        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;

        final notifier = PermitsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.initPermitMetadataListener();

        permitMetadataController.add(
          FakeDocumentSnapshot('meta', true, {
            'activeCollection': 'permits_active_collection',
            'status': 'syncing',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.permitSyncStatus, 'syncing');

        permitsController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('perm1', {'referenceNumber': 12345}),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingPermits, isFalse);
        expect(notifier.permitRecords.first['referenceNumber'], 12345);

        permitsController.addError('Permits Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingPermits, isFalse);

        permitMetadataController.addError('Metadata Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.permitSyncStatus, 'error');

        notifier.dispose();
        await permitMetadataController.close();
        await permitsController.close();
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test('PermitsNotifier handles empty permit metadata snapshot', () async {
      final permitMetadataController =
          StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
      final mockFirestore = FakeFirebaseFirestore((path) {
        return FakeCollectionReference(
          docBuilder: (docId) => FakeDocumentReference(
            snapshotStream: permitMetadataController.stream,
          ),
        );
      });

      AppStateNotifier.isTesting = false;
      AppStateNotifier.testIsFirebaseInitialized = true;

      final notifier = PermitsNotifier(
        isTesting: false,
        testFirestore: mockFirestore,
      );
      notifier.initPermitMetadataListener();
      permitMetadataController.add(FakeDocumentSnapshot('meta', false, null));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(notifier.isLoadingPermits, isFalse);

      notifier.dispose();
      await permitMetadataController.close();
      AppStateNotifier.isTesting = true;
      AppStateNotifier.testIsFirebaseInitialized = null;
    });

    test(
      'PermitsNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = PermitsNotifier(isTesting: false);
        notifier.initPermitMetadataListener();
        expect(notifier.isLoadingPermits, isFalse);
        notifier.dispose();
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'PermitsNotifier handles duplicate active collection metadata, subscription errors, and binding exceptions',
      () async {
        final permitMetadataController =
            StreamController<
              DocumentSnapshot<Map<String, dynamic>>
            >.broadcast();
        final mockFirestore = FakeFirebaseFirestore((path) {
          if (path == 'dataset_metadata') {
            return FakeCollectionReference(
              docBuilder: (docId) => FakeDocumentReference(
                snapshotStream: permitMetadataController.stream,
              ),
            );
          }
          return FakeCollectionReference();
        });

        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;

        // 1. PermitsNotifier metadata listener handles same active collection
        final notifier = PermitsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.initPermitMetadataListener();

        permitMetadataController.add(
          FakeDocumentSnapshot('meta', true, {
            'activeCollection': 'permits_active_collection',
            'status': 'syncing',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Send same metadata, should not bind again, hits the else branch
        permitMetadataController.add(
          FakeDocumentSnapshot('meta', true, {
            'activeCollection': 'permits_active_collection',
            'status': 'syncing',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 2. Permits collection snapshots throws exception on bind
        final mockFirestoreThrow = FakeFirebaseFirestore((path) {
          if (path == 'dataset_metadata') {
            return FakeCollectionReference(
              docBuilder: (docId) => FakeDocumentReference(
                snapshotStream: permitMetadataController.stream,
              ),
            );
          }
          throw Exception('Collection snapshots exception on permits list');
        });

        final notifier2 = PermitsNotifier(
          isTesting: false,
          testFirestore: mockFirestoreThrow,
        );
        notifier2.initPermitMetadataListener();

        permitMetadataController.add(
          FakeDocumentSnapshot('meta', true, {
            'activeCollection': 'permits_active_collection',
            'status': 'syncing',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier2.permitSyncStatus, 'error');

        // 3. Permits metadata snapshots throws exception on bind
        final mockFirestoreThrowMeta = FakeFirebaseFirestore((path) {
          throw Exception('Collection metadata snapshots exception');
        });
        final notifier3 = PermitsNotifier(
          isTesting: false,
          testFirestore: mockFirestoreThrowMeta,
        );
        notifier3.initPermitMetadataListener();
        expect(notifier3.permitSyncStatus, 'error');

        notifier.dispose();
        notifier2.dispose();
        notifier3.dispose();
        await permitMetadataController.close();
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test('getRecordLastUpdated extraction callback works', () {
      final notifier = PermitsNotifier(isTesting: true);
      final manager = notifier.syncManagerForTesting;
      expect(
        manager.getRecordLastUpdated({'lastUpdated': '2026-06-02'}),
        '2026-06-02',
      );
      expect(manager.getRecordLastUpdated({}), '');
      notifier.dispose();
    });
  });
}
