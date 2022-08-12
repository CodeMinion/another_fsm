library another_fsm;


abstract class FsmOwner{
  Fsm? getFsm();
  Future<bool> handleEvent({required FsmEvent event});
}

/// Base class for all events handled by the FSM
abstract class FsmEvent {}

/// Represents a single state in the FSM. The logic for that state
/// will be contained here.
abstract class FsmState {

  /// Called when transitioning into the state.
  Future<void> onEnter({required FsmOwner owner});

  /// Called during every update.
  Future<void> onUpdate({required FsmOwner owner, required int time});

  /// Called when transitioning out of the state.
  Future<void> onExit({required FsmOwner owner});

  /// Called when an event is received by the FSM
  Future<bool> onEvent({required FsmEvent event, required FsmOwner owner});

}

/// Handles the state transitions and forwaring of events to
/// the fsm.
class Fsm {
  final FsmOwner _owner;
  FsmState? _currentState;

  Fsm({required FsmOwner owner}):_owner = owner;

  /// Transitions the FSM to the next state and exist the previous one.
  Future<void> changeState({FsmState? nextState}) async {
    _currentState?.onExit(owner: _owner);
    _currentState = nextState;
    _currentState?.onEnter(owner: _owner);
  }

  Future<void> update({required int time}) async {
    await _currentState?.onUpdate(owner: _owner, time: time);
  }

  /// Send event to current state for handling.
  Future<bool> handleEvent({required FsmEvent event}) async {
    return await _currentState?.onEvent(event:event, owner: _owner) ?? false;
  }

  FsmState? getCurrentState() => _currentState;
}
