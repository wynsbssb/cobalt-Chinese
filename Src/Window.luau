local PaginationHelper = wax.shared.Pagination.new({
	ItemsPerPage = 20,
	TotalItems = 0,
})

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
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
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
	ZIndex = 0,

	MainUICorner,
	Parent = ScreenGui,
})

-- Context Menus
local function CreateContextMenu(Options: {
	[number]: {
		["Icon"]: string,
		["Text"]: string,
		["Callback"]: () -> (),
		["CloseOnClick"]: boolean?,
	}
})
	local ContextMenu = wax.shared.Interface.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		Size = UDim2.fromScale(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		ZIndex = 10000,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 8),
		},

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 0),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},

		["UIStroke"] = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(25, 25, 25),
			Thickness = 1,
		},
	})

	for Order, Data in pairs(Options) do
		local TextButton = wax.shared.Interface.New("TextButton", {
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = ContextMenu,

			["UIPadding"] = {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			},

			["TextLabel"] = {
				Position = UDim2.fromOffset(26, 0),
				Size = UDim2.new(0, 73, 1, 0),
				Text = Data.Text,
			}
		})

		wax.shared.Interface.NewIcon(Data.Icon, {
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Size = UDim2.fromScale(1, 1),

			Parent = TextButton,
		})

		wax.shared.Connect(TextButton.MouseButton1Click:Connect(function()
			if Data.Callback then
				Data.Callback()
			end

			if Data.CloseOnClick ~= false then
				ContextMenu:Destroy()
			end
		end))
	end

	return ContextMenu
end

-- Sonner toast
local SonnerUI = wax.shared.Interface.New("ScrollingFrame", {
	Name = "Sonner",
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(285, 115),
	Position = UDim2.fromScale(1, 1),
	AnchorPoint = Vector2.new(1, 1),
	ZIndex = 5000,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ScrollingEnabled = false,
	ClipsDescendants = true,
	Parent = MainFrame,
})

wax.shared.Sonner.init(SonnerUI)

-- Modal
local ModalBackground = wax.shared.Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 2,

	MainUICorner,
	Parent = MainFrame,
})

local function CreateModalTop(Title: string, Icon: string, Parent: GuiObject)
	local ModalTop = wax.shared.Interface.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = Parent,

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},
	})

	local ModalTitle = wax.shared.Interface.New("TextLabel", {
		Text = Title,
		TextSize = 17,
		Size = UDim2.new(1, 0, 1, 0),
		TextTransparency = 0.5,
		Parent = ModalTop,
	})

	local ModalIcon

	if Icon:match("rbxasset") then
		ModalIcon = wax.shared.Interface.New("ImageLabel", {
			Image = Icon,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(4, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,

			Parent = ModalTop,
		})
	else
		ModalIcon = wax.shared.Interface.NewIcon(Icon, {
			ImageTransparency = 0.5,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(4, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,

			Parent = ModalTop,
		})
	end

	local CloseButton = wax.shared.Interface.New("ImageButton", {
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = ModalTop,
	})

	wax.shared.Interface.NewIcon("x", {
		ImageTransparency = 0.5,
		Size = UDim2.fromOffset(22, 22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		Parent = CloseButton,
	})

	wax.shared.Interface.New("Frame", {
		Parent = Parent,
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 36),
	})

	return ModalTop, ModalTitle, ModalIcon
end

-- Settings
local SettingsFrame = wax.shared.Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	Size = UDim2.new(0.65, 0, 0, 285),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Visible = false,
	Parent = ModalBackground,

	["UICorner"] = {
		CornerRadius = UDim.new(0, 8),
	},

	["UIStroke"] = {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(25, 25, 25),
		Thickness = 1,
	},
})

local SettingsTop = CreateModalTop("Settings", "settings", SettingsFrame)

