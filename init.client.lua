--[[
	MyPlayerClient: slot screen + builder (entire UI is built in code, no assets needed).
	Press M (Config.ToggleKey) or the MYPLAYER button to open.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local MP = ReplicatedStorage:WaitForChild("MyPlayer")
local Config = require(MP:WaitForChild("Config"))
local Attributes = require(MP:WaitForChild("Attributes"))
local Archetypes = require(MP:WaitForChild("Archetypes"))
local Badges = require(MP:WaitForChild("Badges"))
local Takeovers = require(MP:WaitForChild("Takeovers"))
local BuildMath = require(MP:WaitForChild("BuildMath"))
local RthroRig = require(MP:WaitForChild("RthroRig"))
local Request = MP:WaitForChild("Request")
local UI = require(script:WaitForChild("UI"))
local Fx = require(script:WaitForChild("Fx"))
local Presentation = require(script:WaitForChild("Presentation"))
local T = UI.Theme

local state = { Slots = {}, Selected = nil, BaseDesc = nil }
local editing -- { Slot, Build, Dirty }
local updaters = {}
local ctx = { Left = 0, Spent = 0, BadgeTotal = 0, BadgePer = {} }
local schedulePreview = function() end
local commitInputs = function() end
local openBuilder, showScreen, renderSlots, presentBuild

local function request(action, ...)
	local ok, a, b = pcall(Request.InvokeServer, Request, action, ...)
	if not ok then
		return false, "Connection error"
	end
	return a, b
end

---------------------------------------------------------------- shell

local gui = UI.new("ScreenGui", {
	Name = "MyPlayerBuilder", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui"),
})
local backdrop = UI.new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.BG, BorderSizePixel = 0, Visible = false, Active = true, Parent = gui,
})
local canvas = UI.new("Frame", {
	Size = UDim2.fromOffset(1280, 720), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1, Parent = backdrop,
})
local uiScale = UI.new("UIScale", { Parent = canvas })
local function rescale()
	local vp = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.min(vp.X / 1280, vp.Y / 720)
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

local function toast(text, color)
	UI.Toast(canvas, text, color)
end

-- Full-canvas fade used to hide screen swaps.
local curtain = UI.new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.BG, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 150, Parent = canvas,
})

local slotsScreen = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = canvas })
local builderScreen = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = canvas })

local function confirm(text, yesText, onYes)
	local overlay = UI.new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4,
		Text = "", AutoButtonColor = false, ZIndex = 100, Parent = canvas,
	})
	local box = UI.new("Frame", {
		Size = UDim2.fromOffset(440, 170), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = overlay,
	})
	UI.Round(box, 12)
	UI.Stroke(box, T.Panel2, 2)
	UI.Label({
		Text = text, TextWrapped = true, TextSize = 18, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(20, 20), Size = UDim2.new(1, -40, 0, 70), Parent = box,
	})
	UI.Button({ Text = "CANCEL", Position = UDim2.fromOffset(20, 110), Size = UDim2.fromOffset(190, 40), Parent = box, OnClick = function() overlay:Destroy() end })
	UI.Button({
		Text = yesText, BackgroundColor3 = T.Bad, Position = UDim2.fromOffset(230, 110), Size = UDim2.fromOffset(190, 40), Parent = box,
		OnClick = function()
			overlay:Destroy()
			onYes()
		end,
	})
end

---------------------------------------------------------------- builder state helpers

local function refresh()
	local b = editing.Build
	ctx.Spent = BuildMath.AttributePointsSpent(b)
	ctx.Left = Config.AttributePoints - ctx.Spent
	ctx.BadgeTotal, ctx.BadgePer = BuildMath.BadgePoints(b)
	for _, f in ipairs(updaters) do
		f()
	end
end

local function mutate(fn)
	fn(editing.Build)
	editing.Dirty = true
	BuildMath.Normalize(editing.Build)
	refresh()
	schedulePreview()
end

local function valueColor(v)
	if v >= 90 then return Color3.fromRGB(255, 90, 200)
	elseif v >= 80 then return Color3.fromRGB(90, 180, 255)
	elseif v >= 70 then return T.Good
	elseif v >= 55 then return T.Gold end
	return T.Dim
end

---------------------------------------------------------------- slots screen

UI.Label({ Text = "MYPLAYER", Font = Enum.Font.GothamBlack, TextSize = 44, Position = UDim2.fromOffset(40, 24), Size = UDim2.fromOffset(500, 52), Parent = slotsScreen })
UI.Label({
	Text = "Create up to " .. Config.MaxSlots .. " builds. Equip one to play as it.",
	TextColor3 = T.Dim, TextSize = 16, Position = UDim2.fromOffset(42, 76), Size = UDim2.fromOffset(600, 22), Parent = slotsScreen,
})
UI.Button({
	Text = "CLOSE", Position = UDim2.fromOffset(1116, 32), Size = UDim2.fromOffset(124, 38), Parent = slotsScreen,
	OnClick = function() backdrop.Visible = false end,
})
local grid = UI.new("Frame", { Position = UDim2.fromOffset(40, 116), Size = UDim2.fromOffset(1200, 560), BackgroundTransparency = 1, Parent = slotsScreen })
UI.new("UIGridLayout", {
	CellSize = UDim2.fromOffset(224, 262), CellPadding = UDim2.fromOffset(10, 12),
	SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid,
})

