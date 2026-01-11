# Visual Reference: Key Design Elements

## Timer Display Transformation

### Original Design
```
Timer: 96pt ultraLight monospaced
Label: 14pt light lowercase "focus" / "break"
Color: Primary with 0.6 opacity
Layout: Centered, padded
```

### Brutalist Design
```
Timer: 140pt black weight default
Label: 36pt black uppercase "FOCUS" / "BREAK"  
Color: Pure primary (100% opacity)
Layout: Centered, no padding, tight tracking
```

**Size Increase**: 46% larger timer  
**Weight Change**: ultraLight → black (9 weight steps)  
**Case Change**: lowercase → UPPERCASE  
**Tracking**: default → -8 (tighter)

---

## Button Transformation

### Original Design
```
Size: 36pt text, ~70pt tall button
Weight: ultraLight
Style: Glass morphism, rounded 16pt corners
Layout: Side-by-side (HStack)
Padding: 40pt horizontal, 16pt vertical
Background: ultraThinMaterial with 70% opacity
Press: Scale to 95%, opacity to 50%
```

### Brutalist Design
```
Size: 72pt text, 120pt tall button
Weight: black
Style: Stark rectangles, 6pt border
Layout: Stacked (VStack)
Padding: None (full-width)
Background: Solid background with stroke overlay
Press: Color inversion (no scale)
```

**Size Increase**: 100% larger text, 71% taller button  
**Width Change**: Auto-sized → Full-width  
**Interaction**: Smooth scale → Instant invert

---

## Progress Bar Transformation

### Original Design
```
Type: Edge-traced ring
Width: 4pt stroke
Style: Gradient (80% to 40% opacity)
Path: Follows device corners
Effects: Drop shadow, rounded caps
Animation: 0.5s easeInOut
```

### Brutalist Design
```
Type: Top bar rectangle
Height: 40pt solid block
Style: Solid fill (100% opacity)
Path: Straight edge-to-edge
Effects: None
Animation: None (instant)
```

**Size Increase**: 4pt → 40pt (10x larger)  
**Style Change**: Stroke ring → Filled bar  
**Position Change**: Edge trace → Top aligned  

---

## Stats Display Transformation

### Original Design
```
Numbers: 24pt ultraLight monospaced
Labels: 10pt light lowercase
Layout: Side-by-side with 40pt spacing
Separator: None
Colors: Primary with 0.5 opacity labels
```

### Brutalist Design
```
Numbers: 56pt black default
Labels: 14pt black uppercase with 3pt tracking
Layout: Side-by-side with 60pt spacing
Separator: 4pt x 80pt vertical bar
Colors: Pure primary (100% opacity)
```

**Size Increase**: 133% larger numbers  
**Visual Addition**: Bold separator bar  
**Readability**: Much higher contrast

---

## Toggle Control Transformation

### Original Design
```
Icon: SF Symbol (checkmark.circle.fill / circle)
Size: 16pt
Label: 12pt light monospaced lowercase
Color: Primary with 0.5 opacity
```

### Brutalist Design
```
Icon: Custom rectangle checkbox (20x20pt with 12x12pt inner)
Size: 20pt outer
Label: 16pt black uppercase with 2pt tracking
Color: Pure primary (100% opacity)
```

**Style Change**: Rounded SF Symbol → Sharp rectangle  
**Size Increase**: 25% larger  
**Contrast**: Higher visibility

---

## Color Palette

### Original Design
```
Background: systemBackground + ultraThinMaterial overlay
Text: primary with 0.5-0.9 opacity range
Accents: Linear gradients
Shadows: Multiple layers (0.1-0.3 opacity)
```

### Brutalist Design
```
Background: systemBackground (pure)
Text: primary (always 100% opacity)
Accents: None (monochrome only)
Shadows: None
```

**Simplification**: 5+ color variations → 2 colors only  
**Contrast**: Increased by removing opacity  

---

## Animation Comparison

### Original Design
```
Entrance: Spring animations (0.5-0.8s)
Transitions: Fade, scale, move
Delays: Staggered (0.1-0.35s)
Progress: 0.5s easeInOut
Blur: 0.5s easeOut
```

### Brutalist Design
```
Entrance: None (instant)
Transitions: None
Delays: None
Progress: Instant update
Blur: None
```

**Performance**: Significantly reduced render updates  
**UX**: Immediate, uncompromising response  

---

## Typography System

### Original Design
```
Font: System monospaced
Weights: ultraLight (100), light (300)
Case: lowercase
Tracking: default
Design: .monospaced
```

### Brutalist Design
```
Font: System default
Weights: black (900)
Case: UPPERCASE
Tracking: -8 to +8 (varied)
Design: .default
```

**Weight Contrast**: 800 points difference (100→900)  
**Visual Impact**: Dramatically bolder  

---

## Layout Structure

### Original Design
```
Padding: 40-60pt everywhere
Spacing: 20-60pt between elements
Corners: 16pt rounded
Margins: Generous
Alignment: Centered with breathing room
```

### Brutalist Design
```
Padding: 0-60pt (minimal)
Spacing: 0-60pt (varied)
Corners: 0pt (sharp)
Margins: None to minimal
Alignment: Edge-to-edge where possible
```

**Space Usage**: More efficient, bolder fills  
**Visual Density**: Higher impact per pixel  

---

## Summary: At a Glance

| Element | Original | Brutalist | Change |
|---------|----------|-----------|--------|
| Timer | 96pt ultraLight | 140pt black | +46% |
| Buttons | 36pt text | 72pt text | +100% |
| Stats | 24pt numbers | 56pt numbers | +133% |
| Progress | 4pt stroke | 40pt bar | +900% |
| Opacity | 0.05-1.0 | 1.0 only | 100% |
| Corners | 16pt radius | 0pt | Sharp |
| Effects | Many | None | Removed |
| Animation | Yes | No | Instant |
| Colors | Gradients | Solid | Simple |

**Overall**: Bigger, bolder, simpler, faster
