# Testing Guide: Brutalist Design Branch

## How to Test

### Build and Run
1. Open `Tempo.xcodeproj` in Xcode
2. Select an iOS Simulator (iPhone 15 Pro recommended)
3. Build and run (⌘R)

### Test Cases

#### 1. Idle State
**What to Check:**
- [ ] Buttons "25" and "50" are displayed as large rectangular blocks
- [ ] Text is uppercase, black weight, 72pt size
- [ ] 6pt black border around each button
- [ ] Full-width button layout
- [ ] "MINUTE TICKS" toggle with checkbox square
- [ ] Stats display (if streak > 0) with vertical separator bar

**Expected Appearance:**
- Pure black text on white background (light mode)
- Pure white text on black background (dark mode)
- No rounded corners anywhere
- No blur or transparency effects

#### 2. Running State
**What to Check:**
- [ ] Timer displays at 140pt in black weight
- [ ] "FOCUS" or "BREAK" label appears above timer
- [ ] 40pt progress bar fills from left at top of screen
- [ ] 12pt progress bar below timer
- [ ] "STOP" button in brutalist style
- [ ] No animations when transitioning to running state

**Timer Display:**
- Should be massive and dominate the screen
- Numbers tightly kerned (negative tracking)
- Pure monochrome, no opacity variations

#### 3. Progress Indicators
**What to Check:**
- [ ] Top bar grows smoothly from left to right
- [ ] Bar respects safe areas (doesn't go under notch/Dynamic Island)
- [ ] Inline progress bar below timer also respects width
- [ ] Both bars are solid color (no gradients)
- [ ] Progress syncs between both bars

#### 4. Button Interactions
**What to Check:**
- [ ] Button inverts colors on press (black bg, white text)
- [ ] No scale animation or transition
- [ ] Immediate visual response
- [ ] Strong haptic feedback on press

#### 5. Dark Mode
**What to Test:**
- [ ] Switch to dark mode (Settings → Developer → Appearance)
- [ ] All elements invert correctly
- [ ] Text remains high contrast
- [ ] Progress bars invert
- [ ] Button borders and fills invert

#### 6. Different Screen Sizes
**Test on Multiple Simulators:**
- [ ] iPhone SE (small screen) - text should scale down
- [ ] iPhone 15 Pro (standard) - optimal size
- [ ] iPhone 15 Pro Max (large) - text remains readable
- [ ] iPad - verify layout adapts

#### 7. Functional Testing
**Verify All Features Work:**
- [ ] Start 25-minute session
- [ ] Timer counts down correctly
- [ ] Progress bars advance
- [ ] Stop button works
- [ ] Start 50-minute session
- [ ] Break timer works after work phase
- [ ] Stats increment correctly
- [ ] Minute ticks toggle works
- [ ] Haptic feedback fires correctly

## Visual Regression Testing

Compare with original design to verify transformations:

### Typography Changes
- ✅ Timer increased from 96pt to 140pt
- ✅ Button text increased from 36pt to 72pt
- ✅ All weights changed to black (from ultraLight)
- ✅ All labels uppercase (from lowercase)

### Layout Changes
- ✅ Buttons stacked vertically (from horizontal)
- ✅ Full-width elements (from padded)
- ✅ Sharp corners (from 16pt radius)
- ✅ Top progress bar (from edge trace)

### Effect Removal
- ✅ No glass morphism
- ✅ No blur effects
- ✅ No shadows
- ✅ No gradients
- ✅ No animations
- ✅ No opacity variations

## Known Limitations

1. **No Xcode Available in CI**: This branch was developed without access to Xcode build tools, so it hasn't been compiled yet
2. **Simulator Testing Required**: Visual design needs to be tested on actual device/simulator to verify appearance
3. **Accessibility Review Needed**: While high contrast should improve accessibility, VoiceOver testing is recommended

## Design Validation

### Brutalist Principles Checklist
- [x] Raw, unprocessed aesthetic
- [x] Function over form
- [x] Exposed structure (no decoration)
- [x] Monochrome palette
- [x] Heavy, bold typography
- [x] Geometric shapes only
- [x] No curves or softness
- [x] Maximum impact through scale
- [x] Uncompromising directness

## Performance Testing

Compare performance with original:
- [ ] Measure frame rate during timer countdown
- [ ] Check memory usage
- [ ] Verify smooth progress bar movement
- [ ] Test on older devices (iPhone 11, iPhone XR)

Expected improvements:
- Fewer redraws (no animations)
- Less GPU usage (no blur/shadow)
- Simpler view hierarchy
- Reduced memory footprint

## Next Steps

After testing:
1. Take screenshots of all states
2. Create comparison images (before/after)
3. Test on physical device
4. Gather user feedback on design
5. Consider accessibility audit
6. Document any issues found
