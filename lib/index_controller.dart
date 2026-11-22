import 'dart:async';

import 'package:flutter/foundation.dart';

class IndexController extends ChangeNotifier {
  static const int NEXT = 1;
  static const int PREVIOUS = -1;
  static const int MOVE = 0;

  IndexController([this.index = 0]);

  int index;
  bool animation = true;
  int? event;
  Completer<void>? _pending;

  /// Completes when the move finishes or a newer command replaces it.
  Future<void> move(int index, {bool animation = true}) {
    this.index = index;
    return _dispatch(MOVE, animation);
  }

  /// Completes when the move finishes or a newer command replaces it.
  Future<void> next({bool animation = true}) => _dispatch(NEXT, animation);

  /// Completes when the move finishes or a newer command replaces it.
  Future<void> previous({bool animation = true}) =>
      _dispatch(PREVIOUS, animation);

  Future<void> _dispatch(int event, bool animation) {
    complete();
    this.event = event;
    this.animation = animation;
    final command = Completer<void>();
    _pending = command;
    if (hasListeners) {
      notifyListeners();
    } else {
      complete();
    }
    return command.future;
  }

  /// Captures the current command so an older animation cannot finish a new one.
  VoidCallback completionForCurrentCommand() {
    final command = _pending;
    return () {
      if (identical(_pending, command)) complete();
    };
  }

  void complete() {
    final command = _pending;
    _pending = null;
    command?.complete();
  }

  @override
  void dispose() {
    complete();
    super.dispose();
  }
}
