--[[
	MyPlayerService (server)
	  * loads/saves each player's 10 slots (DataStore)
	  * validates every build server-side (client is never trusted)
	  * filters build names
	  * applies the equipped build to the character (Rthro scales, wingspan, stats, attributes)

	Remote: ReplicatedStorage.MyPlayer.Request (RemoteFunction)
	  GetData()                      -> true, { Slots = {["1"]=build,...}, Selected = n }
	  Save(slot, build, equip?)      -> true, savedBuild
	  Delete(slot)                   -> true
	  Select(slot)                   -> true
	  Duplicate(fromSlot, toSlot)    -> true, newBuild
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TextService = game:GetService("TextService")

local MP = ReplicatedStorage:WaitForChild("MyPlayer")
local Config = require(MP.Config)
local Archetypes = require(MP.Archetypes)
local BuildMath = require(MP.BuildMath)
local RthroRig = require(MP.RthroRig)

local Request = Instance.new("RemoteFunction")
Request.Name = "Request"
Request.Parent = MP

local store = DataStoreService:GetDataStore(Config.DataStoreName)
local sessions = {} -- [Player] = { Data, Loaded, Dirty, BaseDesc, Last }

---------------------------------------------------------------- persistence

local function newData()
	return { Version = Config.DataVersion, Slots = {}, Selected = 0 }
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function loadData(player)
	for attempt = 1, 4 do
		local ok, res = pcall(store.GetAsync, store, keyFor(player))
		if ok then
			local data = res or newData()
			data.Slots = data.Slots or {}
			data.Selected = data.Selected or 0
			return data, true
		end
		warn(("[MyPlayer] load failed for %s (try %d): %s"):format(player.Name, attempt, tostring(res)))
		task.wait(attempt)
	end
	return newData(), false -- never save over real data we couldn't read
end

local function saveSession(player)
	local s = sessions[player]
	if not s or not s.Loaded then
		return
	end
	for attempt = 1, 4 do
		local ok, err = pcall(store.SetAsync, store, keyFor(player), s.Data)
		if ok then
			s.Dirty = false
			return true
		end
		warn(("[MyPlayer] save failed for %s (try %d): %s"):format(player.Name, attempt, tostring(err)))
		task.wait(2 ^ attempt)
	end
	return false
end

---------------------------------------------------------------- applying builds

local function applyEquipped(player)
	local s = sessions[player]
	local char = player.Character
	if not (s and char) then
		return
	end
	local slot = s.Data.Selected
	local build = slot and slot > 0 and s.Data.Slots[tostring(slot)]
	if not build then
		return
	end
	task.spawn(function()
		if not s.BaseDesc then
			s.BaseDesc = RthroRig.FetchBaseDescription(player.UserId)
		end
		RthroRig.ApplyToCharacter(char, build, s.BaseDesc)
		if not char.Parent then
			return
		end

		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			local gs = BuildMath.GameplayStats(build)
			hum.UseJumpPower = false
			hum.WalkSpeed = gs.WalkSpeed
			hum.JumpHeight = gs.JumpHeight
		end

		-- Expose everything so your gameplay systems can read it.
		char:SetAttribute("MP_Name", build.Name)
		char:SetAttribute("MP_Number", build.Number)
		char:SetAttribute("MP_Position", build.Position)
		char:SetAttribute("MP_Archetype", build.Archetype)
		char:SetAttribute("MP_Overall", BuildMath.Overall(build))
		char:SetAttribute("MP_Height", build.Height)
		char:SetAttribute("MP_Weight", build.Weight)
		char:SetAttribute("MP_Wingspan", BuildMath.Wingspan(build))
		for key, v in pairs(build.Attributes) do
			char:SetAttribute("MP_" .. key, v)
		end
		for id, tier in pairs(build.Badges) do
			char:SetAttribute("MP_Badge_" .. id, tier)
		end
		char:SetAttribute("MP_TakeoverOffense", build.Takeovers.Offense)
		char:SetAttribute("MP_TakeoverDefense", build.Takeovers.Defense)
		-- the client waits on this to know the build is fully applied (used before the world cinematic)
		char:SetAttribute("MP_ApplyId", (char:GetAttribute("MP_ApplyId") or 0) + 1)
	end)
end

local function revertToOwnAvatar(player)
	local s = sessions[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (s and hum and s.BaseDesc) then
		return
	end
	task.spawn(function()
		pcall(function()
			hum:ApplyDescription(s.BaseDesc)
		end)
		for name in pairs(char:GetAttributes()) do
			if string.sub(name, 1, 3) == "MP_" then
				char:SetAttribute(name, nil)
			end
		end
	end)
end

---------------------------------------------------------------- helpers

local function slotKey(slot)
	if type(slot) == "number" and slot % 1 == 0 and slot >= 1 and slot <= Config.MaxSlots then
		return tostring(slot)
	end
	return nil
end

local function filterName(name, userId)
	local ok, result = pcall(function()
		local obj = TextService:FilterStringAsync(name, userId, Enum.TextFilterContext.PublicChat)
		return obj:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" and #result > 0 then
		return result
	end
	return nil
end

---------------------------------------------------------------- actions

local Actions = {}

function Actions.GetData(player, s)
	if not s.Loaded then
		return false, "Your data failed to load. Rejoin to edit builds."
	end
	return true, { Slots = s.Data.Slots, Selected = s.Data.Selected }
end

function Actions.Save(player, s, slot, raw, equip)
	if not s.Loaded then
		return false, "Data unavailable. Rejoin to save."
	end
	local key = slotKey(slot)
	if not key then
		return false, "Invalid slot"
	end

	local build, err = BuildMath.Sanitize(raw)
	if not build then
		return false, err
	end
	local ok, why = BuildMath.Validate(build)
	if not ok then
		return false, why
	end

	build.Name = filterName(build.Name, player.UserId)
	if not build.Name then
		return false, "That name couldn't be used. Try another."
	end

	local existing = s.Data.Slots[key]
	build.Created = existing and existing.Created or os.time()
	build.Updated = os.time()
	s.Data.Slots[key] = build
	s.Dirty = true

	if equip == true or s.Data.Selected == slot then
		s.Data.Selected = slot
		applyEquipped(player)
	end
	return true, build
end

function Actions.Delete(player, s, slot)
	local key = slotKey(slot)
	if not (s.Loaded and key and s.Data.Slots[key]) then
		return false, "Nothing to delete"
	end
	s.Data.Slots[key] = nil
	if s.Data.Selected == slot then
		s.Data.Selected = 0
		revertToOwnAvatar(player)
	end
	s.Dirty = true
	return true
end

function Actions.Select(player, s, slot)
	local key = slotKey(slot)
	if not (s.Loaded and key and s.Data.Slots[key]) then
		return false, "That slot is empty"
	end
	s.Data.Selected = slot
	s.Dirty = true
	applyEquipped(player)
	return true
end

function Actions.Duplicate(player, s, from, to)
	local fromKey, toKey = slotKey(from), slotKey(to)
	if not (s.Loaded and fromKey and toKey and s.Data.Slots[fromKey]) then
		return false, "Invalid slots"
	end
	if s.Data.Slots[toKey] then
		return false, "Target slot is not empty"
	end
	local copy = BuildMath.Clone(s.Data.Slots[fromKey])
	copy.Name = string.sub(copy.Name, 1, Config.Name.MaxLength - 5) .. " Copy"
	copy.Created, copy.Updated = os.time(), os.time()
	s.Data.Slots[toKey] = copy
	s.Dirty = true
	return true, copy
end

Request.OnServerInvoke = function(player, action, ...)
	local s = sessions[player]
	if not s then
		return false, "Still loading, try again"
	end
	if type(action) ~= "string" then
		return false, "Bad request"
	end
	local handler = Actions[action]
	if not handler then
		return false, "Unknown action"
	end
	if action ~= "GetData" then
		local now = os.clock()
		if now - s.Last < Config.RequestCooldown then
			return false, "Slow down"
		end
		s.Last = now
	end
	local ok, a, b = pcall(handler, player, s, ...)
	if not ok then
		warn("[MyPlayer] " .. action .. " errored: " .. tostring(a))
		return false, "Server error"
	end
	return a, b
end

---------------------------------------------------------------- lifecycle

local function onPlayerAdded(player)
	local s = { Data = newData(), Loaded = false, Dirty = false, Last = 0 }
	sessions[player] = s

	player.CharacterAdded:Connect(function()
		if s.Loaded then
			task.wait(0.5) -- let the default appearance load first
			applyEquipped(player)
		end
	end)

	local data, loaded = loadData(player)
	if not player.Parent then
		return
	end
	s.Data, s.Loaded = data, loaded
	if loaded and player.Character then
		applyEquipped(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	if sessions[player] and sessions[player].Dirty then
		saveSession(player)
	end
	sessions[player] = nil
end)

game:BindToClose(function()
	for player, s in pairs(sessions) do
		if s.Dirty then
			task.spawn(saveSession, player)
		end
	end
	task.wait(3)
end)

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for player, s in pairs(sessions) do
			if s.Dirty then
				task.spawn(saveSession, player)
			end
		end
	end
end)
