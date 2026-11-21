# Command Play — Offline, Fully Voice-Controlled Media Player (Mobile + PC)

> Product & technical specification, built from research on what the best media players offer and which technologies make fully offline voice control practical.
> Note: compiled from established knowledge of the players and libraries named below. Library versions, licences and platform API limits change, so verify them before committing to a dependency.

---

## 1. Vision

A media player for **Android, iOS, Windows, macOS and Linux** where *everything* — finding a file, browsing folders, playing, seeking, adjusting video/audio, managing playlists, changing settings — can be done by speaking. It works **100% offline**: speech recognition, command understanding, library search and playback all run on-device, with no account and no network.

**Design principles**
1. **Voice is a first-class input**, not an add-on. Every action reachable by touch/mouse/keyboard has a voice command.
2. **Offline by default.** No feature depends on a server. Privacy follows from this: audio never leaves the device.
3. **Fast and forgiving.** Commands should act in under ~500 ms, tolerate mis-heard words (fuzzy matching), and be undoable.
4. **Hands-free *and* eyes-free.** Spoken feedback (TTS) and large visual feedback so it works while cooking, driving (audio only), exercising, or for users with motor/visual impairments.
5. **Never hurt playback.** Voice listening must not stop or glitch media, and the player must not mistake its own audio for commands.

---

## 2. Research: Features of the best media players

Reference players studied: **VLC, mpv, MPC-HC/MPC-BE, PotPlayer, Kodi, Plex/Plexamp, foobar2000, MX Player, Poweramp, AIMP, Apple Music/QuickTime/Infuse, Windows Media Player/Media Player (Win11), YouTube Music/Spotify (UX reference).**

### 2.1 Playback core
| Feature | Notes |
|---|---|
| Play / pause / stop / resume | Resume-from-last-position per file |
| Seek: relative (±5/10/30/60 s), absolute (go to 1:23:45), percentage, chapter jump | Frame-accurate and keyframe seek |
| Frame-by-frame step forward/back | Video analysis, VLC/mpv/MPC-HC |
| Playback speed 0.25×–4× with pitch correction | Podcasts, lectures |
| A–B loop, repeat one/all, shuffle | |
| Next/previous track/episode, queue, "play next", "add to queue" | |
| Gapless playback & crossfade | foobar2000, Poweramp |
| Volume, mute, volume normalisation (ReplayGain, loudness), >100% boost | |
| Sleep timer, "stop after this track" | |
| Resume playback after calls/headphone disconnect (audio focus handling) | Mobile essential |
| Background playback, lock-screen/notification controls, media-key & Bluetooth/headset button support | MediaSession (Android), MPRemoteCommandCenter (iOS), SMTC (Windows), MPRIS (Linux) |
| Picture-in-picture, floating/mini player | MX Player, VLC |
| Casting / DLNA / AirPlay / Chromecast | Optional; network-dependent, so keep as add-on |

### 2.2 Video-specific
- **Subtitles:** SRT/ASS/SSA/VTT/embedded PGS; on/off, track select, delay sync (±ms), size/colour/position/background; auto-detect sidecar files; embedded font support.
- **Audio tracks:** switch language/commentary; audio delay sync; audio-only mode.
- **Video adjustments:** brightness, contrast, saturation, hue, gamma; aspect ratio (16:9, 4:3, fill, fit, stretch, crop); zoom/pan; rotate/flip; deinterlace; HDR tone-mapping.
- **Hardware decoding:** MediaCodec (Android), VideoToolbox (Apple), DXVA2/D3D11VA/NVDEC (Windows), VAAPI/VDPAU (Linux). Fall back to software.
- **Chapters, thumbnails on seek bar, screenshot capture, clip/GIF export.**
- **Gestures (mobile):** swipe for seek/volume/brightness, double-tap seek, long-press 2× speed, pinch-zoom (MX Player UX).

