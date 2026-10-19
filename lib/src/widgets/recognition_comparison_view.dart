import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'application_text_scaling.dart';

/// Pure presentation of saved original identity and every verbatim raw stage.
/// Shared attempts remain identifiable; row durations include shared work.
class RecognitionComparisonView extends StatelessWidget {
  const RecognitionComparisonView({required this.comparison, super.key});

  final RecognitionComparison comparison;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final run in comparison.runs) {
      for (final attempt in run.attempts) {
        counts.update(attempt.id, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final material = comparison.material;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Original: ${material.id}'),
        Text('Media: ${material.mediaType}; ${material.byteLength} bytes'),
        Text('Captured: ${material.capturedAt.toIso8601String()}'),
        Text('Original name: ${material.originalName ?? "none"}'),
        Text('Original metadata: ${jsonEncode(material.extensions)}'),
        Text('Comparison: ${comparison.id}'),
        Text('Created: ${comparison.createdAt.toIso8601String()}'),
        for (final run in comparison.runs)
          Card(
            key: ValueKey('recognition-run-${run.desiredConfigurationId}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Desired: ${run.desiredConfigurationId}'),
                  Text('Actual: ${run.actualConfigurationId ?? "unavailable"}'),
                  Text('Status: ${run.status.name}'),
                  Text('Fallback reason: ${run.fallbackReason ?? "none"}'),
                  Text('Actual providers: ${jsonEncode(run.actualProviderIds)}'),
                  Text('Row elapsed: ${run.elapsed.inMilliseconds} ms (includes shared work)'),
                  for (final attempt in run.attempts)
                    _attempt(attempt, shared: counts[attempt.id]! > 1),
                ],
              ),
            ),
          ),
        ExpansionTile(
          title: const Text('Provenance details'),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(jsonEncode(comparison.extensions)),
            ),
          ],
        ),
      ],
    );
    final scaler = ApplicationTextScaling.maybeTextScalerOf(context);
    return scaler == null ? content : MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: content,
    );
  }

  Widget _attempt(RecognitionProviderAttempt attempt, {required bool shared}) {
    final result = attempt.result;
    final availability = attempt.availability;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Attempt: ${attempt.id}${shared ? " — shared work" : ""}'),
          Text('Provider: ${attempt.providerId}; ${attempt.executed ? "executed" : "nonexecuted"}'),
          Text('Attempt original: ${attempt.materialId}'),
          Text('Started: ${attempt.startedAt.toIso8601String()}'),
          Text('Availability: ${availability.state.name}'),
          Text('Capabilities: ${jsonEncode(availability.capabilities.map((item) => item.name).toList())}'),
          Text('Model: ${availability.modelName ?? "none"}'),
          Text('Reason: ${availability.reason ?? "none"}'),
          Text('Attempt elapsed: ${attempt.elapsed.inMilliseconds} ms'),
          Text('Input attempt IDs: ${jsonEncode(attempt.inputAttemptIds)}'),
          Text('OCR completed: ${result.text != null}'),
          if (result.text != null) Text('OCR: ${jsonEncode(result.text)}'),
          Text('Barcode completed: ${result.barcodeCompleted}'),
          for (var index = 0; index < result.barcodes.length; index++)
            Text('Barcode $index: ${jsonEncode(result.barcodes[index].value)}; format ${jsonEncode(result.barcodes[index].format)}'),
          Text('Interpretation completed: ${result.interpretation != null}'),
          if (result.interpretation != null)
            Text('Interpretation: ${jsonEncode(result.interpretation)}'),
          Text('Candidate organization completed: ${result.candidateOrganizationCompleted}'),
          Text('Candidate count: ${result.candidates.length}'),
          for (var index = 0; index < result.candidates.length; index++)
            Text('Candidate $index: kind ${jsonEncode(result.candidates[index].kind)}; value ${jsonEncode(result.candidates[index].value)}'),
          for (final failure in result.failures)
            Text('Failure: ${failure.stage.name} / ${failure.code} / ${failure.message}'),
        ],
      ),
    );
  }
}
