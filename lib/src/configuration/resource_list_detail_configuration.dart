import 'presentation_realization.dart';
import '../view/resource_list_detail_hinge_policy.dart';

/// One visible resource property, independent of a particular Widget.
class ResourceFieldConfiguration {
  const ResourceFieldConfiguration({required this.key, required this.label});

  final String key;
  final String label;

  factory ResourceFieldConfiguration.fromJson(Map<String, dynamic> json) =>
      ResourceFieldConfiguration(
        key: json['key'] as String,
        label: json['label'] as String,
      );

  Map<String, dynamic> toJson() => {'key': key, 'label': label};
}

/// Serializable semantics for a standard Resource List + Detail presentation.
class ResourceListDetailConfiguration {
  const ResourceListDetailConfiguration({
    required this.listTitle,
    required this.detailTitle,
    required this.primaryField,
    required this.detailFields,
    this.secondaryField,
    this.compactBreakpoint = 700,
    this.minimumFoldPaneWidth = 280,
    this.minimumFoldPaneHeight = 180,
    this.allowDetailFocus = true,
    this.defaultHingePolicy = ResourceListDetailHingePolicy.automatic,
    this.allowHingePolicySwitch = true,
    this.realization = PresentationRealization.framework,
  });

  final String listTitle;
  final String detailTitle;
  final String primaryField;
  final String? secondaryField;
  final List<ResourceFieldConfiguration> detailFields;
  final double compactBreakpoint;
  final double minimumFoldPaneWidth;
  final double minimumFoldPaneHeight;
  final bool allowDetailFocus;
  final ResourceListDetailHingePolicy defaultHingePolicy;
  final bool allowHingePolicySwitch;
  final PresentationRealization realization;

  factory ResourceListDetailConfiguration.fromJson(Map<String, dynamic> json) {
    final fields = json['detailFields'] as List<dynamic>;
    final breakpoint = (json['compactBreakpoint'] as num?)?.toDouble() ?? 700;
    final minimumFoldPaneWidth =
        (json['minimumFoldPaneWidth'] as num?)?.toDouble() ?? 280;
    final minimumFoldPaneHeight =
        (json['minimumFoldPaneHeight'] as num?)?.toDouble() ?? 180;
    if (fields.isEmpty ||
        !_isFinitePositive(breakpoint) ||
        !_isFinitePositive(minimumFoldPaneWidth) ||
        !_isFinitePositive(minimumFoldPaneHeight)) {
      throw const FormatException(
        'Detail fields and finite positive layout dimensions are required',
      );
    }
    return ResourceListDetailConfiguration(
      listTitle: json['listTitle'] as String,
      detailTitle: json['detailTitle'] as String,
      primaryField: json['primaryField'] as String,
      secondaryField: json['secondaryField'] as String?,
      detailFields: List.unmodifiable(
        fields.map(
          (field) => ResourceFieldConfiguration.fromJson(
            field as Map<String, dynamic>,
          ),
        ),
      ),
      compactBreakpoint: breakpoint,
      minimumFoldPaneWidth: minimumFoldPaneWidth,
      minimumFoldPaneHeight: minimumFoldPaneHeight,
      allowDetailFocus: json['allowDetailFocus'] as bool? ?? true,
      defaultHingePolicy: ResourceListDetailHingePolicy.fromJson(
        json['defaultHingePolicy'] as String? ?? 'automatic',
      ),
      allowHingePolicySwitch: json['allowHingePolicySwitch'] as bool? ?? true,
      realization: PresentationRealization.fromJson(
        json['realization'] as String? ?? 'framework',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'listTitle': listTitle,
    'detailTitle': detailTitle,
    'primaryField': primaryField,
    if (secondaryField != null) 'secondaryField': secondaryField,
    'detailFields': detailFields.map((field) => field.toJson()).toList(),
    'compactBreakpoint': compactBreakpoint,
    'minimumFoldPaneWidth': minimumFoldPaneWidth,
    'minimumFoldPaneHeight': minimumFoldPaneHeight,
    'allowDetailFocus': allowDetailFocus,
    'defaultHingePolicy': defaultHingePolicy.toJson(),
    'allowHingePolicySwitch': allowHingePolicySwitch,
    'realization': realization.toJson(),
  };

  static bool _isFinitePositive(double value) => value.isFinite && value > 0;
}
