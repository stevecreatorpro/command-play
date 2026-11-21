import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:media_kit/media_kit.dart';

import 'core/wiring.dart';
import 'library/library_service.dart';
import 'library/thumbnail_service.dart';
import 'playback/playback_service.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';
import 'voice/nlu.dart';
import 'voice/voice_controller.dart';
import 'voice/vosk_voice_input.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final library = await LibraryService.open();
  library.pruneMissing(); // drop files that were deleted or moved
  final playback = PlaybackService(library: library);
  final thumbs = ThumbnailService(library);
  final session = ChoiceSession();
  final registry =
      buildRegistry(playback: playback, library: library, session: session);
  final voice = VoiceController(
    nlu: Nlu(),
    registry: registry,
    session: session,
    tts: FlutterTts(),
  );
  final mic = VoskVoiceInput();
  // One app-wide subscription: every finished utterance becomes a command.
  mic.transcripts.listen(voice.handleSpeech);

  runApp(CommandPlayApp(
    playback: playback,
    library: library,
    voice: voice,
    session: session,
    mic: mic,
    thumbs: thumbs,
  ));

  // Thumbnails + durations for anything not processed yet (background).
  thumbs.run();
}

class CommandPlayApp extends StatelessWidget {
  const CommandPlayApp({
    super.key,
    required this.playback,
    required this.library,
    required this.voice,
    required this.session,
    required this.mic,
    required this.thumbs,
  });

  final ThumbnailService thumbs;
  final PlaybackService playback;
  final LibraryService library;
  final VoiceController voice;
  final ChoiceSession session;
  final VoskVoiceInput mic;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Command Play',
      debugShowCheckedModeBanner: false,
      theme: CP.theme(),
      home: HomePage(
        playback: playback,
        library: library,
        voice: voice,
        session: session,
        mic: mic,
        thumbs: thumbs,
      ),
    );
  }
}
