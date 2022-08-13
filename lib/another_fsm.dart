library another_fsm;

import 'dart:async';
import 'dart:collection';

abstract class FsmOwner {
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
  final Queue _transactions = Queue<_FsmTransaction>();

  Fsm({required FsmOwner owner}) : _owner = owner;

  /// Transitions the FSM to the next state and exist the previous one.
  Future<void> changeState({FsmState? nextState}) async {
    // Note: This needs to fully complete before we handle any events.
    Completer completer = Completer();
    _FsmTransaction transaction = _FsmTransaction<void, FsmState>(name: "TransChangeState-$_currentState-$nextState",action: _changeState, completer: completer, value: nextState);
    await _scheduleTransaction(transaction: transaction);
    return completer.future;
  }

  Future<void> _changeState(FsmState? nextState) async {
    // Note: This needs to fully complete before we handle any events.
    await _currentState?.onExit(owner: _owner);
    _currentState = nextState;
    await nextState?.onEnter(owner: _owner);
  }

  Future<void> update({required int time}) async {
    // TODO Add transaction on update too.
    await _currentState?.onUpdate(owner: _owner, time: time);
  }

  /// Send event to current state for handling.
  Future<bool> handleEvent({required FsmEvent event}) async {
    Completer<bool> completer = Completer();
    _FsmTransaction transaction = _FsmTransaction<bool, FsmEvent>( name: "TransHandleEvent-$event", action:_handleEvent, completer: completer, value: event);
    await _scheduleTransaction(transaction: transaction);
    return completer.future;
  }

  Future<bool> _handleEvent(FsmEvent event) async {
    return await getCurrentState()?.onEvent(event: event, owner: _owner) ?? false;
  }

  FsmState? getCurrentState() => _currentState;

  Future<void> _scheduleTransaction({required _FsmTransaction transaction}) async{
    bool empty = _transactions.isEmpty;
    _transactions.addLast(transaction);
    if (empty) {
      _executeNext();
    }
  }

  Future<void> _executeNext() async {
    if (_transactions.isNotEmpty) {
      _FsmTransaction next = _transactions.first;
      next.execute().then((value) {
        _transactions.removeFirst();
          _executeNext();
      });
    }
  }
}

class _FsmTransaction<T,V> {
  String name;
  Future<T> Function(V value) action;
  Completer<T> completer;
  dynamic value;
  _FsmTransaction({required this.name, required this.action, required this.completer, this.value});

  Future execute() async {
    T result;
    result = await action(value);
    completer.complete(result);
  }

  @override
  String toString() => name;
}
