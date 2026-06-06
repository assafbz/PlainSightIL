import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/features/alerts/presentation/notifiers/alerts_notifier.dart';
import 'package:plainsight/core/state/app_state.dart';

void main() {
  group('AlertsNotifier Tests (isTesting: true)', () {
    late AlertsNotifier alertsNotifier;

    setUp(() {
      alertsNotifier = AlertsNotifier(isTesting: true);
    });

    test('Initial mock alerts and subscriptions load correctly', () {
      expect(alertsNotifier.alerts.length, 2);
      expect(alertsNotifier.unreadCount, 1);
      expect(alertsNotifier.isLoading, false);

      expect(alertsNotifier.isSubscribed('cellular_antennas'), true);
      expect(alertsNotifier.isSubscribed('local_market_bonds'), false);
    });

    test(
      'toggleSubscription adds or removes subscription and notifies listeners',
      () async {
        var listenerCalled = false;
        alertsNotifier.addListener(() {
          listenerCalled = true;
        });

        // Unsubscribe cellular_antennas
        await alertsNotifier.toggleSubscription(
          'cellular_antennas',
          'mock_uid',
        );
        expect(alertsNotifier.isSubscribed('cellular_antennas'), false);
        expect(listenerCalled, true);

        listenerCalled = false;

        // Subscribe new dataset
        await alertsNotifier.toggleSubscription(
          'local_market_bonds',
          'mock_uid',
        );
        expect(alertsNotifier.isSubscribed('local_market_bonds'), true);
        expect(listenerCalled, true);
      },
    );

    test('markAsRead updates alert status and unreadCount', () async {
      var listenerCalled = false;
      alertsNotifier.addListener(() {
        listenerCalled = true;
      });

      expect(alertsNotifier.unreadCount, 1);
      expect(
        alertsNotifier.alerts.firstWhere((a) => a.id == 'mock_alert_1').isRead,
        false,
      );

      await alertsNotifier.markAsRead('mock_alert_1', 'mock_uid');

      expect(alertsNotifier.unreadCount, 0);
      expect(
        alertsNotifier.alerts.firstWhere((a) => a.id == 'mock_alert_1').isRead,
        true,
      );
      expect(listenerCalled, true);
    });

    test('markAllAsRead updates all alerts to read status', () async {
      expect(alertsNotifier.unreadCount, 1);

      await alertsNotifier.markAllAsRead('mock_uid');

      expect(alertsNotifier.unreadCount, 0);
      expect(alertsNotifier.alerts.every((a) => a.isRead), true);
    });

    test(
      'deleteAlert removes the alert from feed and notifies listeners',
      () async {
        var listenerCalled = false;
        alertsNotifier.addListener(() {
          listenerCalled = true;
        });

        expect(alertsNotifier.alerts.length, 2);

        await alertsNotifier.deleteAlert('mock_alert_1', 'mock_uid');

        expect(alertsNotifier.alerts.length, 1);
        expect(alertsNotifier.alerts.any((a) => a.id == 'mock_alert_1'), false);
        expect(listenerCalled, true);
      },
    );
  });

  group('AlertsNotifier Production Tests (isTesting: false)', () {
    late StreamController<QuerySnapshot<Map<String, dynamic>>> subsController;
    late StreamController<QuerySnapshot<Map<String, dynamic>>> alertsController;

    setUp(() {
      AppStateNotifier.isTesting = false;
      AppStateNotifier.testIsFirebaseInitialized = true;
      subsController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      alertsController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      // Clear static tracking lists
      FakeDocRef.setDocs.clear();
      FakeDocRef.deletedDocs.clear();
      FakeDocRef.updatedDocs.clear();
      FakeWriteBatch.batchUpdates.clear();
      FakeWriteBatch.batchCommitted = false;

      // Reset throw flags
      FakeFirestore.throwOnCollection = false;
      FakeFirestore.throwOnBatch = false;
      FakeDocRef.throwOnOps = false;
      FakeWriteBatch.throwOnCommit = false;
    });

    tearDown(() {
      subsController.close();
      alertsController.close();
      AppStateNotifier.isTesting = true;
      AppStateNotifier.testIsFirebaseInitialized = null;
    });

    test('initAlertsListener handles empty user ID', () {
      final notifier = AlertsNotifier(isTesting: false);
      notifier.initAlertsListener('');
      expect(notifier.alerts, isEmpty);
      expect(notifier.subscribedDatasetIds, isEmpty);
    });

    test('initAlertsListener binds streams and propagates updates', () async {
      late CollectionReference<Map<String, dynamic>> Function(String)
      colBuilder;
      colBuilder = (path) {
        if (path == 'subscriptions') {
          return FakeCollectionRef(
            path,
            snapshotStream: subsController.stream,
            collectionBuilder: colBuilder,
          );
        } else if (path.endsWith('alerts')) {
          return FakeCollectionRef(
            path,
            snapshotStream: alertsController.stream,
            collectionBuilder: colBuilder,
          );
        }
        return FakeCollectionRef(path, collectionBuilder: colBuilder);
      };

      final mockFirestore = FakeFirestore(collectionBuilder: colBuilder);
      final notifier = AlertsNotifier(
        isTesting: false,
        firestore: mockFirestore,
      );

      var listenerCalled = false;
      notifier.addListener(() {
        listenerCalled = true;
      });

      notifier.initAlertsListener('user_123');
      expect(notifier.isLoading, isTrue);

      // Push subscription snapshot
      subsController.add(
        FakeQuerySnap([
          FakeQueryDocSnap('sub_1', {'datasetId': 'cellular_antennas'}),
        ]),
      );

      // Push alerts snapshot
      alertsController.add(
        FakeQuerySnap([
          FakeQueryDocSnap('alert_1', {
            'id': 'alert_1',
            'userId': 'user_123',
            'type': 'new_records',
            'title': {'en': 'New Title', 'he': 'כותרת'},
            'description': {'en': 'New Desc', 'he': 'תיאור'},
            'datasetId': 'cellular_antennas',
            'isRead': false,
            'createdAt': '2026-06-06T12:00:00Z',
          }),
        ]),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.isLoading, isFalse);
      expect(notifier.subscribedDatasetIds, ['cellular_antennas']);
      expect(notifier.alerts.length, 1);
      expect(notifier.unreadCount, 1);
      expect(listenerCalled, isTrue);

      // Verify cancel listeners / dispose
      notifier.dispose();
    });

    test('toggleSubscription handles delete and set', () async {
      late CollectionReference<Map<String, dynamic>> Function(String)
      colBuilder;
      colBuilder = (path) {
        return FakeCollectionRef(path, collectionBuilder: colBuilder);
      };

      final mockFirestore = FakeFirestore(collectionBuilder: colBuilder);
      final notifier = AlertsNotifier(
        isTesting: false,
        firestore: mockFirestore,
      );

      // 1. Toggle subscribe (when currently unsubscribed)
      expect(notifier.isSubscribed('cellular_antennas'), isFalse);
      await notifier.toggleSubscription('cellular_antennas', 'user_123');
      expect(FakeDocRef.setDocs.length, 1);
      expect(FakeDocRef.setDocs.first['datasetId'], 'cellular_antennas');
      expect(FakeDocRef.setDocs.first['userId'], 'user_123');

      // 2. Toggle unsubscribe (when currently subscribed)
      final subsController2 =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      late CollectionReference<Map<String, dynamic>> Function(String)
      colBuilder2;
      colBuilder2 = (path) {
        if (path == 'subscriptions') {
          return FakeCollectionRef(
            path,
            snapshotStream: subsController2.stream,
            collectionBuilder: colBuilder2,
          );
        }
        return FakeCollectionRef(path, collectionBuilder: colBuilder2);
      };

      final mockFirestore2 = FakeFirestore(collectionBuilder: colBuilder2);

      final notifier2 = AlertsNotifier(
        isTesting: false,
        firestore: mockFirestore2,
      );
      notifier2.initAlertsListener('user_123');
      subsController2.add(
        FakeQuerySnap([
          FakeQueryDocSnap('user_123_cellular_antennas', {
            'datasetId': 'cellular_antennas',
          }),
        ]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier2.isSubscribed('cellular_antennas'), isTrue);

      await notifier2.toggleSubscription('cellular_antennas', 'user_123');
      expect(
        FakeDocRef.deletedDocs.contains('user_123_cellular_antennas'),
        isTrue,
      );
      subsController2.close();
    });

    test('markAsRead updates isRead property in database', () async {
      late CollectionReference<Map<String, dynamic>> Function(String)
      colBuilder;
      colBuilder = (path) {
        return FakeCollectionRef(path, collectionBuilder: colBuilder);
      };

      final mockFirestore = FakeFirestore(collectionBuilder: colBuilder);
      final notifier = AlertsNotifier(
        isTesting: false,
        firestore: mockFirestore,
      );
      await notifier.markAsRead('alert_123', 'user_123');
      expect(FakeDocRef.updatedDocs.length, 1);
      expect(FakeDocRef.updatedDocs.first['isRead'], isTrue);
    });

    test('markAllAsRead commits batch updates', () async {
      final alertsController2 =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      late CollectionReference<Map<String, dynamic>> Function(String)
      colBuilder2;
      colBuilder2 = (path) {
        if (path.endsWith('alerts')) {
          return FakeCollectionRef(
            path,
            snapshotStream: alertsController2.stream,
            collectionBuilder: colBuilder2,
          );
        }
        return FakeCollectionRef(path, collectionBuilder: colBuilder2);
      };

      final mockFirestore2 = FakeFirestore(collectionBuilder: colBuilder2);
      final notifier2 = AlertsNotifier(
        isTesting: false,
        firestore: mockFirestore2,
      );
      notifier2.initAlertsListener('user_123');
      alertsController2.add(
        FakeQuerySnap([
          FakeQueryDocSnap('alert_1', {
            'id': 'alert_1',
            'userId': 'user_123',
            'type': 'new_records',
            'title': {'en': 'Title 1', 'he': '1'},
            'description': {'en': 'Desc 1', 'he': '1'},
            'datasetId': 'cellular_antennas',
            'isRead': false,
            'createdAt': '2026-06-06T12:00:00Z',
          }),
          FakeQueryDocSnap('alert_2', {
            'id': 'alert_2',
            'userId': 'user_123',
            'type': 'new_records',
            'title': {'en': 'Title 2', 'he': '2'},
            'description': {'en': 'Desc 2', 'he': '2'},
            'datasetId': 'cellular_antennas',
            'isRead': true,
            'createdAt': '2026-06-06T12:00:00Z',
          }),
        ]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier2.markAllAsRead('user_123');
      expect(FakeWriteBatch.batchUpdates.length, 1); // Only alert_1 is unread
      expect(FakeWriteBatch.batchUpdates.first['isRead'], isTrue);
      expect(FakeWriteBatch.batchCommitted, isTrue);
      alertsController2.close();
    });

    test('deleteAlert calls delete document', () async {
      late CollectionReference<Map<String, dynamic>> Function(String)
      colBuilder;
      colBuilder = (path) {
        return FakeCollectionRef(path, collectionBuilder: colBuilder);
      };

      final mockFirestore = FakeFirestore(collectionBuilder: colBuilder);
      final notifier = AlertsNotifier(
        isTesting: false,
        firestore: mockFirestore,
      );
      await notifier.deleteAlert('alert_789', 'user_123');
      expect(FakeDocRef.deletedDocs.contains('alert_789'), isTrue);
    });

    test('isFirebaseInitialized returns false when Firebase has no apps', () {
      final notifier = AlertsNotifier(isTesting: false);
      AppStateNotifier.testIsFirebaseInitialized = null;
      expect(notifier.isFirebaseInitialized, isFalse);
    });

    test('initAlertsListener when firebase is not initialized', () {
      final notifier = AlertsNotifier(isTesting: false);
      AppStateNotifier.testIsFirebaseInitialized = false;
      notifier.initAlertsListener('user_123');
      expect(notifier.isLoading, isFalse);
    });

    test('initAlertsListener handles stream error on subscriptions', () async {
      late CollectionReference<Map<String, dynamic>> Function(String)
      colBuilder;
      colBuilder = (path) {
        if (path == 'subscriptions') {
          return FakeCollectionRef(
            path,
            snapshotStream: subsController.stream,
            collectionBuilder: colBuilder,
          );
        } else if (path.endsWith('alerts')) {
          return FakeCollectionRef(
            path,
            snapshotStream: alertsController.stream,
            collectionBuilder: colBuilder,
          );
        }
        return FakeCollectionRef(path, collectionBuilder: colBuilder);
      };

      final mockFirestore = FakeFirestore(collectionBuilder: colBuilder);
      final notifier = AlertsNotifier(
        isTesting: false,
        firestore: mockFirestore,
      );
      notifier.initAlertsListener('user_123');

      subsController.addError(Exception('subscriptions stream error'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('initAlertsListener handles stream error on alerts', () async {
      late CollectionReference<Map<String, dynamic>> Function(String)
      colBuilder;
      colBuilder = (path) {
        if (path == 'subscriptions') {
          return FakeCollectionRef(
            path,
            snapshotStream: subsController.stream,
            collectionBuilder: colBuilder,
          );
        } else if (path.endsWith('alerts')) {
          return FakeCollectionRef(
            path,
            snapshotStream: alertsController.stream,
            collectionBuilder: colBuilder,
          );
        }
        return FakeCollectionRef(path, collectionBuilder: colBuilder);
      };

      final mockFirestore = FakeFirestore(collectionBuilder: colBuilder);
      final notifier = AlertsNotifier(
        isTesting: false,
        firestore: mockFirestore,
      );
      notifier.initAlertsListener('user_123');

      alertsController.addError(Exception('alerts stream error'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.isLoading, isFalse);
    });

    test(
      'initAlertsListener handles firestore collection fetch exception',
      () async {
        FakeFirestore.throwOnCollection = true;
        final mockFirestore = FakeFirestore(
          collectionBuilder: (path) => FakeCollectionRef(path),
        );
        final notifier = AlertsNotifier(
          isTesting: false,
          firestore: mockFirestore,
        );

        notifier.initAlertsListener('user_123');
        expect(notifier.isLoading, isFalse);
      },
    );

    test('toggleSubscription handles firestore exceptions', () async {
      FakeDocRef.throwOnOps = true;
      final mockFirestore = FakeFirestore(
        collectionBuilder: (path) => FakeCollectionRef(path),
      );
      final notifier = AlertsNotifier(
        isTesting: false,
        firestore: mockFirestore,
      );

      expect(
        () => notifier.toggleSubscription('dataset_1', 'user_123'),
        throwsException,
      );
    });

    test('markAsRead handles firestore exceptions', () async {
      FakeDocRef.throwOnOps = true;
      final mockFirestore = FakeFirestore(
        collectionBuilder: (path) => FakeCollectionRef(path),
      );
      final notifier = AlertsNotifier(
        isTesting: false,
        firestore: mockFirestore,
      );

      expect(() => notifier.markAsRead('alert_1', 'user_123'), throwsException);
    });

    test('markAllAsRead handles batch commit firestore exceptions', () async {
      final alertsController2 =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      late CollectionReference<Map<String, dynamic>> Function(String)
      colBuilder2;
      colBuilder2 = (path) {
        if (path.endsWith('alerts')) {
          return FakeCollectionRef(
            path,
            snapshotStream: alertsController2.stream,
            collectionBuilder: colBuilder2,
          );
        }
        return FakeCollectionRef(path, collectionBuilder: colBuilder2);
      };

      final mockFirestore2 = FakeFirestore(collectionBuilder: colBuilder2);
      final notifier2 = AlertsNotifier(
        isTesting: false,
        firestore: mockFirestore2,
      );
      notifier2.initAlertsListener('user_123');

      alertsController2.add(
        FakeQuerySnap([
          FakeQueryDocSnap('alert_1', {
            'id': 'alert_1',
            'userId': 'user_123',
            'type': 'new_records',
            'title': {'en': 'Title 1', 'he': '1'},
            'description': {'en': 'Desc 1', 'he': '1'},
            'datasetId': 'cellular_antennas',
            'isRead': false,
            'createdAt': '2026-06-06T12:00:00Z',
          }),
        ]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      FakeWriteBatch.throwOnCommit = true;
      expect(() => notifier2.markAllAsRead('user_123'), throwsException);
      alertsController2.close();
    });

    test('deleteAlert handles firestore exceptions', () async {
      FakeDocRef.throwOnOps = true;
      final mockFirestore = FakeFirestore(
        collectionBuilder: (path) => FakeCollectionRef(path),
      );
      final notifier = AlertsNotifier(
        isTesting: false,
        firestore: mockFirestore,
      );

      expect(
        () => notifier.deleteAlert('alert_1', 'user_123'),
        throwsException,
      );
    });
  });
}

class FakeFirestore implements FirebaseFirestore {
  final CollectionReference<Map<String, dynamic>> Function(String)
  collectionBuilder;
  static bool throwOnCollection = false;
  static bool throwOnBatch = false;

  FakeFirestore({required this.collectionBuilder});

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    if (throwOnCollection) {
      throw Exception('Simulated collection failure');
    }
    return collectionBuilder(path);
  }

  @override
  WriteBatch batch() {
    if (throwOnBatch) {
      throw Exception('Simulated batch failure');
    }
    return FakeWriteBatch();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCollectionRef implements CollectionReference<Map<String, dynamic>> {
  final String path;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? snapshotStream;
  final CollectionReference<Map<String, dynamic>> Function(String)?
  collectionBuilder;

  FakeCollectionRef(this.path, {this.snapshotStream, this.collectionBuilder});

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeDocRef(
      path ?? 'mock-doc-id',
      collectionBuilder: collectionBuilder,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #snapshots) {
      return snapshotStream ?? Stream.value(FakeQuerySnap([]));
    }
    if (invocation.memberName == #where ||
        invocation.memberName == #orderBy ||
        invocation.memberName == #limit) {
      return this;
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeDocRef implements DocumentReference<Map<String, dynamic>> {
  final String docId;
  final CollectionReference<Map<String, dynamic>> Function(String)?
  collectionBuilder;
  static final List<Map<String, dynamic>> setDocs = [];
  static final List<String> deletedDocs = [];
  static final List<Map<Object, Object?>> updatedDocs = [];
  static bool throwOnOps = false;

  FakeDocRef(this.docId, {this.collectionBuilder});

  @override
  String get id => docId;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionBuilder != null) {
      return collectionBuilder!(collectionPath);
    }
    return FakeCollectionRef(collectionPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (throwOnOps) {
      throw Exception('Simulated doc operation failure');
    }
    if (invocation.memberName == #set) {
      final data = invocation.positionalArguments[0] as Map<String, dynamic>;
      setDocs.add(data);
      return Future<void>.value();
    }
    if (invocation.memberName == #update) {
      final data = invocation.positionalArguments[0] as Map<Object, Object?>;
      updatedDocs.add(data);
      return Future<void>.value();
    }
    if (invocation.memberName == #delete) {
      deletedDocs.add(docId);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeWriteBatch implements WriteBatch {
  static final List<Map<Object, Object?>> batchUpdates = [];
  static bool batchCommitted = false;
  static bool throwOnCommit = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #update) {
      final data = invocation.positionalArguments[1] as Map<Object, Object?>;
      batchUpdates.add(data);
      return null;
    }
    if (invocation.memberName == #commit) {
      if (throwOnCommit) {
        throw Exception('Simulated commit failure');
      }
      batchCommitted = true;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeQuerySnap implements QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  FakeQuerySnap(this._docs);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeQueryDocSnap implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic> _data;

  FakeQueryDocSnap(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
