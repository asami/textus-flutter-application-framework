import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

void main() {
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