### 2.3 Audio-specific
- Equaliser (10-band + presets), bass boost, virtualiser, preamp, balance, **parametric EQ / DSP chain** (Poweramp, foobar2000).
- Tag reading (ID3v2, Vorbis, MP4/iTunes, APE), embedded & folder cover art, **synced lyrics (LRC)** and embedded lyrics.
- Visualisers/waveforms (optional polish).
- Format breadth: MP3, AAC/M4A, FLAC, ALAC, WAV, OGG/Opus, WMA, APE, DSD (optional), AC3/DTS passthrough.

### 2.4 Library & discovery
- Library scan of selected folders; watch for changes; handle SD cards/USB/removable media.
- Browse by folder, artist, album, genre, year, recently added, most played, favourites, "continue watching".
- Fast search over filename + metadata (+ subtitles/lyrics optionally).
- Playlists (create/edit/export M3U/PLS), smart playlists, history, ratings, favourites.
- Offline metadata: embedded tags only by default; optional locally-cached posters/metadata pack (Kodi/Plex use online scrapers — those are optional online enhancers only).

### 2.5 Format & container support
Strategy: embed **FFmpeg-based** decoding (libVLC / libmpv / libavcodec) for broad coverage: MP4, MKV, AVI, MOV, WEBM, FLV, TS, 3GP, HEVC/H.265, H.264, AV1, VP9, MPEG-2, plus all audio above. Platform-native decoders (ExoPlayer/AVFoundation) for efficiency where available.

### 2.6 Settings, UX & accessibility
- Themes (dark/AMOLED/light), resume prompts, parental lock, remember per-file settings (audio track, subtitle, zoom).
- Keyboard shortcuts on PC (MPC-HC/mpv are the benchmark), customisable.
- Accessibility: screen-reader labels, large text, high contrast, switch access — voice control is itself a major accessibility feature.

### 2.7 Gaps in existing players (the opportunity)
- **VLC/mpv/Kodi:** no real voice control. 
- **Phone assistants (Google Assistant, Siri, Alexa):** voice-capable but *mostly online*, limited to play/pause/next and cannot navigate arbitrary local files, set subtitle delay, A–B loop, etc.
- **Windows Voice Access / macOS Voice Control:** generic "click that button" control — clunky for media, not semantic.
- **Result:** no player offers *semantic, complete, offline* voice control of local media. That is Command Play's niche.

---

## 3. Research: Voice-control technology (offline)

### 3.1 Pipeline
```
Mic → VAD → (Wake word / push-to-talk) → Offline STT → Intent parser → Action executor → Player core
                                                              ↑                         ↓
                                                    Library index / context        TTS + UI feedback
```

### 3.2 Offline speech-to-text options
| Engine | Platforms | Licence | Pros | Cons |
|---|---|---|---|---|
| **Vosk** (Kaldi) | Android, iOS, Win, Mac, Linux, RPi | Apache-2.0 | Small models (~50 MB), streaming, **supports custom grammar/vocabulary lists** (huge accuracy boost for commands), 20+ languages | Lower accuracy than Whisper on open dictation |
| **sherpa-onnx** (k2-fsa) | Android, iOS, Win, Mac, Linux, Flutter/React Native bindings | Apache-2.0 | Streaming zipformer models, keyword spotting, VAD, TTS, speaker ID in one toolkit; very fast | Newer, model selection needs care |
| **whisper.cpp / faster-whisper** (OpenAI Whisper) | All | MIT | Best accuracy, 99 languages, handles accents and noisy audio | Not natively streaming; "tiny/base/small" needed on phones; higher latency/battery; may hallucinate on silence |
| **Android `SpeechRecognizer` (on-device)** / **iOS `SFSpeechRecognizer` with `requiresOnDeviceRecognition`** / **Windows speech recognition (offline packs)** | Native | OS | Zero extra size, well-tuned | Offline language packs must be downloaded by user; behaviour varies by OS version/device; iOS/Android may stop recognition after sessions |
| **Picovoice Rhino / Cheetah** | All | Commercial/free tier | Speech-to-intent, very low latency | Proprietary, licence/limits |

