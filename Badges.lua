--[[
	Badge definitions. Each badge has 5 tiers (Bronze..Legend).
	Reqs = { AttributeKey = baseRequirement }. Tier t needs base + Config.BadgeTierOffsets[t] (max 99).
	Opts: MinHeight / MaxHeight in inches.
	Gameplay effects are NOT implemented here - the equipped badges are exposed as character
	attributes ("MP_Badge_<Id>" = tier) so your game systems can read them.
]]

local Config = require(script.Parent.Config)

local Badges = {
	Categories = { "Finishing", "Shooting", "Playmaking", "Defense" },
	List = {},
	ById = {},
	ByCategory = { Finishing = {}, Shooting = {}, Playmaking = {}, Defense = {} },
}

local function make(cat)
	return function(id, name, desc, reqs, opts)
		opts = opts or {}
		local b = {
			Id = id, Name = name, Category = cat, Description = desc, Reqs = reqs,
			MinHeight = opts.MinHeight, MaxHeight = opts.MaxHeight,
		}
		table.insert(Badges.List, b)
		table.insert(Badges.ByCategory[cat], b)
		Badges.ById[id] = b
	end
end

function Badges.Threshold(base, tier)
	return math.min(99, base + Config.BadgeTierOffsets[tier])
end

local F = make("Finishing")
F("Acrobat", "Acrobat", "Better contested layups with spins and euro steps.", { DrivingLayup = 65 })
F("BackdownPunisher", "Backdown Punisher", "More powerful backdowns on smaller defenders.", { PostControl = 68, Strength = 62 }, { MinHeight = 74 })
F("ConsistentFinisher", "Consistent Finisher", "Fewer misses on contested layups and dunks.", { DrivingLayup = 62, CloseShot = 60 })
F("ContactFinisher", "Contact Finisher", "Improved finishes through contact.", { DrivingLayup = 66, Strength = 55 })
F("Dropstepper", "Dropstepper", "Sharper drop-step finishes in the post.", { PostControl = 65, CloseShot = 62 })
F("FancyFootwork", "Fancy Footwork", "Quicker, more accurate hesitation and spin finishes.", { DrivingLayup = 68, Agility = 62 })
F("FastTwitch", "Fast Twitch", "Faster jump off the gather on dunks.", { Vertical = 60, DrivingDunk = 60 })
F("GiantSlayer", "Giant Slayer", "Better finishes over taller defenders.", { DrivingLayup = 70, Vertical = 62 }, { MaxHeight = 78 })
F("LobCityFinisher", "Lob City Finisher", "Boosts alley-oop finishing.", { Vertical = 68, DrivingDunk = 65 })
F("Posterizer", "Posterizer", "More dunk attempts on defenders.", { DrivingDunk = 75, Vertical = 70 })
F("PostSpinTechnician", "Post Spin Technician", "Smoother spin moves in the post.", { PostControl = 70, Agility = 45 }, { MinHeight = 74 })
F("ProTouch", "Pro Touch", "Wider green window on layups.", { DrivingLayup = 65, ShotIQ = 55 })
F("PutbackBoss", "Putback Boss", "Stronger putbacks off the offensive glass.", { OffensiveRebound = 68, CloseShot = 62 })
F("RiseUp", "Rise Up", "Stronger standing dunks over defenders.", { StandingDunk = 70, Vertical = 55 })
F("SlitheryFinisher", "Slithery Finisher", "Better finishing through traffic.", { DrivingLayup = 72, Agility = 65 })
F("TearDropper", "Tear Dropper", "Improved floaters and teardrops.", { DrivingLayup = 65, MidRangeShot = 55 })

local S = make("Shooting")
S("Blinders", "Blinders", "Reduced penalty on late contests from the side.", { ThreePointShot = 65, ShotIQ = 60 })
S("CatchAndShoot", "Catch & Shoot", "Boosts shots right off the catch.", { ThreePointShot = 65 })
S("CircusThrees", "Circus Threes", "Better off-balance, deep threes.", { ThreePointShot = 72, ShotIQ = 60 })
S("CornerSpecialist", "Corner Specialist", "Boosts corner threes.", { ThreePointShot = 66 })
S("Deadeye", "Deadeye", "Reduces the penalty for contested jumpers.", { ThreePointShot = 68, MidRangeShot = 62 })
S("DifficultShots", "Difficult Shots", "Better contested shots in tight spaces.", { MidRangeShot = 66, ShotIQ = 60 })
S("FlexibleRelease", "Flexible Release", "More forgiving release on awkward shots.", { ThreePointShot = 65, MidRangeShot = 60 })
S("GreenMachine", "Green Machine", "Consecutive greens boost the next shot.", { OffensiveConsistency = 68, ShotIQ = 62 })
S("HotZoneHunter", "Hot Zone Hunter", "Boosts shots from your hot zones.", { ShotIQ = 60, MidRangeShot = 62 })
S("HotStart", "Hot Start", "Boosts your first shots of the game.", { OffensiveConsistency = 62, ThreePointShot = 60 })
S("IceInVeins", "Ice in Veins", "Boosts clutch shots and free throws.", { FreeThrow = 68, OffensiveConsistency = 62 })
S("MiddyMagician", "Middy Magician", "Boosts mid-range shots off the dribble.", { MidRangeShot = 70, BallHandle = 50 })
S("QuickDraw", "Quick Draw", "Faster release on catch-and-shoot.", { ThreePointShot = 66, ShotIQ = 55 })
S("SetShooter", "Set Shooter", "Boosts set shots with space.", { MidRangeShot = 62, ThreePointShot = 60 })
S("SlipperyOffBall", "Slippery Off-Ball", "Sheds defenders away from the ball.", { ShotIQ = 62, Agility = 60 })
S("VolumeShooter", "Volume Shooter", "Shooting boost as attempts pile up.", { Stamina = 60, OffensiveConsistency = 65 })

