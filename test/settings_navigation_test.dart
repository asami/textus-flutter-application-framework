import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import 'support/controllable_settings_storage.dart';

class _Controller extends SettingsController {
  _Controller(ControllableSettingsStorage storage) : super(storage: storage);

  int disposeCalls = 0;
  int attached = 0;
  int detached = 0;

  @override
  void addListener(VoidCallback listener) {
    attached++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    detached++;
    super.removeListener(listener);
  }

  @override
  void dispose() {
    if (disposeCalls != 0) return;
    disposeCalls++;
    super.dispose();
  }
}

class _View extends SettingsView {
  _View.borrowed(_Controller controller)
    : super.fromService(service: controller);
  _View.owned(_Controller controller) : super.owned(service: controller);

  int attached = 0;
  int detached = 0;
  int disposeCalls = 0;

  @override
  void addListener(VoidCallback listener) {
    attached++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    detached++;
    super.removeListener(listener);
  }

  @override
  void dispose() {
    if (disposeCalls != 0) return;
    disposeCalls++;
    super.dispose();
  }
}

class _Session {
  _Session({bool ownsService = false}) {
    controller = _Controller(storage);
    view = ownsService ? _View.owned(controller) : _View.borrowed(controller);
  }

  final storage = ControllableSettingsStorage();
  late final _Controller controller;
  late final _View view;

  void dispose() {
    view.dispose();
    controller.dispose();
  }
}

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  final popped = <Route<dynamic>>[];
  final removed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    removed.add(route);
  }
}

class _Launch {
  _Launch(this.view, this.presentation, {this.capabilities});

  final SettingsView view;
  final SettingsPresentation presentation;
  SettingsCapabilities? capabilities;
  Future<void>? completion;
  int completed = 0;

  void open(BuildContext context) {
    completion = showSettings(
      context,
      view: view,
      capabilities: capabilities,
      presentation: presentation,
    );
    unawaited(completion!.then((_) => completed++));
  }

  Widget button(BuildContext context, {bool cupertino = false}) => cupertino
      ? CupertinoButton(
          key: const ValueKey('open-settings'),
          onPressed: () => open(context),
          child: const Text('Open Settings'),
        )
      : TextButton(
          key: const ValueKey('open-settings'),
          onPressed: () => open(context),
          child: const Text('Open Settings'),
        );
}

class _Resources implements ResourceDataSource, ResourceActionHandler {
  final record = ResourceRecord(id: 'one', values: {'name': 'One'});
  int listCalls = 0;
  int readCalls = 0;
  int actionCatalogCalls = 0;
  int commandCalls = 0;

  @override
  Future<List<ResourceRecord>> listResources() async {
    listCalls++;
    return [record];
  }

  @override
  Future<ResourceRecord?> getResource(String id) async {
    readCalls++;
    return id == record.id ? record : null;
  }

  @override
  List<ResourceAction> actionsFor(ResourceRecord record) {
    actionCatalogCalls++;
    return const [ResourceAction(id: 'example', label: 'Example')];
  }

  @override
  Future<void> execute(String actionId, ResourceRecord record) async {
    commandCalls++;
  }
}

class _OtherView extends ChangeNotifier implements ApplicationView {
  void change() => notifyListeners();
}

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _pane =>
    _key('settings-control:${CommonSettings.panePreference.id}');

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

_Session _session(WidgetTester tester, {bool ownsService = false}) {
  final session = _Session(ownsService: ownsService);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    for (var i = 0; i < session.storage.reads.length; i++) {
      if (!session.storage.reads[i].isCompleted) {
        session.storage.reads[i].succeed(null);
      }
    }
    for (var i = 0; i < session.storage.writes.length; i++) {
      if (!session.storage.writes[i].isCompleted) {
        session.storage.writes[i].succeed();
      }
    }
    await _flush(tester);
  });
  return session;
}

