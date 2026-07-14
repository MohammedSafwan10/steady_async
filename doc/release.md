# Release runbook

Version 0.2.2 is a core patch release. Compatible adapter versions remain
unchanged because their public APIs and constraints already support it.

1. Run `tool/verify.ps1` and resolve every warning.
2. Confirm CI passes on minimum, latest, Windows, and macOS jobs.
3. Run `dart pub publish --dry-run` inside `packages/steady_async`.
4. Publish or tag `steady_async 0.2.2`.
5. Do not republish the unchanged adapter versions.
6. GitHub trusted publishing uses repository
   `MohammedSafwan10/steady_async` and these tag patterns:
   - `steady_async-v{{version}}`
   - `steady_async_riverpod-v{{version}}`
   - `steady_async_bloc-v{{version}}`
7. Releases are triggered by matching tags after the pubspec and
   changelog versions are committed.

## Demo DNS

Create a CNAME record:

```text
Name: steady-async
Type: CNAME
Target: MohammedSafwan10.github.io
```

GitHub Pages should deploy from the Actions workflow. The app includes
`web/CNAME`, so the build artifact retains `steady-async.nexdark.com`.
