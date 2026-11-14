--[[
     _          _        _   _ ___
    / \    ____(_) ___  | | | |_ _|
   / _ \  |_  /| |/ __| | | | || |
  / ___ \  / / | | (__  | |_| || |
 /_/   \_\/___||_|\___|  \___/|___|   v2.0.0

 Azic UI - animated Roblox UI library (Linoria-style API)
 Features: animated window, ripple buttons, glowing toggles, smooth sliders,
 searchable dropdowns, inline color picker, keybinds (4 modes), tabboxes,
 dependency boxes, notifications, watermark, config system, live accent themes.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local Teams = game:GetService("Teams")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer

local Library = {
	Version = "2.0.0",
	Options = {}, Toggles = {}, Labels = {},
	Signals = {}, UnloadCallbacks = {}, AccentUpdaters = {}, KeyPickers = {},
	Unloaded = false,
	ToggleKeybind = Enum.KeyCode.RightShift,
	NotifySide = "Right",
	AnimationSpeed = 1,
	ReducedMotion = false,
	AmbientEffects = true,
	Touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
	ConfigFolder = "AzicUI",
	IgnoreIndexes = {},
	Theme = {
		Background = Color3.fromRGB(13, 13, 19),
		Panel = Color3.fromRGB(20, 20, 29),
		Element = Color3.fromRGB(29, 29, 42),
		ElementHover = Color3.fromRGB(40, 40, 58),
		Outline = Color3.fromRGB(46, 46, 66),
		Text = Color3.fromRGB(236, 236, 245),
		Muted = Color3.fromRGB(148, 163, 184),   -- 5.4:1 on Element
		Control = Color3.fromRGB(100, 116, 139), -- >=3:1 control borders
		Accent = Color3.fromRGB(139, 92, 255),
		AccentText = Color3.fromRGB(180, 149, 255), -- accent used for small text
		Risk = Color3.fromRGB(255, 85, 95),
	},
	Themes = {
		Violet = Color3.fromRGB(139, 92, 255),
		Cyan = Color3.fromRGB(34, 211, 238),
		Rose = Color3.fromRGB(251, 80, 130),
		Emerald = Color3.fromRGB(52, 211, 153),
		Amber = Color3.fromRGB(251, 191, 36),
		Ocean = Color3.fromRGB(59, 130, 246),
	},
}
local Theme = Library.Theme

-- Design tokens (global -> semantic -> component)
Library.Tokens = {
	Motion = { Fast = 0.12, Base = 0.2, Slow = 0.35, Enter = 0.45, Exit = 0.22 }, -- exit is faster than enter
	Radius = { Sm = 5, Md = 6, Lg = 8, Xl = 10 },
	Space = { 4, 8, 12, 16, 24 },
}
local Mo = Library.Tokens.Motion
local IsTouch = Library.Touch
-- Touch targets: >=44px rows on touch devices, compact on desktop
local Dim = {
	Row = IsTouch and 40 or 26, Button = IsTouch and 44 or 30, Input = IsTouch and 42 or 28,
	Item = IsTouch and 36 or 24, Hit = IsTouch and 30 or 18, Tab = IsTouch and 44 or 34, Close = IsTouch and 38 or 28,
}
do -- visible focus ring for gamepad / keyboard selection
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency = 1
	local rs = Instance.new("UIStroke"); rs.Color = Color3.new(1, 1, 1); rs.Thickness = 2; rs.Parent = ring
	local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = ring
	Library.Ring = ring
end

local Quint, Back, Out, Linear = Enum.EasingStyle.Quint, Enum.EasingStyle.Back, Enum.EasingDirection.Out, Enum.EasingStyle.Linear
local FontM, FontB, FontN = Enum.Font.GothamMedium, Enum.Font.GothamBold, Enum.Font.RobotoMono
local Left, Right, Center = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right, Enum.TextXAlignment.Center
local MB1, MB2, MB3 = Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function New(class, props, children)
	local inst = Instance.new(class)
	if class == "TextButton" then inst.SelectionImageObject = Library.Ring end
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	inst.Parent = parent
	return inst
end

local function Tween(obj, props, t, style, dir)
	local dur = Library.ReducedMotion and 0 or (t or 0.2) / Library.AnimationSpeed
	local tw = TweenService:Create(obj, TweenInfo.new(dur, Library.ReducedMotion and Linear or style or Quint, dir or Out), props)
	tw:Play()
	return tw
end

local function Corner(r) return New("UICorner", { CornerRadius = UDim.new(0, r or 6) }) end
local function Stroke(c, th, tr)
	return New("UIStroke", { Color = c or Theme.Outline, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function Pad(t, r, b, l)
	return New("UIPadding", { PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r or t), PaddingBottom = UDim.new(0, b or t), PaddingLeft = UDim.new(0, l or r or t) })
end
local function List(pad, dir)
	return New("UIListLayout", { Padding = UDim.new(0, pad or 0), SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = dir or Enum.FillDirection.Vertical })
end
local function Lbl(p)
	p.BackgroundTransparency = 1
	p.Font = p.Font or FontM
	p.TextSize = p.TextSize or 14
	p.TextColor3 = p.TextColor3 or Theme.Text
	p.TextXAlignment = p.TextXAlignment or Left
	return New("TextLabel", p)
end
local function Lighten(c, a) return c:Lerp(Color3.new(1, 1, 1), a) end
local function Round(n, d) local m = 10 ^ (d or 0) return math.floor(n * m + 0.5) / m end

local function PosOf(i)
	if i and i.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(i.Position.X, i.Position.Y) + GuiService:GetGuiInset()
	end
	return UserInputService:GetMouseLocation()
end
local function IsPress(i) return i.UserInputType == MB1 or i.UserInputType == Enum.UserInputType.Touch end
local function IsMove(i) return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch end

function Library:Connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(self.Signals, c)
	return c
end
function Library:OnAccent(fn) table.insert(self.AccentUpdaters, fn) fn(Theme.Accent) end
function Library:SetAccent(c)
	Theme.Accent = c
	Theme.AccentText = Lighten(c, 0.35)
	for _, f in ipairs(self.AccentUpdaters) do pcall(f, c) end
end
function Library:OnUnload(fn) table.insert(self.UnloadCallbacks, fn) end

local function Drag(obj, onMove, onDown, onUp)
	local active = false
	obj.InputBegan:Connect(function(i)
		if IsPress(i) then
			active = true
			if onDown then onDown() end
			onMove(PosOf(i))
		end
	end)
	Library:Connect(UserInputService.InputChanged, function(i)
		if active and IsMove(i) then onMove(PosOf(i)) end
	end)
	Library:Connect(UserInputService.InputEnded, function(i)
		if active and IsPress(i) then
			active = false
			if onUp then onUp() end
		end
	end)
end

local function Ripple(parent, pos)
	local ap, as = parent.AbsolutePosition, parent.AbsoluteSize
	local r = New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.78, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale((pos.X - ap.X) / math.max(as.X, 1), (pos.Y - ap.Y) / math.max(as.Y, 1)),
		Size = UDim2.fromOffset(0, 0), ZIndex = parent.ZIndex + 1, Parent = parent,
	}, { Corner(999) })
	local s = math.max(as.X, as.Y) * 2.4
	Tween(r, { Size = UDim2.fromOffset(s, s), BackgroundTransparency = 1 }, 0.6)
	task.delay(0.65, function() r:Destroy() end)
end

---------------------------------------------------------------------
-- Icons (vector, drawn from frames - no assets needed) and shine
---------------------------------------------------------------------
local kp = NumberSequenceKeypoint.new
local Icons = {}
Library.Icons = Icons
local function Bar(p, x, y, w, h, rot, c, r)
	return New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.5, y), Size = UDim2.fromOffset(w, h), Rotation = rot or 0, BackgroundColor3 = c, BorderSizePixel = 0, Parent = p }, { Corner(r or math.min(w, h) / 2) })
end
local function Dot(p, x, y, d, c) return Bar(p, x, y, d, d, 0, c, d / 2) end
local function Hollow(p, x, y, w, h, th, c, r)
	return New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.5, y), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, Parent = p }, { Corner(r or w / 2), Stroke(c, th) })
end
local function Tri(p, x, s, right, c) -- triangle = half of a rotated square, clipped
	local clip = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.5, 0), Size = UDim2.fromOffset(s, s * 2), BackgroundTransparency = 1, ClipsDescendants = true, Parent = p })
	New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, right and 0 or s, 0, s), Size = UDim2.fromOffset(s * 1.4142, s * 1.4142), Rotation = 45, BackgroundColor3 = c, BorderSizePixel = 0, Parent = clip })
end
Icons.home = function(p, c) Bar(p, 0, 4, 11, 8, 0, c, 2) Bar(p, -3.6, -3, 11, 2.4, -40, c) Bar(p, 3.6, -3, 11, 2.4, 40, c) end
Icons.user = function(p, c) Dot(p, 0, -4.5, 7, c) Bar(p, 0, 6, 13, 7, 0, c, 4) end
Icons.music = function(p, c) Dot(p, -3.5, 5.5, 6, c) Bar(p, 0, -1, 2.2, 12, 0, c, 1) Bar(p, 3.6, -5.5, 6, 2.2, 38, c) end
Icons.gear = function(p, c)
	Hollow(p, 0, 0, 10, 10, 2.4, c)
	for i = 0, 7 do local a = math.rad(i * 45) Bar(p, math.cos(a) * 7.6, math.sin(a) * 7.6, 3.2, 3.2, 0, c, 1) end
end
Icons.eye = function(p, c) Hollow(p, 0, 0, 17, 10, 1.8, c, 5) Dot(p, 0, 0, 5, c) end
Icons.bolt = function(p, c) Bar(p, 2, -4.5, 2.8, 10, 24, c) Bar(p, -2, 4.5, 2.8, 10, 24, c) Bar(p, 0, 0, 8, 2.6, 24, c) end
Icons.shield = function(p, c) Hollow(p, 0, 0, 12, 14, 1.8, c, 5) Bar(p, 0, 0, 2.2, 6, 0, c) end
Icons.game = function(p, c)
	Bar(p, 0, 1, 18, 10, 0, c, 5) Bar(p, -4.5, 1, 4, 1.8, 0, Theme.Panel) Bar(p, -4.5, 1, 1.8, 4, 0, Theme.Panel)
	Dot(p, 4, -0.2, 2.2, Theme.Panel) Dot(p, 6.5, 2.4, 2.2, Theme.Panel)
end
Icons.play = function(p, c) Tri(p, 0.8, 6, true, c) end
Icons.pause = function(p, c) Bar(p, -3.4, 0, 3.4, 12, 0, c, 1) Bar(p, 3.4, 0, 3.4, 12, 0, c, 1) end
Icons.next = function(p, c) Tri(p, -2.2, 5, true, c) Bar(p, 3.6, 0, 2.4, 10, 0, c, 1) end
Icons.prev = function(p, c) Tri(p, 2.2, 5, false, c) Bar(p, -3.6, 0, 2.4, 10, 0, c, 1) end
Icons.close = function(p, c) Bar(p, 0, 0, 14, 2.2, 45, c) Bar(p, 0, 0, 14, 2.2, -45, c) end
Icons.plus = function(p, c) Bar(p, 0, 0, 12, 2.2, 0, c) Bar(p, 0, 0, 2.2, 12, 0, c) end
Icons.minus = function(p, c) Bar(p, 0, 0, 12, 2.2, 0, c) end
Icons.check = function(p, c) Bar(p, -3.2, 1.5, 5.5, 2.4, 45, c) Bar(p, 2.2, 0, 10, 2.4, -52, c) end
Icons.chevron = function(p, c) Bar(p, -2.6, 0, 7, 2.2, 45, c) Bar(p, 2.6, 0, 7, 2.2, -45, c) end
Icons.chevronright = function(p, c) Bar(p, 0, -2.6, 7, 2.2, 45, c) Bar(p, 0, 2.6, 7, 2.2, -45, c) end
Icons.matrix = function(p, c) for _, x in ipairs({ -4, 4 }) do for _, y in ipairs({ -4, 4 }) do Bar(p, x, y, 6, 6, 0, c, 1.5) end end end
Icons.sparkle = function(p, c) Bar(p, 0, 0, 2.6, 17, 0, c) Bar(p, 0, 0, 17, 2.6, 0, c) Bar(p, 0, 0, 2, 9, 45, c) Bar(p, 0, 0, 2, 9, -45, c) end
Icons.arrow = function(p, c) Bar(p, 0, 0, 12, 2.2, -45, c) Bar(p, 2.4, -4.6, 8, 2.2, 0, c) Bar(p, 4.6, -2.4, 2.2, 8, 0, c) end
Icons["repeat"] = function(p, c) Hollow(p, 0, 0, 13, 9, 1.8, c, 4) Tri(p, 2, 3.5, true, c) end

local function MakeIcon(name, parent, color, size)
	size = size or 18
	local box = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = parent })
	local inner = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), Parent = box }, { New("UIScale", { Scale = size / 20 }) })
	if Icons[name] then Icons[name](inner, color or Theme.Text) end
	return box
end
local function Recolor(icon, c, t)
	for _, d in ipairs(icon:GetDescendants()) do
		if d:IsA("Frame") and d.BackgroundTransparency < 1 then Tween(d, { BackgroundColor3 = c }, t or 0.15)
		elseif d:IsA("UIStroke") then Tween(d, { Color = c }, t or 0.15) end
	end
end
function Library:Icon(name, parent, color, size) return MakeIcon(name, parent, color, size) end

