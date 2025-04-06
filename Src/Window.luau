local MAX_LOGS = 20

local DefaultTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Exponential)
local Images = {
	RemoteEvent = "rbxassetid://110803789420086",
	UnreliableRemoteEvent = "rbxassetid://126244162339059",
	RemoteFunction = "rbxassetid://108537517159060",
	BindableEvent = "rbxassetid://116839398727495",
	BindableFunction = "rbxassetid://112264959079193",
}

local ScreenGui = wax.shared.Interface.New("ScreenGui", {
	Name = "Cobalt",
	ResetOnSpawn = false,
	Parent = wax.shared.Interface.GetScreenParent(),
})
wax.shared.ScreenGui = ScreenGui

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

-- Topbar
local TopBar = wax.shared.Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.new(1, 0, 0, 36),

	MainUICorner,
	Parent = MainFrame,

	["TextLabel"] = {
		Text = "Cobalt",
		TextSize = 18,
		Position = UDim2.fromOffset(0, 1),
		Size = UDim2.new(1, 0, 1, -1),
		ZIndex = 2,
	},

	["ImageLabel"] = {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.new(1, -12, 1, -12),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Image = "rbxassetid://91685317120520",
		ZIndex = 2,
	},
})
wax.shared.Interface.HideCorner(TopBar, UDim2.fromScale(1, 0.5), Vector2.new(0, 1))

-- Topbar Buttons
local TopButtons = wax.shared.Interface.New("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 2,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
	["UIPadding"] = {
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		PaddingTop = UDim.new(0, 4),
	},

	Parent = TopBar,
})

local function CreateTopButton(IconName, Order: number, Callback: () -> ()?)
	local Button = wax.shared.Interface.New("ImageButton", {
		LayoutOrder = Order,
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		["UIPadding"] = {
			PaddingBottom = UDim.new(0, 3),
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 3),
			PaddingTop = UDim.new(0, 3),
		},

		Parent = TopButtons,
	})

	local Image = wax.shared.Interface.NewIcon(IconName, {
		ImageTransparency = 0.5,
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		Parent = Button,
	})

	Button.MouseEnter:Connect(function()
		wax.shared.TweenService
			:Create(Image, DefaultTweenInfo, {
				ImageTransparency = 0.25,
			})
			:Play()
	end)
	Button.MouseLeave:Connect(function()
		wax.shared.TweenService
			:Create(Image, DefaultTweenInfo, {
				ImageTransparency = 0.5,
			})
			:Play()
	end)
	if Callback then
		Button.MouseButton1Click:Connect(Callback)
	end

	return Button, Image
end

local function CreateTopSeperator(Order: number)
	wax.shared.Interface.New("ImageLabel", {
		LayoutOrder = Order,
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		Parent = TopButtons,

		["Frame"] = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(50, 50, 50),
			Size = UDim2.fromOffset(4, 4),
			Position = UDim2.fromScale(0.5, 0.5),

			["UICorner"] = {
				CornerRadius = UDim.new(1, 0),
			},
		},
	})
end

local CloseButton = CreateTopButton("x", 4, wax.shared.Unload)
local HideButton = CreateTopButton("minus", 3)
CreateTopSeperator(2)
local SettingsButton = CreateTopButton("settings", 1)
local SearchButton = CreateTopButton("search", 0)

wax.shared.Drag.Setup(MainFrame, TopBar)

-- Remote List
local LeftList = wax.shared.Interface.New("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Size = UDim2.new(0, 240, 1, -36),
	Position = UDim2.fromScale(0, 1),
	Parent = MainFrame,

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	},
})

-- Tabs
local RemoteTabContainer = wax.shared.Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.new(1, 0, 0, 30),
	Parent = LeftList,

	["UICorner"] = {
		CornerRadius = UDim.new(0, 4),
	},

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
})

local function CreateRemoteListTab(TabName: string, Active: boolean)
	local Button = wax.shared.Interface.New("TextButton", {
		BackgroundColor3 = Color3.fromRGB(50, 50, 50),
		BackgroundTransparency = Active and 0 or 1,
		Size = UDim2.fromScale(0, 1),
		TextSize = 15,
		Text = TabName,
		Parent = RemoteTabContainer,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},
	})

	return Button
