--[[
	Cinematic: scripted camera reveal of a build.
	  Cinematic.PlayViewport{ Parent, Camera, Build, Height }  -> reveal inside a ViewportFrame (presentation screen)
	  Cinematic.PlayWorld(build, { Gui })                       -> reveal on the real character in the game world
	  Cinematic.Skip()                                          -> cancel whatever is playing
	Both share the same shot list, letterbox, captions and OVR slam. Skip with the button, Space, Enter or ButtonA.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local MP = ReplicatedStorage:WaitForChild("MyPlayer")
local Config = require(MP:WaitForChild("Config"))
local Archetypes = require(MP:WaitForChild("Archetypes"))
local Takeovers = require(MP:WaitForChild("Takeovers"))
local BuildMath = require(MP:WaitForChild("BuildMath"))
local UI = require(script.Parent.UI)
local Fx = require(script.Parent.Fx)

local player = Players.LocalPlayer
local Cinematic = {}
local current -- the run currently playing: { Cancelled = bool }

---------------------------------------------------------------- shots
-- Camera params are relative to the player: Yaw (deg, 0 = in front), Y / Look (fractions of height),
-- Dist (multiples of height), Fov (deg). Positions interpolate From -> To with ease-in-out.
local SHOTS = {
	{ Dur = 2.6, From = { Yaw = -12, Y = 0.04, Dist = 0.85, Look = 0.04, Fov = 62 }, To = { Yaw = 8, Y = 0.12, Dist = 0.95, Look = 0.78, Fov = 48 } },
	{ Dur = 3.4, From = { Yaw = -70, Y = 0.55, Dist = 1.7, Look = 0.55, Fov = 42 }, To = { Yaw = 35, Y = 0.6, Dist = 1.55, Look = 0.58, Fov = 36 } },
	{ Dur = 2.6, From = { Yaw = 22, Y = 0.9, Dist = 1.2, Look = 0.9, Fov = 34 }, To = { Yaw = 0, Y = 0.9, Dist = 0.62, Look = 0.9, Fov = 26 } },
	{ Dur = 3.0, From = { Yaw = 0, Y = 0.5, Dist = 2.6, Look = 0.5, Fov = 46 }, To = { Yaw = 0, Y = 0.5, Dist = 2.1, Look = 0.5, Fov = 42 } },
}

local function ease(a)
	return -(math.cos(math.pi * a) - 1) / 2
end

local function camAt(basis, height, p)
	local yaw = math.rad(p.Yaw)
	local offset = Vector3.new(math.sin(yaw), 0, -math.cos(yaw)) * p.Dist * height
	local pos = (basis * CFrame.new(offset + Vector3.new(0, p.Y * height, 0))).Position
	local look = (basis * CFrame.new(0, p.Look * height, 0)).Position
	return CFrame.lookAt(pos, look)
end

local function lerpParams(a, b, t)
	local r = {}
	for k, v in pairs(a) do
		r[k] = v + (b[k] - v) * t
	end
	return r
end

local function hold(run, secs)
	local t0 = os.clock()
	while os.clock() - t0 < secs and not run.Cancelled do
		task.wait()
	end
end

-- Returns true if every shot finished, false if cancelled.
local function runShots(camera, basis, height, hooks, run)
	for i, shot in ipairs(SHOTS) do
		if hooks.OnShot then
			hooks.OnShot(i)
		end
		local t0 = os.clock()
		while true do
			if run.Cancelled then
				return false
			end
			local a = math.clamp((os.clock() - t0) / shot.Dur, 0, 1)
			local p = lerpParams(shot.From, shot.To, ease(a))
			-- tiny handheld sway so it doesn't feel robotic
			local sway = math.noise(os.clock() * 0.5, 7) * 0.012
			camera.CFrame = camAt(basis, height, p) * CFrame.Angles(0, 0, sway)
			camera.FieldOfView = p.Fov
			if hooks.OnFrame then
				hooks.OnFrame(camera)
			end
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end
	return true
end

---------------------------------------------------------------- overlay (letterbox, vignette, captions, OVR slam)

local function buildOverlay(parent, accent, onSkip)
	local o = {}
	local L = Config.Cinematic.LetterboxFraction
	local root = UI.new("Frame", {
		Name = "CinematicOverlay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		ClipsDescendants = true, ZIndex = 50, Parent = parent,
	})
	o.Root = root

	local function vignette(anchor, pos, size, rot)
		local f = UI.new("Frame", {
			AnchorPoint = anchor, Position = pos, Size = size, BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0, ZIndex = 51, Parent = root,
		})
		UI.new("UIGradient", { Transparency = NumberSequence.new(0.4, 1), Rotation = rot, Parent = f })
	end
	vignette(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.2, 1), 0)
	vignette(Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.2, 1), 180)
	vignette(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.22), 90)
	vignette(Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.22), 270)

	local top = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 60, Parent = root })
	local bottom = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 60, Parent = root,
	})
	o.Black = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 70, Parent = root })
	local flash = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 65, Parent = root })

	function o.Bars(open, t)
		local size = open and UDim2.new(1, 0, L, 0) or UDim2.new(1, 0, 0, 0)
		Fx.Tween(top, t, { Size = size }, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)
		Fx.Tween(bottom, t, { Size = size }, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)
	end

	function o.Flash(strength)
		flash.BackgroundTransparency = 1 - strength
		Fx.Tween(flash, 0.5, { BackgroundTransparency = 1 })
	end

	-- lower-third caption
	local capBase = UDim2.new(0.06, 0, 1 - L - 0.03, 0)
	local cap = UI.new("CanvasGroup", {
		AnchorPoint = Vector2.new(0, 1), Position = capBase, Size = UDim2.new(0.62, 0, 0, 110),
		BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 62, Parent = root,
	})
	UI.new("Frame", { Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(5, 84), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = cap })
	local capTitle = UI.Label({ Font = Enum.Font.GothamBlack, TextSize = 46, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -20, 0, 58), TextTruncate = Enum.TextTruncate.AtEnd, Parent = cap })
	local capSub = UI.Label({ TextSize = 18, TextColor3 = Color3.fromRGB(205, 210, 225), Position = UDim2.fromOffset(20, 62), Size = UDim2.new(1, -20, 0, 28), Parent = cap })

	function o.Caption(title, sub, typewrite)
		capTitle.Text = title
		capSub.Text = sub or ""
		cap.GroupTransparency = 1
		cap.Position = capBase + UDim2.fromOffset(-36, 0)
		Fx.Tween(cap, 0.5, { GroupTransparency = 0, Position = capBase }, Enum.EasingStyle.Cubic)
		if typewrite then
			capTitle.MaxVisibleGraphemes = 0
			task.spawn(function()
				for i = 1, (utf8.len(title) or #title) do
					if not cap.Parent then
						return
					end
					capTitle.MaxVisibleGraphemes = i
					Fx.Play("Tick")
					task.wait(0.035)
				end
				capTitle.MaxVisibleGraphemes = -1
			end)
		else
			capTitle.MaxVisibleGraphemes = -1
		end
	end

	function o.HideCaption()
		Fx.Tween(cap, 0.3, { GroupTransparency = 1 })
	end

	-- big OVR slam, bottom right
	local slam = UI.new("CanvasGroup", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.94, 0, 1 - L - 0.03, 0), Size = UDim2.fromOffset(320, 150),
		BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 62, Parent = root,
	})
	local slamScale = UI.new("UIScale", { Parent = slam })
	local ovrLbl = UI.Label({ Font = Enum.Font.GothamBlack, TextSize = 108, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(320, 110), Parent = slam })
	local tierLbl = UI.Label({ Font = Enum.Font.GothamBold, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(0, 112), Size = UDim2.fromOffset(320, 26), Parent = slam })

	function o.SlamOvr(ovr, tier)
		ovrLbl.TextColor3 = tier.Color
		tierLbl.TextColor3 = tier.Color
		tierLbl.Text = string.upper(tier.Name) .. "  OVERALL"
		slam.GroupTransparency = 0
		slamScale.Scale = 1.8
		Fx.Tween(slamScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		Fx.CountUp(ovrLbl, 40, ovr, 0.6)
		o.Flash(0.55)
		Fx.Play("Impact")
	end

	function o.HideOvr()
		Fx.Tween(slam, 0.3, { GroupTransparency = 1 })
	end

	UI.Button({
		Text = "SKIP  >>", TextSize = 13, BackgroundColor3 = Color3.fromRGB(20, 22, 30),
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, L, 12), Size = UDim2.fromOffset(96, 30),
		ZIndex = 80, Parent = root, OnClick = onSkip,
	})

	function o.Destroy()
		root:Destroy()
	end
	return o
