local Resize = {}
Resize.__index = Resize

local HANDLE_SIZE = 6
local CORNER_HANDLE_SIZE = 20

function Resize.new(Options: {
	MainFrame: Frame,
	MinimumSize: Vector2?,
	HandleSize: number?,
	CornerHandleSize: number?,
})
	local MainFrame = Options.MainFrame
	local MinimumSize = Options.MinimumSize or Vector2.new(100, 100)

	local MinimumWidth = MinimumSize.X
	local MinimumHeight = MinimumSize.Y

	assert(MainFrame:IsA("Frame"), "MainFrame must be a Frame")

	local self = setmetatable({
		MainFrame = MainFrame,
		ScreenGui = MainFrame:FindFirstAncestorOfClass("ScreenGui"),
	}, Resize)

	local function CalculateResizeProperties(
		initialFramePosition: UDim2,
		initialFrameSize: UDim2,
		mouseDelta: Vector2,
		resizeTypeX: string?,
		resizeTypeY: string?
	)
		local currentScreenGuiAbsSize = self.ScreenGui.AbsoluteSize

		local newCalculatedWidth = initialFrameSize.X.Offset
		local newCalculatedHeight = initialFrameSize.Y.Offset
		local newCalculatedPosOffsetX = initialFramePosition.X.Offset
		local newCalculatedPosOffsetY = initialFramePosition.Y.Offset

		-- Calculate initial absolute properties
		local initialAbsCenterX = currentScreenGuiAbsSize.X * initialFramePosition.X.Scale
			+ initialFramePosition.X.Offset
		local initialAbsSizeX = initialFrameSize.X.Offset
		local initialRightEdgeX = initialAbsCenterX + initialAbsSizeX / 2
		local initialLeftEdgeX = initialAbsCenterX - initialAbsSizeX / 2

		local initialAbsCenterY = currentScreenGuiAbsSize.Y * initialFramePosition.Y.Scale
			+ initialFramePosition.Y.Offset
		local initialAbsSizeY = initialFrameSize.Y.Offset
		local initialBottomEdgeY = initialAbsCenterY + initialAbsSizeY / 2
		local initialTopEdgeY = initialAbsCenterY - initialAbsSizeY / 2

		-- Handle X-axis resizing
		if resizeTypeX then
			if resizeTypeX == "Left" then
				local newLeftEdge = initialLeftEdgeX + mouseDelta.X
				newCalculatedWidth = math.max(MinimumWidth, initialRightEdgeX - newLeftEdge)
				if newCalculatedWidth ~= (initialRightEdgeX - newLeftEdge) then
					newLeftEdge = initialRightEdgeX - newCalculatedWidth
				end
				local newAbsCenterX = newLeftEdge + newCalculatedWidth / 2
				newCalculatedPosOffsetX = newAbsCenterX - currentScreenGuiAbsSize.X * 0.5
			elseif resizeTypeX == "Right" then
				local newRightEdge = initialRightEdgeX + mouseDelta.X
				newCalculatedWidth = math.max(MinimumWidth, newRightEdge - initialLeftEdgeX)
				local newAbsCenterX = initialLeftEdgeX + newCalculatedWidth / 2
				newCalculatedPosOffsetX = newAbsCenterX - currentScreenGuiAbsSize.X * 0.5
			end
		end

		-- Handle Y-axis resizing
		if resizeTypeY then
			if resizeTypeY == "Top" then
				local newTopEdge = initialTopEdgeY + mouseDelta.Y
				newCalculatedHeight = math.max(MinimumHeight, initialBottomEdgeY - newTopEdge)
				if newCalculatedHeight ~= (initialBottomEdgeY - newTopEdge) then
					newTopEdge = initialBottomEdgeY - newCalculatedHeight
				end
				local newAbsCenterY = newTopEdge + newCalculatedHeight / 2
				newCalculatedPosOffsetY = newAbsCenterY - currentScreenGuiAbsSize.Y * 0.5
			elseif resizeTypeY == "Bottom" then
				local newBottomEdge = initialBottomEdgeY + mouseDelta.Y
				newCalculatedHeight = math.max(MinimumHeight, newBottomEdge - initialTopEdgeY)
				local newAbsCenterY = initialTopEdgeY + newCalculatedHeight / 2
				newCalculatedPosOffsetY = newAbsCenterY - currentScreenGuiAbsSize.Y * 0.5
			end
		end

		local finalNewSize = UDim2.new(0, newCalculatedWidth, 0, newCalculatedHeight)
		local finalNewPosition = UDim2.new(0.5, newCalculatedPosOffsetX, 0.5, newCalculatedPosOffsetY)

		return finalNewSize, finalNewPosition
	end

	local LeftSide = wax.shared.Interface.New("Frame", {
		Size = UDim2.new(0, HANDLE_SIZE, 1, -CORNER_HANDLE_SIZE * 2),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6,
	})
	do
		wax.shared.Drag.Setup(MainFrame, LeftSide, function(Info, Input: InputObject)
			local mouseDelta = Input.Position - Info.StartPosition
			local newSize, newPosition =
				CalculateResizeProperties(Info.FramePosition, Info.FrameSize, mouseDelta, "Left", nil)
			MainFrame.Size = newSize
			MainFrame.Position = newPosition
		end)
	end

	local RightSide = wax.shared.Interface.New("Frame", {
		Size = UDim2.new(0, HANDLE_SIZE, 1, -CORNER_HANDLE_SIZE * 2),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6,
	})
	do
		wax.shared.Drag.Setup(MainFrame, RightSide, function(Info, Input: InputObject)
			local mouseDelta = Input.Position - Info.StartPosition
			local newSize, newPosition =
				CalculateResizeProperties(Info.FramePosition, Info.FrameSize, mouseDelta, "Right", nil)
			MainFrame.Size = newSize
			MainFrame.Position = newPosition
		end)
	end

	local TopSide = wax.shared.Interface.New("Frame", {
		Size = UDim2.new(1, -CORNER_HANDLE_SIZE * 2, 0, HANDLE_SIZE),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6,
	})
	do
		wax.shared.Drag.Setup(MainFrame, TopSide, function(Info, Input: InputObject)
			local mouseDelta = Input.Position - Info.StartPosition
			local newSize, newPosition =
				CalculateResizeProperties(Info.FramePosition, Info.FrameSize, mouseDelta, nil, "Top")
			MainFrame.Size = newSize
			MainFrame.Position = newPosition
		end)
	end

	local BottomSide = wax.shared.Interface.New("Frame", {
		Size = UDim2.new(1, -CORNER_HANDLE_SIZE * 2, 0, HANDLE_SIZE),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6,
	})
	do
		wax.shared.Drag.Setup(MainFrame, BottomSide, function(Info, Input: InputObject)
			local mouseDelta = Input.Position - Info.StartPosition
			local newSize, newPosition =
				CalculateResizeProperties(Info.FramePosition, Info.FrameSize, mouseDelta, nil, "Bottom")
			MainFrame.Size = newSize
			MainFrame.Position = newPosition
		end)
	end

	-- Corner Resizing
	local TopLeftCorner = wax.shared.Interface.New("Frame", {
		Size = UDim2.fromOffset(CORNER_HANDLE_SIZE, CORNER_HANDLE_SIZE),
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6 + 1,
	})
	do
		wax.shared.Drag.Setup(MainFrame, TopLeftCorner, function(Info, Input: InputObject)
			local mouseDelta = Input.Position - Info.StartPosition
			local newSize, newPosition =
				CalculateResizeProperties(Info.FramePosition, Info.FrameSize, mouseDelta, "Left", "Top")
			MainFrame.Size = newSize
			MainFrame.Position = newPosition
		end)
	end

	local TopRightCorner = wax.shared.Interface.New("Frame", {
		Size = UDim2.fromOffset(CORNER_HANDLE_SIZE, CORNER_HANDLE_SIZE),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6 + 1,
	})
	do
		wax.shared.Drag.Setup(MainFrame, TopRightCorner, function(Info, Input: InputObject)
			local mouseDelta = Input.Position - Info.StartPosition
			local newSize, newPosition =
				CalculateResizeProperties(Info.FramePosition, Info.FrameSize, mouseDelta, "Right", "Top")
			MainFrame.Size = newSize
			MainFrame.Position = newPosition
		end)
	end

	local BottomLeftCorner = wax.shared.Interface.New("Frame", {
		Size = UDim2.fromOffset(CORNER_HANDLE_SIZE, CORNER_HANDLE_SIZE),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6 + 1,
	})
	do
		wax.shared.Drag.Setup(MainFrame, BottomLeftCorner, function(Info, Input: InputObject)
			local mouseDelta = Input.Position - Info.StartPosition
			local newSize, newPosition =
				CalculateResizeProperties(Info.FramePosition, Info.FrameSize, mouseDelta, "Left", "Bottom")
			MainFrame.Size = newSize
			MainFrame.Position = newPosition
		end)
	end

	local BottomRightCorner = wax.shared.Interface.New("Frame", {
		Size = UDim2.fromOffset(CORNER_HANDLE_SIZE, CORNER_HANDLE_SIZE),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6 + 1,
	})
	do
		wax.shared.Drag.Setup(MainFrame, BottomRightCorner, function(Info, Input: InputObject)
			local mouseDelta = Input.Position - Info.StartPosition
			local newSize, newPosition =
				CalculateResizeProperties(Info.FramePosition, Info.FrameSize, mouseDelta, "Right", "Bottom")
			MainFrame.Size = newSize
			MainFrame.Position = newPosition
		end)
	end

	return self
end

return Resize
