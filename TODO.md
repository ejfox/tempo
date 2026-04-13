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

1. Select the `TempoWatch` target → Signing & Capabilities → + Capability → App Groups
2. Add `group.com.fox.Tempo`
3. Do the same for the `TempoWatchWidgets` target

### 3. Verify iCloud KV Store on Widget Target

1. Select `TempoWatchWidgets` target → Signing & Capabilities
2. Ensure iCloud → Key-Value Storage is enabled with container `$(TeamIdentifierPrefix)com.fox.Tempo`

---

## Future Work

### High Priority

- [ ] Test all 4 complications on a real watch face
- [ ] Test complication timeline refresh during active sessions (verify per-minute entries work)
- [ ] Test App Group data sharing (widget reads watch app writes)
- [ ] Test one-time UserDefaults migration (install old version, update, verify settings preserved)

### Nice to Have

- [ ] Long-press edit mode for in-app customization (v2 — currently in Settings only)
- [ ] Daily session history in UserDefaults for a mini bar chart in the Day complication
- [ ] Watch face complication that acts as a start button (tap to launch + begin session)
- [ ] HealthKit integration (log focus sessions as Mindful Minutes)
- [ ] Focus mode integration (auto-enable Do Not Disturb during focus sessions)
- [ ] iOS companion app improvements (the iOS side is still brutalist/basic compared to the watch)
