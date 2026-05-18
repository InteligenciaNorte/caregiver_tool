import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Persistent helpline card pinned on every step of a MEDIUM-classified
/// session (architecture.md §Safety: "a prominent in-screen card showing
/// helpline info pinned on every step ... a UI reminder only"). The
/// session runs normally; the model is unaware this is shown.
///
/// The call resources, button labels, and Semantics are reused verbatim
/// from the crisis screen (lead-owned, approved copy — not reworded here,
/// Hard Rule #6). Only [_framingLine] is new copy for this card.
///
/// ⚠️ NEW COPY for project-lead review: `_framingLine`. Tone aimed to
/// match feedback_copy_tone (short, warm, non-clinical, non-alarmist —
/// the session is running normally, this is a calm offer, not a stop).
const _framingLine =
    "If any of this is too heavy to hold alone, someone is here for you.";

class HelplineCard extends StatelessWidget {
  const HelplineCard({super.key});

  Future<void> _call(String number) async {
    await launchUrl(
      Uri(scheme: 'tel', path: number),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _framingLine,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: 'Call 988, U S Suicide and Crisis Lifeline',
            child: FilledButton(
              onPressed: () => _call('988'),
              child: const Text('Call 988 (US Suicide & Crisis Lifeline)'),
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: "Call Alzheimer's Association, 1-800-272-3900",
            child: OutlinedButton(
              onPressed: () => _call('18002723900'),
              child:
                  const Text("Call Alzheimer's Association: 1-800-272-3900"),
            ),
          ),
        ],
      ),
    );
  }
}
