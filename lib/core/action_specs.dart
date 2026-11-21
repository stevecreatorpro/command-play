/// Single source of truth for everything the user can do.
///
/// Rule: a feature does not ship unless it has an [ActionSpec] here with
/// example phrases. `test/nlu_test.dart` checks every example parses to its
/// action, and [ActionRegistry.missingHandlers] checks every spec is wired.
/// That is how "full voice parity" is enforced.
class ActionSpec {
  const ActionSpec(this.id, this.description, this.examples);
  final String id;
  final String description;
  final List<String> examples;
}

const kActionSpecs = <ActionSpec>[
  ActionSpec('play', 'Start or resume playback',
      ['play', 'resume', 'unpause']),
  ActionSpec('pause', 'Pause playback',
      ['pause', 'hold on', 'pause the video']),
  ActionSpec('stop', 'Stop playback',
      ['stop', 'stop playing', 'stop the music']),
  ActionSpec('next', 'Next track/episode',
      ['next', 'skip', 'next song', 'skip this song', 'go to the next track']),
  ActionSpec('previous', 'Previous track/episode',
      ['previous', 'previous track', 'play previous']),
  ActionSpec('seekRelative', 'Jump forward/back by an amount',
      ['skip forward 30 seconds', 'go back 10 seconds', 'rewind',
       'fast forward 1 minute']),
  ActionSpec('seekAbsolute', 'Jump to a position',
      ['go to the start', 'go to one hour five minutes', 'go to the middle',
       'go to 50 percent', 'restart']),
  ActionSpec('volumeSet', 'Set volume level',
      ['volume 40 percent', 'set volume to 80', 'volume to fifty']),
  ActionSpec('volumeDelta', 'Raise/lower volume',
      ['volume up', 'louder', 'turn it down', 'quieter']),
  ActionSpec('mute', 'Mute audio', ['mute', 'mute the sound', 'mute it']),
  ActionSpec('unmute', 'Unmute audio',
      ['unmute', 'unmute it', 'unmute the sound']),
  ActionSpec('speedSet', 'Set playback speed',
      ['normal speed', 'double speed', 'play at 1.5x', 'speed 1.5']),
  ActionSpec('speedDelta', 'Faster/slower',
      ['speed up', 'faster', 'slow down', 'slower']),
  ActionSpec('search', 'Find (and optionally play) media in the library',
      ['play thriller', 'find interstellar', 'search for holiday video',
       'play songs by burna boy']),
  ActionSpec('choose', 'Pick one of the listed search results',
      ['the second one', 'number three', 'play first']),
  ActionSpec('cancel', 'Dismiss the current result list',
      ['cancel', 'never mind', 'none of them']),
];
