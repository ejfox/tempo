# Brutalist Monochrome Design Branch

This branch implements a unique brutalist monochrome design approach for the Tempo Pomodoro timer app.

## Design Philosophy

The brutalist design follows these core principles:

### 1. **Pure Monochrome**
- Strictly black and white, no gradients or opacity variations
- High contrast for maximum readability
- Colors automatically adapt to light/dark mode

### 2. **Full-Width Huge Text**
- Timer display: 140pt black weight font
- Massive, edge-to-edge typography that dominates the screen
- Uppercase labels with extended letter spacing (tracking)

### 3. **Brutalist Aesthetics**
- No rounded corners - only sharp rectangles
- No glass morphism or blur effects
- No animations or transitions - immediate, stark responses
- Heavy stroke borders (6pt) on interactive elements

### 4. **Stark UI Elements**

#### Progress Bar
- Changed from subtle edge trace to bold 40pt top bar
- Full-width rectangle that fills from left to right
- Pure black/white fill, no gradients

#### Buttons
- Massive 120pt tall rectangular blocks
- 72pt black weight typography
- 6pt border stroke
- Inverts colors on press (black bg with white text)
- Full-width spans

#### Stats Display
- 56pt numbers in black weight
- Separated by 4pt vertical divider bars
- Uppercase labels with wide tracking
- No opacity fading

#### Timer Display
- 140pt bold numbers
- Negative letter spacing (-8) for tight, industrial feel
- Minimalist "FOCUS" or "BREAK" label above (36pt)
- 12pt thick progress indicator below

## Technical Changes

### Removed Components
- `EdgeProgressBar` - replaced with `BrutalistProgressBar`
- `ScreenEdgeShape` - no longer needed
- `displayCornerRadius` extension - removed rounded corners
- `GlassButtonStyle` - replaced with `BrutalistButtonStyle`

### Simplified State
Removed animation-related state variables:
- `buttonsVisible`
- `button25Scale`, `button50Scale`
- `button25Opacity`, `button50Opacity`
- `statsOpacity`
- `timerScale`
- `progressBarWidth`
- `blurRadius`

### New Components
- `BrutalistProgressBar`: Simple top-aligned rectangle progress bar
- `BrutalistButtonStyle`: High-contrast rectangular button style with invert-on-press

## Visual Impact

The brutalist design creates a unique, bold aesthetic that:
- Commands attention with massive typography
- Feels industrial and uncompromising
- Removes all "softness" from the UI
- Creates a stark, focused experience
- Stands out from typical minimalist iOS designs

## Usage

This design maintains full functionality of the original app:
- 25-minute short sessions
- 50-minute long sessions  
- Break timer
- Streak and daily count tracking
- Minute tick haptics toggle
- Session stop functionality

The brutalist aesthetic simply presents these features with maximum visual impact and minimal decoration.
