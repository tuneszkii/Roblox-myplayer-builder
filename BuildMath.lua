--[[
	BuildMath: everything rules-related. Used by the client (live UI) AND the server (authoritative validation).

	Build shape (JSON-safe, this is what gets saved):
	{
		Name = "Player", Number = 23,
		Position = "PG", Archetype = "PlaymakingShotCreator",
		Height = 78 (in), WingspanOffset = 2 (in over height), Weight = 210 (lbs),
		SkinTone = 3,
		Attributes = { CloseShot = 45, ... },
		Badges = { Deadeye = 3, ... },            -- tier 1..5
		Takeovers = { Offense = "Playmaker", Defense = "Lockdown" },
		Created = os.time(), Updated = os.time(),
	}
]]

local Config = require(script.Parent.Config)
local Attributes = require(script.Parent.Attributes)
local Archetypes = require(script.Parent.Archetypes)
local Badges = require(script.Parent.Badges)
local Takeovers = require(script.Parent.Takeovers)

local BuildMath = {}

local function clamp(v, a, b)
	return math.max(a, math.min(b, v))
end

local function toInt(v)
	return math.floor(v + 0.5)
end

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = deepCopy(v)
	end
	return c
end

BuildMath.Clone = deepCopy

---------------------------------------------------------------- physicals

