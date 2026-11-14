--[[
    Azic UI v2 - Example
    Dashboard (profile, game info, 3D character), music player, categories,
    live matrix background, glow + shine, Open/Close launcher.
]]

local repo = "https://raw.githubusercontent.com/Azic46/AzicUIV3/refs/heads/main/Library.lua"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local Options, Toggles = Library.Options, Library.Toggles

Library.IgnoreIndexes = { "MenuKeybind" }

local Window = Library:CreateWindow({
	Title = "Azic UI",
	Subtitle = "Loading...",          -- replaced by the game name on the Dashboard
	MatrixWord = "AZIC",              -- word highlighted in the live background
	Resizable = true,
	Launcher = true,                  -- floating Open / Close button
	NotifySide = "Right",
})

-- Ready-made pages -----------------------------------------------------
Library:BuildDashboardTab(Window)     -- profile, game info, live stats, 3D character
Library:BuildMusicTab(Window)         -- Roblox audio player with visualizer

-- Your own pages, grouped in a collapsible category ---------------------
local Interface = Window:AddCategory("Interface", "eye")
local Elements = Interface:AddTab("Elements", "sparkle")
local Layout = Interface:AddTab("Layout", "matrix")

local G = Elements:AddLeftGroupbox("Controls", "Every element with its animations")

G:AddToggle("Demo1", { Text = "Toggle with extras", Default = true, Tooltip = "Hover for tooltips" })
	:AddKeyPicker("DemoKey", { Default = "F", Mode = "Toggle", Text = "Demo key" })
	:AddColorPicker("DemoColor", { Default = Color3.fromRGB(120, 160, 255), Title = "Demo color" })

G:AddSlider("DemoSlider", { Text = "Slider", Default = 50, Min = 0, Max = 100, Rounding = 0, Suffix = "%",
	Tooltip = "Drag, use the - / + buttons, or right-click to type a value" })
G:AddDropdown("DemoDrop", { Text = "Dropdown", Values = { "Option 1", "Option 2", "Option 3" }, Default = 1 })
G:AddDropdown("DemoMulti", { Text = "Multi + search", Values = { "Alpha", "Beta", "Gamma", "Delta", "Epsilon" }, Multi = true, Searchable = true, Default = { "Alpha" } })
G:AddInput("DemoInput", { Text = "Textbox", Placeholder = "Type here..." })
G:AddDivider()
G:AddButton({ Text = "Notify", Func = function()
	Library:Notify({ Type = "Success", Description = "Typed notifications: Success, Warning, Error." })
end }):AddButton({ Text = "Danger (double click)", DoubleClick = true, Func = function()
	Library:Notify({ Type = "Warning", Description = "Confirmed." })
end })

local V = Elements:AddRightGroupbox("3D viewport", "Any model, rendered live")
local part = Instance.new("Part")
part.Size, part.Shape, part.Material, part.Color = Vector3.new(4, 4, 4), Enum.PartType.Block, Enum.Material.Neon, Color3.fromRGB(139, 92, 255)
V:AddViewport(nil, { Height = 200, Model = part })

local D = Layout:AddLeftGroupbox("Dependency box")
D:AddToggle("ShowMore", { Text = "Show more" })
local box = D:AddDependencyBox()
box:AddSlider("More", { Text = "More", Default = 5, Min = 0, Max = 10, Rounding = 0, HideMax = true })
box:SetupDependencies({ { Toggles.ShowMore, true } })

local TB = Layout:AddRightTabbox()
TB:AddTab("Tab 1"):AddLabel("Tabboxes group related controls.", true)
TB:AddTab("Tab 2"):AddToggle("InTab2", { Text = "Inside tab 2" })

-- Settings ----------------------------------------------------------------
local Settings = Window:AddTab("Settings", "gear")
local Menu = Settings:AddLeftGroupbox("Menu")
Menu:AddLabel("Menu key"):AddKeyPicker("MenuKeybind", { Default = "RightShift", Mode = "Toggle", NoUI = true, Text = "Menu key" })
Menu:AddButton({ Text = "Unload", DoubleClick = true, Func = function() Library:Unload() end })
Library.ToggleKeybind = Options.MenuKeybind

Library:BuildThemeSection(Settings:AddLeftGroupbox("Appearance", "Accent, live background, effects"))
Library:BuildConfigSection(Settings:AddRightGroupbox("Configs"))

Library:SetWatermarkVisibility(true)
Library:SetWatermark("Azic UI")
Library:Notify({ Type = "Success", Title = "Azic UI loaded", Description = "Use the Open / Close button or RightShift.", Time = 5 })
