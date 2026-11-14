
--[[
    AZIC UI - EXAMPLE
    Fixed Example Script
    Repository: Azic46/AzicUIV3

    Fixes:
    - Correct GitHub URL
    - Safe Library loading
    - Settings created exactly once
    - Protected UI initialization
    - Error reporting
]]

--==================================================
-- 1. LOAD LIBRARY
--==================================================

local BASE_URL =
    "https://raw.githubusercontent.com/Azic46/AzicUIV3/refs/heads/main/"

local success, Library = pcall(function()
    local source = game:HttpGet(BASE_URL .. "Library.lua")

    assert(
        type(source) == "string" and #source > 0,
        "Library.lua returned empty content"
    )

    local compiled, compileError = loadstring(source)

    assert(
        compiled,
        "Library compilation failed: " .. tostring(compileError)
    )

    return compiled()
end)

if not success then
    warn("[Azic UI] Library loading failed:")
    warn(tostring(Library))
    return
end

if type(Library) ~= "table" then
    warn("[Azic UI] Invalid Library returned.")
    return
end

if not Library.CreateWindow then
    warn("[Azic UI] CreateWindow function is missing.")
    return
end

local Options = Library.Options
local Toggles = Library.Toggles

Library.IgnoreIndexes = {
    "MenuKeybind"
}

--==================================================
-- 2. BUILD USER INTERFACE
--==================================================

