$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$root = Split-Path -Parent $PSScriptRoot
$packages = @(
  'packages/steady_async',
  'packages/steady_async_riverpod',
  'packages/steady_async_bloc'
)

dart pub global activate dartdoc
dart pub global activate pana

foreach ($package in $packages) {
  Push-Location (Join-Path $root $package)
  try {
    flutter pub get
    dart format --output=none --set-exit-if-changed lib test example
    flutter analyze --fatal-infos
    flutter test
    dart pub global run dartdoc --no-auto-include-dependencies --no-generate-docs --no-validate-links
    dart pub publish --dry-run
  } finally {
    Pop-Location
  }
}

Push-Location (Join-Path $root 'packages/steady_async')
try {
  pana --exit-code-threshold 0 .
} finally {
  Pop-Location
}

Push-Location (Join-Path $root 'apps/showcase')
try {
  flutter pub get
  dart format --output=none --set-exit-if-changed lib test
  flutter analyze --fatal-infos
  flutter test
  flutter build web --release --base-href /
} finally {
  Pop-Location
}
