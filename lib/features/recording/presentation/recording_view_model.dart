import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../../core/errors/voice_note_exception.dart';
import '../../../core/storage/audio_file_store.dart';
import '../../../core/storage/transcript_draft_store.dart';
import '../../recordings/data/recording_repository.dart';
import '../../recordings/domain/recording.dart';
import '../data/speech_capture_service.dart';
import '../domain/recording_state.dart';

class RecordingViewModel extends ChangeNotifier with WidgetsBindingObserver {
  RecordingViewModel({
    required this._captureService,
    required this._recordingsRepository,
    required this._audioFileStore,
    required this._draftStore,
    this._onBeforeRecording,
    this._onRecordingSaved,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _amplitudeSampleLimit = 48;
  static const _finalEventGracePeriod = Duration(milliseconds: 300);

  final SpeechCaptureService _captureService;
  final RecordingRepository _recordingsRepository;
  final AudioFileStore _audioFileStore;
  final TranscriptDraftStore _draftStore;
  final DateTime Function() _now;
  final Future<void> Function()? _onBeforeRecording;
  final Future<void> Function(Recording recording)? _onRecordingSaved;

  final RecordingStateMachine _stateMachine = RecordingStateMachine();

  StreamSubscription<TranscriptSnapshot>? _transcriptSubscription;
  StreamSubscription<CaptureSessionEvent>? _sessionSubscription;
  Timer? _elapsedTimer;
  Timer? _amplitudeTimer;
  Timer? _draftTimer;

  List<RecognitionLocale> _locales = const <RecognitionLocale>[];
  String? _selectedLocaleId;
  String _transcript = '';
  bool _lastTranscriptWasFinal = false;
  double _amplitude = 0;
  List<double> _amplitudeSamples = const <double>[];
  Duration _activeDuration = Duration.zero;
  Duration _elapsedOffset = Duration.zero;
  DateTime? _startedAt;
  String? _errorMessage;
  String? _lifecycleMessage;
  TranscriptDraft? _recoveredDraft;
  Recording? _lastSavedRecording;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _commandInFlight = false;
  bool _amplitudePollInFlight = false;
  bool _draftWriteInFlight = false;
  int _sessionSequence = 0;
  int? _activeSessionId;

  RecordingState get state => _stateMachine.state;
  List<RecognitionLocale> get locales =>
      List<RecognitionLocale>.unmodifiable(_locales);
  String? get selectedLocaleId => _selectedLocaleId;
  String get transcript => _transcript;
  bool get transcriptIsFinal => _lastTranscriptWasFinal;
  double get amplitude => _amplitude;
  List<double> get amplitudeSamples =>
      List<double>.unmodifiable(_amplitudeSamples);
  Duration get activeDuration => _activeDuration;
  String? get errorMessage => _errorMessage;
  String? get lifecycleMessage => _lifecycleMessage;
  TranscriptDraft? get recoveredDraft => _recoveredDraft;
  Recording? get lastSavedRecording => _lastSavedRecording;
  bool get isInitializing => _isInitializing;
  bool get isCommandInFlight => _commandInFlight;
  bool get isActiveSession => switch (state) {
    RecordingState.starting ||
    RecordingState.recording ||
    RecordingState.paused ||
    RecordingState.stopping ||
    RecordingState.saving => true,
    _ => false,
  };
  bool get canStart => !isActiveSession && !_commandInFlight;
  bool get canChangeLocale => !isActiveSession && !_commandInFlight;

  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;
    notifyListeners();

    try {
      _locales = await _captureService.getSupportedLocales();
      _selectInitialLocale();
      _recoveredDraft = await _draftStore.load();
      _errorMessage = null;
    } on Exception catch (error) {
      _errorMessage = 'Recognition languages could not be loaded: $error';
    } finally {
      _isInitialized = true;
      _isInitializing = false;
      notifyListeners();
    }
  }

  void applyPreferredLocale(String? localeId) {
    if (localeId == null || !_locales.any((locale) => locale.id == localeId)) {
      return;
    }
    if (_selectedLocaleId == localeId) return;
    _selectedLocaleId = localeId;
    notifyListeners();
  }

  void setLocale(String localeId) {
    if (!canChangeLocale) return;
    if (!_locales.any((locale) => locale.id == localeId)) return;
    if (_selectedLocaleId == localeId) return;
    _selectedLocaleId = localeId;
    notifyListeners();
  }

  Future<void> start() => _runCommand(() async {
    if (isActiveSession) return;
    final localeId = _selectedLocaleId;
    if (localeId == null || localeId.isEmpty) {
      _setError(
        const VoiceNoteException(
          code: VoiceNoteErrorCode.unsupportedLocale,
          message: 'No supported recognition language is available.',
        ),
      );
      return;
    }

    final sessionId = ++_sessionSequence;
    _activeSessionId = sessionId;
    _resetSessionPresentation();
    await _subscribeToEvents(sessionId);
    _transitionTo(RecordingState.requestingPermission);

    try {
      final permissionGranted = await _captureService.requestPermission();
      if (!permissionGranted) {
        await _unsubscribeFromEvents();
        _activeSessionId = null;
        _setError(
          const VoiceNoteException(
            code: VoiceNoteErrorCode.permissionDenied,
            message: 'Microphone and speech recognition permission is needed.',
          ),
        );
        return;
      }

      _transitionTo(RecordingState.starting);
      await _onBeforeRecording?.call();
      await _captureService.start(localeId: localeId);
      if (sessionId != _activeSessionId) return;

      _startedAt = _now();
      _startActiveTimers(sessionId);
      _transitionTo(RecordingState.recording);
      _errorMessage = null;
      notifyListeners();
    } on Exception catch (error) {
      await _cancelNativeSession();
      await _unsubscribeFromEvents();
      _activeSessionId = null;
      _setError(VoiceNoteException.fromObject(error));
    }
  });

  Future<void> pause() => _runCommand(() async {
    if (state != RecordingState.recording) return;
    final sessionId = _activeSessionId;
    _markPaused();
    try {
      await _captureService.pause();
    } on Exception catch (error) {
      _markRecording();
      _errorMessage =
          'Pause failed: ${VoiceNoteException.fromObject(error).message}';
      notifyListeners();
    }
    if (sessionId != _activeSessionId) return;
  });

  Future<void> resume() => _runCommand(() async {
    if (state != RecordingState.paused) return;
    try {
      await _captureService.resume();
      _markRecording();
      _errorMessage = null;
      notifyListeners();
    } on Exception catch (error) {
      _errorMessage =
          'Resume failed: ${VoiceNoteException.fromObject(error).message}';
      notifyListeners();
    }
  });

  Future<void> stop() => _runCommand(() async {
    if (state != RecordingState.recording && state != RecordingState.paused) {
      return;
    }

    final sessionId = _activeSessionId;
    final duration = _computeElapsed(_now());
    _activeDuration = duration;
    _stopActiveTimers();
    _transitionTo(RecordingState.stopping);
    notifyListeners();

    String? temporaryAudioPath;
    String? persistedAudioPath;
    try {
      temporaryAudioPath = await _captureService.stop();
      // iOS sends a final snapshot while stopping. Android may finalize
      // the native recognizer just after stop(), so allow one bounded turn
      // for the final event without waiting indefinitely.
      await Future<void>.delayed(_finalEventGracePeriod);
      if (sessionId != _activeSessionId) return;

      _transitionTo(RecordingState.saving);
      notifyListeners();

      final draft = _currentDraft(
        duration: duration,
        reason: 'audio_save_in_progress',
      );
      await _draftStore.save(draft);

      final recordingId = _createRecordingId(_now());
      final persisted = await _audioFileStore.persist(
        temporaryPath: temporaryAudioPath,
        recordingId: recordingId,
      );
      persistedAudioPath = persisted.path;

      final locale = _locales.firstWhere(
        (item) => item.id == _selectedLocaleId,
        orElse: () => RecognitionLocale(
          id: _selectedLocaleId ?? 'unknown',
          name: _selectedLocaleId ?? 'Unknown language',
        ),
      );
      final recording = Recording(
        id: recordingId,
        title: 'Untitled recording',
        createdAt: _now(),
        localeId: locale.id,
        localeName: locale.name,
        duration: duration,
        audioPath: persisted.path,
        fileSizeBytes: persisted.sizeBytes,
        transcript: _transcript.trim(),
      );

      try {
        await _recordingsRepository.insert(recording);
      } on Exception {
        await _audioFileStore.delete(persisted.path);
        rethrow;
      }

      await _draftStore.clear();
      _lastSavedRecording = recording;
      _activeSessionId = null;
      await _unsubscribeFromEvents();
      _transitionTo(RecordingState.completed);
      _errorMessage = null;
      await _onRecordingSaved?.call(recording);
      notifyListeners();
    } on Exception catch (error) {
      if (persistedAudioPath != null) {
        await _audioFileStore.delete(persistedAudioPath);
      }
      final normalized = VoiceNoteException.fromObject(error);
      await _saveDraftSafely(
        _currentDraft(duration: duration, reason: 'audio_save_failed'),
      );
      _activeSessionId = null;
      await _unsubscribeFromEvents();
      _setError(
        VoiceNoteException(
          code: normalized.code == VoiceNoteErrorCode.unknown
              ? VoiceNoteErrorCode.audioCopyFailed
              : normalized.code,
          message: '${normalized.message} The transcript draft was preserved.',
          cause: error,
        ),
      );
    } finally {
      if (temporaryAudioPath != null && temporaryAudioPath.isNotEmpty) {
        try {
          final file = File(temporaryAudioPath);
          if (await file.exists()) await file.delete();
        } on Exception {
          // The OS owns the temporary directory; failure to clean a temp
          // file must not hide a successfully saved recording.
        }
      }
    }
  });

  Future<void> discard() => _runCommand(() async {
    if (!isActiveSession) return;
    _stopActiveTimers();
    try {
      await _captureService.cancel();
      await _draftStore.clear();
      _activeSessionId = null;
      await _unsubscribeFromEvents();
      _resetSessionPresentation();
      _transitionTo(RecordingState.idle);
      notifyListeners();
    } on Exception catch (error) {
      _setError(VoiceNoteException.fromObject(error));
    }
  });

  Future<void> recoverDraft() async {
    final draft = _recoveredDraft;
    if (draft == null || isActiveSession) return;
    _transcript = draft.transcript;
    _activeDuration = draft.duration;
    if (_locales.any((locale) => locale.id == draft.localeId)) {
      _selectedLocaleId = draft.localeId;
    }
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> dismissRecoveredDraft() async {
    await _draftStore.clear();
    if (_recoveredDraft == null) return;
    _recoveredDraft = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    if (state == RecordingState.error) {
      _transitionTo(RecordingState.idle);
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        if (isActiveSession) {
          _lifecycleMessage =
              'If another app or a call takes the microphone, VoiceNote will show the native pause state.';
          notifyListeners();
        }
      case AppLifecycleState.resumed:
        if (_lifecycleMessage != null) {
          _lifecycleMessage = null;
          notifyListeners();
        }
      case AppLifecycleState.detached:
        unawaited(_shutdownForLifecycle());
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _shutdownForLifecycle() async {
    if (!isActiveSession) return;
    await _saveDraftSafely(_currentDraft(reason: 'lifecycle_shutdown'));
    _stopActiveTimers();
    await _cancelNativeSession();
    _activeSessionId = null;
    await _unsubscribeFromEvents();
  }

  Future<void> _runCommand(Future<void> Function() action) async {
    if (_commandInFlight) return;
    _commandInFlight = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _commandInFlight = false;
      notifyListeners();
    }
  }

  Future<void> _subscribeToEvents(int sessionId) async {
    await _unsubscribeFromEvents();
    _transcriptSubscription = _captureService.transcriptStream.listen(
      (event) => _handleTranscript(sessionId, event),
      onError: (Object error, StackTrace stackTrace) {
        unawaited(_handleCaptureError(sessionId, error));
      },
    );
    _sessionSubscription = _captureService.sessionEventStream.listen(
      (event) => _handleSessionEvent(sessionId, event),
      onError: (Object error, StackTrace stackTrace) {
        unawaited(_handleCaptureError(sessionId, error));
      },
    );
  }

  Future<void> _unsubscribeFromEvents() async {
    final transcript = _transcriptSubscription;
    final session = _sessionSubscription;
    _transcriptSubscription = null;
    _sessionSubscription = null;
    await transcript?.cancel();
    await session?.cancel();
  }

  void _handleTranscript(int sessionId, TranscriptSnapshot event) {
    if (!_isCurrentSession(sessionId)) return;
    final next = event.text;
    if (_transcript == next && _lastTranscriptWasFinal == event.isFinal) return;
    _transcript = next;
    _lastTranscriptWasFinal = event.isFinal;
    notifyListeners();
  }

  void _handleSessionEvent(int sessionId, CaptureSessionEvent event) {
    if (!_isCurrentSession(sessionId)) return;
    switch (event) {
      case CaptureSessionEvent.paused:
        if (state == RecordingState.recording) {
          _markPaused();
          _lifecycleMessage = 'Recording paused by a microphone interruption.';
          notifyListeners();
        }
      case CaptureSessionEvent.resumed:
        if (state == RecordingState.paused) {
          _markRecording();
          _lifecycleMessage = null;
          notifyListeners();
        }
    }
  }

  Future<void> _handleCaptureError(int sessionId, Object error) async {
    if (!_isCurrentSession(sessionId)) return;
    _stopActiveTimers();
    await _saveDraftSafely(_currentDraft(reason: 'recognition_error'));
    await _cancelNativeSession();
    _activeSessionId = null;
    await _unsubscribeFromEvents();
    _setError(VoiceNoteException.fromObject(error));
  }

  bool _isCurrentSession(int sessionId) {
    if (_activeSessionId != sessionId) return false;
    return state != RecordingState.idle &&
        state != RecordingState.completed &&
        state != RecordingState.error;
  }

  void _selectInitialLocale() {
    if (_locales.isEmpty) {
      _selectedLocaleId = null;
      return;
    }
    final preferred = _locales.where((locale) => locale.id == 'en-IN');
    _selectedLocaleId = preferred.isNotEmpty
        ? preferred.first.id
        : _locales.first.id;
  }

  void _resetSessionPresentation() {
    _transcript = '';
    _lastTranscriptWasFinal = false;
    _amplitude = 0;
    _amplitudeSamples = const <double>[];
    _activeDuration = Duration.zero;
    _elapsedOffset = Duration.zero;
    _startedAt = null;
    _lastSavedRecording = null;
    _errorMessage = null;
    _lifecycleMessage = null;
  }

  void _markPaused() {
    if (state == RecordingState.recording) {
      _activeDuration = _computeElapsed(_now());
      _elapsedOffset = _activeDuration;
      _startedAt = null;
      _stopActiveTimers();
      _amplitude = 0;
      _transitionTo(RecordingState.paused);
      notifyListeners();
    }
  }

  void _markRecording() {
    if (state != RecordingState.paused) return;
    _startedAt = _now();
    _startActiveTimers(_activeSessionId);
    _transitionTo(RecordingState.recording);
  }

  Duration _computeElapsed(DateTime now) {
    final startedAt = _startedAt;
    if (startedAt == null) return _elapsedOffset;
    return _elapsedOffset + now.difference(startedAt);
  }

  void _startActiveTimers(int? sessionId) {
    _stopActiveTimers();
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (state != RecordingState.recording) return;
      final next = _computeElapsed(_now());
      if (next == _activeDuration) return;
      _activeDuration = next;
      notifyListeners();
    });
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (sessionId == null || !_isCurrentSession(sessionId)) return;
      unawaited(_pollAmplitude(sessionId));
    });
    _draftTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (sessionId == null || !_isCurrentSession(sessionId)) return;
      unawaited(_checkpointDraft());
    });
  }

  void _stopActiveTimers() {
    _elapsedTimer?.cancel();
    _amplitudeTimer?.cancel();
    _draftTimer?.cancel();
    _elapsedTimer = null;
    _amplitudeTimer = null;
    _draftTimer = null;
    _amplitudePollInFlight = false;
  }

  Future<void> _pollAmplitude(int sessionId) async {
    if (_amplitudePollInFlight || !_isCurrentSession(sessionId)) return;
    _amplitudePollInFlight = true;
    try {
      final next = (await _captureService.getAmplitude()).clamp(0.0, 1.0);
      if (!_isCurrentSession(sessionId)) return;
      _amplitude = next;
      final nextSamples = <double>[..._amplitudeSamples, next];
      if (nextSamples.length > _amplitudeSampleLimit) {
        nextSamples.removeRange(0, nextSamples.length - _amplitudeSampleLimit);
      }
      _amplitudeSamples = nextSamples;
      notifyListeners();
    } on Exception {
      // A level meter is best effort; speech and audio data remain usable.
    } finally {
      _amplitudePollInFlight = false;
    }
  }

  Future<void> _checkpointDraft() async {
    if (_draftWriteInFlight || !isActiveSession) return;
    _draftWriteInFlight = true;
    try {
      await _draftStore.save(_currentDraft(reason: 'active_session'));
    } on Exception {
      // A draft is recovery support, not a reason to interrupt a live session.
    } finally {
      _draftWriteInFlight = false;
    }
  }

  Future<void> _saveDraftSafely(TranscriptDraft draft) async {
    try {
      await _draftStore.save(draft);
    } on Exception {
      // The primary recording error remains visible even if recovery storage
      // is also unavailable.
    }
  }

  TranscriptDraft _currentDraft({Duration? duration, required String reason}) {
    final locale = _locales.firstWhere(
      (item) => item.id == _selectedLocaleId,
      orElse: () => RecognitionLocale(
        id: _selectedLocaleId ?? 'unknown',
        name: _selectedLocaleId ?? 'Unknown language',
      ),
    );
    return TranscriptDraft(
      createdAt: _now(),
      localeId: locale.id,
      localeName: locale.name,
      duration: duration ?? _computeElapsed(_now()),
      transcript: _transcript,
      reason: reason,
    );
  }

  String _createRecordingId(DateTime timestamp) {
    final suffix = timestamp.microsecondsSinceEpoch.toRadixString(36);
    return 'recording-$suffix-${_sessionSequence.toRadixString(36)}';
  }

  Future<void> _cancelNativeSession() async {
    try {
      await _captureService.cancel();
    } on Exception {
      // Best effort; the original failure is the useful error to show.
    }
  }

  void _transitionTo(RecordingState next) {
    if (state == next) return;
    _stateMachine.transitionTo(next);
  }

  void _setError(VoiceNoteException error) {
    _stopActiveTimers();
    _errorMessage = error.message;
    if (state != RecordingState.error &&
        _stateMachine.canTransitionTo(RecordingState.error)) {
      _stateMachine.transitionTo(RecordingState.error);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopActiveTimers();
    if (isActiveSession) {
      unawaited(_saveDraftSafely(_currentDraft(reason: 'provider_disposed')));
      unawaited(_cancelNativeSession());
    }
    unawaited(_unsubscribeFromEvents());
    super.dispose();
  }
}
