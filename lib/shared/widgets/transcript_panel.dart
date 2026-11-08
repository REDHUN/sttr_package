import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/section_card.dart';

class TranscriptPanel extends StatelessWidget {
  const TranscriptPanel({
    super.key,
    required this.transcript,
    this.isFinal = false,
    this.controller,
    this.onCopy,
    this.onShare,
    this.minHeight = 190,
  });

  final String transcript;
  final bool isFinal;
  final ScrollController? controller;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final body = transcript.trim().isEmpty
        ? 'Your words will appear here as you speak.'
        : transcript;
    final isPlaceholder = transcript.trim().isEmpty;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notes_rounded,
                size: 20,
                color: AppColors.indigo,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live transcript${isFinal ? ' · final snapshot' : ''}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onCopy != null)
                IconButton(
                  onPressed: transcript.trim().isEmpty ? null : onCopy,
                  tooltip: 'Copy transcript',
                  icon: const Icon(Icons.copy_outlined),
                ),
              if (onShare != null)
                IconButton(
                  onPressed: transcript.trim().isEmpty ? null : onShare,
                  tooltip: 'Share transcript',
                  icon: const Icon(Icons.ios_share_outlined),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight, maxHeight: 320),
            child: Scrollbar(
              controller: controller,
              child: SingleChildScrollView(
                controller: controller,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SelectableText(
                    body,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.55,
                      color: isPlaceholder
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