end

local OutgoingTab = CreateRemoteListTab("Outgoing", true)
local IncomingTab = CreateRemoteListTab("Incoming", false)

-- Remote List
local RemoteListWrapper = wax.shared.Interface.New("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 1, -36),
	Parent = LeftList,

	["UICorner"] = {
		CornerRadius = UDim.new(0, 4),
	},

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
})

local RemoteList = wax.shared.Interface.New("ScrollingFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ScrollBarThickness = 2,
	Parent = RemoteListWrapper,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	},
})

local LogsList

local CurrentLog
function ShowLog(Log)
	for _, Object in pairs(LogsList:GetChildren()) do
		if Object.ClassName == "TextButton" then
			Object:Destroy()
		end
	end

	if CurrentLog then
		wax.shared.TweenService
			:Create(CurrentLog.Button.Instance, DefaultTweenInfo, {
				BackgroundTransparency = 1,
			})
			:Play()
	end

	CurrentLog = Log
	wax.shared.TweenService
		:Create(CurrentLog.Button.Instance, DefaultTweenInfo, {
			BackgroundTransparency = 0,
		})
		:Play()
end

local function CreateRemoteButton(Log): (TextButton, TextLabel, TextLabel)
	local Button = wax.shared.Interface.New("TextButton", {
		BackgroundColor3 = Color3.fromRGB(50, 50, 50),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Text = "",

		["ImageLabel"] = {
			Image = Images[Log.Instance.ClassName],
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
		},

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},

		Parent = RemoteList,
	})

	local Text = wax.shared.Interface.New("TextLabel", {
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,

		Parent = Button,
	})

	local Amount = wax.shared.Interface.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,

		Parent = Button,
	})

	Button.MouseButton1Click:Connect(function()
		if CurrentLog == Log then
			return
		end

		ShowLog(Log)
	end)

	return Button, Text, Amount
end

local RemoteListLine = wax.shared.Interface.New("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Position = UDim2.new(0, 240, 1, 0),
	Size = UDim2.new(0, 2, 1, -36),
	Parent = MainFrame,
})

local RemoteListResize = wax.shared.Interface.New("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.new(1, 4, 1, 0),
	Text = "",

	Parent = RemoteListLine,
})
do
	RemoteListResize.MouseEnter:Connect(function()
		wax.shared.TweenService
			:Create(RemoteListLine, DefaultTweenInfo, {
				BackgroundColor3 = Color3.fromRGB(50, 50, 50),
			})
			:Play()
	end)
	RemoteListResize.MouseLeave:Connect(function()
		wax.shared.TweenService
			:Create(RemoteListLine, DefaultTweenInfo, {
				BackgroundColor3 = Color3.fromRGB(25, 25, 25),
			})
			:Play()
	end)
end

-- Main Remote thing
local LogsWrapper = wax.shared.Interface.New("Frame", {
	AnchorPoint = Vector2.new(1, 1),
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(1, 1),
	Size = UDim2.new(1, -242, 1, -36),
	Parent = MainFrame,

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	},
})

LogsList = wax.shared.Interface.New("ScrollingFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, -38),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ScrollBarThickness = 0,
	Parent = LogsWrapper,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
	},
})