local SettingsScrollingFrame = wax.shared.Interface.New("ScrollingFrame", {
	AnchorPoint = Vector2.new(0, 1),
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 1, -37),
	ClipsDescendants = true,
	ScrollBarThickness = 0,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.fromScale(0, 0),
	Parent = SettingsFrame,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 15),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
	}
})

local function CreateSettingsSection(SectionName: string)
	return wax.shared.Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		Parent = SettingsScrollingFrame,

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 6),
		},

		["TextLabel"] = {
			Text = SectionName,
			FontFace = Font.fromId(12187365364, Enum.FontWeight.Bold),
			TextSize = 18,
			Size = UDim2.new(1, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = -1,
		},
	})
end

local FilterSection = CreateSettingsSection("Filter")

local IgnoredSection = CreateSettingsSection("Ignored")

local BlockedSection = CreateSettingsSection("Blocked")

local CreditsSection = CreateSettingsSection("Credits")

local Credits = {
	{
		Credit = "shadcn",
		Description = "UI Design Insipration (<font color=\"#3798ff\">https://ui.shadcn.com/</font>)"
	},
	{
		Credit = "lucide",
		Description = "Consistent and clean icons (<font color=\"#3798ff\">https://lucide.dev/</font>)"
	},
	{
		Credit = "Emil Kowalski",
		Description = "Creator of Sonner component (<font color=\"#3798ff\">https://sonner.emilkowal.ski/</font>)"
	}
}

local CreditsWrapper = wax.shared.Interface.New("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = CreditsSection,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 10),
	}
})

for Order, Data in pairs(Credits) do
	wax.shared.Interface.New("TextLabel", {
		Text = `<b>{Data.Credit}</b>\n{Data.Description}`,
		Size = UDim2.fromScale(1, 0),
		TextSize = 14,
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = Order,
		Parent = CreditsWrapper
	})
end

-- Info
local InfoFrame = wax.shared.Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	Size = UDim2.new(0.65, 0, 0, 285),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Visible = false,
	Parent = ModalBackground,

	["UICorner"] = {
		CornerRadius = UDim.new(0, 8),
	},

	["UIStroke"] = {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(25, 25, 25),
		Thickness = 1,
	},
})

local InfoTop, InfoTitle, InfoIcon = CreateModalTop("Loading...", Images["RemoteEvent"], InfoFrame)

local InfoButtons = wax.shared.Interface.New("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 6, 1, -7),
	AnchorPoint = Vector2.new(0, 1),
	Size = UDim2.new(1, -12, 0, 32),
	Parent = InfoFrame,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
	}
})

local function CreateInfoButton(Icon: string, Title: string, Callback: (...any) -> ...any)
	local Button = wax.shared.Interface.New("ImageButton", {
		BackgroundTransparency = 1,
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		Size = UDim2.fromScale(0, 1),
		Parent = InfoButtons,
		AutomaticSize = Enum.AutomaticSize.X,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 6),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},

		["UIStroke"] = {
			Color = Color3.fromRGB(25, 25, 25),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},

		["TextLabel"] = {
			Text = Title,
			TextSize = 15,
			Size = UDim2.fromScale(0, 1),
			Position = UDim2.fromOffset(28, 0),
			AutomaticSize = Enum.AutomaticSize.X,
		}
	})

	wax.shared.Interface.NewIcon(Icon, {
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		Parent = Button,
	})

	wax.shared.Connect(Button.MouseButton1Click:Connect(Callback))
	return Button
end

local CopyButton = CreateInfoButton("copy", "Copy", function()
	wax.shared.Sonner.error("This button (Copy) is not implemented yet.")
end)

local NetworkButton = CreateInfoButton("network", "Event", function()
	wax.shared.Sonner.error("This button (Event) is not implemented yet.")
end)

-- Search
local SearchFrame = wax.shared.Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	Size = UDim2.new(0.5, 0, 0.8, 0),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Visible = false,
	Parent = ModalBackground,

	["UICorner"] = {
		CornerRadius = UDim.new(0, 8),
	},

	["UIStroke"] = {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(25, 25, 25),
		Thickness = 1,
	},
})

