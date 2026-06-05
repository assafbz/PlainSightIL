import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainsight/core/state/local_storage_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStorageIO Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('IO locale getter and setter works', () async {
      final storage = LocalStorageIO();
      await storage.init();
      expect(storage.getLocale(), 'en');
      await storage.saveLocale('he');
      expect(storage.getLocale(), 'he');
    });
  });
}