-- Shine: a diagonal gloss bar that sweeps across a surface. Returns a function that plays it.
local function Shine(parent)
	parent.ClipsDescendants = true
	local bar = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.3, 0.5), Size = UDim2.new(0.3, 0, 2.4, 0), Rotation = 20, ZIndex = parent.ZIndex + 2, Parent = parent }, {
		New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 1), kp(0.5, 0.82), kp(1, 1) }) }),
	})
	local busy = false
	return function()
		if busy or Library.ReducedMotion or Library.ShineEnabled == false then return end
		busy = true
		bar.Position = UDim2.fromScale(-0.3, 0.5)
		Tween(bar, { Position = UDim2.fromScale(1.3, 0.5) }, 0.75, Quint)
		task.delay(0.8, function() busy = false end)
	end
end

---------------------------------------------------------------------
-- Root GUI, tooltip, notifications, watermark
---------------------------------------------------------------------
local Gui = New("ScreenGui", { Name = "AzicUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
do
	local ok = pcall(function() Gui.Parent = (gethui and gethui()) or CoreGui end)
	if not ok or not Gui.Parent then Gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end
Library.Gui = Gui

local Tip = Lbl({
	Visible = false, AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, BackgroundColor3 = Theme.Panel,
	TextTransparency = 1, TextSize = 13, ZIndex = 200, Parent = Gui,
}, nil)
Tip.BackgroundTransparency = 1
Corner(5).Parent = Tip; Stroke().Parent = Tip; Pad(5, 9).Parent = Tip
local tipToken = 0
Library:Connect(RunService.RenderStepped, function()
	if Tip.Visible then
		local m = UserInputService:GetMouseLocation()
		Tip.Position = UDim2.fromOffset(m.X + 14, m.Y + 8)
	end
end)
function Library:AddTooltip(obj, getText)
	obj.MouseEnter:Connect(function()
		local t = getText()
		if t and t ~= "" then
			tipToken += 1
			Tip.Text = t
			Tip.Visible = true
			Tween(Tip, { BackgroundTransparency = 0, TextTransparency = 0 }, 0.15)
		end
	end)
	obj.MouseLeave:Connect(function()
		tipToken += 1
		local tk = tipToken
		Tween(Tip, { BackgroundTransparency = 1, TextTransparency = 1 }, 0.1)
		task.delay(0.12, function() if tk == tipToken then Tip.Visible = false end end)
	end)
end

local NotifyHolder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 280, 1, -28), Position = UDim2.new(1, -14, 0, 14), AnchorPoint = Vector2.new(1, 0), Parent = Gui })
local NotifyList = List(8); NotifyList.Parent = NotifyHolder

function Library:Notify(a, b)
	local o = type(a) == "table" and a or { Description = a, Time = b }
	local kinds = { Success = { "Success", Color3.fromRGB(52, 211, 153) }, Warning = { "Warning", Color3.fromRGB(251, 191, 36) }, Error = { "Error", Theme.Risk } }
	local kind = kinds[o.Type or ""]
	local tone = kind and kind[2] or Theme.Accent
	local title, desc, dur = o.Title or (kind and kind[1]) or "Azic UI", o.Description or o.Text or "", o.Time or 4
	local right = self.NotifySide ~= "Left"
	NotifyHolder.AnchorPoint = Vector2.new(right and 1 or 0, 0)
	NotifyHolder.Position = UDim2.new(right and 1 or 0, right and -14 or 14, 0, 14)
	NotifyList.HorizontalAlignment = right and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
	local th = TextService:GetTextSize(desc, 13, FontM, Vector2.new(240, 1000)).Y
	local H = 34 + th + 10
	local wrap = New("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.new(0, 280, 0, 0), Parent = NotifyHolder })
	local inner = New("Frame", { BackgroundColor3 = Theme.Panel, Size = UDim2.new(0, 280, 0, H), Position = UDim2.new(right and 1.1 or -1.1, 0, 0, 0), Parent = wrap }, { Corner(8), Stroke() })
	New("Frame", { BackgroundColor3 = tone, Size = UDim2.new(0, 3, 1, 0), Parent = inner }, { Corner(2) })
	Lbl({ Text = title, Font = FontB, TextColor3 = Lighten(tone, 0.35), Position = UDim2.fromOffset(14, 7), Size = UDim2.new(1, -24, 0, 18), Parent = inner })
	Lbl({ Text = desc, TextSize = 13, TextColor3 = Theme.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(14, 27), Size = UDim2.new(1, -24, 0, th), Parent = inner })
	local bar = New("Frame", { BackgroundColor3 = tone, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, Parent = inner })
	Tween(wrap, { Size = UDim2.new(0, 280, 0, H) }, 0.3)
	Tween(inner, { Position = UDim2.new(0, 0, 0, 0) }, 0.45, Back)
	Tween(bar, { Size = UDim2.new(0, 0, 0, 2) }, dur, Linear)
	task.delay(dur, function()
		Tween(inner, { Position = UDim2.new(right and 1.1 or -1.1, 0, 0, 0) }, 0.35)
		task.wait(0.3)
		Tween(wrap, { Size = UDim2.new(0, 280, 0, 0) }, 0.25)
		task.wait(0.3)
		wrap:Destroy()
	end)
end

function Library:SetWatermark(text)
	if not self.WM then
		local f = New("Frame", { BackgroundColor3 = Theme.Panel, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Parent = Gui }, { Corner(6), Stroke() })
		local l = New("Frame", { BackgroundColor3 = Theme.Accent, Size = UDim2.new(1, 0, 0, 2), Parent = f }, { Corner(2) })
		self:OnAccent(function(c) l.BackgroundColor3 = c end)
		local t = Lbl({ TextSize = 13, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), Parent = f }, nil)
		Pad(0, 10).Parent = t
		self.WM = { Frame = f, Label = t }
	end
	self.WM.Label.Text = text
end
function Library:SetWatermarkVisibility(v) if not self.WM then self:SetWatermark("Azic UI") end self.WM.Frame.Visible = v end

---------------------------------------------------------------------
-- Element base
---------------------------------------------------------------------
local Element = {}
Element.__index = Element
function Element:OnChanged(fn) table.insert(self.Changed, fn) return self end
function Element:_Fire()
	if self.Callback then task.spawn(self.Callback, self.Value, self.Transparency) end
	for _, f in ipairs(self.Changed) do task.spawn(f, self.Value, self.Transparency) end
end
function Element:SetVisible(v) self.Holder.Visible = v end
function Element:SetDisabled(d)
	self.Disabled = d
	if self.Label then Tween(self.Label, { TextTransparency = d and 0.6 or 0 }) end
end
function Element:SetText(t) if self.Label then self.Label.Text = t end end
function Element:Reset() if self.Default ~= nil and self.SetValue then self:SetValue(self.Default) end end

local function NewElement(t, info, holder, label)
	return setmetatable({ Type = t, Changed = {}, Callback = info.Callback, Holder = holder, Label = label, Disabled = info.Disabled or false }, Element)
end
local function TipFor(obj, el, info)
	Library:AddTooltip(obj, function()
		if el.Disabled and info.DisabledTooltip then return info.DisabledTooltip end
		return info.Tooltip
	end)
end

---------------------------------------------------------------------
-- Addons: ColorPicker & KeyPicker
---------------------------------------------------------------------
local function ParseKey(n)
	if n == "MB1" then return MB1 elseif n == "MB2" then return MB2 elseif n == "MB3" then return MB3 end
	if not n or n == "None" then return nil end
	local ok, k = pcall(function() return Enum.KeyCode[n] end)
	return ok and k or nil
end

local function MakeColorPicker(parent, idx, info)
	info = info or {}
	local P = NewElement("ColorPicker", info, parent.Holder, nil)
	P.Transparency = info.Transparency
	local h, s, v = (info.Default or Color3.new(1, 1, 1)):ToHSV()
	P.Value = Color3.fromHSV(h, s, v)
	P.Default = P.Value

	local Swatch = New("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(Dim.Hit + 8, Dim.Hit - 2), BackgroundColor3 = P.Value, Parent = parent.Addons }, { Corner(5), Stroke() })
	Library:AddTooltip(Swatch, function() return info.Title end)
	local Panel = New("Frame", { BackgroundColor3 = Theme.Element, Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true, Visible = false, LayoutOrder = 5, Parent = parent.Holder }, { Corner(6) })
	local SV = New("Frame", { BackgroundColor3 = Color3.fromHSV(h, 1, 1), Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -44, 0, 104), ClipsDescendants = true, Parent = Panel }, { Corner(4) })
	New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = SV }, { New("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
	New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), Parent = SV }, { New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) })
	local SVCur = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = SV }, { Corner(5), Stroke(Color3.new(1, 1, 1), 2) })
	local Hue = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(20, 104), BackgroundColor3 = Color3.new(1, 1, 1), Parent = Panel }, {
		Corner(4),
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
			ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)), ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
			ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)), ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1)) }) }),
	})
	local HueCur = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 6, 0, 4), BackgroundColor3 = Color3.new(1, 1, 1), Parent = Hue }, { Corner(2), Stroke(Color3.new(0, 0, 0), 1, 0.4) })

	local function Update(fire, animate)
		P.Value = Color3.fromHSV(h, s, v)
		Swatch.BackgroundColor3 = P.Value
		SV.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		SVCur.Position = UDim2.fromScale(s, 1 - v)
		HueCur.Position = UDim2.fromScale(0.5, h)
		if fire then P:_Fire() end
	end
	Drag(SV, function(m)
		s = math.clamp((m.X - SV.AbsolutePosition.X) / SV.AbsoluteSize.X, 0, 1)
		v = 1 - math.clamp((m.Y - SV.AbsolutePosition.Y) / SV.AbsoluteSize.Y, 0, 1)
		Update(true)
	end)
	Drag(Hue, function(m)
		h = math.clamp((m.Y - Hue.AbsolutePosition.Y) / Hue.AbsoluteSize.Y, 0, 0.999)
		Update(true)
	end)
	local open = false
	Swatch.MouseButton1Click:Connect(function()
		open = not open
		if open then
			Panel.Visible = true
			Tween(Panel, { Size = UDim2.new(1, 0, 0, 120) }, 0.3)
		else
			Tween(Panel, { Size = UDim2.new(1, 0, 0, 0) }, 0.25)
			task.delay(0.26, function() if not open then Panel.Visible = false end end)
		end
	end)
	function P:SetValue(c) h, s, v = c:ToHSV() Update(true) end
	P.SetValueRGB = P.SetValue
	function P:SetHSV(hh, ss, vv) h, s, v = hh, ss, vv Update(true) end
	Update(false)
	if idx then Library.Options[idx] = P end
	return P
end

local KeyModes = { "Toggle", "Hold", "Always", "Press" }
local function MakeKeyPicker(parent, idx, info)
	info = info or {}
	local KP = NewElement("KeyPicker", info, parent.Holder, nil)
	KP.Value = info.Default or "None"
	KP.Default = KP.Value
	KP.Mode = info.Mode or "Toggle"
	KP.State = KP.Mode == "Always"
	KP.Clicked = {}
	KP.Text = info.Text

	local Btn = New("TextButton", {
		Text = "", AutoButtonColor = false, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, Dim.Hit),
		BackgroundColor3 = Theme.Element, Font = FontN, TextSize = 12, TextColor3 = Theme.Muted, Parent = parent.Addons,
	}, { Corner(5), Stroke(), Pad(0, 6) })
	Btn.MouseEnter:Connect(function() Tween(Btn, { BackgroundColor3 = Theme.ElementHover }, 0.12) end)
	Btn.MouseLeave:Connect(function() Tween(Btn, { BackgroundColor3 = Theme.Element }, 0.12) end)
	Library:AddTooltip(Btn, function() return "Mode: " .. KP.Mode .. "  (right-click to change)" end)

	local function Refresh() Btn.Text = "[" .. tostring(KP.Value) .. "]" end
	function KP:SetValue(t)
		if type(t) == "table" then
			if t[1] then KP.Value = t[1] end
			if t[2] then KP.Mode = t[2] end
		elseif t then KP.Value = t end
		if KP.Mode == "Always" then KP.State = true end
		Refresh()
		if info.ChangedCallback then task.spawn(info.ChangedCallback, ParseKey(KP.Value), {}) end
		for _, f in ipairs(KP.Changed) do task.spawn(f, KP.Value) end
	end
	function KP:GetState() return KP.Mode == "Always" or KP.State end
	function KP:OnClick(fn) table.insert(KP.Clicked, fn) return KP end
	function KP:Matches(input)
		local k = ParseKey(KP.Value)
		if not k then return false end
		if k.EnumType == Enum.UserInputType then return input.UserInputType == k end
		return input.KeyCode == k
	end
	local function Click(state)
		if info.Callback then task.spawn(info.Callback, state) end
		for _, f in ipairs(KP.Clicked) do task.spawn(f, state) end
	end
	function KP:_Down()
		if KP.Mode == "Toggle" then
			KP.State = not KP.State
			if info.SyncToggleState and parent.Type == "Toggle" then parent:SetValue(KP.State) end
			Click(KP.State)
		elseif KP.Mode == "Hold" then KP.State = true Click(true)
		elseif KP.Mode == "Press" then Click(true) end
	end
	function KP:_Up()
		if KP.Mode == "Hold" and KP.State then KP.State = false Click(false) end
	end
	if info.SyncToggleState and parent.Type == "Toggle" then
		KP.State = parent.Value
		parent:OnChanged(function(val) KP.State = val end)
	end

	Btn.MouseButton1Click:Connect(function()
		Btn.Text = "[...]"
		Tween(Btn, { TextColor3 = Theme.AccentText }, 0.15)
		task.defer(function()
			Library.Listener = function(input)
				local name
				if input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.Escape then name = KP.Value
					elseif input.KeyCode == Enum.KeyCode.Backspace then name = "None"
					else name = input.KeyCode.Name end
				elseif input.UserInputType == MB1 then name = "MB1"
				elseif input.UserInputType == MB2 then name = "MB2"
				elseif input.UserInputType == MB3 then name = "MB3" end
				if not name then return false end
				KP:SetValue({ name })
				Tween(Btn, { TextColor3 = Theme.Muted }, 0.15)
				return true
			end
		end)
	end)
	Btn.MouseButton2Click:Connect(function()
		local i = table.find(KeyModes, KP.Mode) or 1
		KP.Mode = KeyModes[i % #KeyModes + 1]
		KP.State = KP.Mode == "Always"
		Library:Notify({ Title = "Keybind mode", Description = (KP.Text or idx or "Keybind") .. " -> " .. KP.Mode, Time = 2 })
	end)
	Refresh()
	table.insert(Library.KeyPickers, KP)
	if idx then Library.Options[idx] = KP end
	return KP
end

local function AttachAddons(obj)
	function obj:AddColorPicker(i, inf) MakeColorPicker(obj, i, inf) return obj end
	function obj:AddKeyPicker(i, inf) MakeKeyPicker(obj, i, inf) return obj end
end
local function NewAddons(head, rightOffset)
	return New("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(rightOffset or 0), 0.5, 0),
		Size = UDim2.fromOffset(0, Dim.Hit + 4), AutomaticSize = Enum.AutomaticSize.X, Parent = head,
	}, { New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
end

---------------------------------------------------------------------
-- Groupbox elements
---------------------------------------------------------------------
local Base = {}
Base.__index = Base

function Base:_Row()
	self.Order = (self.Order or 0) + 1
	return New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self.Order, Parent = self.Container }, { List(4) })
