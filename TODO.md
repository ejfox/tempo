# Tempo — TODO

## Xcode Setup Required

These steps must be done in Xcode (can't be done from the CLI).

### 1. Add TempoWatchWidgets Target

The complication code is written (`Tempo/TempoWatchWidgets/`) but needs a target in the Xcode project.

1. Open `Tempo.xcodeproj` in Xcode
2. File → New → Target → watchOS → Widget Extension
3. Product Name: `TempoWatchWidgets`
4. Bundle Identifier: `com.fox.Tempo.watchkitapp.widgets`
5. Embed in: `TempoWatch`
6. Delete the auto-generated boilerplate files (Xcode creates template files — our real files in `TempoWatchWidgets/` will be auto-discovered by `fileSystemSynchronizedGroups`)
7. Set deployment target to watchOS 11.0
8. Add the `TempoWatchWidgets.entitlements` file to the target's Signing & Capabilities (it already has App Group + iCloud KV Store configured)

### 2. Add App Group Capability in Xcode

The entitlements plist has `group.com.fox.Tempo` but Xcode needs the capability registered:

1. Select the `Tempo` (iOS) target → Signing & Capabilities → + Capability → App Groups → add `group.com.fox.Tempo`
2. Select the `TempoWatch` target → same
3. Select the `TempoWatchWidgets` target → same
4. Select the `TempoWidgets` (iOS widget) target → same

### 3. Verify iCloud KV Store on Widget Target

1. Select `TempoWatchWidgets` target → Signing & Capabilities
2. Ensure iCloud → Key-Value Storage is enabled with container `$(TeamIdentifierPrefix)com.fox.Tempo`

### 4. App Icons

**Provide 1024x1024 PNG** app icons for:
- `Tempo/Assets.xcassets/AppIcon.appiconset/` (iOS)
- `TempoWatch/Assets.xcassets/AppIcon.appiconset/` (watchOS)

Design suggestion: thin circular progress arc on pure black background, matching the edge-trace visual language.

---

## Pre-Submission Checklist

- [ ] Complete Xcode setup steps above
- [ ] Add app icons
- [ ] Build and run on device — verify all 3 iOS tabs work
- [ ] Build and run on Apple Watch — verify complications load
- [ ] Start session on watch → verify iOS syncs
- [ ] Start session on iOS → verify watch syncs
- [ ] Complete 4 sessions → verify long break + cycle reset
- [ ] Kill and relaunch → verify stats persist
- [ ] Add home screen widget → verify data shows
- [ ] Test Live Activity on lock screen + Dynamic Island
- [ ] Run VoiceOver → verify accessibility
- [ ] Archive for TestFlight → verify no submission errors
- [ ] Set MARKETING_VERSION to desired release number

---

## Future Work

- [ ] Long-press edit mode for watch-face-style in-app customization (v2)
- [ ] HealthKit integration (Mindful Minutes)
- [ ] Focus mode integration (auto Do Not Disturb)
- [ ] Onboarding flow for first-time users
- [ ] iPad layout optimization
- [ ] Localization (currently English-only)