Future<void> _host(
  WidgetTester tester,
  _Launch launch,
  GlobalKey<NavigatorState> navigator,
  _Routes routes, {
  TargetPlatform platform = TargetPlatform.android,
}) => tester.pumpWidget(
  MaterialApp(
    navigatorKey: navigator,
    navigatorObservers: [routes],
    theme: ThemeData(platform: platform),
    home: Scaffold(body: Builder(builder: launch.button)),
  ),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _flush(tester);
}

Future<void> _open(WidgetTester tester) async {
  await _tap(tester, _key('open-settings'));
  await tester.pumpAndSettle(); // Only bounded route transitions.
}

Future<void> _choose(WidgetTester tester, int index) async {
  await _tap(tester, _pane);
  await tester.pumpAndSettle();
  await _tap(
    tester,
    _key('settings-choice:${CommonSettings.panePreference.id}:$index'),
  );
  await tester.pumpAndSettle(); // Only bounded dialog dismissal.
}

Future<void> _reset(WidgetTester tester) async {
  await _tap(tester, _key('settings-reset'));
  await tester.pumpAndSettle();
  await _tap(tester, _key('settings-reset-confirm'));
  await tester.pumpAndSettle();
}

void _style(SettingsPresentation style, Route<dynamic> route) {
  final shell = find.byType(SettingsShell);
  expect(shell, findsOneWidget);
  if (style == SettingsPresentation.material) {
    expect(route, isA<MaterialPageRoute<void>>());
    expect(
      find.descendant(of: shell, matching: find.byType(Scaffold)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: shell, matching: find.byType(AppBar)),
      findsOneWidget,
    );
  } else {
    expect(route, isA<CupertinoPageRoute<void>>());
    expect(
      find.descendant(of: shell, matching: find.byType(CupertinoPageScaffold)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: shell, matching: find.byType(CupertinoNavigationBar)),
      findsOneWidget,
    );
  }
}