local function CreateLog(LogInfo: {
	Type: "Incoming" | "Outgoing",
	Time: string,
	Code: string?,
	Arguments: { [any]: any }?,
	Order: number,
	Origin: "Executor" | string,
})
	local Log = wax.shared.Interface.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Size = UDim2.new(1, 0, 0, 104),
		Parent = LogsList,
		LayoutOrder = LogInfo.Order,

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},

		["UICorner"] = {
			CornerRadius = UDim.new(0, 6),
		},
	})

	local LogHighlightedStroke = wax.shared.Interface.New("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(75, 75, 75),
		Thickness = 2,
		Transparency = 1,
		Parent = Log,
	})

	if LogInfo.Type == "Outgoing" and LogInfo.Code then
		local CodeFrame = wax.shared.Interface.New("Frame", {
			BackgroundColor3 = Color3.fromRGB(15, 15, 15),
			Size = UDim2.new(1, 0, 1, -28),
			Parent = Log,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 6),
			},

			["UIPadding"] = {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			},

			["TextLabel"] = {
				Size = UDim2.fromScale(1, 1),
				FontFace = Font.fromId(16658246179),
				Text = wax.shared.Highlighter.Run(LogInfo.Code),
				TextColor3 = Color3.fromHex(wax.shared.Highlighter.Colors.Text),
				TextXAlignment = Enum.TextXAlignment.Left,
				RichText = true,
				TextSize = 16,
			},
		})
	end

	local RemoteOriginImage = wax.shared.Interface.New("ImageLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 2, 1, 0),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		ImageTransparency = 0.5,
		Parent = Log,
	})

	wax.shared.Icons.SetIcon(RemoteOriginImage, LogInfo.Origin == "Executor" and "terminal" or "gamepad-2")

	wax.shared.Interface.New("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 30, 1, 0),
		Size = UDim2.new(0.5, -24, 0, 22),
		BackgroundTransparency = 1,
		Text = LogInfo.Origin == "Executor" and wax.shared.ExecutorName or LogInfo.Origin,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 0.5,
		Parent = Log,
	})

	wax.shared.Interface.New("TextLabel", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -2, 1, 0),
		Size = UDim2.new(0.5, -2, 0, 22),
		BackgroundTransparency = 1,
		Text = "Time: " .. LogInfo.Time,
		TextSize = 16,
		TextTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = Log,
	})

	return Log
end

local LogsPagination = wax.shared.Interface.New("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 32),
	Parent = LogsWrapper,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	},
})

-- UI Handling
wax.shared.Drag.Setup(RemoteListLine, RemoteListResize, function(Info, Input: InputObject)
	local Delta = Input.Position - Info.StartPosition
	local FramePosition: UDim2 = Info.FramePosition
	local Offset = math.clamp(FramePosition.X.Offset + Delta.X, 120, (MainFrame.AbsoluteSize.X - 2) / 2)

	Info.Frame.Position = UDim2.new(FramePosition.X.Scale, Offset, FramePosition.Y.Scale, FramePosition.Y.Offset)

	LeftList.Size = UDim2.new(0, Offset, 1, -36)
	LogsWrapper.Size = UDim2.new(1, -(Offset + 2), 1, -36)
end)

wax.shared.CreateRemoteButton = CreateRemoteButton
wax.shared.CreateLog = CreateLog

function GetCalls(Log, Page)
	local Start = ((Page - 1) * MAX_LOGS) + 1
	local End = math.clamp(0, Start + (MAX_LOGS - 1), #Log.Calls)

	print(Start, End)
end

wax.shared.Communicator.Event:Connect(function(Instance)
	local Log = wax.shared.Logs[Instance]
	if not Log.Button then
		local Button, Text, Calls = CreateRemoteButton(Log)

		Log.Button = {
			Instance = Button,
			Name = Text,
			Calls = Calls,
		}
	end

	Log.Button.Name.Text = Log.Instance.Name
	Log.Button.Calls.Text = `x{#Log.Calls}`
end)

-- CreateRemoteButton({
-- 	Name = "Testing",
-- 	Class = "RemoteEvent",
-- })
-- CreateRemoteButton({
-- 	Name = "GetBallers",
-- 	Class = "RemoteFunction",
-- })

-- CreateLog({
-- 	Type = "Outgoing",
-- 	Origin = "Executor",
-- 	Time = os.date("%X"),
-- 	Code = [[local args = {}

-- remote:FireServer(table.unpack(args))]],
-- 	Order = 1,
-- })

-- CreateLog({
-- 	Type = "Outgoing",
-- 	Origin = "SigmaScript",
-- 	Time = os.date("%X"),
-- 	Code = [[local args = {}

-- remote:FireServer(table.unpack(args))]],
-- 	Order = 2,
-- })
