import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Annonces vocales pour alerter le personnel (nouvelles commandes, appels serveur…).
class VoiceAnnouncer {
  VoiceAnnouncer._();
  static final VoiceAnnouncer instance = VoiceAnnouncer._();

  final FlutterTts _tts = FlutterTts();
  final Queue<String> _queue = Queue<String>();
  bool _initialized = false;
  bool _initializing = false;
  bool _speaking = false;
  bool _pluginAvailable = true;

  void _log(String message) {
    if (kDebugMode) {
      print('[VoiceAnnouncer] $message');
    }
  }

  /// Prépare le moteur vocal dès le démarrage du serveur (évite la 1ʳᵉ commande muette).
  Future<void> warmUp() => _ensureInitialized();

  Future<T?> _safeCall<T>(String label, Future<T> Function() action) async {
    try {
      return await action();
    } on MissingPluginException catch (e) {
      _pluginAvailable = false;
      _log(
        '$label : plugin flutter_tts introuvable. '
        'Arrêtez l\'app puis relancez avec « flutter run » (pas un hot reload). ($e)',
      );
      return null;
    } catch (e) {
      _log('$label ignoré : $e');
      return null;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized || !_pluginAvailable) return;
    if (_initializing) {
      while (_initializing && !_initialized) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _initializing = true;
    try {
      _tts.setErrorHandler((message) => _log('Erreur TTS: $message'));

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _safeCall(
          'setIosAudioCategory',
          () => _tts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [
              IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
              IosTextToSpeechAudioCategoryOptions.duckOthers,
            ],
            IosTextToSpeechAudioMode.voicePrompt,
          ),
        );
      }

      if (!_pluginAvailable) return;

      await _safeCall('setSpeechRate', () => _tts.setSpeechRate(0.48));
      await _safeCall('setVolume', () => _tts.setVolume(1.0));
      await _safeCall('setPitch', () => _tts.setPitch(1.0));
      await _safeCall('awaitSpeakCompletion', () => _tts.awaitSpeakCompletion(true));

      if (!_pluginAvailable) return;

      const preferred = ['fr-FR', 'fr_FR', 'fr-CA', 'fr'];
      for (final lang in preferred) {
        final result = await _safeCall('setLanguage', () => _tts.setLanguage(lang));
        if (result == 1 || result == '1') {
          _log('Langue TTS: $lang');
          break;
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 400));
      _initialized = true;
      _log('Moteur vocal prêt');
    } finally {
      _initializing = false;
    }
  }

  /// Enfile une annonce vocale (les messages sont lus l'un après l'autre).
  Future<void> announce(String message) async {
    if (message.trim().isEmpty || !_pluginAvailable) return;
    try {
      await _ensureInitialized();
      if (!_initialized) return;
      _queue.add(message);
      await _processQueue();
    } catch (e, st) {
      _log('Impossible d\'annoncer « $message »: $e\n$st');
    }
  }

  Future<void> announceNewOrder(String tableLabel) async {
    await announce('Une commande vient d\'être passée sur $tableLabel.');
  }

  Future<void> _processQueue() async {
    if (_speaking || _queue.isEmpty) return;
    _speaking = true;
    while (_queue.isNotEmpty) {
      final message = _queue.removeFirst();
      await _speakAndWait(message);
    }
    _speaking = false;
  }

  Future<void> _speakAndWait(String message) async {
    _log('Annonce: $message');
    final completer = Completer<void>();
    _tts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });

    final result = await _safeCall('speak', () => _tts.speak(message));
    _log('speak() → $result');

    if (result == 1 || result == '1') {
      await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => _log('Timeout attente fin de parole'),
      );
    }
  }
}
