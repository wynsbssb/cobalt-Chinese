local ScreenGui = wax.shared.Interface.New("ScreenGui", {
	Name = "Cobalt",
	ResetOnSpawn = false,
	Parent = wax.shared.Interface.GetScreenParent(),
})

local MainUICorner = wax.shared.Interface.New("UICorner", {
	CornerRadius = UDim.new(0, 6),
})

local MainFrame = wax.shared.Interface.New("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(15, 15, 15),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(640, 420),

	MainUICorner,
	Parent = ScreenGui,
})

local TopBar = wax.shared.Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.new(1, 0, 0, 36),

	MainUICorner,
	Parent = MainFrame,
})
wax.shared.Interface.HideCorner(TopBar, UDim2.fromScale(1, 0.5), Vector2.new(0, 1))

wax.shared.Interface.New("TextLabel", {
	Position = UDim2.fromOffset(0, 1),
	Size = UDim2.new(1, 0, 0, -1),
	Text = "Cobalt",
	TextSize = 18,

	Parent = TopBar,
})
