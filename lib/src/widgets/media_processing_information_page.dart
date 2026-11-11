import 'package:flutter/material.dart';

import 'application_text_scaling.dart';
import 'application_text_toolbar.dart';

/// Passive, caller-supplied information with borrowed application text scaling.
class MediaProcessingInformationPage extends StatelessWidget {
  const MediaProcessingInformationPage({
    required this.title,
    required this.sections,
    super.key,
  });

  final String title;
  final List<({String heading, String description})> sections;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: ApplicationTextScaling.maybeTextScalerOf(context) == null
          ? AppBar(title: Text(title))
          : applicationTextAppBar(
              context,
              title: title,
              width: MediaQuery.sizeOf(context).width,
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < sections.length; index++) ...[
                if (index > 0) const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    sections[index].heading,
                    style: textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Text(sections[index].description, style: textTheme.bodyLarge),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