end

function Base:AddToggle(idx, info)
	info = info or {}
	local Holder = self:_Row()
	local Head = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Dim.Row), Parent = Holder })
	local Label = Lbl({ Text = info.Text or idx, TextColor3 = info.Risky and Theme.Risk or Theme.Text, Size = UDim2.new(1, -50, 1, 0), Parent = Head })
	local Switch = New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(38, 20), BackgroundColor3 = Theme.Element, Parent = Head }, { Corner(10) })
	local SwStroke = Stroke(Theme.Control, 1); SwStroke.Parent = Switch
	local Knob = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Theme.Muted, Parent = Switch }, { Corner(7), New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 220)) }) })

	local T = NewElement("Toggle", info, Holder, Label)
	T.Value = false
	T.Head = Head
	T.Addons = NewAddons(Head, 48)
	local function Render(animate)
		local on, t = T.Value, animate and 0.28 or 0
		Tween(Switch, { BackgroundColor3 = on and Theme.Accent or Theme.Element }, t)
		Tween(SwStroke, { Color = on and Lighten(Theme.Accent, 0.3) or Theme.Control, Thickness = on and 1.5 or 1 }, t)
		Tween(Knob, { Position = on and UDim2.new(1, -10, 0.5, 0) or UDim2.new(0, 10, 0.5, 0), BackgroundColor3 = on and Color3.new(1, 1, 1) or Theme.Muted, Size = UDim2.fromOffset(14, 14) }, t, Back)
	end
	function T:SetValue(v)
		v = v and true or false
		if v == T.Value then return end
		T.Value = v
		Render(true)
		T:_Fire()
	end
	Head.MouseButton1Down:Connect(function() if not T.Disabled then Tween(Knob, { Size = UDim2.fromOffset(20, 14) }, 0.12) end end)
	Head.MouseButton1Click:Connect(function() if not T.Disabled then T:SetValue(not T.Value) end end)
	Head.MouseEnter:Connect(function() if not T.Value then Tween(Switch, { BackgroundColor3 = Theme.ElementHover }, 0.15) end end)
	Head.MouseLeave:Connect(function() Render(true) end)
	Library:OnAccent(function() Render(false) end)
	TipFor(Head, T, info)
	T.Value = info.Default and true or false
	T.Default = T.Value
	Render(false)
	if info.Disabled then T:SetDisabled(true) end
	if info.Visible == false then Holder.Visible = false end
	AttachAddons(T)
	if idx then Library.Toggles[idx] = T end
	return T
end

function Base:AddButton(a, b)
	local info = type(a) == "table" and a or { Text = a, Func = b }
	local Holder = self:_Row()
	local Row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Dim.Button), Parent = Holder }, { List(6, Enum.FillDirection.Horizontal) })
	local Group = { Buttons = {} }

	local function Resize()
		local n, gap = #Group.Buttons, 6
		for _, bt in ipairs(Group.Buttons) do bt.Btn.Size = UDim2.new(1 / n, -(gap * (n - 1)) / n, 1, 0) end
	end
	local function Make(inf)
		local B = NewElement("Button", inf, Holder, nil)
		local Btn = New("TextButton", {
			Text = inf.Text or "Button", Font = FontM, TextSize = 14, TextColor3 = Theme.Text, AutoButtonColor = false,
			BackgroundColor3 = Theme.Element, ClipsDescendants = true, Size = UDim2.new(1, 0, 1, 0), Parent = Row,
		}, { Corner(6) })
		local BS = Stroke(Theme.Control, 1); BS.Parent = Btn
		local Sc = New("UIScale", { Parent = Btn })
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 208)), Parent = Btn })
		local Sweep = Shine(Btn)
		B.Btn, B.Label = Btn, Btn
		local armed = false
		Btn.MouseEnter:Connect(function() if not B.Disabled then Sweep() Tween(Btn, { BackgroundColor3 = Theme.ElementHover }, 0.15) Tween(BS, { Color = Theme.Accent }, 0.15) end end)
		Btn.MouseLeave:Connect(function() Tween(Btn, { BackgroundColor3 = Theme.Element }, 0.2) Tween(BS, { Color = Theme.Control }, 0.2) Tween(Sc, { Scale = 1 }, 0.15) end)
		Btn.MouseButton1Down:Connect(function() if not B.Disabled then Tween(Sc, { Scale = 0.96 }, 0.1) end end)
		Btn.MouseButton1Up:Connect(function() Tween(Sc, { Scale = 1 }, 0.25, Back) end)
		Btn.MouseButton1Click:Connect(function()
			if B.Disabled then return end
			Ripple(Btn, UserInputService:GetMouseLocation())
			if inf.DoubleClick and not armed then
				armed = true
				Btn.Text = "Click again to confirm"
				Tween(Btn, { TextColor3 = Theme.AccentText }, 0.15)
				task.delay(0.9, function()
					if armed then armed = false Btn.Text = inf.Text or "Button" Tween(Btn, { TextColor3 = Theme.Text }, 0.15) end
				end)
				return
			end
			armed = false
			Btn.Text = inf.Text or "Button"
			Tween(Btn, { TextColor3 = Theme.Text }, 0.15)
			if inf.Func then task.spawn(inf.Func) end
		end)
		TipFor(Btn, B, inf)
		function B:SetText(t) inf.Text = t Btn.Text = t end
		function B:SetDisabled(d) B.Disabled = d Tween(Btn, { TextTransparency = d and 0.6 or 0 }, 0.15) end
		function B:SetVisible(v) Btn.Visible = v Resize() end
		function B:AddButton(i2) return Group.Add(i2) end
		if inf.Disabled then B:SetDisabled(true) end
		if inf.Visible == false then Btn.Visible = false end
		table.insert(Group.Buttons, B)
		Resize()
		return B
	end
	Group.Add = function(i2) return Make(type(i2) == "table" and i2 or { Text = i2 }) end
	return Make(info)
end

function Base:AddLabel(a, b, c)
	local idx, text, wrap
	if type(b) == "table" then idx, text, wrap = a, b.Text or "", b.DoesWrap else text, wrap, idx = a, b, c end
	local Holder = self:_Row()
	local Head = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), AutomaticSize = wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None, Parent = Holder })
	local Label = Lbl({ Text = text, TextColor3 = Theme.Muted, TextWrapped = wrap and true or false, TextTruncate = wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 22), AutomaticSize = wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None, Parent = Head })
	local L = NewElement("Label", {}, Holder, Label)
	L.Addons = NewAddons(Head, 0)
	function L:SetText(t) Label.Text = t end
	AttachAddons(L)
	if idx then Library.Labels[idx] = L end
	return L
end

function Base:AddDivider()
	local H = self:_Row()
	H.AutomaticSize = Enum.AutomaticSize.None
	H.Size = UDim2.new(1, 0, 0, 10)
	New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = H }, {
		New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1) }) }),
	})
end

