class_name PirateTheme
extends RefCounted
## Pirate theme colors and constants for R-Matey.
##
## R-Matey: R = Required moves, Matey = for checkMate (pirate pun!)

# =============================================================================
# COLOR PALETTE
# =============================================================================

# Primary colors - wood and ocean tones
const WOOD_PRIMARY := Color("#8B4513")        # SaddleBrown - wood panels
const WOOD_DARK := Color("#5D2E0C")           # Darker wood accent
const OCEAN_DARK := Color("#1a1a2e")          # Dark navy - ocean at night
const OCEAN_MID := Color("#2d2d44")           # Purple-blue - ship deck

# Gold and treasure
const GOLD_BRIGHT := Color("#FFD700")         # Pure gold - important elements
const GOLD_ACCENT := Color("#DAA520")         # Goldenrod - accents
const GOLD_DARK := Color("#B8860B")           # DarkGoldenrod - borders
const TREASURE_GLOW := Color("#FFEC8B")       # Light gold glow

# Text colors
const TEXT_PARCHMENT := Color("#F5DEB3")      # Wheat - main text (parchment)
const TEXT_GOLD := Color("#D4AF37")           # Gold text highlights
const TEXT_SECONDARY := Color("#C4A77D")      # Tan - secondary text
const TEXT_DARK := Color("#3D2914")           # Dark brown for light backgrounds

# Status colors
const SUCCESS_EMERALD := Color("#50C878")     # Emerald - found treasure
const SUCCESS_GLOW := Color("#7FFFD4")        # Aquamarine - success highlight
const DANGER_RED := Color("#8B0000")          # DarkRed - skulls/danger
const DANGER_GLOW := Color("#DC143C")         # Crimson - danger highlight
const WARNING_ORANGE := Color("#FF8C00")      # DarkOrange - warnings

# UI Panel colors
const PANEL_BG := Color(0.12, 0.12, 0.18, 0.95)      # Dark navy panel
const PANEL_BORDER := Color("#4A3728")               # Wood border
const PANEL_HEADER := Color(0.15, 0.13, 0.10, 0.9)   # Darker header

# =============================================================================
# EMOJI ICONS (Unicode)
# =============================================================================

const ICON_SKULL := "💀"           # Wrong move / strike
const ICON_COIN := "🪙"            # Single doubloon
const ICON_COINS := "💰"           # Money bag / total points
const ICON_TREASURE := "🏴‍☠️"        # Pirate flag - puzzle solved
const ICON_CHEST := "📦"           # Treasure chest (alt: use custom sprite)
const ICON_MAP := "🗺️"            # Treasure map - hint
const ICON_HOURGLASS := "⏳"       # Timer
const ICON_COMPASS := "🧭"         # Navigation
const ICON_ANCHOR := "⚓"          # Anchor - stable/locked
const ICON_SHIP := "⛵"            # Ship - progress
const ICON_STAR := "⭐"            # Achievement / perfect
const ICON_FLAME := "🔥"           # Hot streak (kept for familiarity)
const ICON_SPARKLE := "✨"         # Correct move sparkle
const ICON_X_MARK := "❌"          # X marks the spot (unsolved daily)
const ICON_CHECK := "✅"           # Checkmark (solved daily)

# =============================================================================
# THEMED TEXT
# =============================================================================

# Session stats labels (pirate themed)
const LABEL_POINTS := "Doubloons"
const LABEL_STREAK := "Plunder Streak"
const LABEL_SOLVED := "Treasures Found"
const LABEL_ACCURACY := "Precision"
const LABEL_MOVES := "Maneuvers"
const LABEL_ATTEMPTS := "Attempts"

# Section headers
const HEADER_PUZZLE := "Current Bounty"
const HEADER_SESSION := "Voyage Stats"
const HEADER_THIS_PUZZLE := "This Quest"

# Mode names
const MODE_PRACTICE := "Practice Voyage"
const MODE_SPRINT := "Speed Plunder"
const MODE_STREAK := "Treasure Hunt"
const MODE_DAILY := "Daily Bounty"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

## Get colored text with gold highlight
static func gold_text(text: String) -> String:
	return "[color=#FFD700]%s[/color]" % text

## Get text styled for danger/skulls
static func danger_text(text: String) -> String:
	return "[color=#DC143C]%s[/color]" % text

## Get text styled for success
static func success_text(text: String) -> String:
	return "[color=#50C878]%s[/color]" % text

## Format doubloons with icon
static func format_doubloons(amount: int) -> String:
	return "%s %d" % [ICON_COINS, amount]

## Format streak with icon
static func format_streak(streak: int) -> String:
	if streak >= 5:
		return "%s %d" % [ICON_FLAME, streak]  # Hot streak!
	return "%s %d" % [ICON_COIN, streak]

## Get strike display (skulls for used, circles for remaining)
static func format_strikes(current: int, max_strikes: int = 3) -> String:
	var result := ""
	for i in range(max_strikes):
		if i < current:
			result += ICON_SKULL + " "
		else:
			result += "○ "
	return result.strip_edges()
