--[[
	Radar: n-sided radar chart drawn with rotated Frames (no image assets).
	Radar.Create{ Parent, Position, Size = Vector2, Radius, Labels = {richText...}, Values = {0..1}, Color }
	returns { Root, Animate() }
]]

local UI = require(script.Parent.UI)
local Fx = require(script.Parent.Fx)
local T = UI.Theme

local Radar = {}

local function line(parent, a, b, thickness, color, transparency)
	local d = b - a
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	f.Size = UDim2.fromOffset(d.Magnitude, thickness)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function Radar.Create(props)
	local n = #props.Labels
	local size, R, color = props.Size, props.Radius, props.Color
	local center = Vector2.new(size.X / 2, size.Y / 2)

	local root = UI.new("Frame", {
		Position = props.Position or UDim2.new(), Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1, Parent = props.Parent,
	})

	local function vertex(i, r)
		local ang = -math.pi / 2 + (i - 1) * 2 * math.pi / n
		return center + Vector2.new(math.cos(ang), math.sin(ang)) * r
	end

	local gridColor = Color3.fromRGB(70, 78, 98)
	for _, f in ipairs({ 0.25, 0.5, 0.75, 1 }) do
		for i = 1, n do
			line(root, vertex(i, R * f), vertex(i % n + 1, R * f), 1, gridColor, f == 1 and 0.15 or 0.55)
		end
	end
	for i = 1, n do
		line(root, center, vertex(i, R), 1, gridColor, 0.6)
	end

	-- data layer: drawn once at final values, then scaled from the center to animate
	local data = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(center.X, center.Y),
		Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1, Parent = root,
	})
	local scale = UI.new("UIScale", { Scale = 0, Parent = data })

	local pts = {}
	for i = 1, n do
		pts[i] = vertex(i, R * math.clamp(props.Values[i], 0.06, 1))
	end
	for i = 1, n do
		local a, b = pts[i], pts[i % n + 1]
		for s = 0, 12 do
			line(data, center, a:Lerp(b, s / 12), 7, color, 0.86)
		end
	end
	for i = 1, n do
		line(data, pts[i], pts[i % n + 1], 2.5, color, 0)
	end
	for i = 1, n do
		local dot = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(pts[i].X, pts[i].Y),
			Size = UDim2.fromOffset(9, 9), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = data,
		})
		UI.Round(dot, 5)
		UI.Stroke(dot, color, 2)
	end

	for i = 1, n do
		local p = vertex(i, R + 30)
		UI.Label({
			Text = props.Labels[i], RichText = true, TextSize = 12, TextColor3 = T.Dim,
			TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(80, 34), Parent = root,
		})
	end

	local self = { Root = root }
	function self.Animate()
		scale.Scale = 0
		Fx.Tween(scale, 0.8, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	return self
end

return Radar