function renderSlots()
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i = 1, Config.MaxSlots do
		local b = state.Slots[i]
		local active = state.Selected == i
		local card = UI.new("Frame", { BackgroundColor3 = T.Panel, BorderSizePixel = 0, LayoutOrder = i, Parent = grid })
		UI.Round(card, 10)
		UI.Stroke(card, active and T.Gold or T.Panel2, active and 2 or 1)
		Fx.Pop(card, (i - 1) * 0.04)
		UI.Label({ Text = "SLOT " .. i, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Dim, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(80, 16), Parent = card })
		if active then
			UI.Label({
				Text = "ACTIVE", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(1, -72, 0, 8), Size = UDim2.fromOffset(60, 16), Parent = card,
			})
		end

		if not b then
			UI.Label({ Text = "+", TextSize = 64, Font = Enum.Font.GothamBlack, TextColor3 = T.Panel2, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 80), Parent = card })
			UI.Label({ Text = "Empty slot", TextColor3 = T.Dim, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 144), Size = UDim2.new(1, 0, 0, 20), Parent = card })
			UI.Button({
				Text = "CREATE PLAYER", BackgroundColor3 = T.Accent, Position = UDim2.fromOffset(12, 214), Size = UDim2.new(1, -24, 0, 36), Parent = card,
				OnClick = function() openBuilder(i, nil) end,
			})
		else
			local arch = Archetypes.ById[b.Archetype]
			UI.Label({ Text = b.Name, Font = Enum.Font.GothamBlack, TextSize = 20, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 24), Parent = card })
			UI.Label({ Text = b.Position .. " · " .. arch.Name, TextSize = 12, TextColor3 = T.Dim, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 0, 16), Parent = card })
			UI.Label({ Text = tostring(BuildMath.Overall(b)), Font = Enum.Font.GothamBlack, TextSize = 56, TextColor3 = BuildMath.OverallTier(BuildMath.Overall(b)).Color, Position = UDim2.fromOffset(12, 68), Size = UDim2.fromOffset(92, 62), Parent = card })
			UI.Label({
				Text = BuildMath.FormatHeight(b.Height) .. "\n" .. b.Weight .. " lbs\nWS " .. BuildMath.FormatHeight(BuildMath.Wingspan(b)),
				TextSize = 13, TextColor3 = T.Dim, Position = UDim2.fromOffset(112, 74), Size = UDim2.fromOffset(100, 54), Parent = card,
			})
			local tk = {}
			for _, side in ipairs({ "Offense", "Defense" }) do
				local id = b.Takeovers[side]
				if id then
					table.insert(tk, Takeovers.ById[id].Name)
				end
			end
			UI.Label({ Text = "Takeover: " .. (#tk > 0 and table.concat(tk, " / ") or "none"), TextSize = 12, TextColor3 = T.Dim, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(12, 138), Size = UDim2.new(1, -24, 0, 16), Parent = card })
			UI.new("TextButton", {
				Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 174), Parent = card,
			}).Activated:Connect(function()
				presentBuild(b, { Intro = false, Slot = i })
			end)
			local badgeTotal = BuildMath.BadgePoints(b)
			UI.Label({ Text = "Badge pts " .. badgeTotal .. "/" .. Config.BadgePointsTotal, TextSize = 12, TextColor3 = T.Dim, Position = UDim2.fromOffset(12, 156), Size = UDim2.new(1, -24, 0, 16), Parent = card })

			UI.Button({
				Text = active and "EQUIPPED" or "EQUIP", BackgroundColor3 = active and T.Panel2 or T.Accent, TextSize = 13,
				Position = UDim2.fromOffset(12, 180), Size = UDim2.fromOffset(94, 30), Parent = card,
				OnClick = function()
					local ok, err = request("Select", i)
					if ok then
						state.Selected = i
						renderSlots()
						toast("Equipped " .. b.Name, T.Good)
					else
						toast(tostring(err), T.Bad)
					end
				end,
			})
			UI.Button({ Text = "EDIT", TextSize = 13, Position = UDim2.fromOffset(118, 180), Size = UDim2.fromOffset(94, 30), Parent = card, OnClick = function() openBuilder(i, b) end })
			UI.Button({
				Text = "COPY", TextSize = 13, Position = UDim2.fromOffset(12, 216), Size = UDim2.fromOffset(94, 30), Parent = card,
				OnClick = function()
					local free
					for j = 1, Config.MaxSlots do
						if not state.Slots[j] then
							free = j
							break
						end
					end
					if not free then
						toast("No free slots. Delete one first.", T.Bad)
						return
					end
					local ok, res = request("Duplicate", i, free)
					if ok then
						state.Slots[free] = res
						renderSlots()
						toast("Copied to slot " .. free, T.Good)
					else
						toast(tostring(res), T.Bad)
					end
				end,
			})
			UI.Button({
				Text = "DELETE", TextSize = 13, BackgroundColor3 = Color3.fromRGB(90, 36, 44), Position = UDim2.fromOffset(118, 216), Size = UDim2.fromOffset(94, 30), Parent = card,
				OnClick = function()
					confirm("Delete \"" .. b.Name .. "\" from slot " .. i .. "? This can't be undone.", "DELETE", function()
						local ok, err = request("Delete", i)
						if ok then
							state.Slots[i] = nil
							if state.Selected == i then
								state.Selected = nil
							end
							renderSlots()
							toast("Build deleted", T.Good)
						else
							toast(tostring(err), T.Bad)
						end
					end)
				end,
			})
		end
	end
end

-- `during` runs while the screen is fully covered (use it to swap in other screens).
function showScreen(name, during)
	Fx.Tween(curtain, 0.12, { BackgroundTransparency = 0 })
	task.wait(0.13)
	slotsScreen.Visible = name == "Slots"
	builderScreen.Visible = name == "Builder"
	if name == "Slots" then
		renderSlots()
	end
	if during then
		during()
	end
	Fx.Tween(curtain, 0.2, { BackgroundTransparency = 1 })
end

---------------------------------------------------------------- builder screen

local function card(parent, height)
	local f = UI.new("Frame", { Size = UDim2.new(1, -12, 0, height), BackgroundColor3 = T.Panel2, BorderSizePixel = 0, Parent = parent })
	UI.Round(f, 8)
	return f
end

local function scroller(parent, position, size)
	local s = UI.new("ScrollingFrame", {
		Position = position or UDim2.new(), Size = size or UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = parent,
	})
	UI.List(s, 8)
	return s
end

local function small(parent, text, x, y, w, color)
	return UI.Label({ Text = text, TextSize = 12, TextColor3 = color or T.Dim, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent })
end

local function buildBuilder()
	builderScreen:ClearAllChildren()
	table.clear(updaters)
	local b = editing.Build

	UI.Label({ Text = "MYPLAYER BUILDER", Font = Enum.Font.GothamBlack, TextSize = 28, Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(340, 36), Parent = builderScreen })
	UI.Label({ Text = "SLOT " .. editing.Slot, Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = T.Gold, Position = UDim2.fromOffset(372, 18), Size = UDim2.fromOffset(120, 28), Parent = builderScreen })
	UI.Button({
		Text = "BACK", Position = UDim2.fromOffset(1140, 14), Size = UDim2.fromOffset(124, 38), Parent = builderScreen,
		OnClick = function()
			commitInputs()
			if editing.Dirty then
				confirm("Discard your unsaved changes?", "DISCARD", function()
					editing = nil
					showScreen("Slots")
				end)
			else
				editing = nil
				showScreen("Slots")
			end
		end,
	})

	---------------- left: preview + summary
	local left = UI.new("Frame", { Position = UDim2.fromOffset(16, 64), Size = UDim2.fromOffset(330, 584), BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = builderScreen })
	UI.Round(left, 10)
	UI.Gradient(left, Color3.fromRGB(30, 34, 48), T.Panel, 90)
	UI.Stroke(left, T.Panel2, 1)
	local vp = UI.new("ViewportFrame", {
		Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(314, 340), BackgroundColor3 = Color3.fromRGB(14, 16, 24),
		Ambient = Color3.fromRGB(170, 170, 185), LightColor = Color3.fromRGB(255, 244, 230), LightDirection = Vector3.new(-1, -1, 0.6),
		BorderSizePixel = 0, Parent = left,
	})
	UI.Round(vp, 8)
	local loading = UI.Label({ Text = "Loading preview...", TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = vp })
	UI.Label({ Text = "drag to rotate", TextSize = 11, TextColor3 = T.Dim, Position = UDim2.new(0, 10, 1, -20), Size = UDim2.fromOffset(120, 14), Parent = vp })
	local ovrLabel = UI.Label({ Font = Enum.Font.GothamBlack, TextSize = 52, TextColor3 = T.Gold, Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(100, 56), Parent = vp })
	UI.Label({ Text = "OVR", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Dim, Position = UDim2.fromOffset(12, 58), Size = UDim2.fromOffset(60, 14), Parent = vp })

	local function summary(y, fn, size)
		local l = UI.Label({ TextSize = size or 14, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(302, 22), Parent = left })
		table.insert(updaters, function() l.Text = fn() end)
	end
	summary(358, function() return "#" .. b.Number .. "  " .. b.Name end, 20)
	summary(386, function() return b.Position .. " · " .. Archetypes.ById[b.Archetype].Name end)
	summary(412, function() return BuildMath.FormatHeight(b.Height) .. " · " .. b.Weight .. " lbs · WS " .. BuildMath.FormatHeight(BuildMath.Wingspan(b)) end)
	summary(446, function() return "Attribute points left: " .. ctx.Left .. " / " .. Config.AttributePoints end)
	summary(472, function() return "Badge points: " .. ctx.BadgeTotal .. " / " .. Config.BadgePointsTotal end)
	summary(498, function()
		local p = ctx.BadgePer
		return ("FIN %d · SHT %d · PLY %d · DEF %d"):format(p.Finishing, p.Shooting, p.Playmaking, p.Defense)
	end, 12)
	summary(524, function()
		local o, d = b.Takeovers.Offense, b.Takeovers.Defense
		return "Off: " .. (o and Takeovers.ById[o].Name or "none") .. "  |  Def: " .. (d and Takeovers.ById[d].Name or "none")
	end, 13)
	local lastOvr = 0
	table.insert(updaters, function()
		local o = BuildMath.Overall(editing.Build)
		if o ~= lastOvr then
			Fx.CountUp(ovrLabel, lastOvr, o, 0.35)
			Fx.Punch(ovrLabel, 1.1)
			lastOvr = o
		end
		ovrLabel.TextColor3 = BuildMath.OverallTier(o).Color
	end)

	---------------- preview rig
	local camera = UI.new("Camera", { FieldOfView = 40, Parent = vp })
	vp.CurrentCamera = camera
	local rigRef, groundY, yaw = nil, 0, math.rad(-20)

	local function applyYaw()
		if rigRef then
			rigRef:PivotTo(CFrame.new(0, groundY, 0) * CFrame.Angles(0, yaw, 0))
		end
	end

	local token = 0
	schedulePreview = function()
		token += 1
		local mine = token
		task.delay(0.12, function()
			if mine ~= token or not vp.Parent then
				return
			end
			local snapshot = BuildMath.Clone(editing.Build)
			local rig = RthroRig.CreatePreview(snapshot, state.BaseDesc)
			if mine ~= token or not vp.Parent then
				if rig then rig:Destroy() end
				return
			end
			if not rig then
				loading.Text = "Preview unavailable"
				return
			end
			if rigRef then
				rigRef:Destroy()
			end
			loading.Visible = false
			rig.Parent = vp
			rigRef = rig
			rig:PivotTo(CFrame.new(0, 50, 0))
			local cf, size = rig:GetBoundingBox()
			groundY = 50 - (cf.Position.Y - size.Y / 2)
			applyYaw()
			-- fixed camera sized for the tallest legal player so height differences are visible
			local unit = size.Y / BuildMath.RigScales(snapshot).Height
			local maxH = unit * (Config.Scale.HeightScaleAtDefault * Config.Height.Max / Config.Height.Default)
			local dist = (maxH * 0.55) / math.tan(math.rad(camera.FieldOfView / 2))
			local focus = Vector3.new(0, maxH * 0.48, 0)
			camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, -dist), focus)
		end)
	end

	local dragging, lastX = false, 0
	vp.InputBegan:Connect(function(input)
		if UI.IsPress(input) then
			dragging, lastX = true, input.Position.X
		end
	end)
	local d1 = UserInputService.InputChanged:Connect(function(input)
		if dragging and UI.IsMove(input) then
			yaw += (input.Position.X - lastX) * 0.012
			lastX = input.Position.X
			applyYaw()
		end
	end)
	local d2 = UserInputService.InputEnded:Connect(function(input)
		if UI.IsPress(input) then
			dragging = false
		end
	end)
	vp.Destroying:Connect(function()
		d1:Disconnect()
		d2:Disconnect()
	end)

	---------------- right: tabs
	local right = UI.new("Frame", { Position = UDim2.fromOffset(358, 64), Size = UDim2.fromOffset(906, 584), BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = builderScreen })
	UI.Round(right, 10)
	UI.Gradient(right, Color3.fromRGB(30, 34, 48), T.Panel, 90)
	UI.Stroke(right, T.Panel2, 1)
	local pages, tabButtons = {}, {}
	local function showTab(name)
		for n, p in pairs(pages) do
			p.Visible = n == name
		end
		for n, bt in pairs(tabButtons) do
			UI.SetColor(bt, n == name and T.Accent or T.Panel2)
		end
	end
	for i, name in ipairs({ "Profile", "Attributes", "Badges", "Takeovers" }) do
		tabButtons[name] = UI.Button({
			Text = string.upper(name), Position = UDim2.fromOffset(12 + (i - 1) * 172, 8), Size = UDim2.fromOffset(164, 36), Parent = right,
			OnClick = function() showTab(name) end,
		})
		pages[name] = UI.new("Frame", { Position = UDim2.fromOffset(12, 54), Size = UDim2.fromOffset(882, 520), BackgroundTransparency = 1, Visible = false, Parent = right })
	end

	-------- PROFILE
	do
		local page = scroller(pages.Profile)

		local r = card(page, 54)
		UI.Label({ Text = "NAME", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Dim, Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(100, 54), Parent = r })
		local nameBox = UI.new("TextBox", {
			Position = UDim2.fromOffset(120, 10), Size = UDim2.fromOffset(300, 34), BackgroundColor3 = T.Panel, TextColor3 = T.Text,
			PlaceholderText = "Player name", Font = Enum.Font.GothamMedium, TextSize = 18, ClearTextOnFocus = false, Text = b.Name,
			TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, Parent = r,
		})
		UI.Round(nameBox, 6)
		UI.Pad(nameBox, 8)
		UI.Label({ Text = "NUMBER", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Dim, Position = UDim2.fromOffset(450, 0), Size = UDim2.fromOffset(80, 54), Parent = r })
		local numBox = UI.new("TextBox", {
			Position = UDim2.fromOffset(530, 10), Size = UDim2.fromOffset(80, 34), BackgroundColor3 = T.Panel, TextColor3 = T.Text,
			Font = Enum.Font.GothamMedium, TextSize = 18, ClearTextOnFocus = false, Text = tostring(b.Number), BorderSizePixel = 0, Parent = r,
		})
		UI.Round(numBox, 6)
		local function commitName()
			local n = string.sub((string.gsub(nameBox.Text, "^%s*(.-)%s*$", "%1")), 1, Config.Name.MaxLength)
			if n ~= editing.Build.Name then
				mutate(function(x) x.Name = n end)
			end
		end
		local function commitNumber()
			local n = math.floor(tonumber(numBox.Text) or editing.Build.Number)
			n = math.clamp(n, Config.JerseyNumber.Min, Config.JerseyNumber.Max)
			if n ~= editing.Build.Number then
				mutate(function(x) x.Number = n end)
			end
		end
		nameBox.FocusLost:Connect(commitName)
		numBox.FocusLost:Connect(commitNumber)
		commitInputs = function()
			commitName()
			commitNumber()
		end
		table.insert(updaters, function()
			if not nameBox:IsFocused() then nameBox.Text = editing.Build.Name end
			if not numBox:IsFocused() then numBox.Text = tostring(editing.Build.Number) end
		end)

		-- position
		local r2 = card(page, 54)
		UI.Label({ Text = "POSITION", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Dim, Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(100, 54), Parent = r2 })
		for i, p in ipairs(Archetypes.PositionOrder) do
			local bt = UI.Button({
				Text = p, Position = UDim2.fromOffset(120 + (i - 1) * 84, 10), Size = UDim2.fromOffset(76, 34), Parent = r2,
				OnClick = function()
					mutate(function(x)
						x.Position = p
						if not table.find(Archetypes.ById[x.Archetype].Positions, p) then
							BuildMath.ApplyArchetype(x, Archetypes.Default(p).Id)
						end
					end)
				end,
			})
			table.insert(updaters, function() UI.SetColor(bt, editing.Build.Position == p and T.Accent or T.Panel) end)
		end

		-- archetype
		local r3 = card(page, 262)
		UI.Label({ Text = "ARCHETYPE  (changing it resets attributes, badges and takeovers)", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Dim, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(700, 18), Parent = r3 })
		local archGrid = UI.new("Frame", { Position = UDim2.fromOffset(12, 32), Size = UDim2.fromOffset(846, 164), BackgroundTransparency = 1, Parent = r3 })
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(418, 36), CellPadding = UDim2.fromOffset(10, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = archGrid })
		local archDesc = UI.Label({ TextSize = 14, TextColor3 = T.Dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(12, 204), Size = UDim2.fromOffset(846, 50), Parent = r3 })
		local archButtons, shownPos = {}, nil
		table.insert(updaters, function()
			local bb = editing.Build
			if shownPos ~= bb.Position then
				shownPos = bb.Position
				for _, c in ipairs(archGrid:GetChildren()) do
					if c:IsA("GuiButton") then c:Destroy() end
				end
				table.clear(archButtons)
				for i, a in ipairs(Archetypes.ForPosition(bb.Position)) do
					archButtons[a.Id] = UI.Button({
						Text = a.Name, TextSize = 14, LayoutOrder = i, Parent = archGrid,
						OnClick = function() mutate(function(x) BuildMath.ApplyArchetype(x, a.Id) end) end,
					})
				end
			end
			for id, bt in pairs(archButtons) do
				UI.SetColor(bt, id == bb.Archetype and T.Accent or T.Panel)
			end
			archDesc.Text = Archetypes.ById[bb.Archetype].Description
		end)

		-- physical sliders
		local function sliderRow(title, min, max, onChange)
			local row = card(page, 58)
			UI.Label({ Text = title, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Dim, Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(240, 18), Parent = row })
			local val = UI.Label({ TextSize = 18, Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(12, 26), Size = UDim2.fromOffset(250, 24), Parent = row })
			local s = UI.Slider({ Parent = row, Position = UDim2.fromOffset(290, 25), Size = UDim2.fromOffset(540, 8), Min = min, Max = max, Value = min, OnChanged = onChange })
			return s, val
		end
		local hSlider, hVal = sliderRow("HEIGHT", Config.Height.Min, Config.Height.Max, function(v) mutate(function(x) x.Height = v end) end)
		local wSlider, wVal = sliderRow("WINGSPAN", Config.Wingspan.MinOffset, Config.Wingspan.MaxOffset, function(v) mutate(function(x) x.WingspanOffset = v end) end)
		local kSlider, kVal = sliderRow("WEIGHT", 100, 400, function(v) mutate(function(x) x.Weight = v end) end)
		table.insert(updaters, function()
			local bb = editing.Build
			local pos = Archetypes.Positions[bb.Position]
			hSlider:SetRange(pos.HeightMin, pos.HeightMax)
			hSlider:Set(bb.Height)
			hVal.Text = BuildMath.FormatHeight(bb.Height) .. "  (" .. pos.Name .. " range " .. BuildMath.FormatHeight(pos.HeightMin) .. "-" .. BuildMath.FormatHeight(pos.HeightMax) .. ")"
			wSlider:Set(bb.WingspanOffset)
			wVal.Text = BuildMath.FormatHeight(BuildMath.Wingspan(bb)) .. "  (" .. (bb.WingspanOffset >= 0 and "+" or "") .. bb.WingspanOffset .. "\" vs height)"
			local lo, hi = BuildMath.WeightRange(bb.Height)
			kSlider:SetRange(lo, hi)
			kSlider:Set(bb.Weight)
			kVal.Text = bb.Weight .. " lbs  (" .. lo .. "-" .. hi .. ")"
		end)

		-- skin tone
		local r4 = card(page, 58)
		UI.Label({ Text = "SKIN TONE", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Dim, Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(100, 58), Parent = r4 })
		for i, hex in ipairs(Config.SkinTones) do
			local sw = UI.Button({ BackgroundColor3 = Color3.fromHex(hex), Position = UDim2.fromOffset(120 + (i - 1) * 56, 9), Size = UDim2.fromOffset(40, 40), Parent = r4, OnClick = function() mutate(function(x) x.SkinTone = i end) end })
			local stroke = UI.Stroke(sw, T.Gold, 0)
			table.insert(updaters, function() stroke.Thickness = editing.Build.SkinTone == i and 3 or 0 end)
		end
	end

	-------- ATTRIBUTES
	do
		local page = scroller(pages.Attributes)
		local head = card(page, 44)
		local headLbl = UI.Label({ Font = Enum.Font.GothamBold, TextSize = 18, Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(500, 44), Parent = head })
		table.insert(updaters, function() headLbl.Text = "ATTRIBUTE POINTS  " .. ctx.Left .. " / " .. Config.AttributePoints end)
		UI.Label({ Text = "bar: dark = starting value · tick = cap (set by archetype, height, wingspan, weight)", TextSize = 12, TextColor3 = T.Dim, Position = UDim2.fromOffset(330, 0), Size = UDim2.fromOffset(540, 44), Parent = head })

		local order = 0
		for _, cat in ipairs(Attributes.Categories) do
			order += 1
			UI.Label({ Text = string.upper(cat), Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = T.Gold, LayoutOrder = order, Size = UDim2.new(1, -12, 0, 22), Parent = page })
			for _, a in ipairs(Attributes.ByCategory[cat]) do
				order += 1
				local r = UI.new("Frame", { Size = UDim2.new(1, -12, 0, 36), BackgroundColor3 = T.Panel2, BorderSizePixel = 0, LayoutOrder = order, Parent = page })
				UI.Round(r, 6)
				UI.Label({ Text = a.Name, TextSize = 15, Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(190, 36), Parent = r })
				local valLbl = UI.Label({ Font = Enum.Font.GothamBlack, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(204, 0), Size = UDim2.fromOffset(44, 36), Parent = r })
				local bar = UI.new("Frame", { Position = UDim2.fromOffset(258, 14), Size = UDim2.fromOffset(300, 8), BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = r })
				UI.Round(bar, 3)
				local fill = UI.new("Frame", { BackgroundColor3 = T.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = bar })
				UI.Round(fill, 3)
				local baseMark = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(70, 60, 120), BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 0, Parent = bar })
				UI.Round(baseMark, 3)
				local tick = UI.new("Frame", { BackgroundColor3 = T.Gold, BorderSizePixel = 0, Size = UDim2.fromOffset(2, 16), Position = UDim2.fromScale(1, -0.5), Parent = bar })
				local capLbl = small(r, "", 574, 4, 70)
				local costLbl = small(r, "", 574, 18, 70)
				local minus = UI.Button({ Text = "-", TextSize = 20, Position = UDim2.fromOffset(660, 4), Size = UDim2.fromOffset(34, 28), Parent = r })
				local plus = UI.Button({ Text = "+", TextSize = 20, BackgroundColor3 = T.Accent, Position = UDim2.fromOffset(702, 4), Size = UDim2.fromOffset(34, 28), Parent = r })

				UI.OnHold(plus, function()
					local bb = editing.Build
					local v, cap = bb.Attributes[a.Key], BuildMath.GetCap(bb, a.Key)
					if v < cap and BuildMath.PointCost(v, v + 1) <= ctx.Left then
						mutate(function(x) x.Attributes[a.Key] = v + 1 end)
					end
				end)
				UI.OnHold(minus, function()
					local bb = editing.Build
					local v = bb.Attributes[a.Key]
					if v > BuildMath.GetBase(bb, a.Key) then
						mutate(function(x) x.Attributes[a.Key] = v - 1 end)
					end
				end)

				table.insert(updaters, function()
					local bb = editing.Build
					local v, base, cap = bb.Attributes[a.Key], BuildMath.GetBase(bb, a.Key), BuildMath.GetCap(bb, a.Key)
					valLbl.Text = tostring(v)
					valLbl.TextColor3 = valueColor(v)
					Fx.Tween(fill, 0.15, { Size = UDim2.fromScale(v / 99, 1), BackgroundColor3 = UI.ValueColor(v) })
					baseMark.Size = UDim2.fromScale(base / 99, 1)
					tick.Position = UDim2.new(cap / 99, -1, -0.5, 0)
					capLbl.Text = "CAP " .. cap
					local cost = v < cap and BuildMath.PointCost(v, v + 1) or nil
					costLbl.Text = cost and ("+1 = " .. cost .. " pts") or "MAXED"
					UI.SetDisabled(plus, not cost or cost > ctx.Left)
					UI.SetDisabled(minus, v <= base)
				end)
			end
		end
	end

	-------- BADGES
	do
		local page = pages.Badges
		local catBar = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = page })
		local list = scroller(page, UDim2.fromOffset(0, 48), UDim2.new(1, 0, 1, -48))
		local badgeCat = Badges.Categories[1]
		local rowUpdaters = {}
		local catButtons = {}

		local function rebuildRows()
			for _, c in ipairs(list:GetChildren()) do
				if c:IsA("Frame") then c:Destroy() end
			end
			table.clear(rowUpdaters)
			for i, bd in ipairs(Badges.ByCategory[badgeCat]) do
				local r = UI.new("Frame", { Size = UDim2.new(1, -12, 0, 64), BackgroundColor3 = T.Panel2, BorderSizePixel = 0, LayoutOrder = i, Parent = list })
				UI.Round(r, 8)
				UI.Label({ Text = bd.Name, Font = Enum.Font.GothamBold, TextSize = 16, Position = UDim2.fromOffset(12, 5), Size = UDim2.fromOffset(500, 20), Parent = r })
				small(r, bd.Description, 12, 25, 560)
				local req = small(r, "", 12, 43, 580)
				local btns = {}
				for t = 1, #Config.BadgeTiers do
					btns[t] = UI.Button({
						Text = Config.BadgeTierShort[t], TextSize = 13, Position = UDim2.fromOffset(600 + (t - 1) * 54, 10), Size = UDim2.fromOffset(48, 44), Parent = r,
						OnClick = function()
							local cur = editing.Build.Badges[bd.Id] or 0
							if cur == t then
								mutate(function(x) x.Badges[bd.Id] = (t > 1) and (t - 1) or nil end)
							else
								local ok, why = BuildMath.BadgeCanSet(editing.Build, bd.Id, t)
								if not ok then
									toast(why, T.Bad)
									return
								end
								mutate(function(x) x.Badges[bd.Id] = t end)
							end
						end,
					})
				end
				table.insert(rowUpdaters, function()
					local bb = editing.Build
					local cur = bb.Badges[bd.Id] or 0
					for t, bt in ipairs(btns) do
						if t <= cur then
							UI.SetDisabled(bt, false)
							UI.SetColor(bt, Config.BadgeTierColors[t])
							bt.TextColor3 = Color3.fromRGB(20, 20, 25)
						else
							bt.TextColor3 = T.Text
							UI.SetColor(bt, T.Panel)
							UI.SetDisabled(bt, not BuildMath.BadgeCanSet(bb, bd.Id, t))
						end
					end
					if cur >= #Config.BadgeTiers then
						req.Text = "Maxed out: " .. Config.BadgeTiers[cur]
						req.TextColor3 = Config.BadgeTierColors[cur]
					else
						local ok, why = BuildMath.BadgeCanSet(bb, bd.Id, cur + 1)
						local nextName = Config.BadgeTiers[cur + 1]
						req.Text = ok and ("Next: " .. nextName .. " is available") or ("Next (" .. nextName .. "): " .. why)
						req.TextColor3 = ok and T.Good or T.Bad
					end
				end)
			end
			for _, f in ipairs(rowUpdaters) do f() end
		end

		for i, cat in ipairs(Badges.Categories) do
			catButtons[cat] = UI.Button({
				Position = UDim2.fromOffset((i - 1) * 222, 0), Size = UDim2.fromOffset(214, 40), TextSize = 14, Parent = catBar,
				OnClick = function()
					badgeCat = cat
					rebuildRows()
					refresh()
				end,
			})
		end
		table.insert(updaters, function()
			local arch = Archetypes.ById[editing.Build.Archetype]
			for cat, bt in pairs(catButtons) do
				bt.Text = string.upper(cat) .. "  " .. ctx.BadgePer[cat] .. "/" .. arch.BadgeCaps[cat]
				UI.SetColor(bt, cat == badgeCat and T.Accent or T.Panel2)
			end
			for _, f in ipairs(rowUpdaters) do f() end
		end)
		rebuildRows()
	end

	-------- TAKEOVERS
	do
		local page = pages.Takeovers
		for col, side in ipairs({ "Offense", "Defense" }) do
			local colFrame = scroller(page, UDim2.fromOffset((col - 1) * 446, 0), UDim2.fromOffset(436, 520))
			UI.Label({ Text = string.upper(side) .. " TAKEOVER", Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = T.Gold, LayoutOrder = 0, Size = UDim2.new(1, -12, 0, 22), Parent = colFrame })
			local n = 0
			for _, t in ipairs(Takeovers.List) do
				if t.Side == side then
					n += 1
					local bt = UI.Button({ Size = UDim2.new(1, -12, 0, 118), LayoutOrder = n, Parent = colFrame })
					UI.Label({ Text = t.Name, Font = Enum.Font.GothamBlack, TextSize = 18, Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(300, 22), Parent = bt })
					UI.Label({ Text = t.Description, TextSize = 12, TextColor3 = T.Dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(14, 32), Size = UDim2.fromOffset(400, 30), Parent = bt })
					local boosts = {}
					for key, v in pairs(t.Boosts) do
						table.insert(boosts, "+" .. v .. " " .. Attributes.ByKey[key].Name)
					end
					table.sort(boosts)
					UI.Label({ Text = table.concat(boosts, ", "), TextSize = 11, TextColor3 = T.Text, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(14, 62), Size = UDim2.fromOffset(400, 30), Parent = bt })
					local status = UI.Label({ TextSize = 12, Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(14, 96), Size = UDim2.fromOffset(400, 16), Parent = bt })
					bt.Activated:Connect(function()
						local bb = editing.Build
						if bb.Takeovers[side] == t.Id then
							mutate(function(x) x.Takeovers[side] = nil end)
						else
							local ok, why = BuildMath.TakeoverAvailable(bb, t.Id)
							if ok then
								mutate(function(x) x.Takeovers[side] = t.Id end)
							else
								toast(why, T.Bad)
							end
						end
					end)
					table.insert(updaters, function()
						local bb = editing.Build
						local allowed = table.find(Archetypes.ById[bb.Archetype].Takeovers[side], t.Id) ~= nil
						bt.Visible = allowed
						local ok, why = BuildMath.TakeoverAvailable(bb, t.Id)
						local selected = bb.Takeovers[side] == t.Id
						UI.SetColor(bt, selected and T.Accent or T.Panel2)
						status.Text = selected and "EQUIPPED (tap to remove)" or (ok and "Tap to equip" or why)
						status.TextColor3 = selected and T.Gold or (ok and T.Good or T.Bad)
					end)
				end
			end
		end
	end

	---------------- bottom bar
	local saving = false
	local function save(equip)
		if saving then return end
		commitInputs()
		saving = true
		local ok, res = request("Save", editing.Slot, editing.Build, equip)
		saving = false
		if not ok then
			toast(tostring(res), T.Bad)
			return
		end
		state.Slots[editing.Slot] = res
		if equip then
			state.Selected = editing.Slot
		end
		toast(equip and "Saved and equipped" or "Build saved", T.Good)
		local slot = editing.Slot
		editing = nil
		presentBuild(res, { Intro = Config.Cinematic.AutoPlayOnSave, Slot = slot })
	end
	local status = UI.Label({ TextSize = 14, TextColor3 = T.Dim, Position = UDim2.fromOffset(20, 660), Size = UDim2.fromOffset(700, 48), Parent = builderScreen })
	table.insert(updaters, function()
		status.Text = ("Attribute points left: %d   ·   Badge points left: %d"):format(ctx.Left, Config.BadgePointsTotal - ctx.BadgeTotal)
	end)
	UI.Button({
		Text = "RESET", Position = UDim2.fromOffset(796, 664), Size = UDim2.fromOffset(110, 40), Parent = builderScreen,
		OnClick = function()
			confirm("Reset attributes, badges and takeovers to this archetype's starting values?", "RESET", function()
				mutate(function(x) BuildMath.ApplyArchetype(x, x.Archetype) end)
			end)
		end,
	})
	UI.Button({ Text = "SAVE", BackgroundColor3 = Color3.fromRGB(40, 120, 80), Position = UDim2.fromOffset(916, 664), Size = UDim2.fromOffset(110, 40), Parent = builderScreen, OnClick = function() save(false) end })
	UI.Button({ Text = "SAVE & EQUIP", BackgroundColor3 = T.Accent, Position = UDim2.fromOffset(1036, 664), Size = UDim2.fromOffset(228, 40), Parent = builderScreen, OnClick = function() save(true) end })

	showTab("Profile")
	refresh()
	schedulePreview()
