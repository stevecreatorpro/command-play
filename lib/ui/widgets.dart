import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../library/library_service.dart';
import '../playback/playback_service.dart';
import '../voice/voice_controller.dart';
import '../voice/vosk_voice_input.dart';
import 'theme.dart';

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Frosted dark-glass panel.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: const Color(0xCC15121F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: const BorderSide(color: CP.stroke),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Soft purple glows behind the whole UI for depth.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    Widget glow(Alignment a, double size, Color c) => Align(
          alignment: a,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
            ),
          ),
        );
    return IgnorePointer(
      child: Stack(children: [
        const ColoredBox(color: CP.black, child: SizedBox.expand()),
        glow(const Alignment(-1.2, -1.1), 520, const Color(0x557C4DFF)),
        glow(const Alignment(1.3, 0.2), 420, const Color(0x33B69CFF)),
        glow(const Alignment(-0.6, 1.4), 380, const Color(0x2A7C4DFF)),
      ]),
    );
  }
}

/// Gradient artwork tile for a media item (video or music).
class GradientThumb extends StatelessWidget {
  const GradientThumb({
    super.key,
    required this.item,
    this.radius = 14,
    this.iconSize = 28,
    this.label,
    this.image,
  });

  final File? image;
  final MediaItem item;
  final double radius;
  final double iconSize;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final img = image;
    if (img != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(fit: StackFit.expand, children: [
          ColoredBox(
            color: CP.surfaceHigh,
            child: Image.file(
              img,
              fit: BoxFit.cover,
              cacheWidth: 480,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          if (label != null)
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xCC000000),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label!,
                    style: const TextStyle(fontSize: 10, color: Colors.white)),
              ),
            ),
        ]),
      );
    }
    final g = CP.thumbGradients[item.id % CP.thumbGradients.length];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -iconSize * 0.4,
          bottom: -iconSize * 0.5,
          child: Icon(
            item.isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
            size: iconSize * 2.6,
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        Center(
          child: Icon(
            item.isVideo
                ? Icons.play_circle_fill_rounded
                : Icons.graphic_eq_rounded,
            size: iconSize,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        if (label != null)
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xAA000000),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label!,
                  style: const TextStyle(fontSize: 10, color: Colors.white)),
            ),
          ),
      ]),
    );
  }
}

/// Animated equaliser bars (music "now playing" art).
class EqualizerBars extends StatefulWidget {
  const EqualizerBars({super.key, required this.active, this.bars = 24});
  final bool active;
  final int bars;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _BarsPainter(widget.active ? _c.value : 0, widget.bars,
              widget.active),
          size: Size.infinite,
        ),
      );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.t, this.n, this.active);
  final double t;
  final int n;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / (n * 1.6);
    final paint = Paint()
      ..shader = CP.accent.createShader(Offset.zero & size);
    for (var i = 0; i < n; i++) {
      final phase = t * 2 * math.pi + i * 0.55;
      final level = active
          ? 0.25 + 0.75 * (0.5 + 0.5 * math.sin(phase) * math.cos(phase * 0.37 + i))
              .abs()
          : 0.12;
      final h = size.height * level;
      final x = i * w * 1.6 + w * 0.3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - h, w, h), Radius.circular(w / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.t != t || old.active != active;
}

/// Floating mini player shown above the voice dock.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.playback,
    required this.onExpand,
    this.thumbFor,
  });
  final PlaybackService playback;
  final VoidCallback onExpand;
  final File? Function(MediaItem)? thumbFor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MediaItem?>(
      valueListenable: playback.nowPlaying,
      builder: (_, item, __) {
        if (item == null) return const SizedBox.shrink();
        return GlassPanel(
          radius: 22,
          padding: EdgeInsets.zero,
          onTap: onExpand,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
              child: Row(children: [
                SizedBox.square(
                    dimension: 48,
                    child: GradientThumb(
                        item: item,
                        radius: 24,
                        iconSize: 20,
                        image: thumbFor?.call(item))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      StreamBuilder<Duration>(
                        stream: playback.player.stream.position,
                        builder: (_, __) => Text(
                          '${fmtDuration(playback.state.position)} / '
                          '${fmtDuration(playback.state.duration)}',
                          style: const TextStyle(
                              color: CP.textDim, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<bool>(
                  stream: playback.player.stream.playing,
                  builder: (_, __) => IconButton(
                    iconSize: 34,
                    icon: Icon(playback.state.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                    onPressed: playback.playOrPause,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: playback.next,
                ),
              ]),
            ),
            StreamBuilder<Duration>(
              stream: playback.player.stream.position,
              builder: (_, __) {
                final d = playback.state.duration.inMilliseconds;
                final f = d == 0
                    ? 0.0
                    : (playback.state.position.inMilliseconds / d)
                        .clamp(0.0, 1.0);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: f,
                    child: Container(
                        height: 3,
                        decoration:
                            const BoxDecoration(gradient: CP.accent)),
                  ),
                );
              },
            ),
          ]),
        );
      },
    );
  }
}

