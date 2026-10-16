--[[
	Positions (height limits + Overall weights) and Archetypes.
	An archetype ranks attributes as Primary / Secondary / Weak (everything else is Normal),
	which sets each attribute's starting value and cap (see Config.Bases / Config.Caps).
	It also sets badge-point caps per category and which takeovers it can equip.
]]

local Archetypes = {}

Archetypes.PositionOrder = { "PG", "SG", "SF", "PF", "C" }

Archetypes.Positions = {
	PG = {
		Name = "Point Guard", HeightMin = 66, HeightMax = 80,
		Weights = {
			BallHandle = 3, SpeedWithBall = 2, PassAccuracy = 2.5, PassIQ = 1.5, PassVision = 1.5,
			ThreePointShot = 2.5, MidRangeShot = 1.5, DrivingLayup = 1.5, ShotIQ = 1, Speed = 1.5,
			Agility = 1, LateralQuickness = 1, PerimeterDefense = 1, Steal = 1, FreeThrow = 0.5,
		},
	},
	SG = {
		Name = "Shooting Guard", HeightMin = 70, HeightMax = 82,
		Weights = {
			ThreePointShot = 3, MidRangeShot = 2.5, BallHandle = 1.5, DrivingLayup = 1.5, DrivingDunk = 1,
			ShotIQ = 1, OffensiveConsistency = 1, PerimeterDefense = 1.5, Steal = 0.8, Speed = 1.5,
			Agility = 1, LateralQuickness = 1, PassAccuracy = 1, Vertical = 0.8,
		},
	},
	SF = {
		Name = "Small Forward", HeightMin = 74, HeightMax = 84,
		Weights = {
			ThreePointShot = 2, MidRangeShot = 2, DrivingLayup = 1.5, DrivingDunk = 1.5, CloseShot = 1,
			PerimeterDefense = 1.5, InteriorDefense = 0.8, Speed = 1, Vertical = 1.2, Strength = 1,
			DefensiveRebound = 1, BallHandle = 1, ShotIQ = 1, Steal = 0.8,
		},
	},
	PF = {
		Name = "Power Forward", HeightMin = 77, HeightMax = 87,
		Weights = {
			CloseShot = 2, StandingDunk = 1.5, DrivingDunk = 1, PostControl = 1.5, MidRangeShot = 1,
			ThreePointShot = 1, InteriorDefense = 2, Block = 1.5, DefensiveRebound = 2, OffensiveRebound = 1.5,
			Strength = 2, Vertical = 1.2, HelpDefenseIQ = 1, Speed = 0.5,
		},
	},
	C = {
		Name = "Center", HeightMin = 80, HeightMax = 90,
		Weights = {
			CloseShot = 2, StandingDunk = 2.5, PostControl = 2, InteriorDefense = 3, Block = 2.5,
			DefensiveRebound = 2.5, OffensiveRebound = 2, Strength = 2.5, Vertical = 1, HelpDefenseIQ = 1.2,
			FreeThrow = 0.3, Hustle = 0.5,
		},
	},
}

Archetypes.List = {}
Archetypes.ById = {}

-- badgeCaps = { Finishing, Shooting, Playmaking, Defense }
local function A(id, name, positions, primary, secondary, weak, badgeCaps, offense, defense, desc)
	local tier = {}
	for _, k in ipairs(weak) do tier[k] = "Weak" end
	for _, k in ipairs(secondary) do tier[k] = "Secondary" end
	for _, k in ipairs(primary) do tier[k] = "Primary" end
	local a = {
		Id = id, Name = name, Positions = positions, Tier = tier, Description = desc,
		BadgeCaps = { Finishing = badgeCaps[1], Shooting = badgeCaps[2], Playmaking = badgeCaps[3], Defense = badgeCaps[4] },
		Takeovers = { Offense = offense, Defense = defense },
	}
	table.insert(Archetypes.List, a)
	Archetypes.ById[id] = a
end

