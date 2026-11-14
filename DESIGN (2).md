# Azic UI design system

Direction: dark, low-glare tool UI (OLED-style surfaces) with one accent. Boldness is spent on a single moment, the animated accent line and border. Everything else stays quiet.

## Tokens (global -> semantic -> component)

| Semantic token | Value | Used for |
|---|---|---|
| Background / Panel / Element | #0D0D13 / #14141D / #1D1D2A | window, groupboxes, controls |
| Text / Muted | #ECECF5 / #94A3B8 | primary / secondary text (6.4:1 or better on Element) |
| Outline | #2E2E42 | decorative card borders |
| Control | #64748B | control boundaries (3.5:1 on Element) |
| Accent / AccentText | #8B5CFF / #B495FF | fills and glows / small accent text (6.9:1) |
| Risk | #FF555F | risky options, errors |

Motion: Fast 0.12s, Base 0.2s, Slow 0.35s, Enter 0.45s, Exit 0.22s (exit is faster than enter). Ease-out/Back for arrivals, linear for progress bars.
Radius: 5 / 6 / 8 / 10. Spacing: 4 / 8 / 12 / 16 / 24.
Targets: desktop rows 26px; touch-only devices 36-44px.

## Rules
- One accent, switchable live with `Library:SetAccent`.
- State is never color-only (knob position, bar height, text change).
- Press feedback never changes layout bounds (UIScale only).
- Motion can be reduced (`Library.ReducedMotion`) and ambient effects switched off (`Library.AmbientEffects`).
- No emoji or text glyphs as icons; icons are drawn from frames.

## v2.0 additions
- Surfaces are glass: panels at ~14% transparency over the live background, a gloss band on every card header.
- One ambient focal point: the shimmer line and glowing border. Everything else is quiet and can be disabled (Reduce motion, Ambient effects, Window glow, Shine effects).
- Matrix rain stays low contrast (glyphs ~86% transparent); only the user's word is bright.
- Icons are drawn from frames so they recolor with the theme and need no asset IDs.