function Base:AddSlider(idx, info)
	info = info or {}
	local Min, Max, Rounding = info.Min or 0, info.Max or 100, info.Rounding or 0
	local Holder = self:_Row()
	local Top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Parent = Holder })
	local Label = Lbl({ Text = info.Compact and "" or (info.Text or idx), Size = UDim2.new(0.65, 0, 1, 0), Parent = Top })
	local ValueLbl = Lbl({ Font = FontN, TextColor3 = Theme.Muted, TextXAlignment = Right, Size = UDim2.new(0.35, 0, 1, 0), Position = UDim2.fromScale(0.65, 0), TextSize = 13, Parent = Top })
	local SRow = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Dim.Hit + 4), Parent = Holder })
	local Hit = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(Dim.Hit + 8, 0), Size = UDim2.new(1, -(Dim.Hit + 8) * 2, 1, 0), Parent = SRow })
	local Track = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Theme.Element, Parent = Hit }, { Corner(4) })
	local TS = Stroke(Theme.Control, 1); TS.Parent = Track
	local Fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent, Parent = Track }, { Corner(4), New("UIGradient", { Color = ColorSequence.new(Theme.Accent, Lighten(Theme.Accent, 0.35)) }) })
	local Knob = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = Track }, { Corner(8) })
	local S = NewElement("Slider", info, Holder, Label)
	local Step = info.Step or 10 ^ -Rounding
	local function StepBtn(icon, dir)
		local b = New("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(dir < 0 and 0 or 1, 0.5), Position = UDim2.new(dir < 0 and 0 or 1, 0, 0.5, 0), Size = UDim2.fromOffset(Dim.Hit, Dim.Hit), BackgroundColor3 = Theme.Element, Parent = SRow }, { Corner(Dim.Hit / 2), Stroke(Theme.Control, 1) })
		local ic = MakeIcon(icon, b, Theme.Muted, Dim.Hit * 0.55)
		ic.AnchorPoint, ic.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		local token = 0
		b.MouseEnter:Connect(function() Tween(b, { BackgroundColor3 = Theme.ElementHover }, 0.12) Recolor(ic, Theme.Text, 0.12) end)
		b.MouseLeave:Connect(function() token += 1 Tween(b, { BackgroundColor3 = Theme.Element }, 0.15) Recolor(ic, Theme.Muted, 0.15) end)
		b.MouseButton1Down:Connect(function()
			if S.Disabled then return end
			token += 1
			local tk = token
			S:SetValue(S.Value + dir * Step)
			task.delay(0.35, function()
				while tk == token and not S.Disabled do S:SetValue(S.Value + dir * Step) task.wait(0.06) end
			end)
		end)
		b.MouseButton1Up:Connect(function() token += 1 end)
	end
	StepBtn("minus", -1)
	StepBtn("plus", 1)
	S.Min, S.Max = Min, Max
	local function Fmt()
		if info.FormatDisplayValue then
			local ok, r = pcall(info.FormatDisplayValue, S, S.Value)
			if ok and r then return tostring(r) end
		end
		local suf = info.Suffix or ""
		if info.HideMax or info.Compact then return S.Value .. suf end
		return S.Value .. suf .. " / " .. Max .. suf
	end
	local function Render(animate)
		local f = Max == Min and 0 or (S.Value - Min) / (Max - Min)
		local t = animate and 0.12 or 0
		Tween(Fill, { Size = UDim2.fromScale(f, 1) }, t)
		Tween(Knob, { Position = UDim2.fromScale(f, 0.5) }, t)
		ValueLbl.Text = Fmt()
	end
	function S:SetValue(v)
		v = math.clamp(Round(tonumber(v) or Min, Rounding), Min, Max)
		local changed = v ~= S.Value
		S.Value = v
		Render(true)
		if changed then S:_Fire() end
	end
	function S:SetMax(m) Max, S.Max = m, m S:SetValue(S.Value) end
	function S:SetMin(m) Min, S.Min = m, m S:SetValue(S.Value) end
	Drag(Hit, function(m)
		if S.Disabled then return end
		local f = math.clamp((m.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
		S:SetValue(Min + (Max - Min) * f)
	end, function()
		Tween(Knob, { Size = UDim2.fromOffset(16, 16) }, 0.2, Back)
		Tween(ValueLbl, { TextColor3 = Theme.AccentText }, 0.15)
	end, function()
		Tween(Knob, { Size = UDim2.fromOffset(10, 10) }, 0.2)
		Tween(ValueLbl, { TextColor3 = Theme.Muted }, 0.15)
	end)
	Hit.MouseEnter:Connect(function() Tween(TS, { Color = Theme.Accent }, 0.15) end)
	Hit.MouseLeave:Connect(function() Tween(TS, { Color = Theme.Control }, 0.15) end)
	Library:OnAccent(function(c)
		Fill.BackgroundColor3 = c
		Fill:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(c, Lighten(c, 0.35))
	end)
	Library:AddTooltip(Hit, function()
		if S.Disabled and info.DisabledTooltip then return info.DisabledTooltip end
		return (info.Tooltip and (info.Tooltip .. "\n") or "") .. "Right-click to type a value"
	end)
	Hit.MouseButton2Click:Connect(function()
		if S.Disabled then return end
		local Box = New("TextBox", { Text = tostring(S.Value), Font = FontN, TextSize = 13, TextColor3 = Theme.Text, BackgroundColor3 = Theme.Panel, ClearTextOnFocus = false, Size = UDim2.new(0.35, 0, 1, 0), Position = UDim2.fromScale(0.65, 0), ZIndex = 5, Parent = Top }, { Corner(4), Stroke(Theme.Accent, 1) })
		ValueLbl.Visible = false
		Box:CaptureFocus()
		Box.FocusLost:Connect(function(enter)
			local n = tonumber(Box.Text)
			if enter and n then S:SetValue(n) end
			ValueLbl.Visible = true
			Box:Destroy()
		end)
	end)
	S.Value = math.clamp(info.Default or Min, Min, Max)
	S.Default = S.Value
	Render(false)
	if info.Disabled then S:SetDisabled(true) end
	if info.Visible == false then Holder.Visible = false end
	if idx then Library.Options[idx] = S end
	return S
end

function Base:AddInput(idx, info)
	info = info or {}
	local Holder = self:_Row()
	local Label
	if info.Text then Label = Lbl({ Text = info.Text, Size = UDim2.new(1, 0, 0, 18), Parent = Holder }) end
	local Box = New("TextBox", {
		Text = info.Default or "", PlaceholderText = info.Placeholder or "", PlaceholderColor3 = Theme.Muted, TextColor3 = Theme.Text,
		Font = FontM, TextSize = 14, TextXAlignment = Left, ClearTextOnFocus = info.ClearTextOnFocus == true,
		BackgroundColor3 = Theme.Element, Size = UDim2.new(1, 0, 0, Dim.Input), ClipsDescendants = true, Parent = Holder,
	}, { Corner(6), Pad(0, 8) })
	local BS = Stroke(Theme.Control, 1); BS.Parent = Box
	local I = NewElement("Input", info, Holder, Label)
	I.Value = Box.Text
	I.Default = I.Value
	function I:SetValue(t)
		t = tostring(t)
		if info.MaxLength then t = t:sub(1, info.MaxLength) end
		Box.Text = t
		if I.Value ~= t then I.Value = t I:_Fire() end
	end
	Box:GetPropertyChangedSignal("Text"):Connect(function()
		local t = Box.Text
		if info.Numeric then
			local clean = t:gsub("[^%d%.%-]", "")
			if clean ~= t then Box.Text = clean return end
		end
		if info.MaxLength and #t > info.MaxLength then Box.Text = t:sub(1, info.MaxLength) return end
		if not info.Finished and I.Value ~= t then I.Value = t I:_Fire() end
	end)
	Box.Focused:Connect(function() Tween(BS, { Color = Theme.Accent, Thickness = 1.5 }, 0.15) Tween(Box, { BackgroundColor3 = Theme.ElementHover }, 0.15) end)
	Box.FocusLost:Connect(function(enter)
		Tween(BS, { Color = Theme.Control, Thickness = 1 }, 0.15) Tween(Box, { BackgroundColor3 = Theme.Element }, 0.15)
		if info.Finished and enter then I.Value = Box.Text I:_Fire() end
	end)
	TipFor(Box, I, info)
	if info.Visible == false then Holder.Visible = false end
	if idx then Library.Options[idx] = I end
	return I
end

function Base:AddDropdown(idx, info)
	info = info or {}
	local Holder = self:_Row()
	local Label
	if info.Text then Label = Lbl({ Text = info.Text, Size = UDim2.new(1, 0, 0, 18), Parent = Holder }) end
	local Head = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Element, Size = UDim2.new(1, 0, 0, Dim.Input), ClipsDescendants = true, Parent = Holder }, { Corner(6) })
	local HS = Stroke(Theme.Control, 1); HS.Parent = Head
	local Disp = Lbl({ Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(8, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = Head })
	local Arrow = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(20, 20), Parent = Head })
	local ArrowBars = {}
	for _, d in ipairs({ { -3, 45 }, { 3, -45 } }) do
		table.insert(ArrowBars, New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, d[1], 0.5, 0), Size = UDim2.fromOffset(8, 2), Rotation = d[2], BackgroundColor3 = Theme.Muted, BorderSizePixel = 0, Parent = Arrow }, { Corner(1) }))
	end
	local ListF = New("Frame", { BackgroundColor3 = Theme.Element, Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true, Visible = false, LayoutOrder = 2, Parent = Holder }, { Corner(6) })
	local Search
	local topOff = 4
	if info.Searchable then
		Search = New("TextBox", { Text = "", PlaceholderText = "Search...", PlaceholderColor3 = Theme.Muted, TextColor3 = Theme.Text, Font = FontM, TextSize = 13, TextXAlignment = Left, ClearTextOnFocus = false, BackgroundColor3 = Theme.Panel, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 24), Parent = ListF }, { Corner(5), Pad(0, 6) })
		topOff = 32
	end
	local Scroll = New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, topOff), Size = UDim2.new(1, 0, 1, -topOff - 2), ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.Accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = ListF }, { List(2), Pad(0, 4) })

	local D = NewElement("Dropdown", info, Holder, Label)
	D.Multi = info.Multi or false
	D.Values = info.Values or {}
	D.DisabledValues = {}
	for _, v in ipairs(info.DisabledValues or {}) do D.DisabledValues[v] = true end
	D.Value = D.Multi and {} or nil
	local open, items = false, {}

	local function Show(v)
		if info.FormatDisplayValue then local ok, r = pcall(info.FormatDisplayValue, v) if ok and r then return tostring(r) end end
		return tostring(v)
	end
	local function UpdateDisplay()
		if D.Multi then
			local sel = {}
			for _, v in ipairs(D.Values) do if D.Value[v] then table.insert(sel, Show(v)) end end
			Disp.Text = #sel > 0 and table.concat(sel, ", ") or (info.Placeholder or "Select...")
		else
			Disp.Text = D.Value ~= nil and Show(D.Value) or (info.Placeholder or "Select...")
		end
		for v, it in pairs(items) do
			local sel = D.Multi and D.Value[v] or D.Value == v
			Tween(it.Label, { TextColor3 = sel and Theme.AccentText or (D.DisabledValues[v] and Theme.Muted or Theme.Text) }, 0.15)
			Tween(it.Bar, { Size = UDim2.fromOffset(3, sel and 14 or 0) }, 0.2)
		end
	end
	local function ListHeight()
		local n = math.max(1, math.min(#D.Values, info.MaxVisibleDropdownItems or 8))
		return n * (Dim.Item + 2) + topOff + 6
	end
	local function SetOpen(o)
		open = o
		if o then
			ListF.Visible = true
			Tween(ListF, { Size = UDim2.new(1, 0, 0, ListHeight()) }, 0.3)
		else
			Tween(ListF, { Size = UDim2.new(1, 0, 0, 0) }, 0.22)
			task.delay(0.23, function() if not open then ListF.Visible = false end end)
		end
		Tween(Arrow, { Rotation = o and 180 or 0 }, Mo.Base)
		for _, b in ipairs(ArrowBars) do Tween(b, { BackgroundColor3 = o and Theme.AccentText or Theme.Muted }, Mo.Base) end
		Tween(HS, { Color = o and Theme.Accent or Theme.Outline }, 0.2)
	end
	local function Build()
		for _, c in ipairs(Scroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		items = {}
		if #D.Values == 0 then Lbl({ Text = "No options available", TextSize = 13, TextColor3 = Theme.Muted, Size = UDim2.new(1, 0, 0, Dim.Item), Parent = Scroll }) end
		for i, v in ipairs(D.Values) do
			local b = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.ElementHover, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Dim.Item), LayoutOrder = i, Parent = Scroll }, { Corner(5) })
			local bar = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(3, 0), BackgroundColor3 = Theme.Accent, Parent = b }, { Corner(2) })
			local l = Lbl({ Text = Show(v), TextSize = 13, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -12, 1, 0), TextTransparency = D.DisabledValues[v] and 0.5 or 0, Parent = b })
			items[v] = { Btn = b, Label = l, Bar = bar }
			b.MouseEnter:Connect(function() if not D.DisabledValues[v] then Tween(b, { BackgroundTransparency = 0.4 }, 0.12) end end)
			b.MouseLeave:Connect(function() Tween(b, { BackgroundTransparency = 1 }, 0.12) end)
			b.MouseButton1Click:Connect(function()
				if D.DisabledValues[v] then return end
				if D.Multi then D.Value[v] = (not D.Value[v]) or nil else D.Value = v SetOpen(false) end
				UpdateDisplay() D:_Fire()
			end)
		end
		UpdateDisplay()
	end
	function D:SetValue(v)
		if D.Multi then
			D.Value = {}
			if type(v) == "table" then for k, val in pairs(v) do if type(k) == "number" then D.Value[val] = true elseif val then D.Value[k] = true end end
			elseif v then D.Value[v] = true end
		else
			if type(v) == "number" then v = D.Values[v] end
			D.Value = v
		end
		UpdateDisplay() D:_Fire()
	end
	function D:SetValues(vals) D.Values = vals Build() if open then SetOpen(true) end end
	function D:SetDisabledValues(t) D.DisabledValues = {} for _, v in ipairs(t) do D.DisabledValues[v] = true end Build() end
	function D:GetActiveValues()
		if not D.Multi then return D.Value and { D.Value } or {} end
		local r = {} for v in pairs(D.Value) do table.insert(r, v) end return r
	end
	if Search then
		Search:GetPropertyChangedSignal("Text"):Connect(function()
			local q = Search.Text:lower()
			for v, it in pairs(items) do it.Btn.Visible = q == "" or tostring(v):lower():find(q, 1, true) ~= nil end
		end)
	end
	Head.MouseButton1Click:Connect(function() if not D.Disabled then SetOpen(not open) end end)
	Head.MouseEnter:Connect(function() Tween(Head, { BackgroundColor3 = Theme.ElementHover }, 0.15) end)
	Head.MouseLeave:Connect(function() Tween(Head, { BackgroundColor3 = Theme.Element }, 0.15) end)
	Library:OnAccent(function() UpdateDisplay() end)
	TipFor(Head, D, info)

	if info.SpecialType == "Player" then
		local function Refresh()
			local names = {}
			for _, p in ipairs(Players:GetPlayers()) do if not (info.ExcludeLocalPlayer and p == LocalPlayer) then table.insert(names, p.Name) end end
			D.Values = names Build()
		end
		Library:Connect(Players.PlayerAdded, Refresh) Library:Connect(Players.PlayerRemoving, function() task.defer(Refresh) end)
		Refresh()
	elseif info.SpecialType == "Team" then
		local names = {} for _, t in ipairs(Teams:GetTeams()) do table.insert(names, t.Name) end
		D.Values = names Build()
	else Build() end

	local def = info.Default
	D.Default = def
	if def ~= nil then
		if D.Multi then
			if type(def) == "table" then D:SetValue(def) elseif type(def) == "number" then D.Value[D.Values[def]] = true elseif def then D.Value[def] = true end
		else D.Value = type(def) == "number" and D.Values[def] or def end
		UpdateDisplay()
	end
	if info.Disabled then D:SetDisabled(true) end
	if info.Visible == false then Holder.Visible = false end
	if idx then Library.Options[idx] = D end
	return D
end

function Base:AddDependencyBox()
	local Holder = self:_Row()
	local Box = setmetatable({ Container = Holder, Holder = Holder, Order = 0 }, Base)
	function Box:SetupDependencies(deps)
		local function Check()
			local ok = true
			for _, d in ipairs(deps) do
				local obj, want = d[1], d[2]
				if obj.Type == "Dropdown" then
					if obj.Multi then ok = ok and (obj.Value[want] and true or false) else ok = ok and obj.Value == want end
				else ok = ok and obj.Value == want end
			end
			Holder.Visible = ok
		end
		for _, d in ipairs(deps) do d[1]:OnChanged(Check) end
		Check()
	end
	return Box
end

---------------------------------------------------------------------
-- Live stats, glow, matrix background, 3D viewport, music engine
---------------------------------------------------------------------
Library.Stats = { FPS = 60, Ping = 0 }
do
	local acc, frames = 0, 0
	Library:Connect(RunService.RenderStepped, function(dt)
		acc += dt frames += 1
		if acc >= 0.5 then
			Library.Stats.FPS = math.floor(frames / acc + 0.5)
			local ok, v = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
			Library.Stats.Ping = ok and math.floor(v + 0.5) or 0
			acc, frames = 0, 0
		end
	end)
end