A("PlaymakingShotCreator", "Playmaking Shot Creator", { "PG", "SG" },
	{ "BallHandle", "SpeedWithBall", "ThreePointShot", "PassAccuracy" },
	{ "MidRangeShot", "PassIQ", "PassVision", "Speed", "Agility", "ShotIQ", "DrivingLayup", "FreeThrow" },
	{ "StandingDunk", "Block", "InteriorDefense", "PostControl", "OffensiveRebound", "DefensiveRebound" },
	{ 14, 26, 34, 12 }, { "Playmaker", "Sharpshooter" }, { "Lockdown" },
	"Elite handle and shot creation while running the offense.")

A("SharpshootingPlaymaker", "Sharpshooting Playmaker", { "PG", "SG" },
	{ "ThreePointShot", "MidRangeShot", "PassAccuracy", "BallHandle" },
	{ "ShotIQ", "OffensiveConsistency", "FreeThrow", "PassIQ", "PassVision", "SpeedWithBall" },
	{ "StandingDunk", "Block", "InteriorDefense", "PostControl", "DrivingDunk" },
	{ 10, 34, 30, 10 }, { "Sharpshooter", "Playmaker" }, { "Lockdown" },
	"A deadly shooter who can also set the table.")

A("SlashingPlaymaker", "Slashing Playmaker", { "PG", "SG", "SF" },
	{ "DrivingLayup", "DrivingDunk", "BallHandle", "SpeedWithBall", "Speed" },
	{ "PassAccuracy", "Agility", "Vertical", "CloseShot", "LateralQuickness", "Steal" },
	{ "StandingDunk", "PostControl", "Block", "InteriorDefense" },
	{ 32, 14, 28, 14 }, { "Slasher", "Playmaker" }, { "Lockdown" },
	"Attacks the rim and creates for others off the dribble.")

A("ThreeLevelScorer", "Three-Level Scorer", { "SG", "SF" },
	{ "ThreePointShot", "MidRangeShot", "CloseShot", "DrivingLayup" },
	{ "ShotIQ", "OffensiveConsistency", "BallHandle", "DrivingDunk", "FreeThrow", "Vertical" },
	{ "Block", "InteriorDefense", "PostControl", "StandingDunk" },
	{ 22, 30, 16, 10 }, { "Sharpshooter", "Slasher" }, { "Lockdown" },
	"Scores from the rim, mid-range and three with equal comfort.")

A("Sharpshooter", "Sharpshooter", { "SG", "SF" },
	{ "ThreePointShot", "MidRangeShot", "FreeThrow", "ShotIQ" },
	{ "OffensiveConsistency", "BallHandle", "PerimeterDefense", "Speed", "PassAccuracy" },
	{ "Block", "InteriorDefense", "PostControl", "StandingDunk", "OffensiveRebound" },
	{ 8, 40, 14, 12 }, { "Sharpshooter" }, { "Lockdown" },
	"Pure shooting. Space the floor and punish closeouts.")

A("Slasher", "Slasher", { "SG", "SF" },
	{ "DrivingDunk", "DrivingLayup", "Vertical", "Speed", "Agility" },
	{ "BallHandle", "CloseShot", "Strength", "Steal", "PerimeterDefense", "SpeedWithBall" },
	{ "PostControl", "Block", "InteriorDefense" },
	{ 38, 14, 12, 14 }, { "Slasher" }, { "Lockdown" },
	"Explosive athlete who lives at the rim.")

A("ThreeAndDWing", "3&D Wing", { "SG", "SF" },
	{ "ThreePointShot", "PerimeterDefense", "Steal", "LateralQuickness" },
	{ "PassPerception", "DefensiveConsistency", "HelpDefenseIQ", "Speed", "Agility", "ShotIQ", "Hustle", "Stamina" },
	{ "PostControl", "StandingDunk", "Block" },
	{ 10, 26, 8, 36 }, { "Sharpshooter" }, { "Lockdown" },
	"Knocks down threes and guards the other team's best wing.")

A("LockdownDefender", "Lockdown Defender", { "SG", "SF", "PF" },
	{ "PerimeterDefense", "Steal", "LateralQuickness", "PassPerception" },
	{ "DefensiveConsistency", "HelpDefenseIQ", "Strength", "Hustle", "Speed", "Vertical", "Block" },
	{ "BallHandle", "SpeedWithBall", "PostControl", "StandingDunk" },
	{ 12, 14, 8, 40 }, { "Slasher" }, { "Lockdown", "Rebounder" },
	"Defense first: smothers ball handlers and jumps passing lanes.")