local SearchTop = wax.shared.Interface.New("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 36),
	Parent = SearchFrame,

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	},
})

local SearchBox = wax.shared.Interface.New("TextBox", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -30, 1, 0),
	PlaceholderText = "Search for remotes...",
	PlaceholderColor3 = Color3.fromRGB(127, 127, 127),
	Text = "",
	TextSize = 17,
	Parent = SearchTop,
})

local SearchClose = wax.shared.Interface.New("ImageButton", {
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.fromScale(1, 0),
	AnchorPoint = Vector2.new(1, 0),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	Parent = SearchTop,
})

wax.shared.Interface.NewIcon("x", {
	ImageTransparency = 0.5,
	Size = UDim2.fromOffset(22, 22),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,

	Parent = SearchClose,
})

wax.shared.Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.new(1, 0, 0, 1),
	Position = UDim2.fromOffset(0, 36),
	Parent = SearchFrame,
})

local SearchFilterList = wax.shared.Interface.New("ScrollingFrame", {
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.fromOffset(0, 0),
	ScrollBarThickness = 2,
	Position = UDim2.fromOffset(0, 37),
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundTransparency = 1,
	Parent = SearchFrame,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 6),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	},
})

-- Search Filter
local CurrentSearchFilters = {}
local SearchFilterOrder = 0

local FilterAllButton = wax.shared.Interface.New("TextButton", {
	BackgroundColor3 = Color3.fromRGB(15, 15, 15),
	Size = UDim2.fromScale(0, 1),
	AutomaticSize = Enum.AutomaticSize.X,
	TextSize = 15,
	Text = "All",
	LayoutOrder = SearchFilterOrder,
	Parent = SearchFilterList,

	["UICorner"] = {
		CornerRadius = UDim.new(0, 4),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 0),
		PaddingBottom = UDim.new(0, 0),
	},
})

wax.shared.Connect(FilterAllButton.MouseButton1Click:Connect(function()
	for _, Object in pairs(SearchFilterList:GetChildren()) do
		if Object.ClassName == "TextButton" then
			Object.BackgroundTransparency = 1
		end
	end

	CurrentSearchFilters = {}
	FilterAllButton.BackgroundTransparency = 0
end))

for ClassName, Image in pairs(Images) do
	SearchFilterOrder += 1

	local ClassNameFilterButton = wax.shared.Interface.New("TextButton", {
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 15,
		Text = "",
		LayoutOrder = SearchFilterOrder,
		Parent = SearchFilterList,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 0),
			PaddingBottom = UDim.new(0, 0),
		},

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		},

		["ImageLabel"] = {
			Image = Image,
			Size = UDim2.new(1, -7, 1, -7),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(0.5, 0),
		},

		["TextLabel"] = {
			Text = ClassName,
			TextSize = 15,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
		},
	})

	wax.shared.Connect(ClassNameFilterButton.MouseButton1Click:Connect(function()
		local FoundIndex = table.find(CurrentSearchFilters, ClassName)
		if FoundIndex then
			table.remove(CurrentSearchFilters, FoundIndex)
			ClassNameFilterButton.Color3 = Color3.fromRGB(15, 15, 15)

			return
		end

		table.insert(CurrentSearchFilters, ClassName)
		ClassNameFilterButton.Color3 = Color3.fromRGB(25, 25, 25)
	end))
end

wax.shared.Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.new(1, 0, 0, 1),
	Position = UDim2.fromOffset(0, 72),
	Parent = SearchFrame,
})

local SearchResults = wax.shared.Interface.New("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 73),
	Size = UDim2.new(1, 0, 1, -73),
	Parent = SearchFrame,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0),

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 6),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	},
})