**Recommendation:** Use **two tiers**
1. **Command mode (default):** streaming Vosk or sherpa-onnx with a **constrained grammar + dynamic vocabulary** (command verbs + titles/artists/folders from the user's library). This gives high accuracy and low latency for the 95% case.
2. **Free-form mode (fallback):** Whisper `base`/`small` quantised (whisper.cpp) when the constrained recogniser's confidence is low or the user asks something unconstrained (e.g. long title search). Users on low-end devices can disable it.

### 3.3 Wake word (hands-free activation)
- **openWakeWord** (Apache-2.0, trainable), **Porcupine** (commercial, best accuracy/battery, custom word like "Hey Play"), or sherpa-onnx keyword spotting.
- Modes: **always listening (wake word)**, **push-to-talk** (button/hotkey/headset button), **tap-to-talk**, and **"continuous command mode"** (stays open for ~8 s after a command so the user can chain "louder… louder… skip ahead").
- Battery: run wake-word on the lowest-power path (Android foreground service with mic type; iOS has strict background-audio rules → push-to-talk/headset button fallback on iOS when app is backgrounded).

### 3.4 Understanding commands (NLU) — offline
1. **Rule/grammar-based intent matcher** (primary): deterministic and fast. Patterns with slots: `{verb} {object} {amount}`.
2. **Fuzzy & phonetic entity resolution** for file/artist names: speech engines mis-spell names ("Kendrick Lamar" → "kendrick la mar"). Use SQLite **FTS5** + trigram/Levenshtein (e.g. RapidFuzz) + **phonetic keys** (Double Metaphone/Soundex or G2P-based) against the index.
3. **Synonym & paraphrase table** ("skip", "next", "jump to next", "go forward one song").
4. **Optional small on-device LLM** (e.g. 0.5–3B quantised via llama.cpp / MLC) for free-form phrasing ("play something upbeat from last year's trip") — *optional*, behind a toggle, because of size/battery. Constrain the LLM to output a JSON intent from the fixed schema; never let it execute arbitrary actions.
5. **Number/time parsing**: "one hour twenty minutes", "ninety seconds", "half way", "in a minute and a half".
6. **Context memory:** "play it again", "skip that", "more", "louder" resolve relative to current state and last command.
7. **Confidence handling:** high → execute; medium → execute reversible actions and say what was done; low → ask a short disambiguation ("Did you mean *Interstellar* or *Interstellar 2*?"), selectable by "first / second / number two".

### 3.5 Feedback
- **Offline TTS:** native OS TTS (Android TextToSpeech, AVSpeechSynthesizer, Windows SAPI/OneCore) or **Piper / sherpa-onnx TTS** for consistent offline voices.
- Short earcons (listening, understood, error) so voice feedback does not clash with content.
- On-screen transcript, "heard: …", and a command history with undo.

### 3.6 Hard problems & mitigations
| Problem | Mitigation |
|---|---|
| Player's own audio triggers/false-commands | Acoustic echo cancellation (platform AEC / WebRTC AEC), **duck volume while listening** (not pause), wake-word-only listening while playing, raise wake threshold, near-field headset mode |
| Noisy rooms / far-field | Noise suppression (RNNoise), push-to-talk fallback, headset mic |
| Non-English / accent / code-switching | Multi-language model packs, per-user language setting, Whisper fallback, user-defined aliases ("call this folder 'gym music'") |
| Names in other languages | Phonetic matching + alias learning: remember corrections |
| Battery drain from always-on mic | Tiny wake-word model, VAD gating, adaptive sleep, user-selectable mode |
| Privacy | No audio stored by default; visible mic indicator; on-device only; optional "debug audio" opt-in |
| Latency | Streaming STT; keep models memory-resident; pre-build grammar from library on scan |
| Accidental destructive actions | Confirmation for delete/overwrite; undo for last N actions; no delete without explicit setting |
| OS restrictions (iOS background mic, Android 14+ mic foreground-service rules, Windows/macOS mic permissions) | Design per-platform listening modes; clearly onboard permissions |

---

## 4. Voice command catalogue (target: every action)

Commands are examples; each has multiple phrasings and localisations. Wake word omitted for brevity ("Hey Play, …").

### 4.1 Playback
- **Play / pause / stop / resume / restart / "start over"**
- **Seek:** "skip forward 30 seconds", "go back 10", "jump to 1 hour 5 minutes", "go to the middle", "go to 75 percent", "go to the end", "go to the start"
- **Chapters/tracks:** "next / previous chapter", "next episode", "previous song", "go to chapter 3", "play track 5"
- **Frame step:** "next frame", "back one frame", "freeze frame"
- **Speed:** "speed up", "slower", "play at 1.5 speed", "normal speed", "double speed"
- **Loop/shuffle:** "repeat this song", "repeat all", "loop from here to 2 minutes", "set A", "set B", "clear loop", "shuffle on/off"
- **Sleep timer:** "stop in 30 minutes", "stop after this episode"
- **Bookmarks:** "bookmark this", "go to my bookmark", "resume where I left off"

### 4.2 Volume & audio
- "volume up/down", "volume 40 percent", "mute/unmute", "louder/quieter a bit"
- "boost the volume", "normalise volume", "night mode"
- "switch audio to Spanish", "next audio track", "audio delay plus 200 milliseconds"
- Equaliser: "equalizer rock", "more bass", "reset equalizer"

### 4.3 Video & display
- "full screen", "exit full screen", "mini player", "picture in picture"
- "rotate screen", "aspect ratio 16 by 9", "zoom in", "fit to screen", "crop"
- "brightness up/down", "increase contrast", "reset video settings"
- "take a screenshot", "clip the last 10 seconds"
- **Subtitles:** "subtitles on/off", "subtitles English", "next subtitle track", "subtitles earlier by half a second", "bigger subtitles", "load subtitles from the movie folder"
- "show info", "what's playing", "how much time is left", "what time is it in the video"

### 4.4 Search & navigation of files
- **By name:** "play Interstellar", "play the file named holiday video"
- **By metadata:** "play songs by Burna Boy", "play album Love Damini", "play jazz from 2019", "play my most played"
- **By type/place/date:** "show videos from last week", "open the Downloads folder", "go into Movies", "go back", "go up one level", "show the first ten files"
- **By recency/state:** "continue watching", "play the last thing I watched", "play something I haven't finished"
- **By content (optional index):** "find the video where they mention budget" (searches subtitles/lyrics/transcripts built offline)
- **List interaction:** "select the third one", "next page", "scroll down", "read the list", "play all", "add to queue", "play next"
- **Disambiguation:** "the second one", "the one with the red cover", "no, the other one", "cancel"

### 4.5 Playlists & library
- "create playlist Gym", "add this to Gym", "remove this from playlist", "play playlist Gym", "shuffle playlist Gym"
- "favourite this", "rate this five stars", "show favourites", "clear queue", "what's next in the queue"
- "rescan library", "add folder Music/New", "hide this folder"
- "delete this file" (**requires confirm** + optional disable)

### 4.6 App & system
- "open settings", "dark mode", "change language to French", "teach me the commands", "what can I say?", "read help"
- "stop listening", "start listening", "be quiet" (disable voice feedback), "speak more slowly"
- "undo", "repeat that", "cancel"
- Custom aliases: "when I say 'movie night', play folder Movies/Family and turn subtitles on" (user-defined macros).

---

## 5. Product requirements

### 5.1 Functional (MVP → v1)
| ID | Requirement | Priority |
|---|---|---|
| F1 | Play local audio/video of common formats on all platforms | Must |
| F2 | Offline STT with command grammar; ≥95% command accuracy in quiet conditions | Must |
| F3 | Voice search across indexed library (name + tags) with fuzzy/phonetic match | Must |
| F4 | Full transport control by voice (§4.1) | Must |
| F5 | Volume/audio/subtitle/video adjustments by voice (§4.2–4.3) | Must |
| F6 | Voice file-system navigation with spoken & visual list feedback | Must |
| F7 | Wake word + push-to-talk + continuous mode | Must |
| F8 | Works fully in airplane mode (verified by test) | Must |
| F9 | Voice playlists, queue, favourites, bookmarks | Should |
| F10 | Multi-language (English first; then French, Spanish, Portuguese, Arabic, Hindi, Yoruba/Igbo/Hausa as model availability allows) | Should |
| F11 | User-defined aliases/macros | Should |
| F12 | Content search via subtitles/lyrics/offline transcripts | Could |
| F13 | Optional on-device LLM for free-form phrasing | Could |
| F14 | Cast/DLNA (network add-on; core stays offline) | Could |

### 5.2 Non-functional
- **Latency:** wake→action ≤ 700 ms typical (command grammar), ≤ 2 s (Whisper fallback).
- **Footprint:** base app ≤ 150 MB incl. one language model; extra language packs downloadable *before* going offline or sideloaded from storage/USB.
- **Battery:** wake-word listening ≤ ~3–5%/hour on mid-range phone (target).
- **Privacy:** no network permission needed for core features; no analytics by default.
- **Reliability:** playback unaffected by voice-engine crash (isolated process/isolate).
- **Accessibility:** WCAG 2.2 AA UI; full TalkBack/VoiceOver/Narrator labels.

### 5.3 Offline-first contract
"Offline" means: no internet needed for install-time-downloaded models, library scan, search, STT, intents, TTS, playback, subtitles (local files + embedded), lyrics (embedded/local LRC), settings and updates are the *only* things that use network, and are optional. Model packs can be installed from a file so a user who never goes online still gets everything.

---

## 6. Recommended architecture

### 6.1 Stack options
| Option | Playback | Voice | UI | Verdict |
|---|---|---|---|---|
| **A. Flutter (recommended)** | `media_kit` (libmpv, FFmpeg, hardware decode on all 5 OSes) | sherpa-onnx / Vosk via FFI; whisper.cpp via FFI | Flutter (single UI codebase mobile+desktop) | One codebase, strong media backend, FFI to native voice libs |
| B. Native per platform | ExoPlayer/Media3 (Android), AVPlayer (iOS/macOS), libmpv/LibVLC (Win/Linux) | Native speech + Vosk | Kotlin / Swift / WinUI | Best polish & OS integration, 3× the work |
| C. Tauri/Electron + React Native | libmpv/LibVLC bindings | WASM/native Whisper/Vosk | Web tech | Heavier or fragmented; weaker mobile media story |
| D. Qt/QML (C++) | libmpv/LibVLC | Vosk/sherpa C++ | QML | Excellent desktop, mobile is workable but less common |

**Choose A (Flutter + media_kit + sherpa-onnx/Vosk + SQLite FTS5)** unless the team is strongly native.
If licensing matters: libmpv/FFmpeg builds can be GPL/LGPL — use an LGPL build and dynamic linking for app-store distribution; LibVLC is LGPL; Vosk/sherpa/whisper.cpp are permissive.

### 6.2 Module diagram
```
┌────────────────────────────── UI Layer (Flutter) ─────────────────────────────┐
│ Now Playing • Library • Voice HUD (mic, transcript, candidates) • Settings    │
└───────────────┬───────────────────────────────┬──────────────────────────────┘
                │ state (Riverpod/Bloc)         │ commands
┌───────────────▼───────────┐         ┌─────────▼──────────────────────────────┐
│ Playback Service          │◄────────│ Command Bus / Action Registry           │
│ media_kit/libmpv          │         │ (single typed API: every UI and voice   │
│ MediaSession/SMTC/MPRIS   │         │  action goes through the same registry) │
└───────────────┬───────────┘         └─────────▲──────────────────────────────┘
                │                               │ Intent{name, slots, confidence}
┌───────────────▼───────────┐         ┌─────────┴──────────────────────────────┐
│ Library Service          │◄────────│ Voice Service (separate isolate/thread) │
│ scanner • tags • SQLite   │ queries │ audio capture→AEC/NS→VAD→wake→STT→NLU  │
│ FTS5 + phonetic index     │────────►│ dynamic grammar from library • TTS      │
└───────────────────────────┘ vocab   └─────────────────────────────────────────┘
```

**Key idea — Action Registry:** every capability (`seekRelative`, `setSubtitleDelay`, `openFolder`, …) is registered once with a name, typed parameters, and spoken phrases. The UI buttons, keyboard shortcuts, media keys and voice all call the same registry. This guarantees *full voice parity* by construction — a feature without a registry entry cannot ship (enforced by test).

### 6.3 Data model (SQLite)
- `media(id, path, type, title, artist, album, genre, year, duration, size, added_at, play_count, last_played, position_ms, rating, favourite, content_hash)`
- `media_fts` (FTS5 over title/artist/album/path tokens) + `phonetic_keys(media_id, key)`
- `playlist`, `playlist_item`, `queue`, `bookmark`, `history`
- `alias(spoken, target_type, target_id | macro_json)`
- `track_prefs(media_id, audio_track, subtitle_track, sub_delay, audio_delay, zoom, speed)`
- `subtitle_index` (optional, FTS5 over cue text for content search)

### 6.4 Dynamic vocabulary build
After each scan: extract distinct words from titles/artists/folders → add to STT vocabulary/grammar (Vosk supports runtime grammar; for sherpa-onnx use hotwords/contextual biasing) → improves recognition of unusual names. Large libraries (>50k items): bias only top-N recent/frequent items + do a second-pass fuzzy match on the raw transcript against the full FTS index.

### 6.5 Platform integration
| Platform | Background/lock-screen | Notes |
|---|---|---|
| Android | `MediaSessionCompat`/Media3 + foreground service; mic foreground-service type for wake word | Permissions: `RECORD_AUDIO`, `READ_MEDIA_*`/SAF for folders, notification |
| iOS | `AVAudioSession` (playAndRecord, duckOthers), `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter` | Always-on wake word in background is restricted → push-to-talk, headset button, Siri Shortcuts ("Hey Siri, Command Play listen") as bridges |
| Windows | SMTC, WASAPI AEC, global hotkey | Mic privacy toggle handling |
| macOS | Now Playing, global hotkey, sandbox mic entitlement | |
| Linux | MPRIS, PipeWire/PulseAudio AEC | |

---

## 7. UX specification

- **Voice HUD:** a small, non-intrusive overlay: mic state (idle/listening/thinking), live transcript, parsed action chip ("Seek +30 s"), undo button. Auto-fades.
- **Spoken results navigation:** when a search yields multiple results, show **numbered cards** and speak "I found 3. One, Interstellar 2014. Two…" — user says "two". Pagination by voice.
- **First-run onboarding:** pick folders (or "scan everything"), choose language/model, mic permission, 60-second "try saying…" tutorial, choose activation mode.
- **Discoverability:** "What can I say?" shows context-aware examples (different in library vs. video playing). Hints on idle screens.
- **Error handling:** never say "error"; offer help: "I didn't catch that. Try 'play' followed by a name."
- **Privacy UI:** persistent mic indicator, one-tap hard mute, "Offline mode ✓" badge.
- **Touch/keyboard remain** fully functional — voice is additive.

---

## 8. Testing & quality

- **Command accuracy suite:** recorded utterances (multiple accents, ages, noise levels, speaking-while-media-plays) → intent F1 target ≥ 0.95 for core commands. Use public datasets (e.g. Mozilla Common Voice, Fluent Speech Commands, Google Speech Commands) plus self-collected audio.
- **Echo test rig:** play loud content while issuing commands at varied distances.
- **Offline test:** CI step and manual: airplane mode, firewall-blocked, no DNS → run the full feature checklist.
- **Parity test:** automated check that every registry action has ≥3 voice phrasings and a UI path.
- **Fuzzy search tests:** misspellings, phonetic variants, long library (100k files).
- **Battery & thermal profiling** for wake-word.
- **Device matrix:** low-end Android (3 GB RAM), mid/high Android, iPhone (recent −2 generations), Windows 10/11, macOS (Intel/ARM), Ubuntu.
- **Security/privacy review:** no network calls in core path (instrument and assert).

---

## 9. Delivery roadmap

| Phase | Scope | Rough effort* |
|---|---|---|
| **0. Prototype (2–3 wks)** | Flutter + media_kit playing files; push-to-talk with Vosk; 10 commands (play/pause/seek/volume/search by title) | 1–2 devs |
| **1. MVP (2–3 mo)** | Library scanner + FTS5; full transport/volume/subtitle/audio-track voice commands; folder navigation; numbered disambiguation; TTS feedback; Android + Windows | 2–3 devs |
| **2. v1.0 (2–3 mo)** | iOS, macOS, Linux; wake word; continuous mode; playlists/queue/bookmarks; EQ; PiP; aliases; Whisper fallback; localisation (3–5 languages); accessibility audit | 3–4 devs |
| **3. v1.x** | Content search (subtitle/lyric index), optional on-device LLM, macros, casting add-on, custom wake word, personalised acoustic adaptation | ongoing |

*Order-of-magnitude estimates only.

---

## 10. Risks & open decisions

| Risk / decision | Notes |
|---|---|
| iOS background listening limits | Fall back to push-to-talk/headset button/Siri Shortcut |
| Model size vs. accuracy | Ship small default model; offer "high accuracy" download or sideload |
| Licences (FFmpeg/libmpv GPL vs LGPL, codec patents e.g. HEVC/AAC) | Legal review before store release; LGPL builds; rely on OS decoders where licensing is a concern |
| Wake word licensing (Porcupine commercial) | Prefer openWakeWord/sherpa KWS if open-source required |
| Accents and under-served languages (e.g. Nigerian English, Yoruba, Igbo, Hausa) | Evaluate Whisper/fine-tuned sherpa models; user-correctable aliases; collect consenting data for fine-tuning |
| Voice false triggers from content dialogue | Wake-word-only while playing + AEC + ducking |
| Scope creep | Keep the action registry as the single source of truth; add features only with voice parity |

**Decisions to confirm with you**
1. Target languages for launch (English only vs. additional).
2. Wake-word phrase and always-listening vs. push-to-talk default.
3. Flutter vs. fully native stack.
4. Open-source vs. proprietary (affects GPL/LGPL choices).
5. Whether the optional on-device LLM is in scope for v1.

---

## 11. Suggested tech shortlist (quick reference)

| Need | Pick | Alternatives |
|---|---|---|
| App framework | **Flutter** | Kotlin/Swift native, Qt |
| Playback | **media_kit (libmpv/FFmpeg)** | LibVLC, ExoPlayer/AVPlayer, GStreamer |
| STT (command mode) | **Vosk / sherpa-onnx** (streaming + grammar) | Native on-device recognisers |
| STT (fallback) | **whisper.cpp** (tiny/base/small, quantised) | faster-whisper (desktop) |
| Wake word | **openWakeWord / sherpa KWS** | Porcupine |
| VAD / noise | **Silero VAD, RNNoise, platform AEC** | WebRTC VAD |
| NLU | **Rule/grammar + RapidFuzz + Double Metaphone** | Small LLM (llama.cpp) for free-form |
| Storage/search | **SQLite + FTS5** | Isar/ObjectBox + custom index |
| Metadata | **TagLib / FFprobe (ffmpeg_kit)** | audiotags, mutagen-like libs |
| TTS | **Piper / sherpa-onnx TTS, native OS TTS** | |
| Subtitles | libmpv built-in (libass) | custom renderer |

---

## 12. One-paragraph summary

Command Play combines the feature set of the best players (VLC/mpv/MPC/MX/Poweramp/foobar2000 — formats, seeking, speed, subtitles, tracks, EQ, playlists, resume, PiP, media-session integration) with a **fully offline voice layer**: wake-word/push-to-talk → streaming on-device STT biased to the user's own library → rule-based intent parser with fuzzy/phonetic file search → a single **action registry** that guarantees every function is voice-controllable. Built with Flutter + libmpv + Vosk/sherpa-onnx + SQLite FTS5, it fills a gap no current player covers: complete, private, offline voice control of local media on both phones and PCs.
