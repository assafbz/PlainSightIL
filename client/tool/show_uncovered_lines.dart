import 'dart:io';

void main() {
  final lcovFile = File('coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    print('Error: coverage/lcov.info not found.');
    exit(1);
  }

  final lines = lcovFile.readAsLinesSync();
  String currentFile = '';
  final Map<int, int> lineHits = {}; // line -> hits

  for (var line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      lineHits.clear();
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        final lineNum = int.parse(parts[0]);
        final hits = int.parse(parts[1]);
        lineHits[lineNum] = hits;
      }
    } else if (line == 'end_of_record') {
      if (currentFile.endsWith('_notifier.dart')) {
        final uncovered = <int>[];
        lineHits.forEach((lineNum, hits) {
          if (hits == 0) {
            uncovered.add(lineNum);
          }
        });
        if (uncovered.isNotEmpty) {
          print('File: $currentFile');
          print('Uncovered lines (${uncovered.length}): $uncovered\n');
        }
      }
    }
  }
}