-- Glow: soft accent halo behind the window (stacked, fading outlines)
local function MakeGlow(target)
	local layers = {}
	for i = 1, 6 do
		local e = i * 3
		local f = New("Frame", { BackgroundTransparency = 1, ZIndex = 1, Visible = false, Parent = Gui }, {
			Corner(12 + e), New("UIStroke", { Color = Theme.Accent, Thickness = 3.4, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		layers[i] = { Frame = f, Stroke = f:FindFirstChildOfClass("UIStroke"), E = e }
	end
	Library:OnAccent(function(c) for _, l in ipairs(layers) do l.Stroke.Color = c end end)
	Library:Connect(RunService.RenderStepped, function()
		local show = target.Visible and Library.GlowEnabled ~= false
		local vis = 1 - target.GroupTransparency
		local pulse = (Library.ReducedMotion or not Library.AmbientEffects) and 0 or math.sin(os.clock() * 1.6) * 0.04
		local ap, as = target.AbsolutePosition, target.AbsoluteSize
		for i, l in ipairs(layers) do
			l.Frame.Visible = show
			if show then
				l.Frame.Position = UDim2.fromOffset(ap.X - l.E, ap.Y - l.E)
				l.Frame.Size = UDim2.fromOffset(as.X + l.E * 2, as.Y + l.E * 2)
				l.Stroke.Transparency = 1 - (1 - (0.8 + i * 0.03 - pulse)) * vis
			end
		end
	end)
end

-- Matrix: horizontal "hacker rain". Glyph streams run left -> right, your word is highlighted inside them.
local MatrixChars = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZ#$%*+=?/|{}[]()~^"
local function HexOf(c) return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local function MakeMatrix(layer, scaleObj)
	local M = { Enabled = true, Paused = true, Speed = 36, Word = "AZIC", Lanes = {}, FS = 13 }
	local charW = TextService:GetTextSize("MMMMMMMMMM", M.FS, FontN, Vector2.new(100000, 100)).X / 10
	local function Pattern(n)
		local word = tostring(M.Word or "")
		word = word:gsub("[<>&\"'%c]", "")
		word = word:sub(1, 24)
		local hex = HexOf(Theme.AccentText)
		local out, buf, count = {}, {}, 0
		local function flush()
			if #buf > 0 then table.insert(out, '<font transparency="0.86">' .. table.concat(buf) .. "</font>") buf = {} end
		end
		while count < n do
			if #word > 0 and count + #word <= n and math.random() < 0.035 then
				flush()
				table.insert(out, '<font color="' .. hex .. '" transparency="0.05">' .. word .. "</font>")
				count += #word
			else
				local k = math.random(#MatrixChars)
				table.insert(buf, MatrixChars:sub(k, k))
				count += 1
			end
		end
		flush()
		return table.concat(out)
	end
	local built = Vector2.new()
	function M:Rebuild()
		for _, l in ipairs(M.Lanes) do l.Label:Destroy() end
		M.Lanes = {}
		local s = scaleObj and scaleObj.Scale or 1
		local W, H = layer.AbsoluteSize.X / s, layer.AbsoluteSize.Y / s
		built = Vector2.new(W, H)
		if W < 60 or H < 60 then M.P = nil return end
		local n = math.ceil(W / charW) + 12
		M.P = n * charW
		local rowH = M.FS + 5
		for i = 0, math.floor(H / rowH) - 1 do
			local lbl = New("TextLabel", { BackgroundTransparency = 1, RichText = true, Font = FontN, TextSize = M.FS, TextColor3 = Theme.AccentText, TextXAlignment = Left, TextWrapped = false, Size = UDim2.fromOffset(M.P * 2 + 20, rowH), Position = UDim2.fromOffset(-M.P, i * rowH), Parent = layer })
			local pat = Pattern(n)
			lbl.Text = pat .. pat
			M.Lanes[i + 1] = { Label = lbl, N = n, Y = i * rowH, Speed = 0.5 + math.random() * 1.1, Offset = math.random() * M.P }
		end
	end
	function M:SetWord(w) M.Word = w M:Rebuild() end
	function M:SetEnabled(b) M.Enabled = b layer.Visible = b end
	-- soft edge fade so the rain dissolves into the window
	local function Mask(anchor, pos, size, rot, a, b)
		New("Frame", { BackgroundColor3 = Theme.Background, BorderSizePixel = 0, AnchorPoint = anchor, Position = pos, Size = size, ZIndex = 3, Parent = layer }, { New("UIGradient", { Rotation = rot, Transparency = NumberSequence.new(a, b) }) })
	end
	Mask(Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), UDim2.new(0, 120, 1, 0), 0, 0, 1)
	Mask(Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), UDim2.new(0, 120, 1, 0), 0, 1, 0)
	Mask(Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), UDim2.new(1, 0, 0, 50), 90, 1, 0)
	local dirty, acc, resizeToken = false, 0, 0
	Library:OnAccent(function() dirty = true end)
	layer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local s = scaleObj and scaleObj.Scale or 1
		local W, H = layer.AbsoluteSize.X / s, layer.AbsoluteSize.Y / s
		if math.abs(W - built.X) > 2 or math.abs(H - built.Y) > 2 then
			resizeToken += 1
			local tk = resizeToken
			task.delay(0.4, function() if tk == resizeToken then dirty = true end end)
		end
	end)
	Library:Connect(RunService.RenderStepped, function(dt)
		if dirty then dirty = false M:Rebuild() end
		if not M.Enabled or M.Paused or not M.P or Library.ReducedMotion then return end
		for _, l in ipairs(M.Lanes) do
			l.Offset = (l.Offset + dt * M.Speed * l.Speed) % M.P
			l.Label.Position = UDim2.fromOffset(l.Offset - M.P, l.Y)
		end
		acc += dt
		if acc > 0.3 and #M.Lanes > 0 then -- live glitch: re-roll one lane
			acc = 0
			local l = M.Lanes[math.random(#M.Lanes)]
			local pat = Pattern(l.N)
			l.Label.Text = pat .. pat
		end
	end)
	task.defer(function() M:Rebuild() end)
	return M
end

-- 3D viewport widget (ViewportFrame + orbit camera, drag to rotate, wheel to zoom)
local function MakeViewport(parent, height)
	local W = { Angle = math.pi, Auto = true, Zoom = 1, H = 5, Center = Vector3.new() }
	local Frame = New("Frame", { BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.2, Size = UDim2.new(1, 0, 0, height or 220), ClipsDescendants = true, Parent = parent }, { Corner(8), Stroke(Theme.Outline) })
	local Back = New("Frame", { BackgroundColor3 = Theme.Accent, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Parent = Frame }, { New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 1), kp(1, 0.55) }) }) })
	local Ped = New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(0.55, 0, 0, 16), BackgroundTransparency = 1, Parent = Frame }, { Corner(99), Stroke(Theme.Accent, 2, 0.35) })
	Library:OnAccent(function(c) Back.BackgroundColor3 = c Ped:FindFirstChildOfClass("UIStroke").Color = c end)
	local VP = New("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(150, 150, 170), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1.2, -1), Parent = Frame })
	local Cam = New("Camera", { FieldOfView = 30, Parent = VP })
	VP.CurrentCamera = Cam
	New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 5, Parent = Frame }, { New("UIGradient", { Rotation = 135, Transparency = NumberSequence.new({ kp(0, 0.9), kp(0.4, 1), kp(1, 1) }) }) })
	Lbl({ Text = "Drag to rotate  |  Scroll to zoom", TextSize = 11, TextColor3 = Theme.Muted, Position = UDim2.new(0, 10, 1, -20), Size = UDim2.new(1, -20, 0, 16), ZIndex = 6, Parent = Frame })
	function W:SetModel(model)
		if W.Model then W.Model:Destroy() W.Model = nil end
		if not model then return end
		local was = model.Archivable
		model.Archivable = true
		local c = model:Clone()
		model.Archivable = was
		if not c then return end
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Sound") then d:Destroy() end
		end
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
		c.Parent = VP
		local cf, size = c:GetBoundingBox()
		W.Center, W.H, W.Model = cf.Position, math.max(size.Y, 1), c
	end
	local lastX
	Drag(Frame, function(pos)
		if lastX then W.Angle -= (pos.X - lastX) * 0.012 end
		lastX = pos.X
	end, function() W.Dragging = true lastX = nil end, function() W.Dragging = false lastX = nil end)
	Frame.InputChanged:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseWheel then W.Zoom = math.clamp(W.Zoom + i.Position.Z * 0.08, 0.6, 2.2) end
	end)
	Library:Connect(RunService.RenderStepped, function(dt)
		if not W.Model then return end
		if W.Auto and not W.Dragging and not Library.ReducedMotion then W.Angle += dt * 0.6 end
		local dist = (W.H / 2) / math.tan(math.rad(Cam.FieldOfView / 2)) * 1.2 / W.Zoom
		Cam.CFrame = CFrame.lookAt(W.Center + Vector3.new(math.sin(W.Angle) * dist, W.H * 0.08, math.cos(W.Angle) * dist), W.Center)
	end)
	W.Frame = Frame
	return W
end

-- Music engine (Roblox audio IDs)
local Music = {
	Playlist = { -- starter list from community catalogs; availability depends on Roblox audio privacy
		{ Name = "Calm Tapegrain 291", Id = 79761947159286 },
		{ Name = "Soft Asphaltcut 134", Id = 84461051402774 },
		{ Name = "Analog Sidepath 772", Id = 138731892632878 },
		{ Name = "Dustlane Logic 601", Id = 103880680578287 },
		{ Name = "Even Dustsignal 592", Id = 71134170561473 },
	},
	Index = 0, Token = 0, FailStreak = 0, Listeners = {}, Repeat = false,
}
Library.Music = Music
local Snd = Instance.new("Sound")
Snd.Name, Snd.Volume, Snd.Parent = "AzicMusic", 0.5, SoundService
Music.Sound = Snd
local function Emit() for _, f in ipairs(Music.Listeners) do task.spawn(f) end end
function Music:OnState(fn) table.insert(self.Listeners, fn) end
function Music:Play(id, name, fromList)
	id = tostring(id or ""):match("%d+")
	if not id then
		Library:Notify({ Type = "Error", Title = "Couldn't play audio", Description = "Enter a numeric audio ID and try again." })
		return false
	end
	self.Token += 1
	local tk = self.Token
	if not fromList then self.Index, self.FailStreak = 0, 0 end
	Snd:Stop()
	Snd.SoundId = "rbxassetid://" .. id
	Snd.Looped = self.Repeat
	self.Id, self.Title, self.Loading = id, name or ("Audio " .. id), true
	Emit()
	Snd:Play()
	task.spawn(function()
		local waited = 0
		while not Snd.IsLoaded and waited < 8 and tk == self.Token do waited += task.wait(0.1) end
		if tk ~= self.Token then return end
		self.Loading = false
		if not Snd.IsLoaded then
			Snd:Stop()
			self.FailStreak += 1
			Library:Notify({ Type = "Error", Title = "Couldn't load audio", Description = "ID " .. id .. " is private, removed or blocked in this experience. Try another ID." })
			Emit()
			if fromList and self.FailStreak < #self.Playlist then task.wait(0.6) if tk == self.Token then self:Next() end end
			return
		end
		self.FailStreak = 0
		if not name then
			local ok, info = pcall(function() return MarketplaceService:GetProductInfo(tonumber(id)) end)
			if ok and info and info.Name and tk == self.Token then self.Title = info.Name end
		end
		Emit()
	end)
	return true
end
function Music:PlayIndex(i)
	local e = self.Playlist[i]
	if not e then return end
	self.Index = i
	self:Play(e.Id, e.Name, true)
end
function Music:Next() if #self.Playlist > 0 then self:PlayIndex(self.Index % #self.Playlist + 1) end end
function Music:Prev() if #self.Playlist > 0 then self:PlayIndex((self.Index - 2) % #self.Playlist + 1) end end
function Music:Toggle()
	if Snd.IsPlaying then Snd:Pause()
	elseif Snd.IsPaused then Snd:Resume()
	elseif Snd.SoundId ~= "" then Snd:Play()
	else self:PlayIndex(1) end
end
function Music:SetVolume(v) Snd.Volume = math.clamp(v, 0, 1) end
function Music:SetRepeat(b) self.Repeat = b Snd.Looped = b end
function Music:Add(id, name)
	id = tonumber(tostring(id):match("%d+"))
	if not id then return false end
	table.insert(self.Playlist, { Name = name or ("Audio " .. id), Id = id })
	return true
end
for _, ev in ipairs({ "Played", "Paused", "Resumed", "Stopped" }) do Library:Connect(Snd[ev], Emit) end
Library:Connect(Snd.Ended, function()
	Emit()
	if not Snd.Looped and Music.Index > 0 then Music:Next() end
end)
Library:OnUnload(function() Snd:Destroy() end)

---------------------------------------------------------------------
-- Extra Groupbox widgets
---------------------------------------------------------------------
function Base:AddViewport(idx, info)
	info = info or {}
	local Holder = self:_Row()
	local W = MakeViewport(Holder, info.Height or 220)
	if info.Model then W:SetModel(info.Model) end
	W.Holder = Holder
	return W
end

function Base:AddCharacterViewer(idx, info)
	info = info or {}
	local Holder = self:_Row()
	local W = MakeViewport(Holder, info.Height or 250)
	W.Holder = Holder
	function W:Refresh()
		task.spawn(function()
			local char = LocalPlayer.Character
			if char and char:FindFirstChild("HumanoidRootPart") then W:SetModel(char) return end
			local ok, model = pcall(function()
				local d = Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
				return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
			end)
			if ok and model then W:SetModel(model) model:Destroy() end
		end)
	end
	Library:Connect(LocalPlayer.CharacterAdded, function() task.wait(1.2) W:Refresh() end)
	W:Refresh()
	return W
end

function Base:AddProfile()
	local Holder = self:_Row()
	local Card = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 66), Parent = Holder })
	local Ring = New("Frame", { Position = UDim2.fromOffset(0, 7), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = Theme.Element, Parent = Card }, { Corner(26), Stroke(Theme.Accent, 2) })
	Library:OnAccent(function(c) Ring:FindFirstChildOfClass("UIStroke").Color = c end)
	local Img = New("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = Ring }, { Corner(26) })
	New("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 2, 1, 2), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.fromRGB(52, 211, 153), Parent = Ring }, { Corner(6), Stroke(Theme.Panel, 2) })
	Lbl({ Text = LocalPlayer.DisplayName, Font = FontB, TextSize = 17, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(66, 9), Size = UDim2.new(1, -66, 0, 22), Parent = Card })
	Lbl({ Text = "@" .. LocalPlayer.Name, TextSize = 13, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(66, 31), Size = UDim2.new(1, -66, 0, 16), Parent = Card })
	Lbl({ Text = "Online  |  " .. LocalPlayer.AccountAge .. " days on Roblox", TextSize = 11, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(66, 47), Size = UDim2.new(1, -66, 0, 14), Parent = Card })
	task.spawn(function()
		local ok, img = pcall(function() return (Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)) end)
		if ok then Img.Image = img end
	end)
	return { Holder = Holder }
end

function Base:AddStat(name, value)
	local Holder = self:_Row()
	local Row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = Holder })
	Lbl({ Text = name, TextSize = 13, TextColor3 = Theme.Muted, Size = UDim2.new(0.42, 0, 1, 0), Parent = Row })
	local V = Lbl({ Text = tostring(value or "-"), Font = FontN, TextSize = 12, TextXAlignment = Right, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromScale(0.42, 0), Size = UDim2.fromScale(0.58, 1), Parent = Row })
	local S = { Holder = Holder }
	function S:Set(v) V.Text = tostring(v) end
	function S:SetColor(c) V.TextColor3 = c end
	return S
