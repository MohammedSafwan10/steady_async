## 0.2.2

- Made request cancellation leave loading by restoring retained data or idle.
- Preserved the latest stream value when a later stream event fails.
- Made synchronous stream-factory failures rebuild through the guarded error
  path.
- Preserved `appendError` when omitted from paged-state copies while still
  clearing it with `clearError`.
- Made list, grid, and sliver pagination use the append-loading surface
  consistently for empty non-terminal pages.
- Applied updated success-visibility durations to owned action controllers.
- Made async-controller configuration and reset calls safe after disposal.

## 0.2.1

- Prevented sequential actions queued before disposal from executing afterward.
- Made `keepPreviousData: false` hide retained content as documented.
- Preserved the original loader-delay deadline across progress updates.
- Continued list and grid pagination when a page does not fill the viewport.
- Continued list, grid, and sliver pagination past empty non-terminal pages.
- Stopped list, grid, and sliver prefetch from retrying failed appends until the
  retry action is invoked.
- Kept refresh errors visible alongside retained items with retry support.
- Added a dedicated inline `refreshErrorBuilder` so existing full-screen
  `errorBuilder` implementations keep their original layout contract.
- Handled list scroll-controller and async-controller replacement correctly.
- Avoided auto-starting non-idle external controllers while preserving
  `reloadOnLoaderChange` during controller replacement.
- Detected repeated cursor cycles across a pagination session.

## 0.2.0

- Hardened paged-controller disposal, reset, refresh, and stale-result behavior.
- Added non-advancing cursor detection and controller-replacement loading.
- Added `removeWhere` and `removeByKey` with stale-result invalidation.
- Added custom loading and error builders for list, grid, and sliver pagination.

## 0.1.0

- Initial release with perception-aware Future and Stream builders.
- Added immutable async state, explicit controllers, actions, and pagination.
- Added Material 3 defaults, reduced-motion handling, and nine locales.
