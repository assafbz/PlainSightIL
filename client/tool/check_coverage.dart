import 'dart:io';

void main() {
  final lcovFile = File('coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    print('❌ Error: coverage/lcov.info file not found.');
    exit(1);
  }

  final lines = lcovFile.readAsLinesSync();
  String currentFile = '';
  int foundLines = 0;
  int hitLines = 0;

  bool hasFailure = false;

  for (var line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      foundLines = 0;
      hitLines = 0;
    } else if (line.startsWith('LF:')) {
      foundLines = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hitLines = int.parse(line.substring(3));
    } else if (line == 'end_of_record') {
      if (currentFile.isEmpty) continue;

      final double coverage = foundLines > 0
          ? (hitLines / foundLines) * 100
          : 100.0;

      // Determine if check is needed
      final bool isDomainOrData =
          currentFile.contains('/domain/') || currentFile.contains('/data/');
      final bool isNotifier =
          currentFile.endsWith('_notifier.dart') ||
          currentFile.endsWith('app_state.dart');

      if (isNotifier) {
        if (coverage < 100.0) {
          print(
            '❌ Coverage failure for notifier: $currentFile. Got ${coverage.toStringAsFixed(1)}% (expected 100%)',
          );
          hasFailure = true;
        } else {
          print('✅ Notifier: $currentFile is at 100.0% coverage.');
        }
      } else if (isDomainOrData) {
        if (coverage < 90.0) {
          print(
            '❌ Coverage failure for domain/data: $currentFile. Got ${coverage.toStringAsFixed(1)}% (expected >= 90%)',
          );
          hasFailure = true;
        } else {
          print(
            '✅ Domain/Data: $currentFile is at ${coverage.toStringAsFixed(1)}% coverage.',
          );
        }
      }
    }
  }

  if (hasFailure) {
    print('🛑 Coverage verification failed. See issues listed above.');
    exit(1);
  } else {
    print('🎉 All coverage checks passed successfully!');
    exit(0);
  }
}
