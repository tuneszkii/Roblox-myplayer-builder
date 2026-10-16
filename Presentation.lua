--[[
	Presentation: the "player card" screen shown after saving (or by tapping a slot card).
	  * 3D stage with the Rthro rig on a turntable (drag to rotate)
	  * tier-colored player card: OVR, physicals, category radar + grades, top attributes,
	    badge tier counts, takeovers
	  * REPLAY CINEMATIC (in the viewport) and EQUIP & PLAY (equips, then runs the in-world cinematic)

	Presentation.Init{ Canvas, Gui, Request, State, Toast, OnClose, HideUI }
	Presentation.Show(build, { Intro = bool, Slot = n })   -- returns immediately; the rig loads async
	Presentation.Hide()                                    -- instant teardown
	Presentation.IsOpen()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MP = ReplicatedStorage:WaitForChild("MyPlayer")
local Config = require(MP:WaitForChild("Config"))
local Attributes = require(MP:WaitForChild("Attributes"))
local Archetypes = require(MP:WaitForChild("Archetypes"))
local Takeovers = require(MP:WaitForChild("Takeovers"))
local BuildMath = require(MP:WaitForChild("BuildMath"))
local RthroRig = require(MP:WaitForChild("RthroRig"))
local UI = require(script.Parent.UI)
local Fx = require(script.Parent.Fx)
local Radar = require(script.Parent.Radar)
local Cinematic = require(script.Parent.Cinematic)
local T = UI.Theme

local player = Players.LocalPlayer

local STAGE = { Pos = UDim2.fromOffset(40, 40), Size = UDim2.fromOffset(520, 640) }
local FULL = { Pos = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(1280, 720) }

local Presentation = {}
local init, root
local session = 0
local conns = {}

function Presentation.Init(opts)
	init = opts
	root = UI.new("Frame", {
		Name = "Presentation", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		ClipsDescendants = true, Visible = false, Parent = opts.Canvas,
	})
end

function Presentation.IsOpen()
	return root ~= nil and root.Visible
end

function Presentation.Hide()
	session += 1
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	table.clear(conns)
	Cinematic.Skip()
	root:ClearAllChildren()
	root.Visible = false
end

function Presentation.Show(build, opts)
	Presentation.Hide()
	opts = opts or {}
	local my = session
	root.Visible = true
	build = BuildMath.Clone(build)

	local ovr = BuildMath.Overall(build)
	local tier = BuildMath.OverallTier(ovr)
	local color = tier.Color
	local arch = Archetypes.ById[build.Archetype]
	local pos = Archetypes.Positions[build.Position]

	---------------- background: tinted gradient + slow light beams
	local bg = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.BG, BorderSizePixel = 0, Parent = root })
	UI.Gradient(bg, T.BG:Lerp(color, 0.22), T.BG, 35)
	for i, cfg in ipairs({ { x = 0.12, rot = 16 }, { x = 0.36, rot = -14 } }) do
		local beam = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(cfg.x, -0.15), Size = UDim2.fromOffset(240, 1100),
			Rotation = cfg.rot, BackgroundColor3 = color, BorderSizePixel = 0, Parent = bg,
		})
		UI.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.86), NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = beam,
		})
		TweenService:Create(
			beam,
			TweenInfo.new(6 + i, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Rotation = cfg.rot + (i == 1 and 10 or -10) }
		):Play()
	end

	---------------- stage: glowing floor ring + 3D viewport
	local floor = UI.new("Frame", {
		Position = UDim2.fromOffset(120, 606), Size = UDim2.fromOffset(360, 50), BackgroundColor3 = color,
		BackgroundTransparency = 0.82, BorderSizePixel = 0, Visible = false, Parent = root,
	})
	UI.Round(floor, 999)
	local floorStroke = UI.Stroke(floor, color, 3)
	floorStroke.Transparency = 0.2
	Fx.Pulse(floorStroke, { Transparency = 0.75 }, 1.4)

	local vp = UI.new("ViewportFrame", {
		Position = STAGE.Pos, Size = STAGE.Size, BackgroundColor3 = Color3.fromRGB(8, 10, 16), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(140, 140, 160), LightColor = Color3.fromRGB(255, 240, 225),
		LightDirection = Vector3.new(0.4, -0.7, 1), BorderSizePixel = 0, Parent = root,
	})
	local camera = UI.new("Camera", { FieldOfView = 32, Parent = vp })
	vp.CurrentCamera = camera
	local loading = UI.Label({
		Text = "Preparing build...", TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Center,
		Position = STAGE.Pos, Size = STAGE.Size, Parent = root,
	})

	---------------- the card (staggered sections)
	local cardFrame = UI.new("Frame", { Position = UDim2.fromOffset(590, 40), Size = UDim2.fromOffset(650, 640), BackgroundTransparency = 1, Parent = root })
	local sections, onReveal = {}, {}
	local function section(x, y, w, h)
		local g = UI.new("CanvasGroup", {
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1,
			GroupTransparency = 1, Parent = cardFrame,
		})
		g:SetAttribute("FinalPos", g.Position)
		table.insert(sections, g)
		return g
	end
	local function panel(parent, w, h, x, y)
		local f = UI.new("Frame", {
			Position = UDim2.fromOffset(x or 0, y or 0), Size = UDim2.fromOffset(w, h), BackgroundColor3 = T.Panel,
			BorderSizePixel = 0, Parent = parent,
		})
		UI.Round(f, 10)
		UI.Gradient(f, T.Panel2, T.Panel, 90)
		return f
	end

	-- header: name, subline, tier chip, shimmering OVR
	local head = section(0, 0, 650, 100)
	UI.Label({ Text = build.Name, Font = Enum.Font.GothamBlack, TextSize = 40, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.fromOffset(470, 46), Parent = head })
	UI.Label({
		Text = "#" .. build.Number .. "  ·  " .. pos.Name .. "  ·  " .. arch.Name, TextSize = 16, TextColor3 = T.Dim,
		TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(0, 50), Size = UDim2.fromOffset(470, 22), Parent = head,
	})
	local chip = UI.new("Frame", { Position = UDim2.fromOffset(0, 76), Size = UDim2.fromOffset(170, 22), BackgroundColor3 = color, BorderSizePixel = 0, Parent = head })
	UI.Round(chip, 11)
	UI.Label({
		Text = string.upper(tier.Name) .. " TIER", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(16, 16, 22),
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = chip,
	})
	local ovrLbl = UI.Label({
		Text = "0", Font = Enum.Font.GothamBlack, TextSize = 84, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(470, -8), Size = UDim2.fromOffset(180, 90), Parent = head,
	})
	local grad = UI.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(0.5, color:Lerp(Color3.new(1, 1, 1), 0.75)),
			ColorSequenceKeypoint.new(1, color),
		}),
		Parent = ovrLbl,
	})
	Fx.Shimmer(grad, 2.4)
	UI.Label({
		Text = "OVERALL", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(470, 80), Size = UDim2.fromOffset(180, 18), Parent = head,
	})
	table.insert(onReveal, function()
		Fx.CountUp(ovrLbl, 40, ovr, 0.9)
		Fx.Punch(chip, 1.15)
	end)

	-- physical tiles
	local tiles = section(0, 110, 650, 70)
	local off = build.WingspanOffset
	local tileData = {
		{ BuildMath.FormatHeight(build.Height), "HEIGHT" },
		{ build.Weight .. " LBS", "WEIGHT" },
		{ BuildMath.FormatHeight(BuildMath.Wingspan(build)), "WINGSPAN  (" .. (off >= 0 and "+" or "") .. off .. "\")" },
	}
	for i, d in ipairs(tileData) do
		local tile = panel(tiles, 206, 70, (i - 1) * 222, 0)
		UI.Label({ Text = d[1], Font = Enum.Font.GothamBlack, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 34), Parent = tile })
		UI.Label({ Text = d[2], TextSize = 12, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 18), Parent = tile })
	end

	-- radar + grades
	local rsec = section(0, 195, 320, 250)
	local cats = BuildMath.CategoryAverages(build)
	local labels, values = {}, {}
	local dimHex, goldHex = T.Dim:ToHex(), color:ToHex()
	for _, cat in ipairs(Attributes.Categories) do
		table.insert(labels, ("<font size='11' color='#%s'>%s</font>\n<font size='16' color='#%s'><b>%s</b></font>"):format(
			dimHex, string.upper(string.sub(cat, 1, 3)), goldHex, BuildMath.Grade(cats[cat])
		))
		table.insert(values, (cats[cat] - 25) / 74)
	end
	local radar = Radar.Create({
		Parent = rsec, Position = UDim2.new(), Size = Vector2.new(320, 250), Radius = 82,
		Labels = labels, Values = values, Color = color,
	})
	table.insert(onReveal, radar.Animate)

	-- top attributes
	local asec = section(340, 195, 310, 250)
	UI.Label({ Text = "TOP ATTRIBUTES", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Dim, Size = UDim2.fromOffset(300, 18), Parent = asec })
	for i, e in ipairs(BuildMath.TopAttributes(build, 7)) do
		local y = 26 + (i - 1) * 31
		local vc = UI.ValueColor(e.Value)
		UI.Label({ Text = e.Attribute.Name, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(150, 24), Parent = asec })
		local track = UI.new("Frame", { Position = UDim2.fromOffset(152, y + 9), Size = UDim2.fromOffset(100, 6), BackgroundColor3 = T.Panel2, BorderSizePixel = 0, Parent = asec })
		UI.Round(track, 3)
		local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = vc, BorderSizePixel = 0, Parent = track })
		UI.Round(fill, 3)
		UI.Label({ Text = tostring(e.Value), Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = vc, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(256, y), Size = UDim2.fromOffset(50, 24), Parent = asec })
		table.insert(onReveal, function()
			task.delay(0.08 * i, function()
				if fill.Parent then
					Fx.Tween(fill, 0.6, { Size = UDim2.fromScale(e.Value / 99, 1) }, Enum.EasingStyle.Cubic)
				end
			end)
		end)
	end

	-- badge tiers
	local bsec = section(0, 460, 650, 64)
	local bpanel = panel(bsec, 650, 64)
	local badgeTotal = BuildMath.BadgePoints(build)
	UI.Label({ Text = "BADGES", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Dim, Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(120, 16), Parent = bpanel })
	UI.Label({ Text = badgeTotal .. " / " .. Config.BadgePointsTotal .. " pts", Font = Enum.Font.GothamBold, TextSize = 16, Position = UDim2.fromOffset(16, 28), Size = UDim2.fromOffset(140, 22), Parent = bpanel })
	local counts = BuildMath.BadgeTierCounts(build)
	for t = 1, #Config.BadgeTiers do
		local x = 170 + (t - 1) * 96
		local tc = Config.BadgeTierColors[t]
		local icon = UI.new("Frame", { Position = UDim2.fromOffset(x, 16), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = tc, BorderSizePixel = 0, Parent = bpanel })
		UI.Round(icon, 8)
		UI.Gradient(icon, tc:Lerp(Color3.new(1, 1, 1), 0.35), tc:Lerp(Color3.new(0, 0, 0), 0.25), 90)
		UI.Label({ Text = Config.BadgeTierShort[t], Font = Enum.Font.GothamBlack, TextSize = t == 4 and 11 or 14, TextColor3 = Color3.fromRGB(16, 16, 22), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = icon })
		UI.Label({
			Text = "x" .. counts[t], Font = Enum.Font.GothamBlack, TextSize = 20, TextTransparency = counts[t] == 0 and 0.6 or 0,
			Position = UDim2.fromOffset(x + 38, 16), Size = UDim2.fromOffset(46, 32), Parent = bpanel,
		})
	end

	-- takeovers
	local ksec = section(0, 536, 650, 44)
	for i, side in ipairs({ "Offense", "Defense" }) do
		local id = build.Takeovers[side]
		local chipF = panel(ksec, 316, 44, (i - 1) * 334, 0)
		UI.Stroke(chipF, id and color or T.Panel2, id and 2 or 1)
		UI.Label({ Text = string.upper(side) .. " TAKEOVER", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = T.Dim, Position = UDim2.fromOffset(14, 5), Size = UDim2.fromOffset(280, 14), Parent = chipF })
		UI.Label({ Text = id and Takeovers.ById[id].Name or "None", Font = Enum.Font.GothamBlack, TextSize = 17, Position = UDim2.fromOffset(14, 19), Size = UDim2.fromOffset(280, 22), Parent = chipF })
	end

	---------------- stage logic
	local rig, groundY, H
	local yaw, autoRotate, dragging, lastDrag = 0, false, false, 0

	local function placeRig()
		rig:PivotTo(CFrame.new(0, groundY, 0) * CFrame.Angles(0, yaw, 0))
	end
	local function fitStage()
		camera.FieldOfView = 32
		local dist = (H * 0.58) / math.tan(math.rad(camera.FieldOfView / 2))
		camera.CFrame = CFrame.lookAt(Vector3.new(0, H * 0.5, -dist), Vector3.new(0, H * 0.5, 0))
	end
	local function revealCard()
		for i, g in ipairs(sections) do
			local fp = g:GetAttribute("FinalPos")
			g.Position = fp + UDim2.fromOffset(0, 22)
			task.delay(0.06 * i, function()
				if g.Parent then
					Fx.Tween(g, 0.45, { GroupTransparency = 0, Position = fp }, Enum.EasingStyle.Cubic)
				end
			end)
		end
		Fx.Play("Reveal")
		for _, f in ipairs(onReveal) do
			task.spawn(f)
		end
	end

	local function playIntro()
		autoRotate = false
		floor.Visible = false
		for _, g in ipairs(sections) do
			Fx.Tween(g, 0.2, { GroupTransparency = 1 })
		end
		yaw = 0
		placeRig()
		Fx.Tween(vp, 0.5, { Position = FULL.Pos, Size = FULL.Size, BackgroundTransparency = 0 }, Enum.EasingStyle.Quint)
		task.wait(0.55)
		if my ~= session then
			return
		end
		Cinematic.PlayViewport({ Parent = root, Camera = camera, Build = build, Height = H })
		if my ~= session then
			return
		end
		fitStage()
		Fx.Tween(vp, 0.9, { Position = STAGE.Pos, Size = STAGE.Size, BackgroundTransparency = 1 }, Enum.EasingStyle.Quint)
		task.wait(0.35)
		if my ~= session then
			return
		end
		floor.Visible = true
		lastDrag = os.clock()
		autoRotate = true
		revealCard()
	end

	---------------- buttons
	local busy = false
	local bsec2 = section(0, 592, 650, 44)
	UI.Button({
		Text = "REPLAY CINEMATIC", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(210, 44), Parent = bsec2,
		OnClick = function()
			if busy or not rig then
				return
			end
			busy = true
			playIntro()
			busy = false
		end,
	})
	UI.Button({
		Text = "EQUIP & PLAY", BackgroundColor3 = T.Accent, Position = UDim2.fromOffset(222, 0), Size = UDim2.fromOffset(210, 44), Parent = bsec2,
		OnClick = function()
			if busy or not opts.Slot then
				return
			end
			busy = true
			local ok, err = init.Request("Select", opts.Slot)
			if not ok then
				init.Toast(tostring(err), T.Bad)
				busy = false
				return
			end
			init.State.Selected = opts.Slot
			-- wait for the server to finish applying the build to the character
			local char = player.Character
			local before = char and char:GetAttribute("MP_ApplyId")
			local t0 = os.clock()
			while char and char:GetAttribute("MP_ApplyId") == before and os.clock() - t0 < 8 do
				task.wait(0.1)
			end
			if my ~= session then
				return
			end
			init.HideUI()
			Presentation.Hide()
			Cinematic.PlayWorld(build, { Gui = init.Gui })
		end,
	})
	UI.Button({
		Text = "DONE", Position = UDim2.fromOffset(444, 0), Size = UDim2.fromOffset(206, 44), Parent = bsec2,
		OnClick = function()
			init.OnClose()
		end,
	})

	---------------- load the rig, then intro or straight to the card
	task.spawn(function()
		local r = RthroRig.CreatePreview(build, init.State.BaseDesc)
		if my ~= session then
			if r then
				r:Destroy()
			end
			return
		end
		if not r then
			loading.Text = "Preview unavailable"
			revealCard()
			return
		end
		loading:Destroy()
		rig = r
		rig.Parent = vp
		rig:PivotTo(CFrame.new(0, 50, 0))
		local cf, size = rig:GetBoundingBox()
		groundY = 50 - (cf.Position.Y - size.Y / 2)
		H = size.Y
		placeRig()
		fitStage()

		table.insert(conns, RunService.RenderStepped:Connect(function(dt)
			if autoRotate and not dragging and os.clock() - lastDrag > 1.2 and rig.Parent then
				yaw += dt * 0.45
				placeRig()
			end
		end))
		local lastX = 0
		table.insert(conns, vp.InputBegan:Connect(function(input)
			if UI.IsPress(input) then
				dragging, lastX = true, input.Position.X
			end
		end))
		table.insert(conns, UserInputService.InputChanged:Connect(function(input)
			if dragging and UI.IsMove(input) then
				yaw += (input.Position.X - lastX) * 0.012
				lastX = input.Position.X
				lastDrag = os.clock()
				placeRig()
			end
		end))
		table.insert(conns, UserInputService.InputEnded:Connect(function(input)
			if UI.IsPress(input) then
				dragging = false
				lastDrag = os.clock()
			end
		end))

		if opts.Intro then
			playIntro()
		else
			floor.Visible = true
			lastDrag = os.clock()
			autoRotate = true
			revealCard()
		end
	end)
end

return Presentation
