# Mobile verification and release gaps — 2026-11-04

This is an incomplete-parity ledger, not a release certification. Native compilation,
native interactions and a Telegram pixel comparison are distinct from widget tests.

## Implemented in this change

- Check-in discovery starts with the readable list, provides debounced backend
  `user.check_in_fetch` search, keeps the query in map mode, and opens the selected
  post from map markers. Core's repository currently does not apply distance
  filtering: this UI does not claim proximity ordering.
- Check-in creation uses `AppForms.checkIn`, explicit place/current-location
  selection and searchable backend activity artwork. It cannot submit invented
  fallback coordinates. Location preview duplication was removed; keyboard,
  large text and RTL are covered by widget tests. Debug actions use PreviewApi.
- Post cards render `extras.tags` for object and JSON extras, resolving names and
  `thumb`/`icon` artwork from `system.initialSync.checkin_tag_types`. Uploaded
  attachments remain in the existing MediaAttachments renderer. Source:
  `web/src/features/post/Post.tsx` and `CheckInTagArtwork.tsx`; backend:
  `core/models/checkin.go` and `core/application/usecases/system.go`.
- Shared iOS GlassSurface uses registered UIKit UIGlassEffect, with older-iOS
  material fallback, theme updates and Reduce Transparency. UITabBar remains the
  existing system-tab implementation. Shared press handling now suppresses
  disabled actions, honors Reduce Motion and resets on lifecycle changes;
  compact icons retain 44pt targets and text scales once.
- Shared header/row layouts fix narrow auth and large-text Settings overflow.
  Profile error content no longer requests unsupported intrinsic sizing.
  Expanded profile identity/actions remain pinned while details scroll. Group
  previews now dismiss without joining; joining requires the explicit action.
- Flutter/Dart minimums now match the existing resolved dependency lock:
  Flutter 3.47.9 / Dart 3.13. The wrapper reuses an exact-tag installed SDK offline.
- Android release requires the owner's signing credentials and cannot silently
  use the debug certificate. Setup is documented in README.md; no keys created.

## Evidence

- Source inspection: local React Native, web, core and Telegram-iOS references.
- Check-in artwork: seven data/widget regressions cover JSON/object extras,
  localized labels, static URL safety and coexistence with uploaded images.
- Actual backend `static/checkin/256/beach.avif` is retained as a test fixture;
  Flutter engine decoding passes. This does not prove live-service networking.
- Search tests verify backend payloads, stale response rejection, clearing the
  query, switching views and opening the correct post.
- Composer tests verify explicit coordinates, no submission from tags alone,
  Turkish search, preserved selection and keyboard/2x RTL layout.
- NativeGlassView.swift passes simulator-SDK Swift type checking. A mock platform
  view test verifies native view selection, material updates and single dispatch.
- Optional local widget captures: `build/checkin-review/`, generated with
  `CHECKIN_SCREENSHOTS=true`. Fonts are loaded locally, never redistributed.
  These are layout inspection artifacts, not native iOS or pixel-match evidence.
- Full suite command: `./tool/flutterw test --no-pub --dart-define=TENOR_API_KEY=`.
  The empty Tenor key selects the test API path; real Tenor access is not mocked
  by the tests. Final run: **447 passed, 2 skipped, 0 failed** (45 seconds).
- Full analyzer: no errors or warnings; 11 informational diagnostics remain
  (10 vendored style/deprecation notices and the existing Unicode emoji-regex
  diagnostic). `git diff --check` passes.

## Release gates still open

1. iOS native build and simulator interaction: Xcode fails before compilation
   during SPM resolution (`DVTFilePathFSEvents`, `DARWIN_USER_CACHE_DIR` I/O error).
   CoreSimulator returns connection refused. No installed/run iOS build or
   touch validation is claimed for these changes.
2. Android native build/signing: offline Gradle lacks record_android's Android
   Gradle Plugin 9.2.1 dependency. Distribution credentials must be supplied by
   the app owner; no release artifact has been signed or uploaded.
3. Live/staging checks: login/Keychain persistence, protected photo access,
   check-in upload/retry, purchase/notification flows, permissions and lifecycle
   must be exercised on the intended service and physical devices. This change
   made no real check-ins, messages, joins, account changes or purchases.
4. Full React Native feature parity and per-screen Telegram visual/interaction
   parity remain unproven. No pixel comparison or performance profile on device
   has been completed. Passing a catalogue/widget test is not that evidence.
5. Backend check-in proximity filtering is absent; accurate nearby ranking needs
   repository/service work and tests before the UI can promise it.