local function CreateSearchResult(Instance: Instance, Active: boolean)
	local SearchResult = wax.shared.Interface.New("TextButton", {
		Text = "",
		BackgroundTransparency = Active and 0 or 1,
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Size = UDim2.new(1, 0, 0, 36),
		Parent = SearchResults,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 6),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},

		["ImageLabel"] = {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Image = Images[Instance.ClassName],
		},

		["TextLabel"] = {
			Text = Instance.Name,
			TextSize = 17,
			Size = UDim2.new(1, -30, 1, 0),
			Position = UDim2.fromOffset(30, 0),
		},
	})

	return SearchResult
end

-- Topbar
local TopBar = wax.shared.Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.new(1, 0, 0, 36),
	ZIndex = 0,
	MainUICorner,
	Parent = MainFrame,

	["TextLabel"] = {
		Text = "Cobalt",
		TextSize = 18,
		Position = UDim2.fromOffset(0, 1),
		Size = UDim2.new(1, 0, 1, -1),
	},

	["ImageLabel"] = {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.new(1, -12, 1, -12),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Image = "rbxassetid://91685317120520",
	},
})
wax.shared.Interface.HideCorner(TopBar, UDim2.fromScale(1, 0.5), Vector2.yAxis)

-- Topbar Buttons
local TopButtons = wax.shared.Interface.New("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 2,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
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

CreateTopButton("x", 4, wax.shared.Unload)
local HideButton = CreateTopButton("minus", 3)
CreateTopSeperator(2)
local SettingsButton = CreateTopButton("settings", 1)
local SearchButton = CreateTopButton("search", 0)

wax.shared.Drag.Setup(MainFrame, TopBar)

-- Remote List
local LeftList = wax.shared.Interface.New("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.yAxis,
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
	},
})

-- Remote List
local RemoteListWrapper = wax.shared.Interface.New("Frame", {
	AnchorPoint = Vector2.yAxis,
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

local RemoteListLine = wax.shared.Interface.New("Frame", {
	AnchorPoint = Vector2.yAxis,
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
	AnchorPoint = Vector2.one,
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(1, 1),
	Size = UDim2.new(1, -242, 1, -36),
	Parent = MainFrame,

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		PaddingTop = UDim.new(0, 4),
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
		Padding = UDim.new(0, 6),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
	},
})

local LogsPagination = wax.shared.Interface.New("Frame", {
	AnchorPoint = Vector2.yAxis,
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 32),
	Parent = LogsWrapper,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
	},
})

-- Functions
local CurrentTab
local CurrentLog
local CurrentPage = {}

function ShowTab(Tab)
	for _, Object in pairs(RemoteList:GetChildren()) do
		if Object.ClassName == "TextButton" then
			Object.Parent = nil
		end
	end

	if CurrentTab then
		wax.shared.TweenService
			:Create(CurrentTab.Instance, DefaultTweenInfo, {
				BackgroundTransparency = 1,
			})
			:Play()
	end

	CurrentTab = Tab
	wax.shared.TweenService
		:Create(CurrentTab.Instance, DefaultTweenInfo, {
			BackgroundTransparency = 0,
		})
		:Play()

	for _, Log in pairs(Tab.Logs) do
		if not Log.Button then
			local Button, Name, Calls = CreateLogButton(Log)
			Log:SetButton(Button, Name, Calls)
		end

		Log.Button.Name.Text = Log.Instance.Name
		Log.Button.Calls.Text = "x" .. #Log.Calls
		Log.Button.Instance.Parent = RemoteList
	end
end

