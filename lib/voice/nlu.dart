import '../core/intent.dart';

const _ones = <String, int>{
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
  'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12,
  'thirteen': 13, 'fourteen': 14, 'fifteen': 15, 'sixteen': 16,
  'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
};
const _tens = <String, int>{
  'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60,
  'seventy': 70, 'eighty': 80, 'ninety': 90,
};
const _ordinals = <String, int>{
  'first': 1, 'second': 2, 'third': 3, 'fourth': 4, 'fifth': 5,
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
};

class _Num {
  _Num(this.value, this.start, this.end);
  final int value;
  final int start;
  final int end; // exclusive
}

List<_Num> _scanNumbers(List<String> tk) {
  final out = <_Num>[];
  var i = 0;
  while (i < tk.length) {
    var cur = 0;
    var any = false;
    var j = i;
    while (j < tk.length) {
      final w = tk[j];
      final d = int.tryParse(w);
      if (d != null) {
        cur += d;
        any = true;
      } else if (_ones.containsKey(w)) {
        cur += _ones[w]!;
        any = true;
      } else if (_tens.containsKey(w)) {
        cur += _tens[w]!;
        any = true;
      } else if (w == 'hundred' && any) {
        cur = cur == 0 ? 100 : cur * 100;
      } else {
        break;
      }
      j++;
    }
    if (any) {
      out.add(_Num(cur, i, j));
      i = j;
    } else {
      i++;
    }
  }
  return out;
}

int? _firstNumber(String t) {
  final n = _scanNumbers(t.split(' '));
  return n.isEmpty ? null : n.first.value;
}

/// "one hour five minutes" -> 3900 s. Null if no unit was found.
Duration? _parseDuration(String t) {
  var s = t.replaceAllMapped(RegExp(r'\bhalf an? (hour|minute)\b'),
      (m) => m[1] == 'hour' ? '30 minutes' : '30 seconds');
  s = s.replaceAllMapped(
      RegExp(r'\b(?:a|an) (hour|minute|second)'), (m) => '1 ${m[1]}');
  final tk = s.split(' ');
  var total = 0;
  var found = false;
  for (final n in _scanNumbers(tk)) {
    if (n.end >= tk.length) continue;
    final unit = tk[n.end];
    if (unit.startsWith('hour')) {
      total += n.value * 3600;
      found = true;
    } else if (unit.startsWith('min')) {
      total += n.value * 60;
      found = true;
    } else if (unit.startsWith('sec')) {
      total += n.value;
      found = true;
    }
  }
  return found ? Duration(seconds: total) : null;
}

String normalize(String s) {
  var t = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9. ]'), ' ');
  t = t.replaceAll(RegExp(r'\.(?!\d)'), ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t.replaceFirst(RegExp(r'^(?:hey|hi) (?:command )?play\b ?'), '');
  t = t.replaceFirst(RegExp(r'^(?:please|can you|could you|would you) '), '');
  t = t.replaceFirst(RegExp(r' please$'), '');
  return t.trim();
}

/// Rule-based, fully offline command parser. Ordered rules; first match wins.
/// Deterministic and fast; an optional on-device LLM can be added later as a
/// fallback that must output the same [Intent] schema.
class Nlu {
  Intent? parse(String input, {bool hasCandidates = false}) {
    final t = normalize(input);
    if (t.isEmpty) return null;
    final i = _parse(t, hasCandidates);
    return i?.withRaw(input);
  }

