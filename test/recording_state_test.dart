import 'package:flutter_test/flutter_test.dart';

import 'package:voicenote/features/recording/domain/recording_state.dart';

void main() {
  test('allows the normal recording lifecycle', () {
    final machine = RecordingStateMachine();

    machine.transitionTo(RecordingState.requestingPermission);
    machine.transitionTo(RecordingState.starting);
    machine.transitionTo(RecordingState.recording);
    machine.transitionTo(RecordingState.paused);
    machine.transitionTo(RecordingState.recording);
    machine.transitionTo(RecordingState.stopping);
    machine.transitionTo(RecordingState.saving);
    machine.transitionTo(RecordingState.completed);

    expect(machine.state, RecordingState.completed);
  });

  test('rejects invalid transitions', () {
    final machine = RecordingStateMachine();

    expect(
      () => machine.transitionTo(RecordingState.saving),
      throwsA(isA<InvalidRecordingTransitionException>()),
    );
  });

  test('allows an explicit discard back to idle', () {
    final machine = RecordingStateMachine(RecordingState.recording);

    machine.transitionTo(RecordingState.idle);

    expect(machine.state, RecordingState.idle);
  });
}