const _ordinalWords = ['one', 'two', 'three', 'four', 'five'];

/// Voice dock: result picker + speech bubble + command pill with glowing mic.
class VoiceDock extends StatefulWidget {
  const VoiceDock({
    super.key,
    required this.voice,
    required this.mic,
    required this.session,
  });

  final VoiceController voice;
  final VoskVoiceInput mic;
  final ChoiceSession session;

  @override
  State<VoiceDock> createState() => _VoiceDockState();
}

class _VoiceDockState extends State<VoiceDock>
    with SingleTickerProviderStateMixin {
  final _text = TextEditingController();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  StreamSubscription<String>? _partialSub;
  Timer? _hide;
  String _status = '';
  String _partial = '';
  bool _bubble = false;

  @override
  void initState() {
    super.initState();
    _partialSub = widget.mic.partialTranscripts.listen((p) {
      if (!mounted) return;
      setState(() => _partial = p);
      if (p.isNotEmpty) _flash();
    });
    widget.voice.addListener(_onVoice);
    _syncPulse();
  }

  void _onVoice() {
    _syncPulse();
    _flash();
  }

  void _syncPulse() {
    if (widget.voice.listening) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  void _flash() {
    if (!mounted) return;
    setState(() => _bubble = true);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 7), () {
      if (mounted && !widget.voice.listening) setState(() => _bubble = false);
    });
  }

  void _setStatus(String s) {
    setState(() => _status = s);
    _flash();
  }

  Future<void> _toggleMic() async {
    final v = widget.voice;
    if (!widget.mic.isSupported) {
      _setStatus('Voice input is not available on this device yet. '
          'Type a command instead.');
      return;
    }
    if (v.listening) {
      await widget.mic.stop();
      v.setListening(false);
      _setStatus('');
      return;
    }
    try {
      if (!widget.mic.isModelLoaded) {
        _setStatus('Loading speech model (first time takes a few seconds)\u2026');
      }
      await widget.mic.start();
      v.setListening(true);
      _setStatus('Listening\u2026 say a command, then pause.');
    } catch (e) {
      v.setListening(false);
      _setStatus('Microphone error: $e');
    }
  }

  void _submit(String s) {
    if (s.trim().isEmpty) return;
    widget.voice.handleText(s);
    _text.clear();
  }

  @override
  void dispose() {
    _partialSub?.cancel();
    _hide?.cancel();
    widget.voice.removeListener(_onVoice);
    _pulse.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.voice;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Numbered search results ("the second one").
        ListenableBuilder(
          listenable: widget.session,
          builder: (_, __) {
            final c = widget.session.candidates;
            if (c.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassPanel(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Text('Which one?',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const Spacer(),
                    TextButton(
                        onPressed: () => v.handleText('cancel'),
                        child: const Text('Cancel')),
                  ]),
                  for (var i = 0; i < c.length && i < 5; i++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, gradient: CP.accent),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: CP.black, fontWeight: FontWeight.w800)),
                      ),
                      title: Text(c[i].displayTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(c[i].folder,
                          style: const TextStyle(color: CP.textDim)),
                      onTap: () => v.handleText(_ordinalWords[i]),
                    ),
                ]),
              ),
            );
          },
        ),
        // Speech bubble: live words, what was heard, the reply.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: !_bubble
              ? const SizedBox.shrink()
              : Padding(
                  key: const ValueKey('bubble'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListenableBuilder(
                    listenable: v,
                    builder: (_, __) => GlassPanel(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_partial.isNotEmpty)
                            Text('\u201C$_partial\u2026\u201D',
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: CP.lavender,
                                    fontSize: 16))
                          else if (_status.isNotEmpty)
                            Text(_status,
                                style: const TextStyle(color: CP.textDim)),
                          if (v.heard.isNotEmpty && _partial.isEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Heard: \u201C${v.heard}\u201D',
                                style: const TextStyle(
                                    color: CP.textDim, fontSize: 12)),
                          ],
                          if (v.feedback.isNotEmpty && _partial.isEmpty)
                            ShaderMask(
                              shaderCallback: (r) => CP.accent.createShader(r),
                              child: Text(v.feedback,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        // Command pill.
        GlassPanel(
          radius: 32,
          padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
          child: Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: CP.purple, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _text,
                onSubmitted: _submit,
                style: const TextStyle(color: Colors.white),
                cursorColor: CP.purple,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Say or type a command\u2026',
                  hintStyle: TextStyle(color: CP.textDim),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => GestureDetector(
                onTap: _toggleMic,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [CP.purple, CP.purpleDeep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CP.purpleDeep.withValues(
                            alpha: v.listening ? 0.55 + 0.35 * _pulse.value : 0.35),
                        blurRadius: v.listening ? 14 + 18 * _pulse.value : 12,
                        spreadRadius: v.listening ? 2 + 4 * _pulse.value : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    v.listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