function BuildMath.FormatHeight(inches)
	inches = toInt(inches)
	return string.format("%d'%d\"", inches // 12, inches % 12)
end

function BuildMath.WeightRange(height)
	local W = Config.Weight
	local d = height - W.RefHeight
	return toInt(W.MinBase + d * W.MinPerInch), toInt(W.MaxBase + d * W.MaxPerInch)
end

function BuildMath.Wingspan(build)
	return build.Height + build.WingspanOffset
end

-- Shift applied to an attribute's base/cap by the build's body.
function BuildMath.PhysicalMod(build, key)
	local p = Attributes.ByKey[key].Physical
	local h = build.Height - Config.Height.Default
	local wing = build.WingspanOffset - Config.Wingspan.DefaultOffset
	local wMin, wMax = BuildMath.WeightRange(build.Height)
	local wt = (build.Weight - (wMin + wMax) / 2) / 10
	return (p.h or 0) * h + (p.wing or 0) * wing + (p.wt or 0) * wt
end

---------------------------------------------------------------- attributes

function BuildMath.GetBase(build, key)
	local arch = Archetypes.ById[build.Archetype]
	local tier = arch.Tier[key] or "Normal"
	local v = Config.Bases[tier] + BuildMath.PhysicalMod(build, key) * 0.5
	return clamp(toInt(v), Config.Attribute.Floor, Config.Attribute.Ceiling)
end

function BuildMath.GetCap(build, key)
	local arch = Archetypes.ById[build.Archetype]
	local tier = arch.Tier[key] or "Normal"
	local v = Config.Caps[tier] + BuildMath.PhysicalMod(build, key)
	v = clamp(toInt(v), 40, Config.Attribute.Ceiling)
	return math.max(v, BuildMath.GetBase(build, key))
end

-- Points needed to raise an attribute from `from` to `to`.
function BuildMath.PointCost(from, to)
	local cost = 0
	for v = from, to - 1 do
		for _, tier in ipairs(Config.PointTiers) do
			if v < tier[1] then
				cost += tier[2]
				break
			end
		end
	end
	return cost
end

function BuildMath.AttributePointsSpent(build)
	local spent = 0
	for _, a in ipairs(Attributes.List) do
		local v = build.Attributes[a.Key]
		local base = BuildMath.GetBase(build, a.Key)
		if v and v > base then
			spent += BuildMath.PointCost(base, v)
		end
	end
	return spent
end

function BuildMath.Overall(build)
	local pos = Archetypes.Positions[build.Position]
	local sum, wsum = 0, 0
	for key, w in pairs(pos.Weights) do
		sum += (build.Attributes[key] or Config.Attribute.Floor) * w
		wsum += w
	end
	local O = Config.Overall
	local avg = sum / wsum
	return clamp(toInt(O.Offset + (avg - O.AvgFloor) * O.Slope), O.Min, O.Max)
end

---------------------------------------------------------------- badges

-- Returns total points and points per category.
function BuildMath.BadgePoints(build)
	local per, total = {}, 0
	for _, c in ipairs(Badges.Categories) do
		per[c] = 0
	end
	for id, tier in pairs(build.Badges) do
		local b = Badges.ById[id]
		if b then
			per[b.Category] += tier
			total += tier
		end
	end
	return total, per
end

-- ok, reasonString
function BuildMath.BadgeRequirementMet(build, id, tier)
	local b = Badges.ById[id]
	local missing = {}
	if b.MinHeight and build.Height < b.MinHeight then
		table.insert(missing, "Height " .. BuildMath.FormatHeight(b.MinHeight) .. "+")
	end
	if b.MaxHeight and build.Height > b.MaxHeight then
		table.insert(missing, "Height " .. BuildMath.FormatHeight(b.MaxHeight) .. " or under")
	end
	for attr, base in pairs(b.Reqs) do
		local need = Badges.Threshold(base, tier)
		if (build.Attributes[attr] or 0) < need then
			table.insert(missing, Attributes.ByKey[attr].Name .. " " .. need)
		end
	end
	if #missing > 0 then
		table.sort(missing)
		return false, "Needs " .. table.concat(missing, ", ")
	end
	return true
end

-- Can this badge be set to `tier` right now (requirements + point budgets)?
function BuildMath.BadgeCanSet(build, id, tier)
	if tier <= 0 then
		return true
	end
	local ok, why = BuildMath.BadgeRequirementMet(build, id, tier)
	if not ok then
		return false, why
	end
	local b = Badges.ById[id]
	local current = build.Badges[id] or 0
	local total, per = BuildMath.BadgePoints(build)
	local cap = Archetypes.ById[build.Archetype].BadgeCaps[b.Category]
	if per[b.Category] - current + tier > cap then
		return false, b.Category .. " badge points full (" .. cap .. ")"
	end
	if total - current + tier > Config.BadgePointsTotal then
		return false, "Out of total badge points"
	end
	return true
end

---------------------------------------------------------------- takeovers

function BuildMath.TakeoverAvailable(build, id)
	local t = Takeovers.ById[id]
	if not t then
		return false, "Unknown takeover"
	end
	local arch = Archetypes.ById[build.Archetype]
	if not table.find(arch.Takeovers[t.Side], id) then
		return false, "Not available for this archetype"
	end
	local need = t.Requires
	if (build.Attributes[need.Attribute] or 0) < need.Min then
		return false, "Needs " .. Attributes.ByKey[need.Attribute].Name .. " " .. need.Min
	end
	return true
end

---------------------------------------------------------------- building / normalizing

function BuildMath.New(name, position, archetypeId)
	local pos = Archetypes.Positions[position]
	local height = clamp(Config.Height.Default, pos.HeightMin, pos.HeightMax)
	local wMin, wMax = BuildMath.WeightRange(height)
	local build = {
		Name = name,
		Number = 0,
		Position = position,
		Archetype = archetypeId,
		Height = height,
		WingspanOffset = Config.Wingspan.DefaultOffset,
		Weight = toInt(wMin + (wMax - wMin) * 0.45),
		SkinTone = 3,
		Attributes = {},
		Badges = {},
		Takeovers = {},
	}
	BuildMath.Normalize(build)
	return build
end

-- Switching archetype resets attributes, badges and takeovers (like 2K).
function BuildMath.ApplyArchetype(build, archetypeId)
	build.Archetype = archetypeId
	build.Attributes, build.Badges, build.Takeovers = {}, {}, {}
	BuildMath.Normalize(build)
end

-- Clamp everything back into legal territory (in place). Call after any change.
function BuildMath.Normalize(build)
	local arch = Archetypes.ById[build.Archetype]
	local pos = Archetypes.Positions[build.Position]

	build.Height = clamp(toInt(build.Height), pos.HeightMin, pos.HeightMax)
	build.WingspanOffset = clamp(toInt(build.WingspanOffset), Config.Wingspan.MinOffset, Config.Wingspan.MaxOffset)
	local wMin, wMax = BuildMath.WeightRange(build.Height)
	build.Weight = clamp(toInt(build.Weight), wMin, wMax)

	for _, a in ipairs(Attributes.List) do
		local base, cap = BuildMath.GetBase(build, a.Key), BuildMath.GetCap(build, a.Key)
		build.Attributes[a.Key] = clamp(toInt(build.Attributes[a.Key] or base), base, cap)
	end

	-- Over budget (e.g. body change raised a base)? Shave the highest attributes first.
	while BuildMath.AttributePointsSpent(build) > Config.AttributePoints do
		local worstKey, worstVal
		for key, v in pairs(build.Attributes) do
			if v > BuildMath.GetBase(build, key) and (not worstVal or v > worstVal) then
				worstKey, worstVal = key, v
			end
		end
		if not worstKey then
			break
		end
		build.Attributes[worstKey] -= 1
	end

	-- Badges: drop tiers that no longer meet requirements or budgets.
	local ids = {}
	for id in pairs(build.Badges) do
		table.insert(ids, id)
	end
	table.sort(ids)
	local newBadges, total, per = {}, 0, {}
	for _, c in ipairs(Badges.Categories) do
		per[c] = 0
	end
	for _, id in ipairs(ids) do
		local b = Badges.ById[id]
		if b then
			local tier = math.min(#Config.BadgeTiers, toInt(build.Badges[id]))
			while tier > 0 do
				local ok = BuildMath.BadgeRequirementMet(build, id, tier)
				if ok and per[b.Category] + tier <= arch.BadgeCaps[b.Category] and total + tier <= Config.BadgePointsTotal then
					break
				end
				tier -= 1
			end
			if tier > 0 then
				newBadges[id] = tier
				per[b.Category] += tier
				total += tier
			end
		end
	end
	build.Badges = newBadges

	for side, id in pairs(table.clone(build.Takeovers)) do
		local t = Takeovers.ById[id]
		if not t or t.Side ~= side or not BuildMath.TakeoverAvailable(build, id) then
			build.Takeovers[side] = nil
		end
	end
end

---------------------------------------------------------------- server-side sanitizing / validation

local function num(v)
	if type(v) == "number" and v == v and math.abs(v) < 1e6 then
		return v
	end
	return nil
end

-- Copies only known fields out of untrusted data. Returns build or nil, err.
function BuildMath.Sanitize(raw)
	if type(raw) ~= "table" then
		return nil, "Invalid build"
	end
	if type(raw.Name) ~= "string" or type(raw.Position) ~= "string" or type(raw.Archetype) ~= "string" then
		return nil, "Invalid build"
	end
	if not Archetypes.Positions[raw.Position] or not Archetypes.ById[raw.Archetype] then
		return nil, "Unknown position or archetype"
	end
	local height, wing, weight = num(raw.Height), num(raw.WingspanOffset), num(raw.Weight)
	if not (height and wing and weight) then
		return nil, "Invalid physicals"
	end
	local name = (string.gsub(raw.Name, "^%s*(.-)%s*$", "%1"))
	local b = {
		Name = string.sub(name, 1, Config.Name.MaxLength),
		Number = clamp(toInt(num(raw.Number) or 0), Config.JerseyNumber.Min, Config.JerseyNumber.Max),
		Position = raw.Position,
		Archetype = raw.Archetype,
		Height = toInt(height),
		WingspanOffset = toInt(wing),
		Weight = toInt(weight),
		SkinTone = clamp(toInt(num(raw.SkinTone) or 1), 1, #Config.SkinTones),
		Attributes = {},
		Badges = {},
		Takeovers = {},
	}
	local rawAttrs = type(raw.Attributes) == "table" and raw.Attributes or {}
	for _, a in ipairs(Attributes.List) do
		local v = num(rawAttrs[a.Key])
		if not v then
			return nil, "Missing attribute " .. a.Name
		end
		b.Attributes[a.Key] = toInt(v)
	end
	if type(raw.Badges) == "table" then
		for id, tier in pairs(raw.Badges) do
			tier = num(tier)
			if type(id) == "string" and Badges.ById[id] and tier and tier == math.floor(tier) and tier >= 1 and tier <= #Config.BadgeTiers then
				b.Badges[id] = tier
			end
		end
	end
	if type(raw.Takeovers) == "table" then
		for side, id in pairs(raw.Takeovers) do
			if (side == "Offense" or side == "Defense") and type(id) == "string" and Takeovers.ById[id] then
				b.Takeovers[side] = id
			end
		end
	end
	return b
end

-- Strict check (no silent fixing). Returns ok, reason.
function BuildMath.Validate(b)
	local arch = Archetypes.ById[b.Archetype]
	local pos = Archetypes.Positions[b.Position]
	if not (arch and pos) then
		return false, "Unknown position or archetype"
	end
	if not table.find(arch.Positions, b.Position) then
		return false, "That archetype isn't available at this position"
	end
	if #b.Name < Config.Name.MinLength or #b.Name > Config.Name.MaxLength or string.find(b.Name, "%c") then
		return false, "Name must be " .. Config.Name.MinLength .. "-" .. Config.Name.MaxLength .. " characters"
	end
	if b.Height < pos.HeightMin or b.Height > pos.HeightMax then
		return false, "Height is out of range for this position"
	end
	if b.WingspanOffset < Config.Wingspan.MinOffset or b.WingspanOffset > Config.Wingspan.MaxOffset then
		return false, "Wingspan is out of range"
	end
	local wMin, wMax = BuildMath.WeightRange(b.Height)
	if b.Weight < wMin or b.Weight > wMax then
		return false, "Weight is out of range for this height"
	end
	for _, a in ipairs(Attributes.List) do
		local v = b.Attributes[a.Key]
		if v < BuildMath.GetBase(b, a.Key) or v > BuildMath.GetCap(b, a.Key) then
			return false, a.Name .. " is outside its allowed range"
		end
	end
	if BuildMath.AttributePointsSpent(b) > Config.AttributePoints then
		return false, "Too many attribute points spent"
	end
	local total, per = BuildMath.BadgePoints(b)
	if total > Config.BadgePointsTotal then
		return false, "Too many badge points"
	end
	for _, c in ipairs(Badges.Categories) do
		if per[c] > arch.BadgeCaps[c] then
			return false, c .. " badge points exceed this archetype's limit"
		end
	end
	for id, tier in pairs(b.Badges) do
		local ok, why = BuildMath.BadgeRequirementMet(b, id, tier)
		if not ok then
			return false, Badges.ById[id].Name .. ": " .. why
		end
	end
	for side, id in pairs(b.Takeovers) do
		local t = Takeovers.ById[id]
		if not t or t.Side ~= side then
			return false, "Invalid takeover"
		end
		local ok, why = BuildMath.TakeoverAvailable(b, id)
		if not ok then
			return false, t.Name .. ": " .. why
		end
	end
	return true
end

---------------------------------------------------------------- rig + gameplay helpers

function BuildMath.RigScales(build)
	local S = Config.Scale
	local wMin, wMax = BuildMath.WeightRange(build.Height)
	local t = (build.Weight - wMin) / math.max(1, wMax - wMin)
	return {
		Height = S.HeightScaleAtDefault * build.Height / Config.Height.Default,
		Width = S.Width.Min + (S.Width.Max - S.Width.Min) * t,
		Depth = S.Depth.Min + (S.Depth.Max - S.Depth.Min) * t,
		Head = S.HeadScale,
	}
end

-- Multiplier for upper+lower arm length so total wingspan matches the build.
function BuildMath.ArmFactor(build)
	local shoulders = 0.26 * build.Height
	local span = build.Height + build.WingspanOffset
	local default = build.Height + Config.Wingspan.DefaultOffset
	return math.max(0.5, (span - shoulders) / (default - shoulders))
end

function BuildMath.GameplayStats(build)
	local G = Config.Gameplay
	local function lerp(r, a)
		return r[1] + (r[2] - r[1]) * a
	end
	local floor = Config.Attribute.Floor
	local range = Config.Attribute.Ceiling - floor
	return {
		WalkSpeed = lerp(G.WalkSpeed, (build.Attributes.Speed - floor) / range),
		JumpHeight = lerp(G.JumpHeight, (build.Attributes.Vertical - floor) / range),
	}
end

---------------------------------------------------------------- presentation helpers

function BuildMath.OverallTier(ovr)
	for _, t in ipairs(Config.OverallTiers) do
		if ovr >= t.Min then
			return t
		end
	end
	return Config.OverallTiers[#Config.OverallTiers]
end

function BuildMath.CategoryAverages(build)
	local out = {}
	for _, cat in ipairs(Attributes.Categories) do
		local sum, n = 0, 0
		for _, a in ipairs(Attributes.ByCategory[cat]) do
			sum += build.Attributes[a.Key] or 0
			n += 1
		end
		out[cat] = sum / math.max(1, n)
	end
	return out
end

local GRADES = { { 80, "A+" }, { 72, "A" }, { 65, "A-" }, { 58, "B+" }, { 52, "B" }, { 46, "B-" }, { 40, "C+" }, { 0, "C" } }

function BuildMath.Grade(avg)
	for _, g in ipairs(GRADES) do
		if avg >= g[1] then
			return g[2]
		end
	end
	return "C"
end

function BuildMath.TopAttributes(build, n)
	local list = {}
	for _, a in ipairs(Attributes.List) do
		table.insert(list, { Attribute = a, Value = build.Attributes[a.Key] })
	end
	table.sort(list, function(x, y)
		if x.Value ~= y.Value then
			return x.Value > y.Value
		end
		return x.Attribute.Order < y.Attribute.Order
	end)
	return table.move(list, 1, math.min(n, #list), 1, {})
end

-- counts[tier] = number of badges equipped at that tier
function BuildMath.BadgeTierCounts(build)
	local counts = {}
	for t = 1, #Config.BadgeTiers do
		counts[t] = 0
	end
	for _, tier in pairs(build.Badges) do
		counts[tier] += 1
	end
	return counts
end

return BuildMath
