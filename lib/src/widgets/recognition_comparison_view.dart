import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'application_text_scaling.dart';

String _statusLabel(RecognitionRunStatus status) => switch (status) {
  RecognitionRunStatus.completed => '完了',
  RecognitionRunStatus.partial => '一部完了',
  RecognitionRunStatus.failed => '失敗',
  RecognitionRunStatus.unavailable => '利用不可',
};

String _stageLabel(ImageRecognitionStage stage) => switch (stage) {
  ImageRecognitionStage.text => '文字認識',
  ImageRecognitionStage.barcode => 'バーコード認識',
  ImageRecognitionStage.interpretation => '画像の解釈',
  ImageRecognitionStage.provider => '認識処理',
  ImageRecognitionStage.availability => '利用可否',
  ImageRecognitionStage.cleanup => '後処理',
};

String _providerStateLabel(RecognitionProviderState state) => switch (state) {
  RecognitionProviderState.available => '利用可能',
  RecognitionProviderState.unavailable => '利用不可',
  RecognitionProviderState.downloadable => 'ダウンロード可能',
  RecognitionProviderState.preparing => '準備中',
};

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
        Text('原画像ID: ${material.id}'),
        Text('メディア形式: ${material.mediaType}; ${material.byteLength} バイト'),
        Text('撮影日時: ${material.capturedAt.toIso8601String()}'),
        Text('原画像名: ${material.originalName ?? "なし"}'),
        Text('原画像のメタデータ: ${jsonEncode(material.extensions)}'),
        Text('比較ID: ${comparison.id}'),
        Text('作成日時: ${comparison.createdAt.toIso8601String()}'),
        for (final run in comparison.runs)
          Card(
            key: ValueKey('recognition-run-${run.desiredConfigurationId}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('希望する構成: ${run.desiredConfigurationId}'),
                  Text('実際の構成: ${run.actualConfigurationId ?? "利用不可"}'),
                  Text('処理状態: ${_statusLabel(run.status)}'),
                  Text('標準処理への切替理由: ${run.fallbackReason ?? "なし"}'),
                  Text('実際の認識処理ID: ${jsonEncode(run.actualProviderIds)}'),
                  Text('構成の処理時間: ${run.elapsed.inMilliseconds} ms（共通処理を含む）'),
                  for (final attempt in run.attempts)
                    _attempt(attempt, shared: counts[attempt.id]! > 1),
                ],
              ),
            ),
          ),
        ExpansionTile(
          title: const Text('出典の詳細'),
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
    return scaler == null
        ? content
        : MediaQuery(
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
          Text('試行ID: ${attempt.id}${shared ? " — 共通処理" : ""}'),
          Text(
            '認識処理: ${attempt.providerId}; ${attempt.executed ? "実行済み" : "未実行"}',
          ),
          Text('試行の原画像ID: ${attempt.materialId}'),
          Text('開始日時: ${attempt.startedAt.toIso8601String()}'),
          Text('利用状態: ${_providerStateLabel(availability.state)}'),
          Text(
            '対応機能ID: ${jsonEncode(availability.capabilities.map((item) => item.name).toList())}',
          ),
          Text('利用モデル: ${availability.modelName ?? "なし"}'),
          Text('理由: ${availability.reason ?? "なし"}'),
          Text('試行の処理時間: ${attempt.elapsed.inMilliseconds} ms'),
          Text('入力の試行ID: ${jsonEncode(attempt.inputAttemptIds)}'),
          Text('文字認識: ${result.text != null ? "完了" : "未完了"}'),
          if (result.text != null) Text('OCR: ${jsonEncode(result.text)}'),
          Text('バーコード認識: ${result.barcodeCompleted ? "完了" : "未完了"}'),
          for (var index = 0; index < result.barcodes.length; index++)
            Text(
              'バーコード $index: ${jsonEncode(result.barcodes[index].value)}; 形式 ${jsonEncode(result.barcodes[index].format)}',
            ),
          Text('画像の解釈: ${result.interpretation != null ? "完了" : "未完了"}'),
          if (result.interpretation != null)
            Text('画像の解釈結果: ${jsonEncode(result.interpretation)}'),
          Text(
            '候補の整理: ${result.candidateOrganizationCompleted ? "完了" : "未完了"}',
          ),
          Text('候補数: ${result.candidates.length}'),
          for (var index = 0; index < result.candidates.length; index++)
            Text(
              '候補 $index: 種類 ${jsonEncode(result.candidates[index].kind)}; 値 ${jsonEncode(result.candidates[index].value)}',
            ),
          for (final failure in result.failures)
            Text(
              '失敗: ${_stageLabel(failure.stage)} (${failure.stage.name}) / ${failure.code} / ${failure.message}',
            ),
        ],
      ),
    );
  }
}