void main() {
  for (final style in [
    SettingsPresentation.material,
    SettingsPresentation.cupertino,
  ]) {
    group('${style.name} Settings route and application ownership', () {
      testWidgets('N01 matching route completion borrows without implicit I/O', (
        tester,
      ) async {
        // Given a caller-owned unloaded View and a native route launch action.
        final session = _session(tester);
        final launch = _Launch(session.view, style);
        final navigator = GlobalKey<NavigatorState>();
        final routes = _Routes();
        await _host(tester, launch, navigator, routes);

        // When the helper opens Settings and captures its route completion Future.
        await _open(tester);

        // Then route/shell visuals match and mounting neither loads nor owns it.
        _style(style, routes.pushed.last);
        expect(
          tester.widget<SettingsShell>(find.byType(SettingsShell)).view,
          same(session.view),
        );
        expect(session.storage.readCount, 0);
        expect(session.storage.writeCount, 0);
        expect(session.view.disposeCalls, 0);
        expect(session.controller.disposeCalls, 0);
        expect(launch.completed, 0);

        // When the nearest Navigator pops the Settings route.
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        await launch.completion;

        // Then completion signals pop, leaving the borrowed authority active.
        expect(launch.completed, 1);
        expect(session.view.attached, 1);
        expect(session.view.detached, 1);
        expect(session.view.disposeCalls, 0);
        expect(session.controller.disposeCalls, 0);
        session.view.setValue(
          CommonSettings.panePreference.id,
          SettingsPanePreference.preferSinglePane,
        );
        expect(session.view.snapshot.revision, 1);
      });

      testWidgets(
        'N03 pop and reopen retain View values and captured capabilities',
        (tester) async {
          // Given composition's explicit load and a capability-bearing route input.
          final session = _session(tester);
          final loaded = session.view.load();
          session.storage.reads[0].succeed(null);
          await loaded;
          final capabilities = SettingsCapabilities(supported: {'hinge'});
          final launch = _Launch(
            session.view,
            style,
            capabilities: capabilities,
          );
          final navigator = GlobalKey<NavigatorState>();
          final routes = _Routes();
          await _host(tester, launch, navigator, routes);
          await _open(tester);

          // When inputs change outside the route, then edit/pop/reopen use one View.
          launch.capabilities = SettingsCapabilities();
          await _flush(tester);
          expect(
            tester
                .widget<SettingsShell>(find.byType(SettingsShell))
                .capabilities,
            same(capabilities),
          );
          await _choose(tester, 2);
          final snapshot = session.view.snapshot;
          expect(find.text('Unsaved changes'), findsOneWidget);
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
          await launch.completion;
          expect(session.view.snapshot.unsavedIds, isNotEmpty);
          await _open(tester);

          // Then values/adapter/service identities persist without a duplicate read.
          expect(session.view.snapshot, same(snapshot));
          expect(
            session.view.value(CommonSettings.panePreference),
            SettingsPanePreference.preferDualPane,
          );
          expect(session.view.service, same(session.controller));
          expect(session.storage.readCount, 1);
          expect(session.storage.writeCount, 1);
          expect(find.text('Prefer dual pane'), findsOneWidget);
          expect(
            find.textContaining('Unavailable in this environment'),
            findsOneWidget,
          );
          session.storage.writes[0].succeed();
          await _flush(tester);
          expect(find.text('Changes saved'), findsOneWidget);
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
          expect(session.view.attached, 2);
          expect(session.view.detached, 2);
          expect(session.view.disposeCalls, 0);
        },
      );

      testWidgets(
        'N04 nearest nested Navigator owns shell and both native modals',
        (tester) async {
          // Given unrelated root routes and an independently nested Navigator.
          final session = _session(tester);
          final launch = _Launch(session.view, style);
          final rootKey = GlobalKey<NavigatorState>();
          final innerKey = GlobalKey<NavigatorState>();
          final root = _Routes();
          final inner = _Routes();
          final unrelated = MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Unrelated root route')),
          );
          final host = MaterialPageRoute<void>(
            builder: (_) => Navigator(
              key: innerKey,
              observers: [inner],
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => Scaffold(body: launch.button(context)),
              ),
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: rootKey,
              navigatorObservers: [root],
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const SizedBox.shrink(),
              ),
              onGenerateInitialRoutes: (_) => [unrelated, host],
            ),
          );
          await tester.pumpAndSettle();
          final rootPushes = root.pushed.length;

          // When the helper opens Settings, chooses a value and confirms reset.
          await _open(tester);
          _style(style, inner.pushed.last);
          await _choose(tester, 1);
          await _reset(tester);

          // Then shell/chooser/reset pushes and modal pops affect only the inner stack.
          expect(root.pushed.length, rootPushes);
          expect(root.popped, isEmpty);
          expect(root.removed, isEmpty);
          expect(root.pushed, containsAll([unrelated, host]));
          expect(inner.pushed.length, 4); // Initial page, shell, choice, reset.
          expect(inner.popped.length, 2);
          expect(
            inner.pushed[2],
            style == SettingsPresentation.material
                ? isA<DialogRoute<Object>>()
                : isA<CupertinoModalPopupRoute<Object>>(),
          );
          expect(
            inner.pushed[3],
            style == SettingsPresentation.material
                ? isA<DialogRoute<bool>>()
                : isA<CupertinoDialogRoute<bool>>(),
          );
          expect(session.view.snapshot.revision, 2);
          expect(
            session.view.snapshot.lastIntent!.kind,
            SettingsIntentKind.resetCommon,
          );
          innerKey.currentState!.pop();
          await tester.pumpAndSettle();
          expect(launch.completed, 1);
          expect(root.popped, isEmpty);
          expect(session.view.attached, session.view.detached);
        },
      );

      testWidgets(
        'N05 Settings interaction preserves the loaded application space',
        (tester) async {
          // Given actual loaded collection/detail Views and arbitrary other views.
          final session = _session(tester);
          final resources = _Resources();
          final collection = ResourceCollectionView(dataSource: resources);
          final detail = ResourceDetailView(
            dataSource: resources,
            actionHandler: resources,
          );
          final other = _OtherView();
          final model = ApplicationViewModel({
            'settings': session.view,
            'resources': collection,
            'detail': detail,
            'other': other,
          });
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
          });
          await collection.load();
          await detail.select('one');
          final loadedResources = collection.resources;
          final selectedResource = detail.resource;
          final loaded = session.view.load();
          session.storage.reads[0].succeed(null);
          await loaded;
          var notifications = 0;
          model.addListener(() => notifications++);
          final launch = _Launch(model.view<SettingsView>('settings'), style);
          final navigator = GlobalKey<NavigatorState>();
          final routes = _Routes();
          await _host(tester, launch, navigator, routes);

          // When Settings opens/edits/resets/pops and another View still notifies.
          await _open(tester);
          await _choose(tester, 2);
          session.storage.writes[0].succeed();
          await _flush(tester);
          await _reset(tester);
          session.storage.writes[1].succeed();
          await _flush(tester);
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
          final beforeOther = notifications;
          other.change();

          // Then identities/selection survive, notifications flow, no domain action runs.
          expect(
            model.view<ResourceCollectionView>('resources'),
            same(collection),
          );
          expect(model.view<ResourceDetailView>('detail'), same(detail));
          expect(model.view<SettingsView>('settings'), same(session.view));
          expect(collection.resources, same(loadedResources));
          expect(detail.resource, same(selectedResource));
          expect(detail.selectedId, 'one');
          expect(resources.listCalls, 1);
          expect(resources.readCalls, 1);
          expect(resources.actionCatalogCalls, 0);
          expect(resources.commandCalls, 0);
          expect(beforeOther, greaterThan(0));
          expect(notifications, beforeOther + 1);
          expect(session.view.snapshot.revision, 2);
          expect(session.view.disposeCalls, 0);
        },
      );

      testWidgets(
        'N06 owners dispose after pop and borrowed services remain usable',
        (tester) async {
          // Given both legal View ownership modes backed by real controllers.
          for (final owned in [false, true]) {
            final session = _session(tester, ownsService: owned);
            final launch = _Launch(session.view, style);
            final navigator = GlobalKey<NavigatorState>();
            final routes = _Routes();
            await _host(tester, launch, navigator, routes);

            // When a borrowed Settings route opens/pops before its owner disposes.
            await _open(tester);
            navigator.currentState!.pop();
            await tester.pumpAndSettle();
            expect(session.view.disposeCalls, 0);
            expect(session.controller.disposeCalls, 0);
            expect(session.view.attached, 1);
            expect(session.view.detached, 1);
            session.view.dispose();
            session.view.dispose();

            // Then View ownership detaches once; only an owned service is disposed.
            expect(session.view.disposeCalls, 1);
            expect(session.controller.attached, 1);
            expect(session.controller.detached, 1);
            expect(session.controller.disposeCalls, owned ? 1 : 0);
            if (!owned) {
              session.controller.setValue(
                CommonSettings.panePreference.id,
                SettingsPanePreference.preferSinglePane,
              );
              final loaded = session.controller.load();
              session.storage.reads[0].succeed(null);
              await loaded;
              await _flush(tester);
              session.storage.writes[0].succeed();
              await _flush(tester);
              expect(session.controller.snapshot.savedRevision, 1);
              expect(session.controller.snapshot.hasUnsavedChanges, isFalse);
            }
            await tester.pumpWidget(const SizedBox.shrink());
          }
        },
      );

      testWidgets(
        'N07 back/removal detach and pending modal results stay stale',
        (tester) async {
          // Given a borrowed route with no settings intent or storage activity.
          final session = _session(tester);
          final launch = _Launch(session.view, style);
          final navigator = GlobalKey<NavigatorState>();
          final routes = _Routes();
          await _host(tester, launch, navigator, routes);

          // When normal back first closes the shell, then removal outlives each modal.
          await _open(tester);
          await navigator.currentState!.maybePop();
          await tester.pumpAndSettle();
          expect(session.view.attached, session.view.detached);
          for (final reset in [false, true]) {
            await _open(tester);
            final settingsRoute = routes.pushed.last;
            await _tap(tester, reset ? _key('settings-reset') : _pane);
            await tester.pumpAndSettle();
            navigator.currentState!.removeRoute(settingsRoute);
            await tester.pumpAndSettle();
            expect(session.view.attached, session.view.detached);
            if (reset) {
              await _tap(tester, _key('settings-reset-confirm'));
            } else {
              await _tap(
                tester,
                _key('settings-choice:${CommonSettings.panePreference.id}:2'),
              );
            }
            await tester.pumpAndSettle();
            await launch.completion;

            // Then a successful stale modal result edits neither View nor storage.
            expect(session.view.snapshot.revision, 0);
            expect(session.view.snapshot.lastIntent, isNull);
            expect(tester.takeException(), isNull);
            expect(find.byType(SettingsShell), findsNothing);
            expect(session.view.attached, session.view.detached);
          }
          expect(launch.completed, 3);
          expect(session.storage.readCount, 0);
          expect(session.storage.writeCount, 0);
          expect(session.view.disposeCalls, 0);
        },
      );
    });
  }

  group('N02 adaptive mapping and explicit visual-only overrides', () {
    final scenarios = [
      (
        name: 'adaptive iOS',
        platform: TargetPlatform.iOS,
        input: SettingsPresentation.adaptive,
        expected: SettingsPresentation.cupertino,
        cupertinoApp: false,
      ),
      (
        name: 'adaptive Android',
        platform: TargetPlatform.android,
        input: SettingsPresentation.adaptive,
        expected: SettingsPresentation.material,
        cupertinoApp: false,
      ),
      (
        name: 'explicit Material on iOS',
        platform: TargetPlatform.iOS,
        input: SettingsPresentation.material,
        expected: SettingsPresentation.material,
        cupertinoApp: false,
      ),
      (
        name: 'explicit Cupertino on Android',
        platform: TargetPlatform.android,
        input: SettingsPresentation.cupertino,
        expected: SettingsPresentation.cupertino,
        cupertinoApp: false,
      ),
      (
        name: 'CupertinoApp without a Material ancestor',
        platform: TargetPlatform.iOS,
        input: SettingsPresentation.adaptive,
        expected: SettingsPresentation.cupertino,
        cupertinoApp: true,
      ),
    ];
    for (final scenario in scenarios) {
      testWidgets(scenario.name, (tester) async {
        try {
          // Given an ambient platform or CupertinoApp with a caller-owned View.
          final session = _session(tester);
          final launch = _Launch(session.view, scenario.input);
          final navigator = GlobalKey<NavigatorState>();
          final routes = _Routes();
          if (scenario.cupertinoApp) {
            debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
            await tester.pumpWidget(
              CupertinoApp(
                navigatorKey: navigator,
                navigatorObservers: [routes],
                home: CupertinoPageScaffold(
                  child: Builder(
                    builder: (context) =>
                        launch.button(context, cupertino: true),
                  ),
                ),
              ),
            );
          } else {
            await _host(
              tester,
              launch,
              navigator,
              routes,
              platform: scenario.platform,
            );
          }

          // When helper navigation resolves and opens a route in that environment.
          await _open(tester);

          // Then native route and shell agree without preference/schema/I/O effects.
          _style(scenario.expected, routes.pushed.last);
          final shell = tester.widget<SettingsShell>(
            find.byType(SettingsShell),
          );
          expect(shell.presentation, scenario.expected);
          expect(shell.view, same(session.view));
          expect(session.view.snapshot.revision, 0);
          expect(session.storage.readCount, 0);
          expect(session.storage.writeCount, 0);
          if (scenario.cupertinoApp) {
            expect(find.byType(Material), findsNothing);
            await _choose(tester, 1);
            await _reset(tester);
            expect(session.view.snapshot.revision, 2);
            expect(tester.takeException(), isNull);
          }
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
          expect(session.view.disposeCalls, 0);
          expect(session.view.attached, session.view.detached);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  });
}