local buildSuccess, buildError = pcall(function()

    -- Main Window
    local Window = Library:CreateWindow({
        Title = "Azic UI",
        Subtitle = "Loading...",
        MatrixWord = "AZIC",

        Resizable = true,
        Launcher = true,

        NotifySide = "Right",
    })

    assert(Window, "Window creation failed")

    --==================================================
    -- 3. BUILT-IN PAGES
    --==================================================

    Library:BuildDashboardTab(Window)
    Library:BuildMusicTab(Window)

    --==================================================
    -- 4. INTERFACE CATEGORY
    --==================================================

    local Interface = Window:AddCategory(
        "Interface",
        "eye"
    )

    -- Elements Tab
    local Elements = Interface:AddTab(
        "Elements",
        "sparkle"
    )

    -- Layout Tab
    local Layout = Interface:AddTab(
        "Layout",
        "matrix"
    )

    --==================================================
    -- 5. ELEMENTS
    --==================================================

    local G = Elements:AddLeftGroupbox(
        "Controls",
        "Every element with its animations"
    )

    -- Toggle + KeyPicker + ColorPicker
    G:AddToggle("Demo1", {
        Text = "Toggle with extras",
        Default = true,
        Tooltip = "Hover for tooltips"
    })
    :AddKeyPicker("DemoKey", {
        Default = "F",
        Mode = "Toggle",
        Text = "Demo key"
    })
    :AddColorPicker("DemoColor", {
        Default = Color3.fromRGB(120, 160, 255),
        Title = "Demo color"
    })

    -- Slider
    G:AddSlider("DemoSlider", {
        Text = "Slider",
        Default = 50,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = "%",
        Tooltip = "Drag, use - / +, or right-click"
    })

    -- Dropdown
    G:AddDropdown("DemoDrop", {
        Text = "Dropdown",
        Values = {
            "Option 1",
            "Option 2",
            "Option 3"
        },
        Default = 1
    })

    -- Multi Dropdown
    G:AddDropdown("DemoMulti", {
        Text = "Multi + Search",
        Values = {
            "Alpha",
            "Beta",
            "Gamma",
            "Delta",
            "Epsilon"
        },
        Multi = true,
        Searchable = true,
        Default = {
            "Alpha"
        }
    })

    -- Input
    G:AddInput("DemoInput", {
        Text = "Textbox",
        Placeholder = "Type here..."
    })

    G:AddDivider()

    -- Notifications
    G:AddButton({
        Text = "Success Notification",

        Func = function()
            Library:Notify({
                Type = "Success",
                Title = "Success",
                Description = "Azic UI is working correctly."
            })
        end
    })

    G:AddButton({
        Text = "Warning Notification",

        Func = function()
            Library:Notify({
                Type = "Warning",
                Title = "Warning",
                Description = "This is a warning notification."
            })
        end
    })

    G:AddButton({
        Text = "Error Notification",

        Func = function()
            Library:Notify({
                Type = "Error",
                Title = "Error",
                Description = "This is an error notification."
            })
        end
    })

    --==================================================
    -- 6. 3D VIEWPORT
    --==================================================

    local V = Elements:AddRightGroupbox(
        "3D Viewport",
        "Live model preview"
    )

    local part = Instance.new("Part")

    part.Name = "AzicPreviewPart"
    part.Size = Vector3.new(4, 4, 4)
    part.Shape = Enum.PartType.Block
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(139, 92, 255)
    part.Anchored = true

    V:AddViewport(nil, {
        Height = 200,
        Model = part
    })

    --==================================================
    -- 7. DEPENDENCY BOX
    --==================================================

    local D = Layout:AddLeftGroupbox(
        "Dependency Box"
    )

    D:AddToggle("ShowMore", {
        Text = "Show more"
    })

    local dependency = D:AddDependencyBox()

    dependency:AddSlider("More", {
        Text = "More",
        Default = 5,
        Min = 0,
        Max = 10,
        Rounding = 0,
        HideMax = true
    })

    dependency:SetupDependencies({
        {
            Toggles.ShowMore,
            true
        }
    })

    --==================================================
    -- 8. TABBOX
    --==================================================

    local TB = Layout:AddRightTabbox()

    TB:AddTab("Tab 1"):AddLabel(
        "Tabboxes group related controls.",
        true
    )

    TB:AddTab("Tab 2"):AddToggle(
        "InTab2",
        {
            Text = "Inside tab 2"
        }
    )

    --==================================================
    -- 9. SETTINGS TAB
    --==================================================

    -- IMPORTANT:
    -- Settings is created EXACTLY ONCE.

    local Settings = Window:AddTab(
        "Settings",
        "gear"
    )

    assert(Settings, "Settings tab creation failed")

    -- MENU GROUPBOX
    local Menu = Settings:AddLeftGroupbox(
        "Menu"
    )

    Menu:AddLabel("Menu key"):AddKeyPicker(
        "MenuKeybind",
        {
            Default = "RightShift",
            Mode = "Toggle",
            NoUI = true,
            Text = "Menu key"
        }
    )

    -- UNLOAD BUTTON
    Menu:AddButton({
        Text = "Unload",
        DoubleClick = true,

        Func = function()
            Library:Unload()
        end
    })

    -- Connect menu keybind
    Library.ToggleKeybind = Options.MenuKeybind

    -- APPEARANCE GROUPBOX
    local Appearance = Settings:AddLeftGroupbox(
        "Appearance",
        "Accent, Matrix and visual effects"
    )

    Library:BuildThemeSection(Appearance)

    -- CONFIGURATION GROUPBOX
    local Configs = Settings:AddRightGroupbox(
        "Configs"
    )

    Library:BuildConfigSection(Configs)

    --==================================================
    -- 10. WATERMARK
    --==================================================

    Library:SetWatermarkVisibility(true)
    Library:SetWatermark("Azic UI")

    --==================================================
    -- 11. SUCCESS NOTIFICATION
    --==================================================

    Library:Notify({
        Type = "Success",
        Title = "Azic UI Loaded",
        Description = "All pages and settings initialized.",
        Time = 5
    })

end)

--==================================================
-- 12. ERROR HANDLING
--==================================================

if not buildSuccess then

    warn("[Azic UI] UI initialization failed:")
    warn(tostring(buildError))

    if Library.Gui then
        pcall(function()
            Library.Gui:Destroy()
        end)
    end

    return
end

print("--------------------------------")
print(" AZIC UI INITIALIZED")
print(" Version: " .. tostring(Library.Version))
print(" Settings: Initialized")
print(" Dashboard: Initialized")
print(" Music: Initialized")
print(" Interface: Initialized")
print("--------------------------------")