local P = make("Playmaking")
P("AnkleBreaker", "Ankle Breaker", "Dribble moves leave defenders off-balance.", { BallHandle = 70, Agility = 55 })
P("BailOut", "Bail Out", "Better passes out of tight spots.", { PassAccuracy = 62, PassIQ = 58 })
P("BreakStarter", "Break Starter", "More accurate outlet passes.", { PassAccuracy = 65, PassVision = 58 })
P("Dimer", "Dimer", "Boosts open teammates after your assists.", { PassAccuracy = 70, PassIQ = 62 })
P("Downhill", "Downhill", "Faster attack off the dribble going downhill.", { SpeedWithBall = 68, Speed = 62 })
P("HandlesForDays", "Handles for Days", "Dribble moves drain less stamina.", { BallHandle = 72, Stamina = 60 })
P("LightningLaunch", "Lightning Launch", "Explosive first step off the dribble.", { SpeedWithBall = 66, Agility = 60 })
P("MismatchExpert", "Mismatch Expert", "Better when attacking mismatches.", { BallHandle = 62, PassIQ = 58 })
P("NeedleThreader", "Needle Threader", "Tight-window passes are more accurate.", { PassAccuracy = 70, PassVision = 65 })
P("PassFakes", "Pass Fakes", "Pass fakes freeze defenders.", { PassIQ = 60, BallHandle = 55 })
P("PostPlaymaker", "Post Playmaker", "Better passes out of the post.", { PassAccuracy = 60, PostControl = 55 })
P("QuickFirstStep", "Quick First Step", "Faster first step on drives.", { Speed = 62, SpeedWithBall = 60 })
P("SpaceCreator", "Space Creator", "Better step-back and side-step separation.", { BallHandle = 66, ThreePointShot = 60 })
P("StopAndGo", "Stop & Go", "Boosts stop-and-go dribble moves.", { BallHandle = 64, SpeedWithBall = 62 })
P("TightHandles", "Tight Handles", "Fewer turnovers under pressure.", { BallHandle = 68 })
P("Unpluckable", "Unpluckable", "Harder for defenders to strip you.", { BallHandle = 70, Strength = 45 })

local D = make("Defense")
D("Anchor", "Anchor", "Better help defense and contests near the rim.", { InteriorDefense = 68, Block = 62, HelpDefenseIQ = 60 })
D("BrickWall", "Brick Wall", "Your screens are tougher to fight through.", { Strength = 65 })
D("Box", "Box", "Better box-outs and positioning.", { DefensiveRebound = 62, Strength = 60 })
D("ChaseDownArtist", "Chase Down Artist", "Boosts chase-down blocks.", { Block = 65, Speed = 60 })
D("Clamps", "Clamps", "Locks up ball handlers.", { PerimeterDefense = 70, LateralQuickness = 65 })
D("Intimidator", "Intimidator", "Shooters struggle against you at the rim.", { InteriorDefense = 66, Block = 60 })
D("Interceptor", "Interceptor", "Boosts pass-lane steals.", { PassPerception = 65, Steal = 62 })
D("Menace", "Menace", "Rattles the shooter you're guarding.", { PerimeterDefense = 68, Steal = 60 })
D("OffBallPest", "Off-Ball Pest", "Harasses players away from the ball.", { PerimeterDefense = 62, Hustle = 60 })
D("PickDodger", "Pick Dodger", "Slip through screens more easily.", { LateralQuickness = 62, Agility = 58 })
D("PickPocket", "Pick Pocket", "Faster, more effective steals.", { Steal = 68 })
D("PogoStick", "Pogo Stick", "Quicker repeat jumps for rebounds and blocks.", { Vertical = 65, Hustle = 58 })
D("PostLockdown", "Post Lockdown", "Better post defense.", { InteriorDefense = 68, Strength = 62 }, { MinHeight = 74 })
D("ReboundChaser", "Rebound Chaser", "Improved pursuit of rebounds.", { DefensiveRebound = 66, Hustle = 60 })
D("RimProtector", "Rim Protector", "Better and more frequent blocks.", { Block = 70, Vertical = 58 })
D("Worm", "Worm", "Slips around for position on offensive boards.", { OffensiveRebound = 66, Agility = 55 })

return Badges
