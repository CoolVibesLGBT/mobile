# Coolvibes Flutter contract

The user requires full React Native feature parity, the current web branding,
and pixel-level visual/interaction fidelity to the local Telegram-iOS reference.
A compiled prototype is not completion of the migration.

- Project root is this `mobile` directory. Do not create another nested Coolvibes project.
- React Native reference: `/Users/ersanyakit/Documents/coolvibes/coolvibes/mobile/coolvibes`.
- Visual/interaction reference: `/Users/ersanyakit/Downloads/Telegram-iOS-master`.
- Active web artwork: `/Users/ersanyakit/Documents/coolvibes/web/public/images/brand/dott-v3`.
- Every repeated responsibility has one component owner. Do not create a second
  form, person row, image loader, message bubble, loading/error renderer, glass
  renderer or press handler for the same job. Compose existing components.
- `AppForms` owns business form definitions, including the debug catalogue.
  The catalogue instantiates production widgets; never draw preview copies.
- `AppDesign` owns font, color, spacing, corner, separator and timing tokens.
  Trace values to the Telegram source. Match fonts, borders, Liquid Glass,
  down/up/cancel/long-press behavior, transitions and Lottie playback.
- iOS glass uses UIKit `UIGlassEffect` where available. System tabs use `UITabBar`.
  Platform-specific implementations stay behind the same public component API.
- Respect Reduce Motion/Transparency, text scaling, lifecycle and RTL.
- Keep a debug route for every screen/sheet and meaningful loading/error/empty
  state. Debug fixtures must never write to the real service or user settings.
- Preserve API names/payloads, auth and photo-access rules. Never invent successful
  business operations to fill a gap. Keep the incomplete-parity ledger honest.
- Source inspection, widget tests, native build, native interaction and a pixel
  comparison are separate evidence. Do not claim 1:1 before actual comparisons.
