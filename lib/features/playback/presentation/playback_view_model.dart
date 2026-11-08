import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/errors/voice_note_exception.dart';
import '../../recordings/domain/recording.dart';

class PlaybackViewModel extends ChangeNotifier {
  PlaybackViewModel({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _positionSubscription = _player.positionStream.listen((position) {
      if (_position == position) return;
      _position = position;
      notifyListeners();
    });
    _durationSubscription = _player.durationStream.listen((duration) {
      final next = duration ?? Duration.zero;
      if (_duration == next) return;
      _duration = next;
      notifyListeners();
    });
    _stateSubscription = _player.playerStateStream.listen((state) {
      final nextPlaying = state.playing;
      final nextLoading =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      if (_isPlaying == nextPlaying && _isLoading == nextLoading) return;
      _isPlaying = nextPlaying;
      _isLoading = nextLoading;
      notifyListeners();
    });
  }

  final AudioPlayer _player;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration?> _durationSubscription;
  late final StreamSubscription<PlayerState> _stateSubscription;

  String? _loadedRecordingId;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool Function()? _canPlay;

  String? get loadedRecordingId => _loadedRecordingId;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setCanPlay(bool Function() callback) {
    _canPlay = callback;
  }

  Future<void> load(Recording recording) async {
    if (_loadedRecordingId == recording.id &&
        _player.audioSource != null &&
        _errorMessage == null) {
      return;
    }

    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      final duration = await _player.setFilePath(recording.audioPath);
      _loadedRecordingId = recording.id;
      _duration = duration ?? Duration.zero;
      _position = Duration.zero;
    } on Exception catch (error) {
      _loadedRecordingId = null;
      _errorMessage = VoiceNoteException(
        code: VoiceNoteErrorCode.playbackFailed,
        message: 'Audio is not available for playback.',
        cause: error,
      ).message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> play() async {
    if (_canPlay?.call() == false) {
      _errorMessage = 'Stop recording before starting playback.';
      notifyListeners();
      return;
    }
    try {
      _errorMessage = null;
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    } on Exception catch (error) {
      _errorMessage = 'Playback could not start: $error';
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    final bounded = position < Duration.zero
        ? Duration.zero
        : position > _duration
        ? _duration
        : position;
    await _player.seek(bounded);
  }

  @override
  void dispose() {
    unawaited(_positionSubscription.cancel());
    unawaited(_durationSubscription.cancel());
    unawaited(_stateSubscription.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }
}
