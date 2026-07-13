# Architecture

`steady_async` separates async state from how that state is revealed to users.
Controllers own request generations and reject stale completions. Views apply a
timing policy that delays transient loaders, guarantees a minimum visible time,
and preserves previous content during refreshes. Adapter packages only translate
external state into the core model.

The core never claims to cancel a Dart `Future`; `cancel()` invalidates its
generation so that its eventual result cannot mutate public state.

Paged-controller disposal, reset, refresh replacement, and local removal use
the same generation rule. Calls after disposal are safe no-ops and never start
new data-source work. A non-null cursor must advance; returning the requested
cursor again is surfaced as a pagination error.
