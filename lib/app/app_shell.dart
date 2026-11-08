import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/recording/presentation/recording_page.dart';
import '../features/recording/presentation/recording_view_model.dart';
import '../features/recordings/presentation/history_page.dart';
import '../features/recordings/presentation/recordings_view_model.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/settings_view_model.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initialize());
    });
  }

  Future<void> _initialize() async {
    final settings = context.read<SettingsViewModel>();
    final recording = context.read<RecordingViewModel>();
    final recordings = context.read<RecordingsViewModel>();
    await Future.wait<void>(<Future<void>>[
      settings.initialize(),
      recording.initialize(),
      recordings.initialize(),
    ]);
    recording.applyPreferredLocale(settings.preferredLocaleId);
    if (!mounted) return;
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [RecordingPage(), HistoryPage(), SettingsPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none_rounded),
            selectedIcon: Icon(Icons.mic_rounded),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: !_initialized && _selectedIndex == 0
          ? FloatingActionButton.small(
              onPressed: null,
              tooltip: 'Loading VoiceNote',
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
    );
  }

  void _onDestinationSelected(int index) {
    final recording = context.read<RecordingViewModel>();
    if (index != 0 && recording.isActiveSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording continues. Return to Record to control it.'),
        ),
      );
      return;
    }
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }
}