end

function openBuilder(slot, existing)
	local build = existing and BuildMath.Clone(existing)
	if not build then
		build = BuildMath.New("My Player", "PG", Archetypes.Default("PG").Id)
	else
		BuildMath.Normalize(build) -- heals older saves if you retune Config
	end
	editing = { Slot = slot, Build = build, Dirty = existing == nil }
	buildBuilder()
	showScreen("Builder")
end

---------------------------------------------------------------- presentation

Presentation.Init({
	Canvas = canvas,
	Gui = gui,
	Request = request,
	State = state,
	Toast = toast,
	OnClose = function()
		showScreen("Slots", function()
			Presentation.Hide()
		end)
	end,
	HideUI = function()
		backdrop.Visible = false
	end,
})

function presentBuild(build, opts)
	showScreen("None", function()
		Presentation.Show(build, opts)
	end)
end

---------------------------------------------------------------- open / close

local openBtn
local function setOpen(open)
	backdrop.Visible = open
	openBtn.Visible = not open
	if open then
		if not Presentation.IsOpen() then
			showScreen(editing and "Builder" or "Slots")
		end
	end
end

openBtn = UI.Button({
	Text = "MYPLAYER", BackgroundColor3 = T.Accent, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(120, 34), Parent = gui, OnClick = function() setOpen(true) end,
})

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Config.ToggleKey then
		return
	end
	setOpen(not backdrop.Visible)
end)

-- close button on slots screen only hides the backdrop; keep the open button in sync
backdrop:GetPropertyChangedSignal("Visible"):Connect(function()
	openBtn.Visible = not backdrop.Visible
end)

---------------------------------------------------------------- boot

task.spawn(function()
	state.BaseDesc = RthroRig.FetchBaseDescription(player.UserId)
end)

task.spawn(function()
	local ok, data = request("GetData")
	if not ok then
		toast(tostring(data), T.Bad)
		return
	end
	for key, build in pairs(data.Slots) do
		state.Slots[tonumber(key)] = build
	end
	state.Selected = data.Selected > 0 and data.Selected or nil
	if Config.OpenOnJoin then
		setOpen(true)
	end
end)
