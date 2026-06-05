import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainsight/core/state/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStorage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Locale get and save works', () async {
      await LocalStorage.init();
      expect(LocalStorage.getLocale(), 'en');
      await LocalStorage.saveLocale('he');
      // On non-web platform, it calls the io implementation
      expect(LocalStorage.getLocale(), 'he');
    });
  });
}
