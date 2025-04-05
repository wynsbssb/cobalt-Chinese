local Drag = {
	Dragging = false,
	Frame = nil,
	FramePosition = nil,
	StartPosition = nil,
	ChangedConnection = nil,
}

function Drag.Setup(Frame: GuiObject, DragFrame: GuiObject)
	DragFrame.InputBegan:Connect(function(Input: InputObject)
		if not wax.shared.IsClickInput(Input) then
			return
		end

		Drag.Dragging = true
		Drag.Frame = Frame
		Drag.FramePosition = Frame.Position
		Drag.StartPosition = Input.Position

		Drag.ChangedConnection = Input.Changed:Connect(function()
			if Input.UserInputState ~= Enum.UserInputState.End then
				return
			end

			print("ended")

			Drag.Dragging = false
			Drag.Frame = nil

			if Drag.ChangedConnection and Drag.ChangedConnection.Connected then
				Drag.ChangedConnection:Disconnect()
				Drag.ChangedConnection = nil
			end
		end)
	end)
end

wax.shared.Connect(wax.shared.UserInputService.InputChanged:Connect(function(Input: InputObject)
	if Drag.Dragging and wax.shared.IsMoveInput(Input) then
		local Delta = Input.Position - Drag.StartPosition
		local FramePosition: UDim2 = Drag.FramePosition

		Drag.Frame.Position = UDim2.new(
			FramePosition.X.Scale,
			FramePosition.X.Offset + Delta.X,
			FramePosition.Y.Scale,
			FramePosition.Y.Offset + Delta.Y
		)
	end
end))

return Drag
