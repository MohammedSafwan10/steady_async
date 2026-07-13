# First release runbook

Publication is intentionally manual for version 0.1.0.

1. Confirm `steady_async`, `steady_async_riverpod`, and `steady_async_bloc` are
   still available on pub.dev. Availability is not a reservation.
2. Verify `nexdark.com` in Google Search Console with its DNS TXT record, then
   create the `nexdark.com` publisher on pub.dev.
3. Run `tool/verify.ps1` and resolve every warning.
4. Run `dart pub publish --dry-run` inside each package, in core-first order.
5. Publish `steady_async` from Mohammed Safwan's pub.dev Google account, then
   transfer it to the verified `nexdark.com` publisher.
6. Publish and transfer `steady_async_riverpod`, then `steady_async_bloc`.
7. Enable GitHub trusted publishing only after all three manual releases.

## Demo DNS

Create a CNAME record:

```text
Name: steady-async
Type: CNAME
Target: MohammedSafwan10.github.io
```

GitHub Pages should deploy from the Actions workflow. The app includes
`web/CNAME`, so the build artifact retains `steady-async.nexdark.com`.