function ShowLog(Log)
	for _, Object in pairs(LogsList:GetChildren()) do
		if Object.ClassName == "Frame" then
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

	local Page = CurrentPage[Log]
	if not Page then
		CurrentPage[Log] = 1
		Page = 1
	end

	PaginationHelper:Update(#Log.Calls)
	PaginationHelper:SetPage(Page)

	LogsList.CanvasPosition = Vector2.zero
	ShowPagination(Log)
	ShowCalls(Log, Page)
end

function ShowCalls(Log, Page)
	local Start, End = PaginationHelper:GetIndexRanges(Page)

	for Index = Start, End do
		local Call = Log.Calls[Index]
		if not Call then
			break
		end

		CreateCallFrame({
			Arguments = Call.Arguments,
			Time = Call.Time,
			Origin = Call.Origin,
			Order = Index,
		})
	end
end

function ShowPagination(Log)
	for _, Object in pairs(LogsPagination:GetChildren()) do
		if Object.ClassName == "TextButton" or Object.ClassName == "TextBox" then
			Object:Destroy()
		end
	end

	local Pages = PaginationHelper:GetVisualInfo()
	for Order, Info in pairs(Pages) do
		CreatePageElement(Info, Order, Info == CurrentPage[Log], Log)
	end
end

function CreateRemoteTab(TabName: string, Active: boolean, Logs)
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

	local Tab = {
		Name = TabName,
		Logs = Logs,
		Instance = Button,
	}

	if Active then
		CurrentTab = Tab
	end

	wax.shared.Connect(Button.MouseButton1Click:Connect(function()
		if CurrentTab == Tab then
			return
		end

		ShowTab(Tab)
	end))

	return Button
end

function CreatePageElement(PageOrType, Order, Active, Log)
	if PageOrType == "ellipsis" then
		local Ellipsis = wax.shared.Interface.New("TextBox", {
			BackgroundColor3 = Color3.fromRGB(25, 25, 25),
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			LayoutOrder = 1,
			PlaceholderText = "-",
			Text = "",
			TextSize = 15,
			RichText = false,
			Parent = LogsPagination,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 4),
			},
		})

		wax.shared.Connect(Ellipsis.FocusLost:Connect(function(EnterPressed)
			if not EnterPressed then
				return
			end

			local Page = tonumber(Ellipsis.Text)
			if not Page then
				Ellipsis.Text = ""
				return
			end

			local Success = pcall(function()
				PaginationHelper:SetPage(Page)
				CurrentPage[Log] = Page
				ShowLog(CurrentLog)
			end)

			if not Success then
				wax.shared.Sonner.error("Invalid page number provided!")
			end
		end))

		return
	end

	local Button = wax.shared.Interface.New("TextButton", {
		BackgroundColor3 = Active and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25),
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Text = tostring(PageOrType),
		LayoutOrder = 1,
		TextSize = 15,
		Parent = LogsPagination,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},
	})

	wax.shared.Connect(Button.MouseButton1Click:Connect(function()
		PaginationHelper:SetPage(PageOrType)
		CurrentPage[Log] = PageOrType
		ShowLog(CurrentLog)
	end))
end

function CreateLogButton(Log): (TextButton, TextLabel, TextLabel)
	local Button = wax.shared.Interface.New("TextButton", {
		BackgroundColor3 = Color3.fromRGB(50, 50, 50),
		BackgroundTransparency = 1,
		LayoutOrder = Log.Index or 1,
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

function CreateArgHolder(Index: number, Value: any, Parent: GuiObject)
	local Holder = wax.shared.Interface.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		LayoutOrder = Index,
		Size = UDim2.new(1, 0, 0, 27),

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},

		Parent = Parent,
	})

	wax.shared.Interface.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = Index,
		TextSize = 15,
		TextTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,

		Parent = Holder,
	})

	wax.shared.Interface.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = typeof(Value),
		TextSize = 15,
		TextTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Right,

		Parent = Holder,
	})

	wax.shared.Interface.New("TextLabel", {
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -18, 1, 0),
		TextColor3 = Color3.fromHex(wax.shared.Highlighter.GetArgumentColor(Value)),
		Text = wax.shared.DisplayArgument(Value),
		RichText = false,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,

		Parent = Holder,
	})

	return Holder
end

