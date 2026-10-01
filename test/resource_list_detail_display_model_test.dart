import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

void main() {
  group('Common settings presentation resolution', () {
    test('D01 defaults respect eligibility and selected sequential intent', () {
      // Given every common pane default and a notification observer.
      final model = ResourceListDetailDisplayModel();
      addTearDown(model.dispose);
      var notifications = 0;
      model.addListener(() => notifications++);
      for (final pane in SettingsPanePreference.values) {
        model.applySettingsPreferences(panePreference: pane);
        model.showList();
        final before = notifications;

        // When all eligibility and selection combinations are resolved purely.
        for (final capable in [false, true]) {
          for (final selected in [false, true]) {
            final result = model.resolve(
              splitCapable: capable,
              hasSelection: selected,
            );

            // Then only eligible automatic/dual defaults split without intent.
            expect(
              result,
              capable && pane != SettingsPanePreference.preferSinglePane
                  ? ResourceListDetailPresentation.split
                  : ResourceListDetailPresentation.compactList,
            );
          }
        }
        expect(notifications, before);

        // When detail navigation is requested and each layout is resolved purely.
        model.openDetail();
        final afterOpen = notifications;
        for (final capable in [false, true]) {
          for (final selected in [false, true]) {
            // Then eligible defaults split; otherwise only selected detail opens.
            expect(
              model.resolve(splitCapable: capable, hasSelection: selected),
              capable && pane != SettingsPanePreference.preferSinglePane
                  ? ResourceListDetailPresentation.split
                  : selected
                  ? ResourceListDetailPresentation.compactDetail
                  : ResourceListDetailPresentation.compactList,
            );
          }
        }
        expect(notifications, afterOpen);
        expect(model.preferenceOverride, isNull);
      }
    });

    test(
      'D02 explicit choices survive sizing and invalid focus falls back',
      () {
        // Given a single-pane default with ordinary sequential navigation.
        final model = ResourceListDetailDisplayModel()
          ..applySettingsPreferences(
            panePreference: SettingsPanePreference.preferSinglePane,
          );
        addTearDown(model.dispose);

        // When navigation, explicit split and explicit focus encounter space changes.
        model.openDetail();
        model.showList();
        final navigationOverride = model.preferenceOverride;
        model.restoreSplit();
        final split = model.resolve(splitCapable: true, hasSelection: false);
        final smallSplit = model.resolve(
          splitCapable: false,
          hasSelection: false,
        );
        final restoredSplit = model.resolve(
          splitCapable: true,
          hasSelection: false,
        );
        model.focusDetail();
        final smallFocus = model.resolve(
          splitCapable: false,
          hasSelection: true,
        );
        final restoredFocus = model.resolve(
          splitCapable: true,
          hasSelection: true,
        );
        final absent = model.resolve(splitCapable: true, hasSelection: false);
        final disabled = model.resolve(
          splitCapable: true,
          hasSelection: true,
          allowDetailFocus: false,
        );

        // Then session choices persist while invalid focus uses the common default.
        expect(navigationOverride, isNull);
        expect(split, ResourceListDetailPresentation.split);
        expect(smallSplit, ResourceListDetailPresentation.compactList);
        expect(restoredSplit, ResourceListDetailPresentation.split);
        expect(smallFocus, ResourceListDetailPresentation.compactDetail);
        expect(restoredFocus, ResourceListDetailPresentation.detailFocused);
        expect(absent, ResourceListDetailPresentation.compactList);
        expect(disabled, ResourceListDetailPresentation.compactDetail);
        expect(
          model.preferenceOverride,
          ResourceListDetailDisplayPreference.detailFocused,
        );
      },
    );

    test(
      'D03 hinge precedence retains choices through unavailable capability',
      () {
        // Given an inherited hinge preference with a caller configuration fallback.
        final model = ResourceListDetailDisplayModel();
        addTearDown(model.dispose);
        ResourceListDetailHingePolicy resolve(bool gap) =>
            model.resolveHingePolicy(
              hasOcclusion: gap,
              defaultPolicy: ResourceListDetailHingePolicy.span,
            );

        // When explicit global automatic and session choices meet capability loss.
        final inherited = resolve(true);
        model.applySettingsPreferences(
          panePreference: SettingsPanePreference.preferDualPane,
          hingePreference: ResourceListDetailHingePolicy.automatic,
        );
        final automaticGap = resolve(true);
        final automaticCrease = resolve(false);
        model.setHingePolicy(ResourceListDetailHingePolicy.span);
        final session = resolve(true);
        model.applySettingsPreferences(
          panePreference: SettingsPanePreference.preferDualPane,
          hingePreference: ResourceListDetailHingePolicy.avoid,
          hingeApplicable: false,
        );
        final unavailableGap = resolve(true);
        final unavailableCrease = resolve(false);
        model.applySettingsPreferences(
          panePreference: SettingsPanePreference.preferDualPane,
          hingePreference: ResourceListDetailHingePolicy.avoid,
        );
        final returnedSession = resolve(true);
        model.applySettingsPreferences(
          panePreference: SettingsPanePreference.preferDualPane,
          hingePreference: ResourceListDetailHingePolicy.avoid,
          clearHingeOverride: true,
        );

        // Then precedence and safe fallback never promote an ineligible avoid split.
        expect(inherited, ResourceListDetailHingePolicy.span);
        expect(automaticGap, ResourceListDetailHingePolicy.avoid);
        expect(automaticCrease, ResourceListDetailHingePolicy.span);
        expect(session, ResourceListDetailHingePolicy.span);
        expect(unavailableGap, ResourceListDetailHingePolicy.avoid);
        expect(unavailableCrease, ResourceListDetailHingePolicy.span);
        expect(returnedSession, ResourceListDetailHingePolicy.span);
        expect(resolve(false), ResourceListDetailHingePolicy.avoid);
        expect(
          model.resolve(splitCapable: false, hasSelection: false),
          ResourceListDetailPresentation.compactList,
        );
      },
    );

    test('D04 atomic applies and repeated explicit setters notify once', () {
      // Given a legacy split getter without an explicit session override.
      final model = ResourceListDetailDisplayModel();
      addTearDown(model.dispose);
      var notifications = 0;
      model.addListener(() => notifications++);
      expect(model.preference, ResourceListDetailDisplayPreference.split);
      expect(model.preferenceOverride, isNull);

      // When repeated choices and independent common dimension clears are applied.
      model.restoreSplit();
      model.restoreSplit();
      expect(notifications, 1);
      model.focusDetail();
      model.focusDetail();
      model.setHingePolicy(ResourceListDetailHingePolicy.span);
      model.setHingePolicy(ResourceListDetailHingePolicy.span);
      model.applySettingsPreferences(
        panePreference: SettingsPanePreference.preferSinglePane,
        hingePreference: ResourceListDetailHingePolicy.avoid,
        clearPaneOverride: true,
      );
      final retainedHinge = model.hingePolicyOverride;
      model.applySettingsPreferences(
        panePreference: SettingsPanePreference.preferSinglePane,
        hingePreference: ResourceListDetailHingePolicy.avoid,
      );
      model.restoreSplit();
      model.applySettingsPreferences(
        panePreference: SettingsPanePreference.preferSinglePane,
        hingePreference: ResourceListDetailHingePolicy.avoid,
        clearHingeOverride: true,
      );

      // Then atomic updates notify once and keep compact intent and the other choice.
      expect(notifications, 6);
      expect(retainedHinge, ResourceListDetailHingePolicy.span);
      expect(
        model.preferenceOverride,
        ResourceListDetailDisplayPreference.split,
      );
      expect(model.hingePolicyOverride, isNull);
      expect(model.compactDetailRequested, isTrue);
    });
  });

  group('ResourceListDetailDisplayModel resolution', () {
    test('should resolve compact list until compact detail is requested', () {
      // Given the default split preference without a selected Resource.
      final model = ResourceListDetailDisplayModel();
      addTearDown(model.dispose);

      // When compact space is resolved before and after a detail request.
      final beforeSelection = model.resolve(
        splitCapable: false,
        hasSelection: false,
      );
      model.openDetail();
      final withoutSelection = model.resolve(
        splitCapable: false,
        hasSelection: false,
      );
      final withSelection = model.resolve(
        splitCapable: false,
        hasSelection: true,
      );

      // Then only a selected requested detail occupies compact space.
      expect(beforeSelection, ResourceListDetailPresentation.compactList);
      expect(withoutSelection, ResourceListDetailPresentation.compactList);
      expect(withSelection, ResourceListDetailPresentation.compactDetail);
      expect(model.preference, ResourceListDetailDisplayPreference.split);
    });

    test(
      'should preserve explicit focus through compact space and restore it',
      () {
        // Given a selected Resource with an explicit focused-detail preference.
        final model = ResourceListDetailDisplayModel();
        addTearDown(model.dispose);

        // When capable space shrinks and later returns.
        model.focusDetail();
        final compact = model.resolve(splitCapable: false, hasSelection: true);
        final restored = model.resolve(splitCapable: true, hasSelection: true);
        model.restoreSplit();
        final split = model.resolve(splitCapable: true, hasSelection: true);

        // Then compact detail does not erase focus and restore returns split.
        expect(compact, ResourceListDetailPresentation.compactDetail);
        expect(restored, ResourceListDetailPresentation.detailFocused);
        expect(split, ResourceListDetailPresentation.split);
      },
    );

    test(
      'should resolve split when focus is disabled or no selection exists',
      () {
        // Given an explicit focus preference in split-capable space.
        final model = ResourceListDetailDisplayModel()..focusDetail();
        addTearDown(model.dispose);

        // When focus is disabled or the selection disappears.
        final disabled = model.resolve(
          splitCapable: true,
          hasSelection: true,
          allowDetailFocus: false,
        );
        final noSelection = model.resolve(
          splitCapable: true,
          hasSelection: false,
        );

        // Then normal split presentation remains valid.
        expect(disabled, ResourceListDetailPresentation.split);
        expect(noSelection, ResourceListDetailPresentation.split);
      },
    );
  });

  group('ResourceListDetailDisplayModel state changes', () {
    test('should notify only for changed presentation-session state', () {
      // Given a display model observed by its presentation owner.
      final model = ResourceListDetailDisplayModel();
      addTearDown(model.dispose);
      var notifications = 0;
      model.addListener(() => notifications++);

      // When repeated and distinct display requests are made.
      model.openDetail();
      model.openDetail();
      model.focusDetail();
      model.restoreSplit();
      model.showList();
      model.showList();

      // Then only distinct state changes notify observers.
      expect(notifications, 4);
    });
  });

  group('ResourceListDetailDisplayModel hinge policy', () {
    test('should resolve hinge policy without changing presentation state', () {
      // Given a focused compact-intent session observed by its presentation owner.
      final model = ResourceListDetailDisplayModel()..focusDetail();
      addTearDown(model.dispose);
      var notifications = 0;
      model.addListener(() => notifications++);

      // When automatic, configured, and explicit policy values are resolved.
      expect(
        model.resolveHingePolicy(hasOcclusion: true),
        ResourceListDetailHingePolicy.avoid,
      );
      expect(
        model.resolveHingePolicy(hasOcclusion: false),
        ResourceListDetailHingePolicy.span,
      );
      expect(
        model.resolveHingePolicy(
          hasOcclusion: false,
          defaultPolicy: ResourceListDetailHingePolicy.avoid,
        ),
        ResourceListDetailHingePolicy.avoid,
      );
      model.setHingePolicy(ResourceListDetailHingePolicy.span);
      model.setHingePolicy(ResourceListDetailHingePolicy.span);

      // Then the override wins posture/configuration without changing focus intent.
      expect(
        model.resolveHingePolicy(
          hasOcclusion: true,
          defaultPolicy: ResourceListDetailHingePolicy.avoid,
        ),
        ResourceListDetailHingePolicy.span,
      );
      expect(
        model.preference,
        ResourceListDetailDisplayPreference.detailFocused,
      );
      expect(model.compactDetailRequested, isTrue);
      expect(model.hingePolicyOverride, ResourceListDetailHingePolicy.span);
      expect(notifications, 1);
    });
  });

  group('ResourceListDetailConfiguration compatibility', () {
    test('should default new hinge fields for older JSON', () {
      // Given configuration JSON created before focus and hinge capability fields.
      const json = <String, dynamic>{
        'listTitle': 'Resources',
        'detailTitle': 'Detail',
        'primaryField': 'name',
        'detailFields': [
          {'key': 'summary', 'label': 'Summary'},
        ],
      };

      // When the public configuration contract is decoded.
      final configuration = ResourceListDetailConfiguration.fromJson(json);

      // Then the existing JSON retains enabled focus and automatic hinge behavior.
      expect(configuration.allowDetailFocus, isTrue);
      expect(
        configuration.defaultHingePolicy,
        ResourceListDetailHingePolicy.automatic,
      );
      expect(configuration.allowHingePolicySwitch, isTrue);
    });

    test('should serialize every public hinge policy value', () {
      // Given every stable hinge policy value.
      const policies = ResourceListDetailHingePolicy.values;

      // When each value is encoded and decoded through the public contract.
      final restored = [
        for (final policy in policies)
          ResourceListDetailHingePolicy.fromJson(policy.toJson()),
      ];

      // Then values round-trip and unknown input is rejected.
      expect(restored, policies);
      expect(
        () => ResourceListDetailHingePolicy.fromJson('across-the-hinge'),
        throwsFormatException,
      );
    });

    test('should round-trip explicit hinge policy configuration', () {
      // Given configuration that opts into a non-default initial hinge treatment.
      const configuration = ResourceListDetailConfiguration(
        listTitle: 'Resources',
        detailTitle: 'Detail',
        primaryField: 'name',
        detailFields: [
          ResourceFieldConfiguration(key: 'summary', label: 'Summary'),
        ],
        defaultHingePolicy: ResourceListDetailHingePolicy.span,
        allowHingePolicySwitch: false,
      );

      // When it is encoded and decoded through the public configuration contract.
      final restored = ResourceListDetailConfiguration.fromJson(
        configuration.toJson(),
      );

      // Then both explicit policy choices are retained.
      expect(restored.defaultHingePolicy, ResourceListDetailHingePolicy.span);
      expect(restored.allowHingePolicySwitch, isFalse);
      expect(restored.toJson(), configuration.toJson());
    });
  });
}
