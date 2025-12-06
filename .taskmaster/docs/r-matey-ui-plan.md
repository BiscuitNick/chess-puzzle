# R-Matey UI Enhancement Plan

## Overview

Transform the chess puzzle game into "R-Matey" - a pirate-themed puzzle game with improved UI organization and visual clarity.

**Name Meaning:**
- **R** → Required Moves (to checkmate)
- **Matey** → For Checkmate (pirate slang for "friend/mate")

---

## Phase 1: Game Tab & UI Reorganization

### 1.1 Add "Game" Tab to Side Panel

**Move from Top Bar to Game Tab:**
- Puzzle ID
- Player color (which side you're playing)
- Mate-in information
- Puzzle rating

**Add New Game Stats:**
- Moves made (current puzzle)
- Total puzzles solved (session)
- Current streak
- Running difficulty points (sum of ratings solved)
- Session time elapsed
- Accuracy percentage (correct moves / total attempts)

**Tab Order:** Game | Options | Debug

### 1.2 Simplify Top Bar

After moving info to Game tab, top bar becomes minimal:
- Back button (left)
- Game mode indicator (center) - e.g., "Practice Mode" or "Sprint - 3:45"
- Settings gear icon (right, optional)

### 1.3 Green "Next" Button Styling

Create a success-styled button for "Next":
- Background: Green (`Color(0.2, 0.7, 0.3, 1)`)
- Hover: Lighter green (`Color(0.3, 0.8, 0.4, 1)`)
- Text: White
- Border radius: 4px
- Apply only when puzzle is solved (visual reward)

---

## Phase 2: Pirate Theme - "R-Matey"

### 2.1 Visual Theme Elements

| Original | Pirate Theme | Icon/Visual |
|----------|--------------|-------------|
| Streak counter | Treasure haul | 💰 Gold coins |
| Correct move | Loot collected | ✨ Sparkle + coin sound |
| Wrong move (strike) | Skull mark | 💀 Skull icon |
| Puzzle solved | Treasure chest opened | 🏴‍☠️ Chest animation |
| Rating points | Doubloons | 🪙 Gold coin stack |
| Timer | Hourglass/Sandglass | ⏳ Pirate hourglass |
| Hint | Treasure map | 🗺️ Map piece reveal |
| Daily progress | X marks the spot | ❌ / ✅ on treasure map |

### 2.2 Color Palette (Pirate Theme)

```
Primary:        #8B4513 (SaddleBrown) - Wood tones
Secondary:      #DAA520 (Goldenrod) - Gold accents
Background:     #1a1a2e (Dark navy) - Ocean night
Panel BG:       #2d2d44 (Dark purple-blue) - Ship deck
Success:        #50C878 (Emerald) - Found treasure
Error:          #8B0000 (DarkRed) - Danger/skulls
Text Primary:   #F5DEB3 (Wheat) - Parchment
Text Secondary: #D4AF37 (Gold) - Highlights
Accent:         #FFD700 (Gold) - Important elements
```

### 2.3 Typography Suggestions

- Headers: "Pirata One" or "Treasure Map Deadhand" (pirate-style font)
- Body: Keep readable font (current fonts work)
- Numbers/Stats: Bold, gold-colored

### 2.4 UI Element Redesigns

**Streak Counter → Treasure Counter:**
```
Current:  🔥 5
Pirate:   💰 5 Doubloons
```

**Strike Indicator → Skull Counter:**
```
Current:  ❌ ❌ ○
Pirate:   💀 💀 ○  (skulls for strikes, empty circle for remaining)
```

**Daily Progress → Treasure Map:**
```
Current:  ✓ ✓ ○ ○ ○
Pirate:   🏴‍☠️ 🏴‍☠️ 🗺️ 🗺️ 🗺️  (flags for solved, maps for pending)
```

**Timer Display → Hourglass:**
```
Current:  3:45
Pirate:   ⏳ 3:45  with sand-draining animation
```

### 2.5 Sound Effects (Future)

- Correct move: Coin clink / "Arrr!"
- Wrong move: Cannon boom / wood creak
- Puzzle solved: Treasure chest opening
- Streak milestone: Ship bell
- Game over: Dramatic pirate music sting

### 2.6 Animations (Future)

- Coins falling on correct move
- Skull appearing on wrong move
- Treasure chest burst on puzzle complete
- Ship rocking on timer warning

---

## Phase 3: Implementation Approach

### 3.1 Create Theme Resource System

Create a proper Godot Theme resource for consistent styling:

```
assets/themes/
├── default_theme.tres      (current look, fallback)
├── pirate_theme.tres       (R-Matey pirate theme)
└── theme_colors.gd         (color constants)
```

### 3.2 Theme-Aware Components

Modify existing components to support theming:

1. **StrikeIndicator** - Support custom icons (X vs Skull)
2. **StreakCounter** - Support custom prefix icon (fire vs coins)
3. **DailyProgress** - Support custom state icons
4. **TimerDisplay** - Support prefix icon
5. **Buttons** - Use theme-based StyleBoxFlat

### 3.3 Settings Integration

Add theme selection to Settings menu:
- Theme dropdown: "Classic" | "Pirate (R-Matey)"
- Preview thumbnails for each theme
- Persist selection in user data

---

## Implementation Order

### Immediate (This Session)

1. **Add "Game" tab to side panel**
   - Create new tab with game stats
   - Move puzzle info from top bar
   - Add session stats (moves, solved, points)

2. **Style "Next" button green**
   - Add StyleBoxFlat with green background
   - White text override
   - Apply when enabled

3. **Simplify top bar**
   - Remove puzzle info (now in Game tab)
   - Add mode indicator

### Short-term (Next Session)

4. **Create theme resource structure**
   - Define color constants
   - Create base theme resource
   - Create pirate theme variant

5. **Update components for theming**
   - StrikeIndicator with icon support
   - StreakCounter with icon support
   - Timer with icon prefix

### Medium-term (Future)

6. **Add pirate assets**
   - Icon set (skull, coins, chest, map)
   - Optional: Custom fonts
   - Optional: Sound effects

7. **Theme selection UI**
   - Settings menu integration
   - Theme preview
   - Persistence

---

## File Changes Summary

### New Files
- `assets/themes/pirate_theme.tres`
- `assets/themes/theme_colors.gd`
- `assets/icons/pirate/` (skull.png, coin.png, chest.png, map.png)

### Modified Files
- `scenes/ui/puzzle_screen.tscn` - Add Game tab, restyle Next button
- `scripts/ui/puzzle_screen.gd` - Game tab logic, stats tracking
- `scenes/components/strike_indicator.tscn` - Icon customization
- `scenes/components/streak_counter.tscn` - Icon customization
- `scripts/ui/settings_menu.gd` - Theme selection (future)

---

## Success Metrics

- [ ] Game tab shows all puzzle info + session stats
- [ ] Top bar is simplified
- [ ] Next button is green when enabled
- [ ] Theme system supports multiple themes
- [ ] Pirate theme is visually cohesive
- [ ] Components adapt to selected theme
- [ ] User can switch themes in settings

---

## Open Questions

1. **Board theme?** Should chess pieces also have a pirate variant? (e.g., captain = king, cannons = rooks)
2. **Difficulty points formula?** Sum of ratings, or weighted by mate depth?
3. **Streak bonuses?** Multiplier for consecutive solves?
4. **Achievement system?** Pirate ranks based on total doubloons?

---

## Notes

The pirate theme adds personality while the core gameplay remains unchanged. The theme system allows future expansion (holiday themes, minimalist, etc.) without major refactoring.

**R-Matey** works as both:
- A pun on "ahoy matey" (pirate greeting)
- A descriptor: "Required moves to Mate" = R-Matey