function CreateCallFrame(CallInfo: {
	Time: string,
	Arguments: { [any]: any },
	Order: number,
	Origin: BaseScript | nil,
})
	local CallFrame = wax.shared.Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Size = UDim2.fromScale(1, 0),
		Parent = LogsList,
		LayoutOrder = CallInfo.Order,

		["UIListLayout"] = {
			Padding = UDim.new(0, 6),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},

		MainUICorner,
	})

	local _LogHighlightedStroke = wax.shared.Interface.New("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(75, 75, 75),
		Thickness = 2,
		Transparency = 1,

		Parent = CallFrame,
	})

	local ArgumentsFrame = wax.shared.Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		Size = UDim2.fromScale(1, 0),
		Visible = #CallInfo.Arguments > 0,

		["UIListLayout"] = {
			Padding = UDim.new(0, 6),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},

		MainUICorner,

		Parent = CallFrame,
	})
	do
		for Index, Value in pairs(CallInfo.Arguments) do
			CreateArgHolder(Index, Value, ArgumentsFrame)
		end
	end

	wax.shared.Interface.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),

		wax.shared.Interface.NewIcon(CallInfo.Origin and "gamepad-2" or "terminal", {
			AnchorPoint = Vector2.yAxis,
			ImageTransparency = 0.5,
			Position = UDim2.new(0, 2, 1, 0),
			Size = UDim2.fromOffset(22, 22),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
		}),

		wax.shared.Interface.New("TextLabel", {
			AnchorPoint = Vector2.yAxis,
			Position = UDim2.new(0, 30, 1, 0),
			Size = UDim2.new(0.5, -24, 0, 22),
			BackgroundTransparency = 1,
			Text = CallInfo.Origin and CallInfo.Origin.Name or wax.shared.ExecutorName,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 0.5,
		}),

		wax.shared.Interface.New("TextLabel", {
			AnchorPoint = Vector2.one,
			Position = UDim2.new(1, -2, 1, 0),
			Size = UDim2.new(0.5, -2, 0, 22),
			BackgroundTransparency = 1,
			Text = "Time: " .. CallInfo.Time,
			TextSize = 16,
			TextTransparency = 0.5,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),

		Parent = CallFrame,
	})

	return CallFrame
end

-- UI Handling
CreateRemoteTab("Outgoing", true, wax.shared.Logs.Outgoing)
CreateRemoteTab("Incoming", false, wax.shared.Logs.Incoming)

wax.shared.Drag.Setup(RemoteListLine, RemoteListResize, function(Info, Input: InputObject)
	local Delta = Input.Position - Info.StartPosition
	local FramePosition: UDim2 = Info.FramePosition
	local Offset = math.clamp(FramePosition.X.Offset + Delta.X, 120, (MainFrame.AbsoluteSize.X - 2) / 2)

	Info.Frame.Position = UDim2.new(FramePosition.X.Scale, Offset, FramePosition.Y.Scale, FramePosition.Y.Offset)

	LeftList.Size = UDim2.new(0, Offset, 1, -36)
	LogsWrapper.Size = UDim2.new(1, -(Offset + 2), 1, -36)
end)

wax.shared.Connect(wax.shared.Communicator.Event:Connect(function(Instance, Type, CallInfo, CallIndex)
	if not (CurrentTab and CurrentTab.Name == Type) then
		return
	end

	local Log = wax.shared.Logs[Type][Instance]

	local Page = CurrentPage[Log]
	if not Page then
		Page = 1
		CurrentPage[Log] = Page
	end

	if not Log.Button then
		local Button, Name, Calls = CreateLogButton(Log)
		Log:SetButton(Button, Name, Calls)
	end

	Log.Button.Name.Text = Log.Instance.Name
	Log.Button.Calls.Text = "x" .. #Log.Calls

	if CurrentLog == Log then
		PaginationHelper:Update(#Log.Calls)

		local Start, End = PaginationHelper:GetIndexRanges(Page)
		if CallIndex < Start or CallIndex > End then
			ShowPagination(Log)
			return
		end

		CreateCallFrame({
			Arguments = CallInfo[1],
			Time = CallInfo[2],
			Origin = CallInfo[3],
			Order = CallIndex,
		})
	end
end))
