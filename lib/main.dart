import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/voice_note_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(providers: buildAppProviders(), child: const VoiceNoteApp()),
  );
}
