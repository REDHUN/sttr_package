import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:voicenote/app/voice_note_app.dart';

void main() {
  testWidgets('VoiceNote app renders the record workspace', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: buildAppProviders(),
        child: const VoiceNoteApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('VoiceNote'), findsOneWidget);
    expect(find.text('Start recording'), findsOneWidget);
    expect(find.text('Live transcript'), findsOneWidget);
  });
}
