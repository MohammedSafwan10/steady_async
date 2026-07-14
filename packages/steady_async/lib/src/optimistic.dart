import 'package:flutter/foundation.dart';

/// State of an optimistic change.
enum SteadyOptimisticStatus { pending, committed, rolledBack, invalidated }

/// An idempotent optimistic change that can be committed or rolled back once.
class SteadyOptimisticHandle {
  /// Creates a pending handle backed by idempotent transaction callbacks.
  SteadyOptimisticHandle.pending({
    required bool Function() commit,
    required bool Function() rollback,
    bool Function()? invalidate,
  })  : _apply = null,
        _commit = commit,
        _rollback = rollback,
        _invalidate = invalidate,
        _applied = true;

  /// Creates an already-invalid handle for safe post-disposal no-ops.
  SteadyOptimisticHandle.invalidated()
      : _apply = null,
        _commit = _returnFalse,
        _rollback = _returnFalse,
        _invalidate = null,
        _applied = false,
        _status = SteadyOptimisticStatus.invalidated;

  /// Creates application-owned optimistic state applied by `runOptimistic`.
  factory SteadyOptimisticHandle.apply({
    required VoidCallback apply,
    VoidCallback? commit,
    required VoidCallback rollback,
  }) {
    return SteadyOptimisticHandle._deferred(
      apply: apply,
      commit: commit,
      rollback: rollback,
    );
  }

  SteadyOptimisticHandle._deferred({
    required VoidCallback apply,
    VoidCallback? commit,
    required VoidCallback rollback,
  })  : _apply = apply,
        _commit = (() {
          commit?.call();
          return true;
        }),
        _rollback = (() {
          rollback();
          return true;
        }),
        _invalidate = null,
        _applied = false;

  final VoidCallback? _apply;
  final bool Function() _commit;
  final bool Function() _rollback;
  final bool Function()? _invalidate;
  SteadyOptimisticStatus _status = SteadyOptimisticStatus.pending;
  bool _applied;
  bool _resolving = false;

  /// Current terminal or pending transaction status.
  SteadyOptimisticStatus get status => _status;

  /// Whether commit or rollback can still resolve this handle.
  bool get isPending => _status == SteadyOptimisticStatus.pending;

  /// Whether this mutation is currently reflected in application state.
  bool get isApplied => _applied;

  /// Applies a deferred application-owned mutation exactly once.
  bool activate() {
    if (!isPending || _applied || _resolving) return false;
    final apply = _apply;
    if (apply == null) return false;
    try {
      apply();
      _applied = true;
      return true;
    } catch (error, stackTrace) {
      _report(error, stackTrace);
      _status = SteadyOptimisticStatus.invalidated;
      return false;
    }
  }

  /// Commits this handle once and returns whether it changed state.
  bool commit() {
    return _resolve(_commit, SteadyOptimisticStatus.committed);
  }

  /// Rolls this handle back once and returns whether it changed state.
  bool rollback() {
    if (isPending && !_applied && !activate()) return false;
    return _resolve(_rollback, SteadyOptimisticStatus.rolledBack);
  }

  /// Makes a pending handle stale without applying commit or rollback.
  bool invalidate() {
    if (!isPending || _resolving) return false;
    _resolving = true;
    final invalidate = _invalidate;
    final success = invalidate == null || _safeInvoke(invalidate);
    if (success) _status = SteadyOptimisticStatus.invalidated;
    _resolving = false;
    return success;
  }

  bool _resolve(
    bool Function() callback,
    SteadyOptimisticStatus terminalStatus,
  ) {
    if (!isPending || !_applied || _resolving) return false;
    _resolving = true;
    final success = _safeInvoke(callback);
    if (success) _status = terminalStatus;
    _resolving = false;
    return success;
  }

  bool _safeInvoke(bool Function() callback) {
    try {
      return callback();
    } catch (error, stackTrace) {
      _report(error, stackTrace);
      return false;
    }
  }

  void _report(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'steady_async',
        context: ErrorDescription('while resolving an optimistic change'),
      ),
    );
  }
}

bool _returnFalse() => false;
