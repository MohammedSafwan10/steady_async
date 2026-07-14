# Architecture

`steady_async` separates async state from how that state is revealed to users.
Controllers own request generations and reject stale completions. Views apply a
timing policy that delays transient loaders, guarantees a minimum visible time,
and preserves previous content during refreshes. Adapter packages only translate
external state into the core model.

Ordinary Dart `Future` factories use generation invalidation: obsolete results
cannot mutate public state, but the underlying work continues. Named
`.cancellable` APIs require a real transport cancellation callback. Reset,
replacement, timeout, and disposal call that callback at most once.

Paged-controller disposal, reset, refresh replacement, and local removal use
the same generation rule. Calls after disposal are safe no-ops and never start
new data-source work. A non-null cursor must advance; returning the requested
cursor again is surfaced as a pagination error.

Lifecycle transitions detach and invalidate active requests before invoking
cancellation callbacks or observers. Synchronous callbacks therefore cannot
orphan a replacement request. Observer events never include loaded values,
page items, cursors, or source keys.
