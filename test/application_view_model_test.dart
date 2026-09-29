import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

class _OtherView extends ChangeNotifier implements ApplicationView {
  bool wasDisposed = false;

  void change() => notifyListeners();

  @override
  void dispose() {
    wasDisposed = true;
    super.dispose();
  }
}

void main() {
  test(
    'the application view space owns and observes arbitrary named views',
    () {
      final other = _OtherView();
      final model = ApplicationViewModel({'other': other});
      var notifications = 0;
      model.addListener(() => notifications++);

      expect(model.view<_OtherView>('other'), same(other));
      expect(model.viewIds, contains('other'));
      other.change();
      expect(notifications, 1);
      expect(() => model.view<_OtherView>('missing'), throwsArgumentError);
      expect(
        () => model.view<ResourceCollectionView>('other'),
        throwsStateError,
      );

      model.dispose();
      expect(other.wasDisposed, isTrue);
    },
  );

  test('one semantic view cannot be registered under two IDs', () {
    final other = _OtherView();
    expect(
      () => ApplicationViewModel({'one': other, 'two': other}),
      throwsArgumentError,
    );
    other.dispose();
  });
}
