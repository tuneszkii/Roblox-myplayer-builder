--[[
	Attribute definitions.
	Physical coefficients shift an attribute's base AND cap:
	  h    = per inch above/below 6'6"
	  wing = per inch of wingspan above/below the default (+2")
	  wt   = per 10 lbs above/below the mid weight for that height
]]

local Attributes = {}

Attributes.Categories = { "Finishing", "Shooting", "Playmaking", "Defense", "Rebounding", "Athleticism" }

local RAW = {
	-- Finishing
	{ "CloseShot", "Close Shot", "Finishing", { h = 0.2 } },
	{ "DrivingLayup", "Driving Layup", "Finishing", { h = -0.4, wt = -0.3 } },
	{ "DrivingDunk", "Driving Dunk", "Finishing", { h = 0.3, wing = 0.5, wt = -0.1 } },
	{ "StandingDunk", "Standing Dunk", "Finishing", { h = 1.0, wing = 0.8, wt = 0.3 } },
	{ "PostControl", "Post Control", "Finishing", { h = 0.4, wt = 0.8 } },
	-- Shooting
	{ "MidRangeShot", "Mid-Range Shot", "Shooting", { h = -0.2 } },
	{ "ThreePointShot", "Three-Point Shot", "Shooting", { h = -0.4, wt = -0.1 } },
	{ "FreeThrow", "Free Throw", "Shooting", {} },
	{ "ShotIQ", "Shot IQ", "Shooting", {} },
	{ "OffensiveConsistency", "Offensive Consistency", "Shooting", {} },
	-- Playmaking
	{ "PassAccuracy", "Pass Accuracy", "Playmaking", { h = -0.2 } },
	{ "BallHandle", "Ball Handle", "Playmaking", { h = -0.8, wt = -0.3 } },
	{ "SpeedWithBall", "Speed With Ball", "Playmaking", { h = -0.9, wt = -0.5 } },
	{ "PassIQ", "Pass IQ", "Playmaking", {} },
	{ "PassVision", "Pass Vision", "Playmaking", {} },
	-- Defense
	{ "InteriorDefense", "Interior Defense", "Defense", { h = 0.7, wing = 0.8, wt = 0.7 } },
	{ "PerimeterDefense", "Perimeter Defense", "Defense", { h = -0.5, wt = -0.3 } },
	{ "Steal", "Steal", "Defense", { h = -0.3, wing = 0.5 } },
	{ "Block", "Block", "Defense", { h = 0.8, wing = 1.0 } },
	{ "LateralQuickness", "Lateral Quickness", "Defense", { h = -1.0, wt = -0.8 } },
	{ "HelpDefenseIQ", "Help Defense IQ", "Defense", {} },
	{ "PassPerception", "Pass Perception", "Defense", {} },
	{ "DefensiveConsistency", "Defensive Consistency", "Defense", {} },
	-- Rebounding
	{ "OffensiveRebound", "Offensive Rebound", "Rebounding", { h = 0.6, wing = 0.6, wt = 0.5 } },
	{ "DefensiveRebound", "Defensive Rebound", "Rebounding", { h = 0.6, wing = 0.6, wt = 0.5 } },
	-- Athleticism
	{ "Speed", "Speed", "Athleticism", { h = -0.9, wt = -0.7 } },
	{ "Agility", "Agility", "Athleticism", { h = -1.0, wing = -0.2, wt = -0.8 } },
	{ "Strength", "Strength", "Athleticism", { h = 0.4, wt = 1.4 } },
	{ "Vertical", "Vertical", "Athleticism", { h = -0.5, wing = 0.3, wt = -0.5 } },
	{ "Stamina", "Stamina", "Athleticism", { wt = -0.4 } },
	{ "Hustle", "Hustle", "Athleticism", {} },
	{ "OverallDurability", "Overall Durability", "Athleticism", { wt = 0.3 } },
}

Attributes.List = {}
Attributes.ByKey = {}
Attributes.ByCategory = {}
for _, c in ipairs(Attributes.Categories) do
	Attributes.ByCategory[c] = {}
end
for i, r in ipairs(RAW) do
	local a = { Key = r[1], Name = r[2], Category = r[3], Physical = r[4], Order = i }
	table.insert(Attributes.List, a)
	Attributes.ByKey[a.Key] = a
	table.insert(Attributes.ByCategory[a.Category], a)
end

return Attributes
