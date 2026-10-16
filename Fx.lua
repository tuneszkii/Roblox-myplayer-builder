--[[ Fx: small animation helpers shared by the UI, presentation and cinematics. ]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MyPlayer"):WaitForChild("Config"))

local Fx = {}

function Fx.Tween(inst, time, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Plays Config.Sounds[name] if an ID was provided.
function Fx.Play(name, pitch)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = Config.SoundVolume
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 6)
end

-- Counts a TextLabel's number from -> to with ease-out. Newer calls cancel older ones.
function Fx.CountUp(label, from, to, duration, formatter)
	local token = (label:GetAttribute("CountToken") or 0) + 1
	label:SetAttribute("CountToken", token)
	task.spawn(function()
		local t0 = os.clock()
		while label.Parent and label:GetAttribute("CountToken") == token do
			local a = math.min(1, (os.clock() - t0) / duration)
			local e = 1 - (1 - a) ^ 3
			local v = math.floor(from + (to - from) * e + 0.5)
			label.Text = formatter and formatter(v) or tostring(v)
			if a >= 1 then
				break
			end
			task.wait()
		end
	end)
end

local function scaleOf(inst)
	local s = inst:FindFirstChild("FxScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "FxScale"
		s.Parent = inst
	end
	return s
end

-- Entrance: starts slightly small, springs to full size.
function Fx.Pop(inst, delay)
	local s = scaleOf(inst)
	s.Scale = 0.88
	task.delay(delay or 0, function()
		if s.Parent then
			Fx.Tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
end

-- Quick emphasis bump.
function Fx.Punch(inst, amount)
	local s = scaleOf(inst)
	s.Scale = amount or 1.12
	Fx.Tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Sweeps a UIGradient's Offset back and forth (shine effect).
function Fx.Shimmer(gradient, period)
	task.spawn(function()
		local t = 0
		while gradient.Parent do
			t += task.wait()
			gradient.Offset = Vector2.new((t / period) % 2 - 1, 0)
		end
	end)
end

-- Endless soft pulse of a UIStroke / any numeric property.
function Fx.Pulse(inst, props, seconds)
	local tw = TweenService:Create(inst, TweenInfo.new(seconds or 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), props)
	tw:Play()
	return tw
end

return Fx
