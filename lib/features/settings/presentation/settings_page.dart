import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../recording/presentation/recording_view_model.dart';
import '../../recordings/presentation/recordings_view_model.dart';
import 'settings_view_model.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    final recording = context.watch<RecordingViewModel>();
    final recordings = context.watch<RecordingsViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Text(
              'Make VoiceNote feel like yours.',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Preferences are stored locally on this device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _SettingsSection(
              title: 'Appearance',
              icon: Icons.palette_outlined,
              child: SegmentedButton<ThemePreference>(
                segments: const [
                  ButtonSegment(
                    value: ThemePreference.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemePreference.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemePreference.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                ],
                selected: <ThemePreference>{settings.theme},
                onSelectionChanged: (selection) {
                  settings.setTheme(selection.first);
                },
              ),
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Recognition language',
              icon: Icons.language_rounded,
              child: DropdownButtonFormField<String>(
                initialValue: recording.selectedLocaleId,
                decoration: const InputDecoration(
                  labelText: 'Preferred language',
                ),
                items: recording.locales
                    .map(
                      (locale) => DropdownMenuItem<String>(
                        value: locale.id,
                        child: Text('${locale.name} · ${locale.id}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: recording.canChangeLocale
                    ? (value) {
                        if (value == null) return;
                        recording.setLocale(value);
                        settings.setPreferredLocale(value);
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Storage',
              icon: Icons.storage_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${recordings.totalCount} recording${recordings.totalCount == 1 ? '' : 's'} · ${formatFileSize(recordings.totalBytes)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Audio files are copied into VoiceNote’s app-private documents storage. No broad device storage permission is used.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: recordings.totalCount == 0
                        ? null
                        : () => _clearStorage(context),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Clear all recordings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Recognition privacy',
              icon: Icons.privacy_tip_outlined,
              child: Text(
                'Speech recognition is provided by the platform recognizer. Depending on the device and provider, speech may use online services. VoiceNote does not promise offline recognition or automatic language detection.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'About',
              icon: Icons.info_outline_rounded,
              child: const Text(
                'VoiceNote records a single WAV stream while stt_record streams accumulated transcript snapshots. Android 13+ is the most reliable capture mode; older Android devices may return incomplete or empty audio.',
              ),
            ),
            if (settings.errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                settings.errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _clearStorage(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all recordings?'),
        content: const Text(
          'This permanently removes every saved audio file and transcript.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<RecordingsViewModel>().clearAll();
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.indigo),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
