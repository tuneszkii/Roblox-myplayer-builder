--[[ UI toolkit: builders, polished buttons (gradient, press squash, sounds), sliders, hold-to-repeat, toasts. ]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Fx = require(script.Parent.Fx)

local UI = {}

UI.Theme = {
	BG = Color3.fromRGB(10, 12, 18),
	Panel = Color3.fromRGB(22, 26, 36),
	Panel2 = Color3.fromRGB(34, 39, 52),
	Accent = Color3.fromRGB(130, 80, 255),
	Gold = Color3.fromRGB(255, 190, 50),
	Text = Color3.fromRGB(240, 242, 248),
	Dim = Color3.fromRGB(150, 158, 175),
	Good = Color3.fromRGB(70, 210, 120),
	Bad = Color3.fromRGB(240, 85, 95),
}

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

UI.IsPress, UI.IsMove = isPress, isMove

function UI.new(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	inst.Parent = parent
	return inst
end

function UI.Round(inst, r)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = inst })
end

function UI.Stroke(inst, color, thickness)
	return UI.new("UIStroke", {
		Color = color or UI.Theme.Panel2,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

function UI.Gradient(inst, c0, c1, rotation)
	return UI.new("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rotation or 90, Parent = inst })
end

function UI.Pad(inst, p)
	return UI.new("UIPadding", {
		PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p),
		PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p),
		Parent = inst,
	})
end

function UI.List(inst, pad, dir)
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, pad or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = dir or Enum.FillDirection.Vertical,
		Parent = inst,
	})
end

-- Color for an attribute value (shared by builder and presentation).
function UI.ValueColor(v)
	if v >= 90 then
		return Color3.fromRGB(255, 90, 200)
	elseif v >= 80 then
		return Color3.fromRGB(90, 180, 255)
	elseif v >= 70 then
		return UI.Theme.Good
	elseif v >= 55 then
		return UI.Theme.Gold
	end
	return UI.Theme.Dim
end

function UI.Label(props)
	local p = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextColor3 = UI.Theme.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	return UI.new("TextLabel", p)
end

function UI.SetColor(btn, c)
	btn:SetAttribute("BaseColor", c)
	btn.BackgroundColor3 = c
end

function UI.SetDisabled(btn, disabled)
	btn:SetAttribute("Disabled", disabled)
	btn.TextTransparency = disabled and 0.55 or 0
	btn.BackgroundTransparency = disabled and 0.45 or 0
end

