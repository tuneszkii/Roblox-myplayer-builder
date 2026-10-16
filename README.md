# MyPlayer Builder (NBA 2K26-style, Rthro R15)

Code-only Luau project. No assets, no UI templates. **Untested in Studio**: I wrote it without a Roblox runtime, so expect to fix a typo or two on first run.

## Install

**Rojo:** `rojo serve` with `default.project.json`.

**Manual:**
- `src/shared/MyPlayer/*.lua` → Folder `ReplicatedStorage/MyPlayer`, each file a ModuleScript named after the file
- `src/server/MyPlayerService.server.lua` → Script in `ServerScriptService`
- `src/client/MyPlayerClient/init.client.lua` → LocalScript `MyPlayerClient` in `StarterPlayerScripts`, with `UI.lua` as a ModuleScript child named `UI`

Then in Game Settings:
- **Security**: enable *Studio Access to API Services* (DataStore saving in Studio)
- **Avatar**: set the type to R15 and raise the height/width scale limits so ~0.85–1.16 isn't clamped

Press **M** or tap **MYPLAYER** to open.

## Features
- 10 slots per player: create, edit, copy, delete, equip (DataStore-saved)
- 5 positions with height limits (PG 5'6"–6'8" … C 6'8"–7'6")
- 15 archetypes: each sets attribute starting values and caps, badge-point caps per category, and takeover options
- 32 attributes in 6 categories with tiered point costs (1/2/3/4/6/8 per point)
- Attribute caps shift with height, wingspan and weight (`Attributes.lua` coefficients)
- Height, wingspan (offset from height) and weight (range depends on height)
- 64 badges × 5 tiers (Bronze → Legend), attribute requirements, per-category and total point limits
- 7 takeovers (1 offense + 1 defense per build) with attribute requirements
- Position-weighted Overall rating
- Live 3D preview in a ViewportFrame, drag to rotate
- **Polish pass:** gradient panels, press-squash buttons, animated attribute bars and OVR count-ups, tier-colored OVR (Bronze/Silver/Gold/Amethyst/Pink Diamond), curtain transitions between screens, sliding toasts, optional UI sounds
- **Build presentation:** a player-card screen with a turntable 3D stage, shimmering OVR, physical tiles, category radar chart with letter grades, top-7 attributes, badge tier counts and takeovers. Opens after every save, or tap the top of any slot card.
- **Cinematics:** a four-shot camera reveal (foot-to-head tilt, orbit, face push-in, wide OVR slam) with letterbox bars, vignette, typewriter name caption and screen flash. Skip with the button, Space, Enter or ButtonA.
  - *Replay Cinematic* plays it inside the card's 3D viewport
  - *Equip & Play* equips the build, waits for the server to apply it, then plays the same sequence on your real character in the world (depth of field, bloom, tint, controls locked, camera returned afterwards)
- Server re-validates everything and filters names

## Rthro
`RthroRig.lua` sets `BodyTypeScale = 1` plus height/width/depth/head scale and skin tone from the build. Wingspan has no Roblox scale, so the upper and lower arms are lengthened and the shoulder/elbow/wrist joints re-seated.

To force specific Rthro body parts, put catalog asset IDs in `Config.Rthro.PartIds`. I didn't hardcode any because I can't verify them from memory. With all zeros, the player's own avatar parts are used.

## What the equipped build does
The server sets `WalkSpeed` from Speed and `JumpHeight` from Vertical. It also writes character attributes you can read from your gameplay code:
`MP_Overall`, `MP_<AttributeKey>`, `MP_Badge_<BadgeId>` (tier 1–5), `MP_TakeoverOffense`, `MP_TakeoverDefense`, `MP_Position`, `MP_Height`, `MP_Wingspan`, and more.

Badge and takeover effects are **not** implemented. Your shooting, dribbling and defense systems should read those attributes. `Takeovers.lua` has the boost values and durations.

## Tuning
Everything is in `Config.lua`: point budget, tier costs, caps/bases, Overall curve, badge tier thresholds, weight and height ranges, scale mapping.

## Known limits
- Raw `SetAsync`; swap in ProfileService or ProfileStore for production session locking
- The preview rig has no idle animation
- UI is designed at 1280×720 and scaled; on phones the text will be small
- Changing the archetype resets attributes, badges and takeovers (like 2K)

## Polish / cinematic files
- `Fx.lua`: tween, count-up, pop/punch, shimmer, pulse, sounds
- `Radar.lua`: radar chart from rotated frames, no images
- `Cinematic.lua`: shot list (`SHOTS` table), overlay, viewport and world players
- `Presentation.lua`: the player-card screen

Tweak the shots by editing `SHOTS` in `Cinematic.lua` (Yaw in degrees, Y/Look as fractions of height, Dist in multiples of height, Fov). Disable the auto-reveal after saving with `Config.Cinematic.AutoPlayOnSave = false`.

**Sounds:** fill `Config.Sounds` (Click, Hover, Confirm, Error, Whoosh, Impact, Tick, Reveal) with `rbxassetid://` IDs you own or have verified. Empty entries are silent. I didn't hardcode any IDs.

Notes: the world cinematic needs `MP_ApplyId` (set by the server after each equip), so keep both scripts in sync. Radar and cinematic overlays are built from Frames/CanvasGroups, so they cost a few hundred instances only while the presentation is open.
