import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/voice_note_exception.dart';
import '../../../core/storage/audio_file_store.dart';
import '../data/recording_repository.dart';
import '../domain/recording.dart';

class RecordingsViewModel extends ChangeNotifier {
  RecordingsViewModel({
    required this._repository,
    required this._audioFileStore,
  });

  static const pageSize = 20;

  final RecordingRepository _repository;
  final AudioFileStore _audioFileStore;

  final List<Recording> _recordings = <Recording>[];
  Timer? _searchDebounce;
  String _query = '';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _totalCount = 0;
  int _totalBytes = 0;

  List<Recording> get recordings => List<Recording>.unmodifiable(_recordings);
  String get query => _query;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  int get totalCount => _totalCount;
  int get totalBytes => _totalBytes;

  Future<void> initialize() => refresh();

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), refresh);
  }

  Future<void> refresh() async {
    _searchDebounce?.cancel();
    _isLoading = true;
    _isLoadingMore = false;
    _hasMore = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final items = await _repository.search(
        query: _query,
        offset: 0,
        limit: pageSize,
      );
      _recordings
        ..clear()
        ..addAll(items);
      _hasMore = items.length == pageSize;
      await _refreshStorageStats();
    } on VoiceNoteException catch (error) {
      _errorMessage = error.message;
    } on Exception catch (error) {
      _errorMessage = 'Unable to load recordings: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final items = await _repository.search(
        query: _query,
        offset: _recordings.length,
        limit: pageSize,
      );
      _recordings.addAll(items);
      _hasMore = items.length == pageSize;
    } on VoiceNoteException catch (error) {
      _errorMessage = error.message;
    } on Exception catch (error) {
      _errorMessage = 'Unable to load more recordings: $error';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> update(Recording recording) async {
    try {
      await _repository.update(recording);
      final index = _recordings.indexWhere((item) => item.id == recording.id);
      if (index >= 0) {
        _recordings[index] = recording;
        notifyListeners();
      }
      await _refreshStorageStats();
    } on VoiceNoteException {
      rethrow;
    }
  }

  Future<void> delete(Recording recording) async {
    await _repository.delete(recording.id);
    try {
      await _audioFileStore.delete(recording.audioPath);
    } finally {
      _recordings.removeWhere((item) => item.id == recording.id);
      await _refreshStorageStats();
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    final items = List<Recording>.from(_recordings);
    await _repository.deleteAll();
    for (final item in items) {
      await _audioFileStore.delete(item.audioPath);
    }
    _recordings.clear();
    _hasMore = false;
    await _refreshStorageStats();
    notifyListeners();
  }

  Future<void> _refreshStorageStats() async {
    _totalCount = await _repository.count(query: _query);
    _totalBytes = await _repository.totalBytes();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
