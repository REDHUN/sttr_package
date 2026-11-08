import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../features/recordings/domain/recording.dart';

class RecordingCard extends StatelessWidget {
  const RecordingCard({
    super.key,
    required this.recording,
    required this.onTap,
  });

  final Recording recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasTranscript = recording.transcript.trim().isNotEmpty;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.paleIndigo,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: AppColors.indigo,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recording.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${formatDateTime(recording.createdAt)} · ${formatDuration(recording.duration)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      hasTranscript
                          ? recording.transcript
                          : 'No transcript text',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: hasTranscript
                            ? null
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onTap,
                tooltip: 'Open recording',
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
