import 'package:flutter_test/flutter_test.dart';
import 'package:saha/data.dart';

void main() {
  test('set numbers follow the order after a delete', () {
    final l = <Map>[
      {'id': 'a', 'd': '2026-11-25', 'set': 2, 't': 1},
      {'id': 'b', 'd': '2026-11-25', 'set': 2, 't': 2},
      {'id': 'c', 'd': '2026-11-25', 'set': 3, 't': 3},
      {'id': 'x', 'd': '2026-11-24', 'set': 5, 't': 0},
    ];
    Store.renumberForTest(l, '2026-11-25');
    expect([for (final r in l) r['set']], [1, 2, 3, 5]);
  });
}
