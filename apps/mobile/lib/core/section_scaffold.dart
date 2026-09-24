import 'package:flutter/material.dart';

import 'disclaimer.dart';

class SectionScaffold extends StatelessWidget {
  const SectionScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showDisclaimer = false,
  });

  final String title;
  final Widget child;
  final bool showDisclaimer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (showDisclaimer) ...[
            const DisclaimerBanner(),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
