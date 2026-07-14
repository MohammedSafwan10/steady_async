# Release runbook

The prepared release set is `steady_async 0.3.0`,
`steady_async_riverpod 0.2.0`, and `steady_async_bloc 0.2.0`.

1. Run `tool/verify.ps1` and resolve every warning.
2. Confirm CI passes on minimum, latest, Windows, and macOS jobs.
3. Review the live showcase and `doc/migration.md`; publishing requires the
   maintainer's explicit approval after that review.
4. Run clean `dart pub publish --dry-run` checks in all three package folders.
5. Publish or tag core first, then Riverpod, then BLoC.
6. GitHub trusted publishing uses repository
   `MohammedSafwan10/steady_async` and these tag patterns:
   - `steady_async-v{{version}}`
   - `steady_async_riverpod-v{{version}}`
   - `steady_async_bloc-v{{version}}`
7. Releases are triggered by matching tags after the pubspec and
   changelog versions are committed.
8. A push to `main` updates source and the showcase. It does not update pub.dev
   unless a matching trusted-publishing tag is created.

## Demo DNS

Create a CNAME record:

```text
Name: steady-async
Type: CNAME
Target: MohammedSafwan10.github.io
```

GitHub Pages should deploy from the Actions workflow. The app includes
`web/CNAME`, so the build artifact retains `steady-async.nexdark.com`.
