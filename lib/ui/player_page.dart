import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../library/library_service.dart';
import '../library/thumbnail_service.dart';
import '../playback/playback_service.dart';
import '../voice/voice_controller.dart';
import '../voice/vosk_voice_input.dart';
import 'theme.dart';
import 'widgets.dart';

/// Full-screen immersive player for video and music.
class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.playback,
    required this.voice,
    required this.mic,
    required this.session,
    required this.thumbs,
  });

  final ThumbnailService thumbs;
  final PlaybackService playback;
  final VoiceController voice;
  final VoskVoiceInput mic;
  final ChoiceSession session;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  bool _controls = true;
  Timer? _hide;

  PlaybackService get pb => widget.playback;

  @override
  void initState() {
    super.initState();
    _bump();
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  /// Show controls, then auto-hide after 3 s while playing.
  void _bump() {
    setState(() => _controls = true);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && pb.state.playing && !widget.voice.listening) {
        setState(() => _controls = false);
      }
    });
  }

  void _toggleControls() {
    if (_controls) {
      _hide?.cancel();
      setState(() => _controls = false);
    } else {
      _bump();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () {
          pb.playOrPause();
          _bump();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          pb.seekRelative(const Duration(seconds: 10));
          _bump();
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          pb.seekRelative(const Duration(seconds: -10));
          _bump();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: ValueListenableBuilder<MediaItem?>(
            valueListenable: pb.nowPlaying,
            builder: (_, item, __) => MouseRegion(
              onHover: (_) {
                if (!_controls) _bump();
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                child: Stack(children: [
                  Positioned.fill(
                    child: item == null || item.isVideo
                        ? Video(
                            controller: pb.video,
                            controls: NoVideoControls,
                            fill: Colors.black,
                          )
                        : _MusicArt(
                            item: item,
                            playback: pb,
                            image: widget.thumbs.thumbFor(item)),
                  ),
                  _overlay(item),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(MediaItem? item) {
    return AnimatedOpacity(
      opacity: _controls ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: !_controls,
        child: Column(children: [
          // Top bar.
          Container(
            decoration: const BoxDecoration(gradient: CP.scrimTop),
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 40),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item?.displayTitle ?? 'Nothing playing',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      if (item != null)
                        Text(item.folder,
                            style: const TextStyle(
                                color: CP.textDim, fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          const Spacer(),
          // Bottom controls + voice.
          Container(
            decoration: const BoxDecoration(gradient: CP.scrimBottom),
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 12),
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _seekBar(),
                    const SizedBox(height: 4),
                    _transport(),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: VoiceDock(
                          voice: widget.voice,
                          mic: widget.mic,
                          session: widget.session),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _seekBar() => StreamBuilder<Duration>(
        stream: pb.player.stream.position,
        builder: (_, __) {
          final pos = pb.state.position;
          final dur = pb.state.duration;
          final max = dur.inMilliseconds.toDouble();
          return Column(children: [
            Slider(
              value: max == 0
                  ? 0
                  : pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble(),
              max: max == 0 ? 1 : max,
              onChanged: (v) {
                pb.seekTo(Duration(milliseconds: v.round()));
                _bump();
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Text(fmtDuration(pos),
                    style: const TextStyle(color: CP.textDim, fontSize: 12)),
                const Spacer(),
                Text(fmtDuration(dur),
                    style: const TextStyle(color: CP.textDim, fontSize: 12)),
              ]),
            ),
          ]);
        },
      );

  Widget _transport() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StreamBuilder<double>(
            stream: pb.player.stream.rate,
            builder: (_, __) => TextButton(
              onPressed: () {
                const speeds = [1.0, 1.25, 1.5, 2.0, 0.75];
                final i = speeds.indexOf(pb.state.rate);
                pb.setSpeed(speeds[(i + 1) % speeds.length]);
                _bump();
              },
              child: Text('${pb.state.rate}x',
                  style: const TextStyle(
                      color: CP.lavender, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            iconSize: 34,
            icon: const Icon(Icons.replay_10_rounded),
            onPressed: () {
              pb.seekRelative(const Duration(seconds: -10));
              _bump();
            },
          ),
          const SizedBox(width: 18),
          StreamBuilder<bool>(
            stream: pb.player.stream.playing,
            builder: (_, __) => GestureDetector(
              onTap: () {
                pb.playOrPause();
                _bump();
              },
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: CP.accent,
                  boxShadow: [
                    BoxShadow(
                        color: CP.purpleDeep.withValues(alpha: 0.6),
                        blurRadius: 28,
                        spreadRadius: 2),
                  ],
                ),
                child: Icon(
                  pb.state.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 42,
                  color: CP.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          IconButton(
            iconSize: 34,
            icon: const Icon(Icons.forward_10_rounded),
            onPressed: () {
              pb.seekRelative(const Duration(seconds: 10));
              _bump();
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            iconSize: 30,
            icon: const Icon(Icons.skip_next_rounded),
            onPressed: pb.next,
          ),
        ],
      );
}

class _MusicArt extends StatelessWidget {
  const _MusicArt({required this.item, required this.playback, this.image});
  final File? image;
  final MediaItem item;
  final PlaybackService playback;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const AmbientBackground(),
      Center(
        child: LayoutBuilder(builder: (_, c) {
          final art = (c.biggest.shortestSide * 0.42).clamp(160.0, 360.0);
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: art,
              height: art,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(art * 0.12),
                boxShadow: [
                  BoxShadow(
                      color: CP.purpleDeep.withValues(alpha: 0.5),
                      blurRadius: 60),
                ],
              ),
              child: GradientThumb(
                  item: item,
                  radius: art * 0.12,
                  iconSize: art * 0.25,
                  image: image),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: art * 1.4,
              height: 70,
              child: StreamBuilder<bool>(
                stream: playback.player.stream.playing,
                builder: (_, __) =>
                    EqualizerBars(active: playback.state.playing),
              ),
            ),
            const SizedBox(height: 120),
          ]);
        }),
      ),
    ]);
  }
}