A("AthleticFinisher", "Athletic Finisher", { "SF", "PF" },
	{ "DrivingDunk", "StandingDunk", "Vertical", "Strength", "CloseShot" },
	{ "Speed", "DrivingLayup", "OffensiveRebound", "Block", "InteriorDefense", "Hustle", "Agility" },
	{ "ThreePointShot", "BallHandle", "SpeedWithBall", "PassIQ" },
	{ 40, 8, 6, 22 }, { "Slasher", "PostScorer" }, { "RimProtector", "Rebounder" },
	"Above-the-rim forward who finishes everything.")

A("PointForward", "Point Forward", { "SF", "PF" },
	{ "PassAccuracy", "BallHandle", "PassIQ", "PassVision" },
	{ "ThreePointShot", "MidRangeShot", "DrivingLayup", "ShotIQ", "DefensiveRebound", "Strength" },
	{ "StandingDunk", "Block", "InteriorDefense" },
	{ 16, 20, 38, 14 }, { "Playmaker", "Slasher" }, { "Rebounder", "Lockdown" },
	"A big wing who initiates the offense.")

A("StretchBig", "Stretch Big", { "PF", "C" },
	{ "ThreePointShot", "MidRangeShot", "FreeThrow", "ShotIQ", "DefensiveRebound" },
	{ "OffensiveConsistency", "CloseShot", "PassAccuracy", "Block", "InteriorDefense", "HelpDefenseIQ" },
	{ "BallHandle", "SpeedWithBall", "Speed", "LateralQuickness", "Agility" },
	{ 12, 34, 10, 22 }, { "Sharpshooter" }, { "RimProtector", "Rebounder" },
	"Spaces the floor from the big spot.")

A("PostScorer", "Post Scorer", { "PF", "C" },
	{ "PostControl", "CloseShot", "StandingDunk", "Strength" },
	{ "OffensiveRebound", "InteriorDefense", "DefensiveRebound", "ShotIQ", "FreeThrow", "MidRangeShot" },
	{ "ThreePointShot", "BallHandle", "SpeedWithBall", "Speed", "LateralQuickness" },
	{ 40, 14, 8, 20 }, { "PostScorer" }, { "RimProtector", "Rebounder" },
	"Old-school back-to-the-basket scorer.")

A("RimProtector", "Rim Protector", { "PF", "C" },
	{ "Block", "InteriorDefense", "DefensiveRebound", "HelpDefenseIQ" },
	{ "StandingDunk", "Strength", "OffensiveRebound", "Vertical", "CloseShot", "DefensiveConsistency", "Hustle" },
	{ "ThreePointShot", "BallHandle", "SpeedWithBall", "Speed", "LateralQuickness", "Agility" },
	{ 14, 4, 4, 44 }, { "PostScorer" }, { "RimProtector" },
	"Anchors the paint and erases shots.")

A("GlassCleaner", "Glass Cleaner", { "PF", "C" },
	{ "DefensiveRebound", "OffensiveRebound", "Strength", "Hustle" },
	{ "InteriorDefense", "Block", "StandingDunk", "CloseShot", "Vertical", "Stamina", "PostControl" },
	{ "ThreePointShot", "BallHandle", "SpeedWithBall", "Speed" },
	{ 24, 4, 4, 38 }, { "PostScorer" }, { "Rebounder", "RimProtector" },
	"Owns the boards and the second chance.")

A("PointCenter", "Point Center", { "PF", "C" },
	{ "PassAccuracy", "PassIQ", "PassVision", "CloseShot" },
	{ "PostControl", "InteriorDefense", "DefensiveRebound", "BallHandle", "ShotIQ", "MidRangeShot", "Strength" },
	{ "SpeedWithBall", "Speed", "LateralQuickness", "ThreePointShot" },
	{ 18, 14, 36, 18 }, { "Playmaker", "PostScorer" }, { "RimProtector" },
	"A big who runs the offense from the elbow.")

function Archetypes.ForPosition(position)
	local out = {}
	for _, a in ipairs(Archetypes.List) do
		if table.find(a.Positions, position) then
			table.insert(out, a)
		end
	end
	return out
end

function Archetypes.Default(position)
	return Archetypes.ForPosition(position)[1]
end

return Archetypes
