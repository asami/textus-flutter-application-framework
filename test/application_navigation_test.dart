import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

void main() {
  final configuration = ApplicationNavigationConfiguration(
    initialDestinationId: 'home',
    destinations: const [
      NavigationDestinationConfiguration(
        id: 'home',
        label: 'Home',
        symbol: NavigationSymbol.home,
      ),
      NavigationDestinationConfiguration(
        id: 'library',
        label: 'Library',
        symbol: NavigationSymbol.folder,
      ),
    ],
  );

  test('round-trips the framework navigation model', () {
    // Given a valid declarative navigation model.
    final source = configuration.toJson();

    // When it is decoded again.
    final decoded = ApplicationNavigationConfiguration.fromJson(source);

    // Then destination order, initial selection and symbols remain stable.
    expect(decoded.toJson(), source);
    expect(decoded.destinations.map((destination) => destination.id), [
      'home',
      'library',
    ]);
  });

  test('rejects ambiguous or missing navigation destinations', () {
    // Given duplicate ids, a missing initial id, or an unknown symbol.
    const destination = NavigationDestinationConfiguration(
      id: 'home',
      label: 'Home',
      symbol: NavigationSymbol.home,
    );

    // When each invalid model is constructed or decoded.
    // Then it cannot become a navigation shell configuration.
    expect(
      () => ApplicationNavigationConfiguration(
        initialDestinationId: 'home',
        destinations: [destination, destination],
      ),
      throwsFormatException,
    );
    expect(
      () => ApplicationNavigationConfiguration(
        initialDestinationId: 'missing',
        destinations: configuration.destinations,
      ),
      throwsFormatException,
    );
    expect(() => NavigationSymbol.fromJson('unknown'), throwsFormatException);
  });

  testWidgets('switches tabs while retaining inactive page state', (
    tester,
  ) async {
    // Given application-owned pages inside the framework shell.
    await tester.pumpWidget(
      MaterialApp(
        home: ApplicationNavigationShell(
          configuration: configuration,
          pages: const {
            'home': _CounterPage(),
            'library': Center(child: Text('Library body')),
          },
        ),
      ),
    );
    await tester.tap(find.text('Increment'));
    await tester.pump();
    expect(find.text('Count: 1'), findsOneWidget);

    // When the user visits Library and returns Home.
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('Library body'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    // Then Home keeps its previous state.
    expect(find.text('Count: 1'), findsOneWidget);
  });

  testWidgets('requires an exact page binding for configured ids', (
    tester,
  ) async {
    // Given one configured destination has no application page.
    await tester.pumpWidget(
      MaterialApp(
        home: ApplicationNavigationShell(
          configuration: configuration,
          pages: const {'home': Text('Home body')},
        ),
      ),
    );

    // When the framework builds the shell, then it reports the mismatch.
    expect(tester.takeException(), isArgumentError);
  });
}

class _CounterPage extends StatefulWidget {
  const _CounterPage();

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Count: $count'),
        TextButton(
          onPressed: () => setState(() => count++),
          child: const Text('Increment'),
        ),
      ],
    ),
  );
}