end

function Base:AddMusicPlayer()
	local Holder = self:_Row()
	local Card = New("Frame", { BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 184), Parent = Holder }, { Corner(8), Stroke(Theme.Outline) })
	local sweep = Shine(Card)
	local Viz = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 48), Parent = Card })
	local bars, heights, NB = {}, {}, 32
	for i = 1, NB do
		heights[i] = 0.04
		bars[i] = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((i - 1) / NB, 1, 1, 0), Size = UDim2.new(1 / NB, -2, 0.06, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = Viz }, {
			Corner(2), New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 175)) }),
		})
	end
	Library:OnAccent(function(c) for _, b in ipairs(bars) do b.BackgroundColor3 = c end end)
	local Title = Lbl({ Text = "Nothing playing", Font = FontB, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(12, 68), Size = UDim2.new(1, -24, 0, 20), Parent = Card })
	local Sub = Lbl({ Text = "Pick a track or enter an audio ID", TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(12, 88), Size = UDim2.new(1, -24, 0, 16), Parent = Card })
	local Track = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 108), Size = UDim2.new(1, -24, 0, 16), Parent = Card })
	local TBar = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = Theme.Panel, Parent = Track }, { Corner(3) })
	local TFill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent, Parent = TBar }, { Corner(3) })
	local TKnob = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(11, 11), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = TBar }, { Corner(6) })
	Library:OnAccent(function(c) TFill.BackgroundColor3 = c end)
	local TimeL = Lbl({ Text = "0:00", Font = FontN, TextSize = 11, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(12, 126), Size = UDim2.fromOffset(60, 14), Parent = Card })
	local TimeR = Lbl({ Text = "0:00", Font = FontN, TextSize = 11, TextColor3 = Theme.Muted, TextXAlignment = Right, Position = UDim2.new(1, -72, 0, 126), Size = UDim2.fromOffset(60, 14), Parent = Card })
	local Ctl = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 142), Size = UDim2.new(1, 0, 0, 38), Parent = Card }, {
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function CBtn(icon, size, order, filled)
		local b = New("TextButton", { Text = "", AutoButtonColor = false, LayoutOrder = order, Size = UDim2.fromOffset(size, size), BackgroundColor3 = filled and Theme.Accent or Theme.Panel, Parent = Ctl }, { Corner(size / 2), Stroke(filled and Theme.Accent or Theme.Control, 1) })
		local ic = MakeIcon(icon, b, filled and Color3.new(1, 1, 1) or Theme.Text, size * 0.5)
		ic.AnchorPoint, ic.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		b.MouseEnter:Connect(function() Tween(b, { BackgroundColor3 = filled and Lighten(Theme.Accent, 0.2) or Theme.ElementHover }, 0.12) end)
		b.MouseLeave:Connect(function() Tween(b, { BackgroundColor3 = filled and Theme.Accent or Theme.Panel }, 0.2) end)
		if filled then Library:OnAccent(function(c) b.BackgroundColor3 = c b:FindFirstChildOfClass("UIStroke").Color = c end) end
		return b, ic
	end
	local PrevB = CBtn("prev", 32, 1)
	local PlayB, PlayIc = CBtn("play", 40, 2, true)
	local PauseIc = MakeIcon("pause", PlayB, Color3.new(1, 1, 1), 20)
	PauseIc.AnchorPoint, PauseIc.Position, PauseIc.Visible = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), false
	local NextB = CBtn("next", 32, 3)
	local RepB, RepIc = CBtn("repeat", 32, 4)
	PrevB.MouseButton1Click:Connect(function() Music:Prev() end)
	NextB.MouseButton1Click:Connect(function() Music:Next() end)
	PlayB.MouseButton1Click:Connect(function() Music:Toggle() sweep() end)
	RepB.MouseButton1Click:Connect(function()
		Music:SetRepeat(not Music.Repeat)
		Recolor(RepIc, Music.Repeat and Theme.AccentText or Theme.Text)
	end)
	local function Refresh()
		local playing = Snd.IsPlaying
		PlayIc.Visible, PauseIc.Visible = not playing, playing
		Title.Text = Music.Title or "Nothing playing"
		Sub.Text = Music.Loading and "Loading..." or (Music.Id and ("Audio ID " .. Music.Id) or "Pick a track or enter an audio ID")
	end
	Music:OnState(function() Refresh() if Snd.IsPlaying then sweep() end end)
	Refresh()
	local function Fmt(s) s = math.max(0, math.floor(s)) return string.format("%d:%02d", s // 60, s % 60) end
	Drag(Track, function(pos)
		if Snd.TimeLength > 0 then
			local f = math.clamp((pos.X - TBar.AbsolutePosition.X) / TBar.AbsoluteSize.X, 0, 1)
			Snd.TimePosition = f * Snd.TimeLength
		end
	end)
	local acc = 0
	Library:Connect(RunService.RenderStepped, function(dt)
		local playing = Snd.IsPlaying
		local loud = playing and math.clamp(Snd.PlaybackLoudness / 450, 0, 1) or 0
		local t = os.clock()
		for i, b in ipairs(bars) do
			local n = (math.noise(i * 0.43, t * 2.4) + 1) / 2
			local target = playing and (0.07 + loud * (0.25 + 0.75 * n)) or 0.04
			heights[i] += (target - heights[i]) * math.min(1, dt * 14)
			b.Size = UDim2.new(1 / NB, -2, heights[i], 0)
		end
		local f = Snd.TimeLength > 0 and Snd.TimePosition / Snd.TimeLength or 0
		TFill.Size, TKnob.Position = UDim2.fromScale(f, 1), UDim2.fromScale(f, 0.5)
		acc += dt
		if acc > 0.25 then acc = 0 TimeL.Text, TimeR.Text = Fmt(Snd.TimePosition), Fmt(Snd.TimeLength) end
	end)
	return { Holder = Holder }
end

---------------------------------------------------------------------
-- Groupbox / Tabbox / Tab / Window
---------------------------------------------------------------------
local function NewGroupbox(scroll, name, sub)
	local Outer = New("Frame", { BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.14, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = scroll }, { Corner(8), Stroke(), List(0) })
	local Title = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, sub and 46 or 32), Parent = Outer })
	New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Parent = Title }, { Corner(8), New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 0.9), kp(1, 1) }) }) })
	New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 0, 1), BorderSizePixel = 0, Parent = Title })
	local Bar = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(3, 14), BackgroundColor3 = Theme.Accent, Parent = Title }, { Corner(2) })
	Lbl({ Text = name, Font = FontB, Position = UDim2.fromOffset(21, sub and 6 or 0), Size = UDim2.new(1, -30, 0, sub and 20 or 32), Parent = Title })
	if sub then Lbl({ Text = sub, TextSize = 11, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(21, 26), Size = UDim2.new(1, -30, 0, 14), Parent = Title }) end
	Library:OnAccent(function(c) Bar.BackgroundColor3 = c end)
	local Container = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = Outer }, { List(6), Pad(0, 10, 10, 10) })
	return setmetatable({ Container = Container, Order = 0, Outer = Outer }, Base)
end

