import 'package:flutter_test/flutter_test.dart';
import 'package:saha/ada.dart';

AdaAdim a(int y, int h, {bool isinma = false, int grup = -1}) => AdaAdim(yapilan: y, hedef: h, isinma: isinma, grup: grup);

void main() {
  group('adaSiradaki', () {
    test('starts from the first step', () {
      expect(adaSiradaki([a(0, 1, isinma: true), a(0, 3), a(0, 3)]), 0);
    });

    test('a skipped warm-up is not asked for once training started', () {
      expect(adaSiradaki([a(0, 1, isinma: true), a(1, 3), a(0, 3)]), 1);
      expect(adaSiradaki([a(0, 1, isinma: true), a(3, 3), a(3, 3)]), isNull);
    });

    test('moves on after the last step with progress, then comes back to skipped ones', () {
      expect(adaSiradaki([a(0, 3), a(3, 3), a(0, 3)]), 2);
      expect(adaSiradaki([a(0, 3), a(3, 3), a(3, 3)]), 0);
    });

    test('a superset alternates a, b, a, b', () {
      final l = [a(3, 3), a(0, 2, grup: 0), a(0, 2, grup: 0), a(0, 2)];
      expect(adaSiradaki(l), 1);
      expect(adaSiradaki([a(3, 3), a(1, 2, grup: 0), a(0, 2, grup: 0), a(0, 2)]), 2);
      expect(adaSiradaki([a(3, 3), a(1, 2, grup: 0), a(1, 2, grup: 0), a(0, 2)]), 1);
      expect(adaSiradaki([a(3, 3), a(2, 2, grup: 0), a(2, 2, grup: 0), a(0, 2)]), 3);
    });

    test('two supersets next to each other stay apart', () {
      final l = [a(1, 2, grup: 0), a(1, 2, grup: 0), a(0, 2, grup: 1), a(0, 2, grup: 1)];
      expect(adaSiradaki(l), 0);
    });

    test('empty list', () => expect(adaSiradaki(const []), isNull));
  });

  test('adaSure reads seconds and minutes', () {
    expect(adaSure('2×20 sn'), 20);
    expect(adaSure('2×30 sn her taraf'), 30);
    expect(adaSure('10 dk'), 600);
    expect(adaSure('3×10 · RIR 3'), isNull);
    expect(adaSure('2×30 s each side'), 30);
    expect(adaSure(null), isNull);
  });

  test('adaDoz keeps sets × reps', () {
    expect(adaDoz('3×10 · RIR 3'), '3 × 10');
    expect(adaDoz('2×3 + kısmi'), '2 × 3 + kısmi');
    expect(adaDoz(null), '');
  });
}
