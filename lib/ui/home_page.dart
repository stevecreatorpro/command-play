import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../library/library_service.dart';
import '../library/thumbnail_service.dart';
import '../playback/playback_service.dart';
import '../voice/voice_controller.dart';
import '../voice/vosk_voice_input.dart';
import 'logo.dart';
import 'player_page.dart';
import 'theme.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({
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
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<MediaItem> _items = const [];
  String _query = '';
  int _tab = 0; // 0 = videos, 1 = music
  bool _scanning = false;
  bool _playerOpen = false;

  @override
  void initState() {
    super.initState();
    _reload();
    widget.playback.nowPlaying.addListener(_onNowPlaying);
    widget.playback.lastError.addListener(_onError);
    widget.thumbs.version.addListener(_reload);
  }

  void _onError() {
    final e = widget.playback.lastError.value;
    if (e != null) _toast(e);
  }

  @override
  void dispose() {
    widget.playback.nowPlaying.removeListener(_onNowPlaying);
    widget.playback.lastError.removeListener(_onError);
    widget.thumbs.version.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() => _items = widget.library.all());
  }

  // Videos started by voice or tap open the immersive player automatically.
  void _onNowPlaying() {
    final item = widget.playback.nowPlaying.value;
    if (item != null && item.isVideo) _openPlayer();
  }

  Future<void> _openPlayer() async {
    if (_playerOpen) return;
    _playerOpen = true;
    await Navigator.of(context).push(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => PlayerPage(
        playback: widget.playback,
        voice: widget.voice,
        mic: widget.mic,
        session: widget.session,
        thumbs: widget.thumbs,
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child),
      ),
    ));
    _playerOpen = false;
  }

  /// Plays [list] as a queue from [index], so next/previous and auto-advance work.
  Future<void> _play(List<MediaItem> list, int index) async {
    final ok = await widget.playback.openQueue(list, index);
    if (ok && !_playerOpen) _openPlayer();
  }

  Future<void> _addFolder() async {
    if (Platform.isAndroid) {
      await [Permission.videos, Permission.audio, Permission.storage].request();
    }
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    setState(() => _scanning = true);
    try {
      final n = await widget.library.scan(dir);
      _reload();
      widget.thumbs.run(); // thumbnails + durations in the background
      _toast('Added $n new files \u00B7 ${widget.library.count} in library');
    } catch (e) {
      _toast('Could not read that folder: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: CP.surfaceHigh,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? _items
        : _items.where((i) => i.title.toLowerCase().contains(q)).toList();
    final videos = filtered.where((i) => i.isVideo).toList();
    final music = filtered.where((i) => !i.isVideo).toList();
    final list = _tab == 0 ? videos : music;
    final recent = _items.take(10).toList();
    final wide = MediaQuery.sizeOf(context).width > 900;

    return Scaffold(
      body: Stack(children: [
        const AmbientBackground(),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(child: _header()),
                SliverToBoxAdapter(child: _searchBar()),
                if (_items.isEmpty)
                  SliverFillRemaining(
                      hasScrollBody: false, child: _emptyState())
                else ...[
                  if (q.isEmpty) ...[
                    _sectionTitle('Recently added'),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: wide ? 190 : 150,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: recent.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (_, i) =>
                              _recentCard(recent, i, wide ? 260 : 200),
                        ),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(child: _tabs(videos.length, music.length)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 230),
                    sliver: list.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: Text(
                                _tab == 0
                                    ? 'No videos here yet'
                                    : 'No music here yet',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: CP.textDim),
                              ),
                            ),
                          )
                        : SliverList.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _tile(list, i),
                          ),
                  ),
                ],
              ]),
            ),
          ),
        ),
        // Floating mini player + voice dock.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    MiniPlayer(
                        playback: widget.playback,
                        onExpand: _openPlayer,
                        thumbFor: widget.thumbs.thumbFor),
                    const SizedBox(height: 10),
                    VoiceDock(
                        voice: widget.voice,
                        mic: widget.mic,
                        session: widget.session),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Row(children: [
          const CPlayLogo(size: 40, background: true),
          const SizedBox(width: 12),
          const Text('Command Play',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: CP.purple)),
            ),
          Tooltip(
            message: 'Add a music or video folder',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _scanning ? null : _addFolder,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, gradient: CP.accent),
                child: const Icon(Icons.create_new_folder_rounded,
                    color: CP.black),
              ),
            ),
          ),
        ]),
      );

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
        child: GlassPanel(
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white),
            cursorColor: CP.purple,
            decoration: const InputDecoration(
              border: InputBorder.none,
              icon: Icon(Icons.search_rounded, color: CP.textDim),
              hintText: 'Search your library',
              hintStyle: TextStyle(color: CP.textDim),
            ),
          ),
        ),
      );

  Widget _sectionTitle(String t) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Text(t,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        ),
      );

  String? _durLabel(MediaItem i) =>
      i.durationMs > 0 ? fmtDuration(i.duration) : null;

  /// Thin "continue watching" bar for partly watched items.
  Widget _progress(MediaItem i, double radius) {
    if (i.positionMs <= 0 || i.durationMs <= 0) return const SizedBox.shrink();
    final f = (i.positionMs / i.durationMs).clamp(0.0, 1.0);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
        child: Container(
          height: 4,
          color: const Color(0x66000000),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: f,
            child: Container(decoration: const BoxDecoration(gradient: CP.accent)),
          ),
        ),
      ),
    );
  }

  Widget _recentCard(List<MediaItem> items, int index, double width) {
    final item = items[index];
    return SizedBox(
        width: width,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _play(items, index),
          child: Stack(children: [
            Positioned.fill(
                child: GradientThumb(
                    item: item,
                    radius: 18,
                    iconSize: 34,
                    image: widget.thumbs.thumbFor(item))),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: CP.scrimBottom,
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Row(children: [
                Expanded(
                  child: Text(item.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                if (_durLabel(item) != null)
                  Text(_durLabel(item)!,
                      style: const TextStyle(
                          fontSize: 12, color: CP.lavender)),
              ]),
            ),
            _progress(item, 18),
          ]),
        ),
      );
  }

  Widget _tabs(int videoCount, int musicCount) {
    Widget tab(int i, String label, int count) {
      final on = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: on ? CP.accent : null,
            ),
            alignment: Alignment.center,
            child: Text('$label  $count',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: on ? CP.black : CP.textDim,
                )),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: GlassPanel(
        radius: 18,
        padding: const EdgeInsets.all(5),
        child: Row(children: [
          tab(0, 'All videos', videoCount),
          tab(1, 'Music', musicCount),
        ]),
      ),
    );
  }

  Widget _tile(List<MediaItem> items, int index) {
    final item = items[index];
    return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _play(items, index),
        child: Row(children: [
          SizedBox(
            width: item.isVideo ? 128 : 72,
            height: 72,
            child: Stack(children: [
              Positioned.fill(
                child: GradientThumb(
                  item: item,
                  iconSize: 24,
                  image: widget.thumbs.thumbFor(item),
                  label: _durLabel(item),
                ),
              ),
              _progress(item, 14),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                    item.positionMs > 0 && item.durationMs > 0
                        ? '${item.folder} \u00B7 ${fmtDuration(Duration(milliseconds: item.positionMs))} watched'
                        : item.folder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: CP.textDim, fontSize: 12)),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration:
                const BoxDecoration(shape: BoxShape.circle, gradient: CP.accent),
            child: const Icon(Icons.play_arrow_rounded, color: CP.black),
          ),
        ]),
      );
  }

  Widget _emptyState() {
    Widget chip(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CP.stroke),
            color: CP.surface,
          ),
          child: Text('\u201C$t\u201D', style: const TextStyle(color: CP.lavender)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 240),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CPlayLogo(size: 120, background: true),
        const SizedBox(height: 24),
        const Text('Your media, by voice',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text(
          'Add a folder of videos or music. Everything works offline.',
          textAlign: TextAlign.center,
          style: TextStyle(color: CP.textDim),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: CP.purple,
            foregroundColor: CP.black,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          onPressed: _scanning ? null : _addFolder,
          icon: const Icon(Icons.create_new_folder_rounded),
          label: const Text('Add a folder',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 28),
        const Text('Then try saying', style: TextStyle(color: CP.textDim)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          chip('play interstellar'),
          chip('skip forward 30 seconds'),
          chip('volume fifty'),
          chip('pause'),
        ]),
      ]),
    );
  }
}
