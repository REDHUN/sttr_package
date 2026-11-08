import '../../../core/errors/voice_note_exception.dart';

enum RecordingState {
  idle,
  requestingPermission,
  starting,
  recording,
  paused,
  stopping,
  saving,
  completed,
  error,
}

class InvalidRecordingTransitionException extends VoiceNoteException {
  InvalidRecordingTransitionException({required this.from, required this.to})
    : super(
        code: VoiceNoteErrorCode.unknown,
        message: 'Invalid recording state transition: $from → $to',
      );

  final RecordingState from;
  final RecordingState to;
}

class RecordingStateMachine {
  RecordingStateMachine([this._state = RecordingState.idle]);

  RecordingState _state;

  RecordingState get state => _state;

  bool canTransitionTo(RecordingState next) {
    if (_state == next) return true;

    final allowed = <RecordingState, Set<RecordingState>>{
      RecordingState.idle: {RecordingState.requestingPermission},
      RecordingState.requestingPermission: {
        RecordingState.starting,
        RecordingState.error,
        RecordingState.idle,
      },
      RecordingState.starting: {
        RecordingState.recording,
        RecordingState.error,
        RecordingState.idle,
      },
      RecordingState.recording: {
        RecordingState.paused,
        RecordingState.stopping,
        RecordingState.idle,
        RecordingState.error,
      },
      RecordingState.paused: {
        RecordingState.recording,
        RecordingState.stopping,
        RecordingState.idle,
        RecordingState.error,
      },
      RecordingState.stopping: {RecordingState.saving, RecordingState.error},
      RecordingState.saving: {RecordingState.completed, RecordingState.error},
      RecordingState.completed: {
        RecordingState.requestingPermission,
        RecordingState.idle,
      },
      RecordingState.error: {
        RecordingState.requestingPermission,
        RecordingState.idle,
      },
    };

    return allowed[_state]?.contains(next) ?? false;
  }

  void transitionTo(RecordingState next) {
    if (!canTransitionTo(next)) {
      throw InvalidRecordingTransitionException(from: _state, to: next);
    }
    _state = next;
  }
}
