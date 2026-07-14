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
  })  : _commit = commit,
        _rollback = rollback,
        _invalidate = invalidate;

  /// Applies application-owned optimistic state immediately.
  factory SteadyOptimisticHandle.apply({
    required VoidCallback apply,
    VoidCallback? commit,
    required VoidCallback rollback,
  }) {
    apply();
    return SteadyOptimisticHandle.pending(
      commit: () {
        commit?.call();
        return true;
      },
      rollback: () {
        rollback();
        return true;
      },
    );
  }

  final bool Function() _commit;
  final bool Function() _rollback;
  final bool Function()? _invalidate;
  SteadyOptimisticStatus _status = SteadyOptimisticStatus.pending;

  /// Current terminal or pending transaction status.
  SteadyOptimisticStatus get status => _status;

  /// Whether commit or rollback can still resolve this handle.
  bool get isPending => _status == SteadyOptimisticStatus.pending;

  /// Commits this handle once and returns whether it changed state.
  bool commit() {
    if (!isPending || !_safeInvoke(_commit)) return false;
    _status = SteadyOptimisticStatus.committed;
    return true;
  }

  /// Rolls this handle back once and returns whether it changed state.
  bool rollback() {
    if (!isPending || !_safeInvoke(_rollback)) return false;
    _status = SteadyOptimisticStatus.rolledBack;
    return true;
  }

  /// Makes a pending handle stale without applying commit or rollback.
  bool invalidate() {
    if (!isPending) return false;
    final invalidate = _invalidate;
    if (invalidate != null && !_safeInvoke(invalidate)) return false;
    _status = SteadyOptimisticStatus.invalidated;
    return true;
  }

  bool _safeInvoke(bool Function() callback) {
    try {
      return callback();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'steady_async',
          context: ErrorDescription('while resolving an optimistic change'),
        ),
      );
      return false;
    }
  }
}
