import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

class _ObservedScaler extends TextScaler {
  _ObservedScaler(this.function);
  final double Function(double) function;
  final inputs = <double>[];

  @override
  double scale(double fontSize) {
    inputs.add(fontSize);
    return function(fontSize);
  }

  @override
  double get textScaleFactor => throw StateError('Not rendering math');
}

void main() {
  group('App multiplier preserves the original OS function', () {
    for (final entry in <String, double Function(double)>{
      'default': (s) => s,
      'linear two': (s) => s * 2,
      'nonlinear': (s) => s + 0.5 * math.min(s, 16),
    }.entries) {
      for (final multiplier in [1.0, 1.15, 1.30]) {
        test(
          'TS01 ${entry.key} with $multiplier scales original sizes once',
          () {
            // Given a recorded OS function and an actual common catalog choice.
            final source = _ObservedScaler(entry.value);
            final scaler = composeApplicationTextScaler(
              systemTextScaler: source,
              multiplier: multiplier,
            );
            for (final size in [10.0, 16.0, 32.0]) {
              // When an original logical size is rendered.
              final result = scaler.scale(size);
              // Then app multiplication follows the OS function without resampling.
              expect(result, closeTo(multiplier * entry.value(size), 1e-10));
            }
            // Then the OS received exactly the original sizes, and Standard is OS.
            expect(source.inputs, [10.0, 16.0, 32.0]);
            if (multiplier == 1.0) expect(scaler, same(source));
            if (entry.key == 'nonlinear' && multiplier == 1.30) {
              // When the documented nonlinear example is evaluated.
              final example = scaler.scale(16);
              // Then 1.30 * S(16) is exactly the promised 31.2 output.
              expect(example, closeTo(31.2, 1e-10));
            }
          },
        );
      }
    }

    test('TS02 invalid multipliers reject before invoking OS math', () {
      // Given a scaler whose legacy estimate cannot drive rendering.
      final source = _ObservedScaler((s) => s + math.min(s, 16) / 2);
      for (final invalid in [
        0.0,
        -1.0,
        1.2,
        double.nan,
        double.infinity,
        -double.infinity,
      ]) {
        // When a value outside the finite catalog is composed.
        // Then it rejects without sampling the OS function.
        expect(
          () => composeApplicationTextScaler(
            systemTextScaler: source,
            multiplier: invalid,
          ),
          throwsArgumentError,
        );
        expect(source.inputs, isEmpty);
      }
    });

    test('TS02 recomposition replaces the previous app choice', () {
      // Given a nonlinear OS function already composed with Largest.
      final source = _ObservedScaler((s) => s + math.min(s, 16) / 2);
      final largest = composeApplicationTextScaler(
        systemTextScaler: source,
        multiplier: 1.30,
      );
      // When the same helper composes Larger and Standard over its own wrapper.
      final larger = composeApplicationTextScaler(
        systemTextScaler: largest,
        multiplier: 1.15,
      );
      final standard = composeApplicationTextScaler(
        systemTextScaler: larger,
        multiplier: 1.0,
      );
      // Then one OS evaluation receives the original size; Standard unwraps fully.
      expect(larger.scale(16), closeTo(1.15 * 24, 1e-10));
      expect(source.inputs, [16.0]);
      expect(standard, same(source));
      expect(standard.scale(32), 40);
      expect(source.inputs, [16.0, 32.0]);
    });
  });
}
