import 'package:davart_mobile/features/catalog/presentation/product_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('area calculator rounds up to whole packs', () {
    expect(packsForArea(10, 1.44), 8); // 11.5 m² → 7.99 → 8
    expect(packsForArea(10, 1.44, withReserve: false), 7); // 6.94 → 7
    expect(packsForArea(2.88, 1.44, withReserve: false), 2); // exact, no extra pack
    expect(packsForArea(12, 1.2), 12); // 13.8 / 1.2 = 11.5 → 12
    expect(packsForArea(0, 1.44), isNull);
    expect(packsForArea(5, null), isNull);
  });
}
