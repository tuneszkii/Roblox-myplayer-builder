--[[
	Takeovers. A build equips up to one Offense and one Defense takeover.
	Which ones are selectable depends on the archetype, and each has an attribute requirement.
	Boosts are the temporary attribute bonuses you apply in-game while the takeover is active.
]]

local Takeovers = { List = {}, ById = {} }

local function T(id, side, name, desc, requires, boosts, duration)
	local t = {
		Id = id, Side = side, Name = name, Description = desc,
		Requires = requires, Boosts = boosts, Duration = duration or 25,
	}
	table.insert(Takeovers.List, t)
	Takeovers.ById[id] = t
end

T("Sharpshooter", "Offense", "Sharpshooter", "Shooting boost and wider green windows while active.",
	{ Attribute = "ThreePointShot", Min = 75 },
	{ ThreePointShot = 6, MidRangeShot = 5, ShotIQ = 5, OffensiveConsistency = 5 })

T("Slasher", "Offense", "Slasher", "Explosive drives and stronger finishes at the rim.",
	{ Attribute = "DrivingLayup", Min = 75 },
	{ DrivingLayup = 6, DrivingDunk = 6, Speed = 3, Agility = 3, Vertical = 3 })

T("Playmaker", "Offense", "Playmaker", "Tighter handle and sharper passing.",
	{ Attribute = "PassAccuracy", Min = 75 },
	{ PassAccuracy = 6, BallHandle = 5, SpeedWithBall = 5, PassIQ = 5 })

T("PostScorer", "Offense", "Post Scorer", "Dominant back-down game and paint scoring.",
	{ Attribute = "PostControl", Min = 75 },
	{ PostControl = 6, CloseShot = 5, StandingDunk = 5, Strength = 4 })

T("Lockdown", "Defense", "Lockdown", "Smothering perimeter defense and quicker hands.",
	{ Attribute = "PerimeterDefense", Min = 75 },
	{ PerimeterDefense = 6, Steal = 5, LateralQuickness = 5, PassPerception = 4 })

T("RimProtector", "Defense", "Rim Protector", "Erases shots at the rim and discourages drives.",
	{ Attribute = "Block", Min = 75 },
	{ Block = 6, InteriorDefense = 6, Vertical = 3, HelpDefenseIQ = 4 })

T("Rebounder", "Defense", "Rebounder", "Pursues every board with extra strength and hustle.",
	{ Attribute = "DefensiveRebound", Min = 75 },
	{ DefensiveRebound = 6, OffensiveRebound = 6, Strength = 3, Hustle = 4 })

return Takeovers
