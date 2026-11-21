import 'action_specs.dart';
import 'intent.dart';

typedef ActionHandler = Future<ActionResult> Function(Map<String, Object?> args);

/// Maps action ids to handlers. Voice, buttons, keyboard shortcuts and media
/// keys all go through [execute], so they can never drift apart.
class ActionRegistry {
  final Map<String, ActionHandler> _handlers = {};

  void register(String id, ActionHandler handler) => _handlers[id] = handler;

  /// Spec ids with no handler. Should be empty; asserted at startup.
  List<String> get missingHandlers =>
      [for (final s in kActionSpecs) if (!_handlers.containsKey(s.id)) s.id];

  Future<ActionResult> execute(Intent intent) async {
    final handler = _handlers[intent.actionId];
    if (handler == null) {
      return const ActionResult(false, 'That action is not available yet.');
    }
    try {
      return await handler(intent.args);
    } catch (e) {
      return const ActionResult(false, 'Sorry, that did not work.');
    }
  }
}