local function NewTabbox(scroll)
	local Outer = New("Frame", { BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.14, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = scroll }, { Corner(8), Stroke(), List(0) })
	local Header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = Outer }, { List(0, Enum.FillDirection.Horizontal) })
	local Body = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = Outer })
	local TB = { Tabs = {}, Active = nil }
	function TB:AddTab(name)
		local Btn = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Header })
		local L = Lbl({ Text = name, Font = FontB, TextColor3 = Theme.Muted, TextXAlignment = Center, Size = UDim2.fromScale(1, 1), Parent = Btn })
		local Line = New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = Theme.Accent, Parent = Btn }, { Corner(1) })
		local Cont = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = Body }, { List(6), Pad(2, 10, 10, 10) })
		local Tab = setmetatable({ Container = Cont, Order = 0 }, Base)
		Library:OnAccent(function(c) Line.BackgroundColor3 = c end)
		local function Set(on)
			Cont.Visible = on
			Tween(L, { TextColor3 = on and Theme.Text or Theme.Muted }, 0.2)
			Tween(Line, { Size = UDim2.new(on and 0.6 or 0, 0, 0, 2) }, 0.3)
		end
		Btn.MouseButton1Click:Connect(function()
			if TB.Active then TB.Active.Set(false) end
			TB.Active = { Set = Set } Set(true)
		end)
		table.insert(TB.Tabs, Btn)
		for _, b in ipairs(TB.Tabs) do b.Size = UDim2.new(1 / #TB.Tabs, 0, 1, 0) end
		if #TB.Tabs == 1 then TB.Active = { Set = Set } Set(true) end
		return Tab
	end
	return TB
end

function Library:CreateWindow(cfg)
	cfg = cfg or {}
	local TOP, BOT, SIDE = 46, 26, 184
	local Window = { Tabs = {}, TabList = {}, ActiveTab = nil, Visible = false }
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local Main = New("CanvasGroup", {
		Name = "Main", ZIndex = 2, AnchorPoint = Vector2.new(0.5, 0.5), Position = cfg.Position or UDim2.fromScale(0.5, 0.5),
		Size = cfg.Size or UDim2.fromOffset(math.min(820, vp.X - 40), math.min(540, vp.Y - 40)),
		BackgroundColor3 = Theme.Background, GroupTransparency = 1, Visible = false, Parent = Gui,
	}, { Corner(12) })
	Window.Main = Main
	local Scale = New("UIScale", { Scale = 0.88, Parent = Main })
	local MainStroke = Stroke(Theme.Accent, 1.5); MainStroke.Parent = Main
	local StrokeGrad = New("UIGradient", { Parent = MainStroke })
	MakeGlow(Main)

	-- ambient light from the top (glass feel)
	local Ambient = New("Frame", { BackgroundColor3 = Theme.Accent, Size = UDim2.fromScale(1, 0.6), BorderSizePixel = 0, Parent = Main }, { New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 0.84), kp(1, 1) }) }) })

	-- live matrix background
	local MLayer = New("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(0, TOP), Size = UDim2.new(1, 0, 1, -(TOP + BOT)), Parent = Main })
	local Matrix = MakeMatrix(MLayer, Scale)
	Matrix.Word = cfg.MatrixWord or "AZIC"
	if cfg.Matrix == false then Matrix:SetEnabled(false) end
	Window.Matrix = Matrix

	-- top bar
	local Top = New("Frame", { BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.2, Size = UDim2.new(1, 0, 0, TOP), BorderSizePixel = 0, Parent = Main }, {
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 220)) }),
	})
	local Logo = New("Frame", { Position = UDim2.fromOffset(14, 11), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Theme.Accent, Parent = Top }, { Corner(7), New("UIGradient", { Rotation = 45 }) })
	local LogoGrad = Logo:FindFirstChildOfClass("UIGradient")
	local logoIc = MakeIcon("sparkle", Logo, Color3.new(1, 1, 1), 16)
	logoIc.AnchorPoint, logoIc.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	local sweepLogo = Shine(Logo)
	Lbl({ Text = cfg.Title or "Azic UI", Font = FontB, TextSize = 15, Position = UDim2.fromOffset(48, 6), Size = UDim2.new(0.3, 0, 0, 18), Parent = Top })
	local SubLbl = Lbl({ Text = cfg.Subtitle or ("v" .. Library.Version), TextSize = 11, TextColor3 = Theme.Muted, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(48, 24), Size = UDim2.new(0.3, 0, 0, 14), Parent = Top })
	function Window:SetSubtitle(t) SubLbl.Text = t end

	-- tab pill (current page)
	local Pill = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(130, 28), BackgroundColor3 = Theme.Element, Parent = Top }, { Corner(14), Stroke(Theme.Outline) })
	local PillDot = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Theme.Accent, Parent = Pill }, { Corner(4) })
	local PillLbl = Lbl({ Text = "", TextSize = 13, TextXAlignment = Center, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -30, 1, 0), Parent = Pill })

	local function IconBtn(icon, xOff, hoverBg)
		local b = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = hoverBg, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOff, 0.5, 0), Size = UDim2.fromOffset(Dim.Close, Dim.Close), Parent = Top }, { Corner(8) })
		local ic = MakeIcon(icon, b, Theme.Muted, 16)
		ic.AnchorPoint, ic.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		b.MouseEnter:Connect(function() Tween(b, { BackgroundTransparency = 0.15 }, Mo.Fast) Recolor(ic, Color3.new(1, 1, 1), Mo.Fast) end)
		b.MouseLeave:Connect(function() Tween(b, { BackgroundTransparency = 1 }, Mo.Base) Recolor(ic, Theme.Muted, Mo.Base) end)
		return b
	end
	local Close = IconBtn("close", -10, Theme.Risk)
	local Gear = IconBtn("gear", -10 - Dim.Close - 6, Theme.Element)
	Close.MouseButton1Click:Connect(function()
		Window:SetVisible(false)
		local k = Library.ToggleKeybind
		local name = typeof(k) == "EnumItem" and k.Name or (type(k) == "table" and tostring(k.Value)) or "your menu key"
		Library:Notify({ Title = "Menu hidden", Description = "Press " .. name .. " or use the Open button to show it again.", Time = 3 })
	end)
	Gear.MouseButton1Click:Connect(function() if Window.Tabs.Settings then Window:SelectTab(Window.Tabs.Settings) end end)

	local Line = New("Frame", { Position = UDim2.fromOffset(0, TOP), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = Main }, { New("UIGradient") })
	local LineGrad = Line:FindFirstChildOfClass("UIGradient")
	Library:OnAccent(function(c)
		LineGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c), ColorSequenceKeypoint.new(0.5, Lighten(c, 0.6)), ColorSequenceKeypoint.new(1, c) })
		LogoGrad.Color = ColorSequence.new(c, Lighten(c, 0.4))
		Logo.BackgroundColor3, PillDot.BackgroundColor3, Ambient.BackgroundColor3 = c, c, c
		StrokeGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c), ColorSequenceKeypoint.new(0.5, Theme.Outline), ColorSequenceKeypoint.new(1, c) })
	end)
	Library:Connect(RunService.RenderStepped, function()
		if Library.ReducedMotion or not Library.AmbientEffects then return end
		local t = os.clock()
		LineGrad.Offset = Vector2.new(((t * 0.4) % 2) - 1, 0)
		StrokeGrad.Rotation = (t * 45) % 360
	end)

	-- dragging
	local dragging, dStart, dPos
	Top.InputBegan:Connect(function(i) if IsPress(i) then dragging, dStart, dPos = true, PosOf(i), Main.Position end end)
	Library:Connect(UserInputService.InputChanged, function(i)
		if dragging and IsMove(i) then
			local d = PosOf(i) - dStart
			Tween(Main, { Position = UDim2.new(dPos.X.Scale, dPos.X.Offset + d.X, dPos.Y.Scale, dPos.Y.Offset + d.Y) }, 0.07)
		end
	end)
	Library:Connect(UserInputService.InputEnded, function(i) if IsPress(i) then dragging = false end end)

	-- sidebar
	local Side = New("Frame", { BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.3, Position = UDim2.fromOffset(0, TOP + 2), Size = UDim2.new(0, SIDE, 1, -(TOP + 2 + BOT)), BorderSizePixel = 0, Parent = Main }, {
		New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Theme.Outline, BorderSizePixel = 0 }),
	})
	local TabList = New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -70), ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = Side }, { List(4), Pad(10, 8) })

	-- user card (bottom of sidebar)
	local UCard = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.25, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.new(1, -16, 0, 54), Parent = Side }, { Corner(10), Stroke(Theme.Outline) })
	local UShine = Shine(UCard)
	local UImg = New("ImageLabel", { BackgroundColor3 = Theme.Panel, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(36, 36), Parent = UCard }, { Corner(18), Stroke(Theme.Accent, 1.5) })
	Library:OnAccent(function(c) UImg:FindFirstChildOfClass("UIStroke").Color = c end)
	Lbl({ Text = LocalPlayer.DisplayName, Font = FontB, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(52, 9), Size = UDim2.new(1, -90, 0, 18), Parent = UCard })
	Lbl({ Text = "@" .. LocalPlayer.Name, TextSize = 11, TextColor3 = Theme.Muted, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(52, 27), Size = UDim2.new(1, -90, 0, 16), Parent = UCard })
	local UArrow = MakeIcon("arrow", UCard, Theme.Muted, 16)
	UArrow.AnchorPoint, UArrow.Position = Vector2.new(1, 0.5), UDim2.new(1, -12, 0.5, 0)
	UCard.MouseEnter:Connect(function() UShine() Recolor(UArrow, Theme.AccentText) end)
	UCard.MouseLeave:Connect(function() Recolor(UArrow, Theme.Muted) end)
	UCard.MouseButton1Click:Connect(function() if Window.Tabs.Dashboard then Window:SelectTab(Window.Tabs.Dashboard) end end)
	task.spawn(function()
		local ok, img = pcall(function() return (Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)) end)
		if ok then UImg.Image = img end
	end)

	-- content + status bar
	local Content = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(SIDE, TOP + 2), Size = UDim2.new(1, -SIDE, 1, -(TOP + 2 + BOT)), Parent = Main }, { Pad(10) })
	local Status = New("Frame", { BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.15, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, BOT), BorderSizePixel = 0, Parent = Main }, {
		New("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Outline, BorderSizePixel = 0 }),
	})
	local SDot = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = Color3.fromRGB(52, 211, 153), Parent = Status }, { Corner(4) })
	local SLeft = Lbl({ Text = "Connected", TextSize = 11, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(0.3, 0, 1, 0), Parent = Status })
	local SMid = Lbl({ Text = "", TextSize = 11, TextColor3 = Theme.Muted, TextXAlignment = Center, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromScale(0.32, 0), Size = UDim2.fromScale(0.36, 1), Parent = Status })
	local SRight = Lbl({ Text = "", Font = FontN, TextSize = 11, TextColor3 = Theme.Muted, TextXAlignment = Right, Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, -12, 1, 0), Parent = Status })
	local sacc = 0
	Library:Connect(RunService.RenderStepped, function(dt)
		if not Window.Visible then return end
		if not (Library.ReducedMotion or not Library.AmbientEffects) then SDot.BackgroundTransparency = 0.25 + 0.25 * math.sin(os.clock() * 3) end
		sacc += dt
		if sacc >= 0.5 then
			sacc = 0
			SRight.Text = string.format("%d FPS   %d ms   %s", Library.Stats.FPS, Library.Stats.Ping, os.date("%H:%M"))
			SMid.Text = (Music.Sound.IsPlaying and Music.Title) and ("Now playing: " .. Music.Title) or ""
		end
	end)

	-- resizing
	if cfg.Resizable ~= false then
		local Grip = New("TextButton", { Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(24, 24), ZIndex = 10, Parent = Main })
		for _, g in ipairs({ { -9, 12 }, { -5, 6 } }) do
			New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, g[1], 1, g[1]), Size = UDim2.fromOffset(g[2], 2), Rotation = -45, BackgroundColor3 = Theme.Muted, BorderSizePixel = 0, Parent = Grip }, { Corner(1) })
		end
		Drag(Grip, function(pos)
			local ap = Main.AbsolutePosition
			Main.Size = UDim2.fromOffset(math.clamp(pos.X - ap.X, 600, 1500), math.clamp(pos.Y - ap.Y, 400, 1000))
		end, function()
			local ap = Main.AbsolutePosition
			Main.AnchorPoint = Vector2.new(0, 0)
			Main.Position = UDim2.fromOffset(ap.X, ap.Y)
		end)
	end

	-- show / hide (exit is faster than enter)
	function Window:SetVisible(v)
		self.Visible = v
		Matrix.Paused = not v
		if self.LauncherLabel then self.LauncherLabel.Text = v and "Close" or "Open" end
		if v then
			Main.Visible = true
			Tween(Main, { GroupTransparency = 0 }, Mo.Slow)
			Tween(Scale, { Scale = 1 }, Mo.Enter, Back)
			sweepLogo()
		else
			Tween(Main, { GroupTransparency = 1 }, Mo.Exit)
			Tween(Scale, { Scale = 0.9 }, Mo.Exit)
			task.delay(Mo.Exit + 0.04, function() if not self.Visible then Main.Visible = false end end)
		end
	end
	function Window:SelectTab(tab)
		if self.ActiveTab == tab then return end
		if self.ActiveTab then self.ActiveTab:_SetActive(false) end
		self.ActiveTab = tab
		PillLbl.Text = tab.Name
		tab:_SetActive(true)
	end

	-- tabs / categories
	local function MakeTab(name, icon, parentFrame, sub)
		local Tab = { Name = name, Active = false }
		local Btn = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.new(1, 0, 0, sub and (Dim.Tab - 6) or Dim.Tab), Parent = parentFrame }, { Corner(8) })
		local ix = sub and 24 or 12
		local Ic
		if icon then
			Ic = MakeIcon(icon, Btn, Theme.Muted, 18)
			Ic.AnchorPoint, Ic.Position = Vector2.new(0, 0.5), UDim2.new(0, ix, 0.5, 0)
		end
		local TL = Lbl({ Text = name, TextColor3 = Theme.Muted, TextSize = sub and 13 or 14, Position = UDim2.fromOffset(ix + (Ic and 28 or 4), 0), Size = UDim2.new(1, -(ix + 40), 1, 0), Parent = Btn })
		local Ind = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(3, 0), BackgroundColor3 = Theme.Accent, Parent = Btn }, { Corner(2) })
		local Dot = New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Theme.AccentText, BackgroundTransparency = 1, Parent = Btn }, { Corner(3) })
		Library:OnAccent(function(c) Ind.BackgroundColor3 = c Dot.BackgroundColor3 = Theme.AccentText end)
		local sw = Shine(Btn)
		local Page = New("CanvasGroup", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, GroupTransparency = 1, Parent = Content })
		local function Col(xs, xo)
			return New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(xs, xo, 0, 0), Size = UDim2.new(0.5, -5, 1, 0), ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.Accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = Page }, { List(10), Pad(0, 0, 4, 0) })
		end
		local LeftCol, RightCol = Col(0, 0), Col(0.5, 5)
		Btn.MouseEnter:Connect(function() if not Tab.Active then Tween(Btn, { BackgroundTransparency = 0.88 }, Mo.Fast) Tween(TL, { TextColor3 = Theme.Text }, Mo.Fast) sw() end end)
		Btn.MouseLeave:Connect(function() if not Tab.Active then Tween(Btn, { BackgroundTransparency = 1 }, Mo.Base) Tween(TL, { TextColor3 = Theme.Muted }, Mo.Base) end end)
		Btn.MouseButton1Click:Connect(function() Ripple(Btn, UserInputService:GetMouseLocation()) Window:SelectTab(Tab) end)
		function Tab:_SetActive(on)
			Tab.Active = on
			if on then
				Page.Visible = true
				Page.Position = UDim2.fromOffset(0, 18)
				Tween(Page, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, 0.4)
				Tween(Ind, { Size = UDim2.fromOffset(3, 18) }, 0.35, Back)
				Tween(TL, { TextColor3 = Theme.Text }, 0.2)
				Tween(Btn, { BackgroundTransparency = 0.82 }, 0.2)
				Tween(Dot, { BackgroundTransparency = 0 }, 0.25)
				if Ic then Recolor(Ic, Theme.AccentText) end
			else
				Tween(Page, { GroupTransparency = 1 }, 0.15)
				Tween(Ind, { Size = UDim2.fromOffset(3, 0) }, 0.2)
				Tween(TL, { TextColor3 = Theme.Muted }, 0.2)
				Tween(Btn, { BackgroundTransparency = 1 }, 0.2)
				Tween(Dot, { BackgroundTransparency = 1 }, 0.2)
				if Ic then Recolor(Ic, Theme.Muted) end
				task.delay(0.16, function() if not Tab.Active then Page.Visible = false end end)
			end
		end
		function Tab:AddLeftGroupbox(n, s) return NewGroupbox(LeftCol, n, s) end
		function Tab:AddRightGroupbox(n, s) return NewGroupbox(RightCol, n, s) end
		function Tab:AddLeftTabbox() return NewTabbox(LeftCol) end
		function Tab:AddRightTabbox() return NewTabbox(RightCol) end
		Window.Tabs[name] = Tab
		table.insert(Window.TabList, Tab)
		if not Window.ActiveTab then Window:SelectTab(Tab) end
		return Tab
	end
	function Window:AddTab(name, icon) return MakeTab(name, icon, TabList, false) end

	function Window:AddCategory(name, icon)
		local Cat = { Count = 0, Open = true }
		local Head = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.6, Size = UDim2.new(1, 0, 0, Dim.Tab), ClipsDescendants = true, Parent = TabList }, { Corner(8) })
		local ic = MakeIcon(icon or "matrix", Head, Theme.Muted, 18)
		ic.AnchorPoint, ic.Position = Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, 0)
		Lbl({ Text = name, Font = FontB, TextSize = 14, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -70, 1, 0), Parent = Head })
		local Chev = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(16, 16), Parent = Head })
		MakeIcon("chevron", Chev, Theme.Muted, 16)
		local Box = New("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.new(1, 0, 0, 0), Parent = TabList }, { List(2) })
		local function H() return Cat.Count * (Dim.Tab - 6 + 2) end
		Head.MouseButton1Click:Connect(function()
			Cat.Open = not Cat.Open
			Tween(Box, { Size = UDim2.new(1, 0, 0, Cat.Open and H() or 0) }, 0.3)
			Tween(Chev, { Rotation = Cat.Open and 0 or -90 }, 0.25)
		end)
		function Cat:AddTab(tn, ti)
			Cat.Count += 1
			local t = MakeTab(tn, ti, Box, true)
			Box.Size = UDim2.new(1, 0, 0, Cat.Open and H() or 0)
			return t
		end
		return Cat
	end

	Library.Window = Window
	if cfg.ToggleKeybind then Library.ToggleKeybind = cfg.ToggleKeybind end
	if cfg.NotifySide then Library.NotifySide = cfg.NotifySide end

	-- Open / Close launcher (floating pill, draggable)
	if cfg.Launcher ~= false then
		local Pl = New("TextButton", { Name = "Launcher", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(118, Dim.Close + 6), BackgroundColor3 = Theme.Panel, ZIndex = 60, Parent = Gui }, { Corner(99) })
		local PS = Stroke(Theme.Accent, 1.5); PS.Parent = Pl
		Library:OnAccent(function(c) PS.Color = c end)
		local sw = Shine(Pl)
		local ic = MakeIcon("sparkle", Pl, Theme.AccentText, 16)
		ic.AnchorPoint, ic.Position, ic.ZIndex = Vector2.new(0, 0.5), UDim2.new(0, 16, 0.5, 0), 61
		local lab = Lbl({ Text = "Open", Font = FontB, TextSize = 13, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -50, 1, 0), ZIndex = 61, Parent = Pl })
		Window.LauncherLabel = lab
		Pl.MouseEnter:Connect(function() sw() Tween(Pl, { BackgroundColor3 = Theme.ElementHover }, Mo.Fast) end)
		Pl.MouseLeave:Connect(function() Tween(Pl, { BackgroundColor3 = Theme.Panel }, Mo.Base) end)
		local pdrag, pStart, pPos, moved
		Pl.InputBegan:Connect(function(i) if IsPress(i) then pdrag, moved, pStart, pPos = true, false, PosOf(i), Pl.Position end end)
		Library:Connect(UserInputService.InputChanged, function(i)
			if pdrag and IsMove(i) then
				local d = PosOf(i) - pStart
				if d.Magnitude > 6 then moved = true end
				if moved then Pl.Position = UDim2.new(pPos.X.Scale, pPos.X.Offset + d.X, pPos.Y.Scale, pPos.Y.Offset + d.Y) end
			end
		end)
		Library:Connect(UserInputService.InputEnded, function(i) if IsPress(i) then pdrag = false end end)
		Pl.MouseButton1Click:Connect(function() if not moved then Window:SetVisible(not Window.Visible) end end)
		Library:Connect(RunService.RenderStepped, function()
			if Library.ReducedMotion or not Library.AmbientEffects then return end
			PS.Transparency = 0.15 + 0.2 * (math.sin(os.clock() * 2) + 1) / 2
		end)
	end

	if cfg.AutoShow ~= false then task.defer(function() Window:SetVisible(true) end) end
	return Window