end

local function bindSkip(run)
	return UserInputService.InputBegan:Connect(function(input)
		local k = input.KeyCode
		if k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA then
			run.Cancelled = true
		end
	end)
end

---------------------------------------------------------------- the sequence (shared)

local function sequence(env)
	local run, o, b = env.Run, env.Overlay, env.Build
	local ovr = BuildMath.Overall(b)
	local tier = BuildMath.OverallTier(ovr)
	local arch = Archetypes.ById[b.Archetype]
	local pos = Archetypes.Positions[b.Position]

	local badgeCount = 0
	for _ in pairs(b.Badges) do
		badgeCount += 1
	end
	local tk = {}
	for _, side in ipairs({ "Offense", "Defense" }) do
		local id = b.Takeovers[side]
		if id then
			table.insert(tk, Takeovers.ById[id].Name)
		end
	end
	local takeoverText = #tk > 0 and string.upper(table.concat(tk, " + ")) or "NO TAKEOVER"

	o.Bars(true, 0.7)
	Fx.Tween(o.Black, 0.9, { BackgroundTransparency = 1 })
	Fx.Play("Whoosh")

	local completed = runShots(env.Camera, env.Basis, env.Height, {
		OnFrame = env.OnFrame,
		OnShot = function(i)
			if i == 2 then
				Fx.Play("Whoosh", 0.9)
				o.Caption("#" .. b.Number .. "  " .. string.upper(b.Name), pos.Name .. "  ·  " .. arch.Name, true)
			elseif i == 3 then
				o.Caption(string.upper(arch.Name), badgeCount .. " BADGES  ·  " .. takeoverText)
			elseif i == 4 then
				o.Caption(
					BuildMath.FormatHeight(b.Height) .. "  ·  " .. b.Weight .. " LBS",
					"WINGSPAN " .. BuildMath.FormatHeight(BuildMath.Wingspan(b))
				)
				o.SlamOvr(ovr, tier)
			end
		end,
	}, run)

	if completed then
		hold(run, 1.1)
	end
	o.HideCaption()
	o.HideOvr()
	o.Bars(false, 0.45)
	if not run.Cancelled then
		task.wait(0.5)
	end
	return completed
