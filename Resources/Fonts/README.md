# Fonts

The design uses **Inter** (UI) and **JetBrains Mono** (timestamps). The app falls back to the
system font + system monospace when these aren't installed, so it builds and runs without them.

To ship the exact design typography:

1. Drop the `.ttf` files here (both are OFL-licensed, free to bundle):
   - `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`, `Inter-Bold.ttf`
   - `JetBrainsMono-Regular.ttf`, `JetBrainsMono-Medium.ttf`
2. Add them to the Xcode target (drag into the project, check "Auris" target).
3. Add `ATSApplicationFontsPath` = `Resources/Fonts` (or list each file under
   `Application fonts resource path`) in `Info.plist`.

`AurisFont` in `DesignSystem/Theme.swift` already prefers these families when available.
