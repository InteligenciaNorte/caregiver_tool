import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Persistent helpline affordance pinned on every step of a
/// MEDIUM-classified session (architecture.md §Safety: "a prominent
/// in-screen card ... pinned on every step ... a UI reminder only"). The
/// session runs normally; the model is unaware.
///
/// Deliberately small. Collapsed by default to a slim one-line bar so the
/// reflection (the emotional core) keeps room and it does not feel
/// surveilling; tapping expands to a single primary action (988 — the
/// crisis line most relevant to the MEDIUM cohort). It is collapsible but
/// NEVER removable: collapsed it is still a one-tap, always-present
/// support affordance. The full resource list (988 + Alzheimer's) is
/// reachable any time via the always-present "I need help right now"
/// header link on the session screen, so the card need not duplicate it.
/// Default-collapsed and the single-action reduction are project-owner
/// decisions (2026-05-18) flagged for safety-owner review.
///
/// The 988 button label + Semantics are reused verbatim from the crisis
/// screen (lead-owned, approved copy — not reworded, Hard Rule #6).
///
/// ⚠️ NEW COPY for project-lead review: `_supportLine` (the only new
/// string; used in both states). Tone aimed at feedback_copy_tone:
/// short, warm, non-clinical, non-alarmist, non-surveilling.
const _supportLine = "You don't have to carry this alone.";

class HelplineCard extends StatefulWidget {
  const HelplineCard({super.key});

  @override
  State<HelplineCard> createState() => _HelplineCardState();
}

class _HelplineCardState extends State<HelplineCard> {
  bool _expanded = false;

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
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.bottomCenter,
        child: _expanded ? _expandedView(theme, scheme) : _collapsedBar(theme),
      ),
    );
  }

  /// Slim, full-width, ≥48dp tap target. Tapping reveals the action; it
  /// never dismisses — there is no closed state, only collapsed.
  Widget _collapsedBar(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: 'Helpline. Tap to show how to get help now.',
      child: InkWell(
        key: const Key('helplineExpand'),
        onTap: () => setState(() => _expanded = true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.favorite_outline,
                  size: 20, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _supportLine,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.expand_less, color: scheme.onSecondaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _expandedView(ThemeData theme, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _supportLine,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Collapse only — not dismiss. The bar always remains.
              Semantics(
                button: true,
                label: 'Collapse helpline',
                child: InkWell(
                  key: const Key('helplineCollapse'),
                  onTap: () => setState(() => _expanded = false),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.expand_more,
                        color: scheme.onSecondaryContainer),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Call 988, U S Suicide and Crisis Lifeline',
            child: FilledButton(
              onPressed: () => _call('988'),
              child: const Text('Call 988 (US Suicide & Crisis Lifeline)'),
            ),
          ),
        ],
      ),
    );
  }
}