end

---------------------------------------------------------------- public API

function Cinematic.Skip()
	if current then
		current.Cancelled = true
	end
end

function Cinematic.IsPlaying()
	return current ~= nil
end

function Cinematic.PlayViewport(opts)
	if current then
		current.Cancelled = true
	end
	local run = { Cancelled = false }
	current = run
	local tier = BuildMath.OverallTier(BuildMath.Overall(opts.Build))
	local overlay = buildOverlay(opts.Parent, tier.Color, function()
		run.Cancelled = true
	end)
	local skipConn = bindSkip(run)

	local ok, result = pcall(sequence, {
		Run = run, Overlay = overlay, Build = opts.Build,
		Camera = opts.Camera, Basis = CFrame.new(), Height = opts.Height,
	})
	skipConn:Disconnect()
	overlay.Destroy()
	if current == run then
		current = nil
	end
	if not ok then
		warn("[MyPlayer] cinematic error: " .. tostring(result))
	end
	return ok and result
end

function Cinematic.PlayWorld(build, opts)
	opts = opts or {}
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp) then
		return false
	end
	if current then
		current.Cancelled = true
	end
	local run = { Cancelled = false }
	current = run

	local camera = workspace.CurrentCamera
	local saved = { Type = camera.CameraType, FOV = camera.FieldOfView }
	local tier = BuildMath.OverallTier(BuildMath.Overall(build))

	local guiWasEnabled = opts.Gui and opts.Gui.Enabled
	if opts.Gui then
		opts.Gui.Enabled = false
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)

	local controls
	pcall(function()
		controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
		controls:Disable()
	end)

	local sg = UI.new("ScreenGui", {
		Name = "MyPlayerCinematic", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui"),
	})
	local overlay = buildOverlay(sg, tier.Color, function()
		run.Cancelled = true
	end)
	local skipConn = bindSkip(run)

	-- feet-origin basis facing the way the character faces
	local feet = hrp.Position - Vector3.new(0, hum.HipHeight + hrp.Size.Y / 2, 0)
	local flat = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	local basis = CFrame.lookAt(feet, feet + flat.Unit)
	local height = math.max(4, char:GetExtentsSize().Y)
	local focus = (basis * CFrame.new(0, height * 0.6, 0)).Position

	-- film look: tint, bloom, depth of field (client-side only)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Contrast = 0.12
	cc.Saturation = 0.1
	cc.TintColor = tier.Color:Lerp(Color3.new(1, 1, 1), 0.85)
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 0.85
	bloom.Parent = Lighting
	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.3
	dof.NearIntensity = 0
	dof.InFocusRadius = height
	dof.FocusDistance = 10
	dof.Parent = Lighting

	camera.CameraType = Enum.CameraType.Scriptable

	local ok, err = pcall(sequence, {
		Run = run, Overlay = overlay, Build = build, Camera = camera, Basis = basis, Height = height,
		OnFrame = function(cam)
			dof.FocusDistance = (cam.CFrame.Position - focus).Magnitude
		end,
	})
	if not ok then
		warn("[MyPlayer] world cinematic error: " .. tostring(err))
	end

	-- fade to black, hand the camera back, fade in
	Fx.Tween(overlay.Black, 0.25, { BackgroundTransparency = 0 })
	task.wait(0.3)
	skipConn:Disconnect()
	camera.CameraType = saved.Type
	camera.CameraSubject = hum
	camera.FieldOfView = saved.FOV
	cc:Destroy()
	bloom:Destroy()
	dof:Destroy()
	if controls then
		controls:Enable()
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
	if opts.Gui then
		opts.Gui.Enabled = guiWasEnabled
	end
	Fx.Tween(overlay.Black, 0.4, { BackgroundTransparency = 1 })
	task.wait(0.45)
	sg:Destroy()
	if current == run then
		current = nil
	end
	return ok
end

return Cinematic
