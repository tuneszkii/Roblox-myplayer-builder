--[[
	RthroRig: turns a build's physicals into an R15 Rthro-proportioned character.
	  * HumanoidDescription: BodyTypeScale/ProportionScale (Rthro), Height/Width/Depth/Head scale, skin tone
	  * Wingspan: Roblox has no wingspan scale, so upper/lower arm parts are lengthened and the
	    shoulder/elbow/wrist Motor6Ds are re-seated on their rig attachments.
	Works on the client (ViewportFrame preview) and on the server (real character).
]]

local Players = game:GetService("Players")

local Config = require(script.Parent.Config)
local BuildMath = require(script.Parent.BuildMath)

local RthroRig = {}

local SKIN_PROPS = { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }

function RthroRig.FetchBaseDescription(userId)
	if Config.Rthro.UseOwnAvatar then
		local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
		if ok and desc then
			return desc
		end
	end
	return Instance.new("HumanoidDescription")
end

function RthroRig.BuildDescription(build, baseDesc)
	local desc = baseDesc and baseDesc:Clone() or Instance.new("HumanoidDescription")

	for part, id in pairs(Config.Rthro.PartIds) do
		if id and id ~= 0 then
			desc[part] = id
		end
	end

	local s = BuildMath.RigScales(build)
	desc.HeightScale = s.Height
	desc.WidthScale = s.Width
	desc.DepthScale = s.Depth
	desc.HeadScale = s.Head
	desc.BodyTypeScale = Config.Rthro.BodyTypeScale
	desc.ProportionScale = Config.Rthro.ProportionScale

	local skin = Color3.fromHex(Config.SkinTones[build.SkinTone] or Config.SkinTones[1])
	for _, prop in ipairs(SKIN_PROPS) do
		desc[prop] = skin
	end
	return desc
end

-- Idempotent: always scales from the part's original size.
local function scaleLimb(part, factor)
	local orig = part:GetAttribute("MP_OrigSize")
	if not orig then
		orig = part.Size
		part:SetAttribute("MP_OrigSize", orig)
	end
	part.Size = Vector3.new(orig.X, orig.Y * factor, orig.Z)
	for _, att in ipairs(part:GetChildren()) do
		if att:IsA("Attachment") then
			local ocf = att:GetAttribute("MP_OrigCF")
			if not ocf then
				ocf = att.CFrame
				att:SetAttribute("MP_OrigCF", ocf)
			end
			local p = ocf.Position
			att.CFrame = CFrame.new(p.X, p.Y * factor, p.Z) * (ocf - p)
		end
	end
end

function RthroRig.ApplyWingspan(model, build)
	local factor = BuildMath.ArmFactor(build)
	for _, side in ipairs({ "Left", "Right" }) do
		for _, limb in ipairs({ "UpperArm", "LowerArm" }) do
			local part = model:FindFirstChild(side .. limb)
			if part then
				scaleLimb(part, factor)
			end
		end
		for _, joint in ipairs({ "Shoulder", "Elbow", "Wrist" }) do
			local name = side .. joint
			local motor = model:FindFirstChild(name, true)
			if motor and motor:IsA("Motor6D") and motor.Part0 and motor.Part1 then
				local a0 = motor.Part0:FindFirstChild(name .. "RigAttachment")
				local a1 = motor.Part1:FindFirstChild(name .. "RigAttachment")
				if a0 and a1 then
					motor.C0 = a0.CFrame
					motor.C1 = a1.CFrame
				end
			end
		end
	end
end

-- Yields. Returns a standalone R15 model (for ViewportFrames) or nil.
function RthroRig.CreatePreview(build, baseDesc)
	local desc = RthroRig.BuildDescription(build, baseDesc)
	local ok, rig = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	if not ok or not rig then
		warn("[MyPlayer] Preview rig failed: " .. tostring(rig))
		return nil
	end
	rig.Name = "PreviewRig"
	RthroRig.ApplyWingspan(rig, build)
	return rig
end

-- Yields. Applies the build to a live character (server).
function RthroRig.ApplyToCharacter(character, build, baseDesc)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false
	end
	local ok, err = pcall(function()
		hum:ApplyDescription(RthroRig.BuildDescription(build, baseDesc))
	end)
	if not ok then
		warn("[MyPlayer] ApplyDescription failed: " .. tostring(err))
		return false
	end
	RthroRig.ApplyWingspan(character, build)
	return true
end

return RthroRig