end

function Library:ToggleUI() if self.Window then self.Window:SetVisible(not self.Window.Visible) end end

Library:Connect(UserInputService.InputBegan, function(input)
	if Library.Listener then
		if Library.Listener(input) then Library.Listener = nil end
		return
	end
	if UserInputService:GetFocusedTextBox() then return end
	local tk = Library.ToggleKeybind
	if typeof(tk) == "EnumItem" then
		if input.KeyCode == tk then Library:ToggleUI() end
	elseif type(tk) == "table" and tk.Matches and tk:Matches(input) then
		Library:ToggleUI()
	end
	for _, kp in ipairs(Library.KeyPickers) do if kp:Matches(input) then kp:_Down() end end
end)
Library:Connect(UserInputService.InputEnded, function(input)
	for _, kp in ipairs(Library.KeyPickers) do if kp:Matches(input) then kp:_Up() end end
end)

---------------------------------------------------------------------
-- Config system + settings builders
---------------------------------------------------------------------
local function FS() return writefile and readfile and isfolder and makefolder and listfiles and isfile end
local function CfgPath(name) return Library.ConfigFolder .. "/configs/" .. name .. ".json" end
local function Ensure()
	if not isfolder(Library.ConfigFolder) then makefolder(Library.ConfigFolder) end
	if not isfolder(Library.ConfigFolder .. "/configs") then makefolder(Library.ConfigFolder .. "/configs") end
end

function Library:GetConfigs()
	if not FS() then return {} end
	Ensure()
	local out = {}
	for _, p in ipairs(listfiles(self.ConfigFolder .. "/configs")) do
		local n = p:match("([^/\\]+)%.json$")
		if n then table.insert(out, n) end
	end
	return out
end

function Library:SaveConfig(name)
	if not FS() then return false, "Your executor does not support saving files" end
	if not name or name:gsub(" ", "") == "" then return false, "Enter a config name first" end
	Ensure()
	local d = {}
	local function skip(i) return i:sub(1, 5) == "Azic_" or table.find(self.IgnoreIndexes, i) end
	for idx, o in pairs(self.Toggles) do if not skip(idx) then d[idx] = { t = "Toggle", v = o.Value } end end
	for idx, o in pairs(self.Options) do
		if not skip(idx) then
			if o.Type == "ColorPicker" then d[idx] = { t = o.Type, v = { o.Value.R, o.Value.G, o.Value.B } }
			elseif o.Type == "KeyPicker" then d[idx] = { t = o.Type, v = o.Value, m = o.Mode }
			else d[idx] = { t = o.Type, v = o.Value } end
		end
	end
	local ok, err = pcall(function() writefile(CfgPath(name), HttpService:JSONEncode(d)) end)
	return ok, err
end

function Library:LoadConfig(name)
	if not FS() or not isfile(CfgPath(name)) then return false, "Select a saved config first" end
	local ok, d = pcall(function() return HttpService:JSONDecode(readfile(CfgPath(name))) end)
	if not ok then return false, "That config file is damaged. Save it again" end
	for idx, e in pairs(d) do
		local o = self.Toggles[idx] or self.Options[idx]
		if o then
			pcall(function()
				if e.t == "ColorPicker" then o:SetValue(Color3.new(e.v[1], e.v[2], e.v[3]))
				elseif e.t == "KeyPicker" then o:SetValue({ e.v, e.m })
				else o:SetValue(e.v) end
			end)
		end
	end
	return true
end

function Library:BuildThemeSection(group)
	local names = {}
	for n in pairs(self.Themes) do table.insert(names, n) end
	table.sort(names)
	group:AddDropdown("Azic_Theme", { Text = "Accent theme", Values = names, Default = "Violet", Callback = function(v) if v then Library:SetAccent(Library.Themes[v]) end end })
	group:AddLabel("Custom accent"):AddColorPicker("Azic_Accent", { Default = Theme.Accent, Title = "Accent color", Callback = function(c) Library:SetAccent(c) end })
	group:AddDivider()
	group:AddToggle("Azic_Matrix", { Text = "Live background", Default = true, Tooltip = "Matrix rain behind the pages", Callback = function(v) if Library.Window then Library.Window.Matrix:SetEnabled(v) end end })
	group:AddInput("Azic_MatrixWord", { Text = "Background word", Default = "AZIC", Placeholder = "Type a word, press Enter", MaxLength = 16, Finished = true, Tooltip = "Your word appears highlighted inside the glyph streams", Callback = function(v) if Library.Window then Library.Window.Matrix:SetWord(v) end end })
	group:AddSlider("Azic_MatrixSpeed", { Text = "Background speed", Default = 36, Min = 0, Max = 120, Rounding = 0, Suffix = " px/s", HideMax = true, Callback = function(v) if Library.Window then Library.Window.Matrix.Speed = v end end })
	group:AddDivider()
	group:AddToggle("Azic_Glow", { Text = "Window glow", Default = true, Callback = function(v) Library.GlowEnabled = v end })
	group:AddToggle("Azic_Shine", { Text = "Shine effects", Default = true, Callback = function(v) Library.ShineEnabled = v end })
	group:AddToggle("Azic_Reduce", { Text = "Reduce motion", Tooltip = "Instant transitions, no ambient effects", Callback = function(v) Library.ReducedMotion = v end })
	group:AddToggle("Azic_Ambient", { Text = "Ambient effects", Default = true, Tooltip = "Shimmer line, glowing border and pulses", Callback = function(v) Library.AmbientEffects = v end })
	group:AddSlider("Azic_AnimSpeed", { Text = "Animation speed", Default = 1, Min = 0.25, Max = 3, Rounding = 2, Suffix = "x", HideMax = true, Callback = function(v) Library.AnimationSpeed = v end })
end

-- Ready-made pages ---------------------------------------------------
function Library:BuildDashboardTab(Window)
	local Tab = Window:AddTab("Dashboard", "home")
	local Prof = Tab:AddLeftGroupbox("Profile", "Your account in this session")
	Prof:AddProfile()
	Prof:AddDivider()
	Prof:AddStat("User ID", LocalPlayer.UserId)
	Prof:AddStat("Membership", LocalPlayer.MembershipType.Name)
	local TeamStat = Prof:AddStat("Team", "None")
	local Gm = Tab:AddLeftGroupbox("Game", "Where you are right now")
	local st = {
		Name = Gm:AddStat("Experience", "Loading..."),
		Place = Gm:AddStat("Place ID", game.PlaceId),
		Server = Gm:AddStat("Server", game.JobId ~= "" and game.JobId:sub(1, 8) or "Studio"),
		Players = Gm:AddStat("Players", "-"),
		Uptime = Gm:AddStat("Uptime", "-"),
		FPS = Gm:AddStat("FPS", "-"),
		Ping = Gm:AddStat("Ping", "-"),
	}
	task.spawn(function()
		local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
		local n = (ok and info and info.Name) or game.Name
		st.Name:Set(n)
		Window:SetSubtitle(n)
	end)
	local acc = 0
	Library:Connect(RunService.Heartbeat, function(dt)
		acc += dt
		if acc < 0.5 then return end
		acc = 0
		st.Players:Set(#Players:GetPlayers() .. " / " .. Players.MaxPlayers)
		local t = math.floor(workspace.DistributedGameTime)
		st.Uptime:Set(string.format("%d:%02d:%02d", t // 3600, t % 3600 // 60, t % 60))
		local fps, ping = Library.Stats.FPS, Library.Stats.Ping
		st.FPS:Set(fps) st.FPS:SetColor(fps >= 50 and Color3.fromRGB(52, 211, 153) or (fps >= 30 and Color3.fromRGB(251, 191, 36) or Theme.Risk))
		st.Ping:Set(ping .. " ms") st.Ping:SetColor(ping <= 100 and Color3.fromRGB(52, 211, 153) or (ping <= 200 and Color3.fromRGB(251, 191, 36) or Theme.Risk))
		TeamStat:Set(LocalPlayer.Team and LocalPlayer.Team.Name or "None")
	end)
	local Ch = Tab:AddRightGroupbox("Character", "Live 3D preview of your avatar")
	local view = Ch:AddCharacterViewer(nil, { Height = 290 })
	Ch:AddToggle("Azic_AutoRotate", { Text = "Auto-rotate", Default = true, Callback = function(v) view.Auto = v end })
	Ch:AddButton({ Text = "Refresh avatar", Func = function() view:Refresh() end })
	return Tab
end

function Library:BuildMusicTab(Window)
	local Tab = Window:AddTab("Music", "music")
	local NP = Tab:AddLeftGroupbox("Now playing", "Roblox audio player")
	NP:AddMusicPlayer()
	NP:AddSlider("Azic_MusicVol", { Text = "Volume", Default = 50, Min = 0, Max = 100, Rounding = 0, Suffix = "%", HideMax = true, Callback = function(v) Library.Music:SetVolume(v / 100) end })
	local Lib = Tab:AddRightGroupbox("Library", "Play any audio ID or use the playlist")
	local function names()
		local t = {}
		for _, e in ipairs(Library.Music.Playlist) do table.insert(t, e.Name) end
		return t
	end
	Lib:AddInput("Azic_MusicId", { Text = "Audio ID", Placeholder = "e.g. 79761947159286", Numeric = true })
	local list
	Lib:AddButton({ Text = "Play ID", Func = function() Library.Music:Play(Library.Options.Azic_MusicId.Value) end })
		:AddButton({ Text = "Add to playlist", Func = function()
			if Library.Music:Add(Library.Options.Azic_MusicId.Value) then
				list:SetValues(names())
				Library:Notify({ Type = "Success", Description = "Added to your playlist." })
			else
				Library:Notify({ Type = "Error", Title = "Couldn't add track", Description = "Enter a numeric audio ID first." })
			end
		end })
	Lib:AddDivider()
	list = Lib:AddDropdown("Azic_MusicList", { Text = "Playlist", Values = names(), Placeholder = "Choose a track" })
	Lib:AddButton({ Text = "Play selected", Func = function()
		for i, e in ipairs(Library.Music.Playlist) do
			if e.Name == list.Value then Library.Music:PlayIndex(i) return end
		end
		Library:Notify({ Type = "Warning", Title = "No track selected", Description = "Choose a track from the playlist first." })
	end })
	Lib:AddDivider()
	Lib:AddLabel("Find audio IDs in the Creator Store (Audio). Private or removed IDs can't be played and are skipped automatically.", true)
	return Tab
end

function Library:BuildConfigSection(group)
	group:AddInput("Azic_CfgName", { Text = "Config name", Placeholder = "my-config" })
	local list = group:AddDropdown("Azic_CfgList", { Text = "Configs", Values = self:GetConfigs(), Default = 0, Placeholder = "No configs yet" })
	group:AddButton({ Text = "Save config", Func = function()
		local ok, err = Library:SaveConfig(Library.Options.Azic_CfgName.Value)
		Library:Notify(ok and { Type = "Success", Description = "Config saved." } or { Type = "Error", Title = "Couldn't save config", Description = tostring(err) .. "." })
		list:SetValues(Library:GetConfigs())
	end }):AddButton({ Text = "Load config", Func = function()
		local ok, err = Library:LoadConfig(list.Value)
		Library:Notify(ok and { Type = "Success", Description = "Config loaded." } or { Type = "Error", Title = "Couldn't load config", Description = tostring(err) .. "." })
	end })
	group:AddButton({ Text = "Refresh list", Func = function() list:SetValues(Library:GetConfigs()) end })
	group:AddButton({ Text = "Reset all to defaults", DoubleClick = true, Tooltip = "Resets every option (not themes or configs)", Func = function()
		Library:ResetAll()
		Library:Notify({ Type = "Warning", Title = "Defaults restored", Description = "All options were reset." })
	end })
end

function Library:ResetAll()
	for _, tbl in ipairs({ self.Toggles, self.Options }) do
		for idx, o in pairs(tbl) do
			if tostring(idx):sub(1, 5) ~= "Azic_" and not table.find(self.IgnoreIndexes, idx) then pcall(o.Reset, o) end
		end
	end
end

function Library:Unload()
	if self.Unloaded then return end
	self.Unloaded = true
	for _, f in ipairs(self.UnloadCallbacks) do pcall(f) end
	for _, c in ipairs(self.Signals) do pcall(function() c:Disconnect() end) end
	Gui:Destroy()
end

if getgenv then getgenv().AzicLibrary = Library end
return Library
