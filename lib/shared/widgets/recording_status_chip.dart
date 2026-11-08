import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/recording/domain/recording_state.dart';

class RecordingStatusChip extends StatelessWidget {
  const RecordingStatusChip({super.key, required this.state});

  final RecordingState state;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (state) {
      RecordingState.idle => (
        'Ready',
        Theme.of(context).colorScheme.outline,
        Icons.mic_none,
      ),
      RecordingState.requestingPermission => (
        'Permission',
        AppColors.warning,
        Icons.lock_outline,
      ),
      RecordingState.starting => (
        'Starting',
        AppColors.warning,
        Icons.hourglass_top,
      ),
      RecordingState.recording => (
        'Recording',
        AppColors.recording,
        Icons.fiber_manual_record,
      ),
      RecordingState.paused => (
        'Paused',
        AppColors.warning,
        Icons.pause_circle_outline,
      ),
      RecordingState.stopping => ('Processing', AppColors.warning, Icons.sync),
      RecordingState.saving => (
        'Saving',
        AppColors.warning,
        Icons.cloud_upload_outlined,
      ),
      RecordingState.completed => (
        'Saved',
        AppColors.success,
        Icons.check_circle_outline,
      ),
      RecordingState.error => (
        'Needs attention',
        AppColors.recording,
        Icons.error_outline,
      ),
    };

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      backgroundColor: color.withValues(alpha: 0.11),
      side: BorderSide.none,
    );
  }
}
