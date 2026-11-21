/// A parsed, typed request to do something. Produced by voice (or typed) input,
/// consumed by the [ActionRegistry]. UI buttons can build Intents too.
class Intent {
  const Intent(this.actionId, [this.args = const {}, this.raw = '']);

  final String actionId;
  final Map<String, Object?> args;
  final String raw;

  Intent withRaw(String raw) => Intent(actionId, args, raw);

  @override
  String toString() => '$actionId $args';
}

class ActionResult {
  const ActionResult(this.ok, this.message);
  final bool ok;
  final String message;
}
