import 'package:flutter_test/flutter_test.dart';
import 'package:reep/utils/format.dart';

void main() {
  test('时长格式化', () {
    expect(formatDuration(const Duration(minutes: 5, seconds: 3)), '05:03');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03');
  });

  test('配速格式化', () {
    expect(formatPace(330), "5'30\"");
    expect(formatPace(null), '--\'--"');
  });
}
