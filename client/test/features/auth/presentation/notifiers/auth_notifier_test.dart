import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/auth/presentation/notifiers/auth_notifier.dart';

void main() {
  group('AuthNotifier Structural tests', () {
    test('Can instantiate AuthNotifier in testing mode', () {
      final notifier = AuthNotifier(isTesting: true);
      expect(notifier.isAuthenticated, isTrue);
    });
  });
}