  Intent? _parse(String t, bool hasCandidates) {
    RegExpMatch? m;

    // --- result-list interaction -------------------------------------
    if (RegExp(r'^(cancel|never mind|nevermind|none of them|forget it)$')
        .hasMatch(t)) {
      return const Intent('cancel');
    }
    if (hasCandidates) {
      m = RegExp(r'^(?:(?:select|choose|play|open|number|the)\s+)*'
              r'(first|second|third|fourth|fifth|one|two|three|four|five)'
              r'(?:\s+one)?$')
          .firstMatch(t);
      if (m != null) return Intent('choose', {'index': _ordinals[m[1]!]});
    }

    // --- transport ----------------------------------------------------
    if (RegExp(r'^(pause|hold on|wait)( .*)?$').hasMatch(t)) {
      return const Intent('pause');
    }
    if (RegExp(r'^(stop|stop playing|stop the (video|music|song))$')
        .hasMatch(t)) {
      return const Intent('stop');
    }
    if (RegExp(r'^(play|resume|continue|unpause|start)'
            r'( (it|the video|the music|the song|playback|again|playing))?$')
        .hasMatch(t)) {
      return const Intent('play');
    }
    if (RegExp(r'^(restart|start over|play from the beginning|'
            r'from the beginning)$')
        .hasMatch(t)) {
      return const Intent('seekAbsolute', {'ms': 0});
    }

    // --- next / previous ---------------------------------------------
    if (RegExp(r'^(skip|next)$').hasMatch(t) ||
        RegExp(r'^skip (this|it)( song| track| one)?$').hasMatch(t) ||
        RegExp(r'^(?:go to |skip to |play )?(?:the )?next'
                r'(?: (?:song|track|episode|video|one|file))?$')
            .hasMatch(t)) {
      return const Intent('next');
    }
    if (RegExp(r'^(?:go to |skip to |play )?(?:the )?(?:previous|prev)'
            r'(?: (?:song|track|episode|video|one|file))?$')
        .hasMatch(t)) {
      return const Intent('previous');
    }

    // --- absolute seek -----------------------------------------------
    if (RegExp(r'^(?:go|jump|seek|skip)(?: back)? to (?:the )?'
            r'(?:start|beginning)')
        .hasMatch(t)) {
      return const Intent('seekAbsolute', {'ms': 0});
    }
    if (RegExp(r'^(?:go|jump|seek|skip) to (?:the )?end').hasMatch(t)) {
      return const Intent('seekAbsolute', {'fraction': 0.999});
    }
    if (RegExp(r'^(?:go|jump|seek|skip) to (?:the )?(?:middle|half ?way)')
        .hasMatch(t)) {
      return const Intent('seekAbsolute', {'fraction': 0.5});
    }
    if (RegExp(r'^(?:go|jump|seek|skip) to ').hasMatch(t)) {
      if (t.contains(' percent')) {
        final n = _firstNumber(t);
        if (n != null) {
          return Intent('seekAbsolute', {'fraction': (n / 100).clamp(0.0, 1.0)});
        }
      }
      final d = _parseDuration(t);
      if (d != null) return Intent('seekAbsolute', {'ms': d.inMilliseconds});
    }

    // --- relative seek -----------------------------------------------
    if (RegExp(r'^(skip|go|jump|seek|fast forward|forward|rewind|back|'
            r'backward|fast)\b')
        .hasMatch(t)) {
      final back = RegExp(r'\b(back|backward|backwards|rewind|earlier)\b')
          .hasMatch(t);
      final fwd =
          RegExp(r'\b(forward|forwards|ahead|skip|jump|fast|later)\b')
              .hasMatch(t);
      if (back || fwd) {
        final secs = _parseDuration(t)?.inSeconds ?? _firstNumber(t) ?? 10;
        return Intent('seekRelative', {'seconds': back ? -secs : secs});
      }
    }

    // --- volume -------------------------------------------------------
    final little = RegExp(r'\b(a bit|a little|slightly)\b').hasMatch(t);
    if (RegExp(r'^(?:volume up|louder|turn (?:it )?up|'
            r'(?:increase|raise) (?:the )?volume|more volume)(?: .*)?$')
        .hasMatch(t)) {
      return Intent('volumeDelta', {'delta': little ? 5 : 10});
    }
    if (RegExp(r'^(?:volume down|quieter|softer|turn (?:it )?down|'
            r'(?:lower|decrease|reduce) (?:the )?volume|less volume)(?: .*)?$')
        .hasMatch(t)) {
      return Intent('volumeDelta', {'delta': little ? -5 : -10});
    }
    m = RegExp(r'^(?:set )?(?:the )?volume (?:to |at )?(.+)$').firstMatch(t);
    if (m != null) {
      final n = _firstNumber(m[1]!);
      if (n != null) return Intent('volumeSet', {'percent': n.clamp(0, 100)});
    }
    if (RegExp(r'^unmute\b').hasMatch(t)) return const Intent('unmute');
    if (RegExp(r'^mute\b').hasMatch(t)) return const Intent('mute');

    // --- speed --------------------------------------------------------
    if (RegExp(r'^(?:speed up|faster|play faster)$').hasMatch(t)) {
      return const Intent('speedDelta', {'delta': 0.25});
    }
    if (RegExp(r'^(?:slow down|slower|play slower)$').hasMatch(t)) {
      return const Intent('speedDelta', {'delta': -0.25});
    }
    if (RegExp(r'^(?:normal|regular|reset) speed$').hasMatch(t)) {
      return const Intent('speedSet', {'speed': 1.0});
    }
    if (t == 'double speed') return const Intent('speedSet', {'speed': 2.0});
    if (t == 'half speed') return const Intent('speedSet', {'speed': 0.5});
    m = RegExp(r'^play at (\d+(?:\.\d+)?) ?x$').firstMatch(t) ??
        RegExp(r'^speed (?:to )?(\d+(?:\.\d+)?)$').firstMatch(t) ??
        RegExp(r'^(?:set )?(\d+(?:\.\d+)?) ?(?:x|times)? speed$').firstMatch(t);
    if (m != null) {
      return Intent('speedSet', {'speed': double.parse(m[1]!)});
    }

    // --- library search (last: it is the catch-all "play <name>") ------
    m = RegExp(r'^(play|open|find|search for|search|show me|show) (.+)$')
        .firstMatch(t);
    if (m != null) {
      var q = m[2]!.replaceFirst(
          RegExp(r'^(?:the )?(?:file|song|video|movie|track|album|folder|'
              r'songs|music|videos)(?: named| called| by)? '),
          '');
      q = q.trim();
      if (q.isNotEmpty) {
        return Intent('search', {'query': q, 'play': m[1] == 'play'});
      }
    }
    return null;
  }
}
