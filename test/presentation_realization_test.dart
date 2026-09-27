import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

void main() {
  test('presentation realization values round-trip through configuration', () {
    for (final realization in PresentationRealization.values) {
      expect(
        PresentationRealization.fromJson(realization.toJson()),
        realization,
      );
    }
  });
}