function UI.Button(props)
	local onClick = props.OnClick
	local p = {
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = UI.Theme.Text,
		BackgroundColor3 = UI.Theme.Panel2,
		Text = "",
	}
	for k, v in pairs(props) do
		if k ~= "OnClick" then
			p[k] = v
		end
	end
	local btn = UI.new("TextButton", p)
	UI.Round(btn, 6)
	UI.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 196, 210)),
		Rotation = 90,
		Parent = btn,
	})
	local press = UI.new("UIScale", { Name = "PressScale", Parent = btn })
	btn:SetAttribute("BaseColor", btn.BackgroundColor3)

	btn.MouseEnter:Connect(function()
		if not btn:GetAttribute("Disabled") then
			Fx.Play("Hover")
			local base = btn:GetAttribute("BaseColor")
			TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.14) }):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = btn:GetAttribute("BaseColor") }):Play()
		Fx.Tween(press, 0.08, { Scale = 1 })
	end)
	btn.MouseButton1Down:Connect(function()
		if not btn:GetAttribute("Disabled") then
			Fx.Tween(press, 0.06, { Scale = 0.95 })
		end
	end)
	btn.MouseButton1Up:Connect(function()
		Fx.Tween(press, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	if onClick then
		btn.Activated:Connect(function()
			if not btn:GetAttribute("Disabled") then
				Fx.Play("Click")
				onClick()
			end
		end)
	end
	return btn
end

-- Calls fn immediately on press, then repeatedly while held.
function UI.OnHold(btn, fn)
	local token = 0
	btn.InputBegan:Connect(function(input)
		if not isPress(input) or btn:GetAttribute("Disabled") then
			return
		end
		token += 1
		local mine = token
		fn()
		task.delay(0.4, function()
			while token == mine and btn.Parent and not btn:GetAttribute("Disabled") do
				fn()
				task.wait(0.05)
			end
		end)
	end)
	btn.InputEnded:Connect(function(input)
		if isPress(input) then
			token += 1
		end
	end)
	btn.MouseLeave:Connect(function()
		token += 1
	end)
end

--[[ Slider. props: Parent, Position, Size, Min, Max, Value, Step, OnChanged(value, final)
     returns { Set(v), SetRange(min,max), Value, Min, Max } ]]
function UI.Slider(props)
	local T = UI.Theme
	local track = UI.new("Frame", {
		Position = props.Position, Size = props.Size, BackgroundColor3 = T.Panel,
		BorderSizePixel = 0, Parent = props.Parent,
	})
	UI.Round(track, 4)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = track })
	UI.Round(fill, 4)
	UI.Gradient(fill, T.Accent:Lerp(Color3.new(1, 1, 1), 0.25), T.Accent, 0)
	local knob = UI.new("Frame", {
		Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = T.Text, BorderSizePixel = 0, Parent = track,
	})
	UI.Round(knob, 10)
	UI.Stroke(knob, T.Accent, 3)
	local hit = UI.new("TextButton", {
		Size = UDim2.new(1, 24, 1, 28), Position = UDim2.fromOffset(-12, -14),
		BackgroundTransparency = 1, Text = "", Parent = track,
	})

	local self = { Min = props.Min, Max = props.Max, Value = props.Value or props.Min, Step = props.Step or 1 }
	local dragging = false

	local function visual()
		local a = (self.Max == self.Min) and 0 or (self.Value - self.Min) / (self.Max - self.Min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
	end

	function self:Set(v)
		self.Value = math.clamp(v, self.Min, self.Max)
		visual()
	end

	function self:SetRange(min, max)
		self.Min, self.Max = min, max
		self.Value = math.clamp(self.Value, min, max)
		visual()
	end

	local function fromX(x, final)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		local v = self.Min + a * (self.Max - self.Min)
		v = math.clamp(math.floor((v - self.Min) / self.Step + 0.5) * self.Step + self.Min, self.Min, self.Max)
		if v ~= self.Value or final then
			self.Value = v
			visual()
			if v ~= self.LastTick then
				self.LastTick = v
				Fx.Play("Tick")
			end
			if props.OnChanged then
				props.OnChanged(v, final)
			end
		end
	end

	hit.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging = true
			Fx.Tween(knob, 0.1, { Size = UDim2.fromOffset(26, 26) })
			fromX(input.Position.X, false)
		end
	end)
	local c1 = UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			fromX(input.Position.X, false)
		end
	end)
	local c2 = UserInputService.InputEnded:Connect(function(input)
		if dragging and isPress(input) then
			dragging = false
			Fx.Tween(knob, 0.15, { Size = UDim2.fromOffset(20, 20) }, Enum.EasingStyle.Back)
			fromX(input.Position.X, true)
		end
	end)
	track.Destroying:Connect(function()
		c1:Disconnect()
		c2:Disconnect()
	end)

	visual()
	return self
end

local currentToast
function UI.Toast(parent, text, color)
	if currentToast then
		currentToast:Destroy()
	end
	local shown = UDim2.new(0.5, 0, 1, -14)
	local f = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 60),
		Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Theme.Panel, BorderSizePixel = 0, ZIndex = 300, Parent = parent,
	})
	currentToast = f
	UI.Round(f, 8)
	UI.Stroke(f, color or UI.Theme.Accent, 2)
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = f })
	UI.Label({
		Text = text, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.GothamBold, TextSize = 15, ZIndex = 301, Parent = f,
	})
	Fx.Tween(f, 0.3, { Position = shown }, Enum.EasingStyle.Back)
	Fx.Play(color == UI.Theme.Bad and "Error" or "Confirm")
	task.delay(2.6, function()
		if f.Parent then
			Fx.Tween(f, 0.25, { Position = UDim2.new(0.5, 0, 1, 60) })
			task.wait(0.27)
			f:Destroy()
		end
	end)
end

return UI
