# Azic UI

Animated Roblox UI library with a Linoria-style API. Written from scratch, so it is not a copy of LinoriaLib.

## Load

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Azic46/AzicUIV3/refs/heads/main/Library.lua"))()
```

See `Example.lua` for every element.

## Features

**New in v2.0**
- Glass look with gloss bands, glow halo around the window and shine sweeps on buttons, tabs and cards
- Floating **Open / Close** button (draggable) plus close and settings buttons in the title bar
- Sidebar with icons, collapsible categories (`Window:AddCategory`) and a user card with avatar
- Drawn vector icons (`Library.Icons`, `Library:Icon(name, parent, color, size)`)
- **Live matrix background**: glyph streams run left to right, your word is highlighted inside them (`Window.Matrix:SetWord("...")`)
- **3D viewport widgets**: `AddCharacterViewer` (your avatar, drag to rotate) and `AddViewport` (any model)
- Dashboard page: profile, game name, place/server info, players, uptime, FPS, ping (`Library:BuildDashboardTab(Window)`)
- Music page: Roblox audio ID player, playlist, seek bar, volume and a live visualizer (`Library:BuildMusicTab(Window)`)
- Status bar with FPS, ping, clock and the current track
- Slider with - / + buttons (hold to repeat), groupbox subtitles

**Animations & effects**
- Window open/close: fade + back-ease scale
- Animated shimmer line, rotating gradient border, gradient logo
- Tab switching: page slides + fades in, indicator pops, hover states
- Buttons: ripple, press-scale, hover glow, double-click confirm
- Toggles: sliding squash knob with accent glow
- Sliders: gliding fill, knob pop while dragging, live accent value
- Dropdowns: animated expand, rotating arrow, searchable, multi-select
- Notifications: slide-in, progress bar, auto slide-out (Left or Right)
- Tooltips with fade, draggable + resizable window
- Global animation speed (`Library.AnimationSpeed` or the theme-section slider)

**Elements**
`AddToggle`, `AddButton` (+ sub-buttons), `AddLabel`, `AddDivider`, `AddSlider`, `AddInput`, `AddDropdown`
(single, multi, searchable, `SpecialType = "Player" | "Team"`), `AddColorPicker` and `AddKeyPicker`
(Toggle / Hold / Always / Press, right-click the key to change mode), tabboxes, dependency boxes.

**v1.1 - UX & accessibility pass**
- Contrast checked: text >= 6.4:1, control borders >= 3.5:1 (WCAG AA / non-text 3:1)
- Touch mode: rows, buttons, tabs and hit areas grow to ~40-44px on touch-only devices
- Visible focus ring for gamepad selection, vector icons instead of text glyphs
- Motion tokens (`Library.Tokens.Motion`), exit faster than enter, **Reduce motion** and **Ambient effects** toggles
- Sliders can be set without dragging: click or right-click to type a value
- `Reset all to defaults` (double-click to confirm), `Element:Reset()`, `Library:ResetAll()`
- Typed notifications: `Library:Notify({ Type = "Success" | "Warning" | "Error", Description = "..." })`
- Clear empty states and actionable error messages, "Menu hidden" hint when you close the window

**Extras**
- Live accent themes: `Library:SetAccent(Color3)` recolors everything instantly
- Config system: `SaveConfig`, `LoadConfig`, `GetConfigs`, `BuildConfigSection`
- Watermark: `SetWatermark`, `SetWatermarkVisibility`
- `Library:Notify(text, time)` or `Library:Notify({ Title, Description, Time })`

## API (Linoria-compatible)

```lua
local Window = Library:CreateWindow({ Title = "My Hub", Resizable = true, NotifySide = "Right" })
local Tab    = Window:AddTab("Main")
local Group  = Tab:AddLeftGroupbox("Group")

Group:AddToggle("MyToggle", { Text = "Toggle", Default = true })
Library.Toggles.MyToggle:OnChanged(function(v) print(v) end)

Group:AddSlider("MySlider", { Text = "Slider", Default = 5, Min = 0, Max = 10, Rounding = 1 })
Library.Options.MySlider:SetValue(7)
```

Differences from Linoria: `ClearTextOnFocus` on inputs defaults to `false`; there is no custom cursor or keybind-list frame yet.

## Notes
- Config saving needs an environment that provides `writefile` / `readfile` / `listfiles`; otherwise it returns an error message.
- The window toggles with `RightShift` by default (`Library.ToggleKeybind`).

## Music notes
Roblox only lets you play audio that is public or owned by you. The starter playlist comes from community catalogs and is **not guaranteed** to be available. Unplayable IDs show an error and the player skips to the next track. Use the Creator Store (Audio) to find IDs.
