--[[
	MyPlayer Builder - central tuning file.
	Everything balance-related lives here so you can tweak without touching logic.
]]

local Config = {
	MaxSlots = 10,
	DataStoreName = "MyPlayerBuilds_v1",
	DataVersion = 1,
	AutosaveInterval = 60,
	RequestCooldown = 0.25,
	OpenOnJoin = true,
	ToggleKey = Enum.KeyCode.M,

	Name = { MinLength = 2, MaxLength = 20 },
	JerseyNumber = { Min = 0, Max = 99 },

	-- Physicals (inches / lbs). Wingspan is stored as an offset from height.
	Height = { Min = 66, Max = 90, Default = 78 }, -- 5'6" .. 7'6", default 6'6"
	Wingspan = { MinOffset = -2, MaxOffset = 8, DefaultOffset = 2 },
	-- Weight range scales with height: min = MinBase + (h-66)*MinPerInch, max likewise.
	Weight = { MinBase = 140, MinPerInch = 3.6, MaxBase = 200, MaxPerInch = 5.6, RefHeight = 66 },

	-- Attributes
	Attribute = { Floor = 25, Ceiling = 99 },
	AttributePoints = 1100, -- total points a build can spend above its archetype baseline
	-- Cost to go from v -> v+1 is the cost of the first tier whose limit is > v.
	PointTiers = { { 60, 1 }, { 70, 2 }, { 80, 3 }, { 90, 4 }, { 95, 6 }, { 99, 8 } },
	-- Archetypes rank every attribute as Primary / Secondary / Normal / Weak.
	Caps = { Primary = 99, Secondary = 92, Normal = 80, Weak = 62 },
	Bases = { Primary = 60, Secondary = 52, Normal = 42, Weak = 32 },
	-- Overall = Offset + (positionWeightedAverage - AvgFloor) * Slope
	Overall = { AvgFloor = 40, Offset = 60, Slope = 0.8, Min = 40, Max = 99 },

	-- Badges
	BadgeTiers = { "Bronze", "Silver", "Gold", "Hall of Fame", "Legend" },
	BadgeTierShort = { "B", "S", "G", "HOF", "L" },
	BadgeTierColors = {
		Color3.fromRGB(176, 112, 64),
		Color3.fromRGB(190, 196, 206),
		Color3.fromRGB(245, 190, 40),
		Color3.fromRGB(170, 90, 255),
		Color3.fromRGB(255, 80, 120),
	},
	-- Requirement for tier t = badge base requirement + offset[t] (capped at 99)
	BadgeTierOffsets = { 0, 8, 16, 24, 30 },
	BadgePointsTotal = 60, -- tier N costs N points; archetypes also cap each category

	SkinTones = { "#FDE0C8", "#F1C27D", "#E0AC69", "#C68642", "#A0674B", "#8D5524", "#6B4226", "#3B2417" },

	-- Presentation: card/OVR color tiers (sorted high to low, last must be Min = 0)
	OverallTiers = {
		{ Min = 97, Name = "Pink Diamond", Color = Color3.fromRGB(255, 105, 200) },
		{ Min = 90, Name = "Amethyst", Color = Color3.fromRGB(165, 105, 255) },
		{ Min = 80, Name = "Gold", Color = Color3.fromRGB(255, 190, 50) },
		{ Min = 70, Name = "Silver", Color = Color3.fromRGB(200, 206, 216) },
		{ Min = 0, Name = "Bronze", Color = Color3.fromRGB(205, 127, 70) },
	},

	-- Optional UI/cinematic sounds. Paste "rbxassetid://..." IDs; empty = silent.
	Sounds = { Click = "", Hover = "", Confirm = "", Error = "", Whoosh = "", Impact = "", Tick = "", Reveal = "" },
	SoundVolume = 0.5,

	Cinematic = {
		AutoPlayOnSave = true, -- play the build reveal after every save
		LetterboxFraction = 0.11, -- height of each black bar (0..0.5)
	},

	-- Rig scaling
	Scale = {
		HeightScaleAtDefault = 1.0, -- HeightScale used for a 6'6" player
		Width = { Min = 0.85, Max = 1.15 }, -- mapped across the legal weight range
		Depth = { Min = 0.85, Max = 1.10 },
		HeadScale = 1.0,
	},

	Rthro = {
		BodyTypeScale = 1, -- 1 = full Rthro proportions
		ProportionScale = 1,
		UseOwnAvatar = true, -- keep the player's clothes/accessories/face
		-- Optional: force specific Rthro body parts. Put real catalog asset IDs here.
		-- 0 = keep whatever the player's avatar already has.
		PartIds = { Head = 0, Torso = 0, LeftArm = 0, RightArm = 0, LeftLeg = 0, RightLeg = 0 },
	},

	-- Attribute -> Humanoid mapping for the equipped build
	Gameplay = {
		WalkSpeed = { 12, 20 }, -- Speed 25 -> 99
		JumpHeight = { 5, 9.5 }, -- Vertical 25 -> 99
	},
}

return Config
