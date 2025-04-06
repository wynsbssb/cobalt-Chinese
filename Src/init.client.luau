-- Environment
for _, Service in pairs({
	"CoreGui",
	"TweenService",
	"Players",
	"ContentProvider",
	"RunService",
	"UserInputService",
}) do
	wax.shared[Service] = cloneref(game:GetService(Service))
end

-- UI
require("Utils/Connect")

wax.shared.Drag = require("Utils/Drag")
wax.shared.Interface = require("Utils/Interface")
wax.shared.Icons = require("Utils/Icons")
wax.shared.Sonner = require("Utils/Sonner")

-- Variables
wax.shared.LocalPlayer = wax.shared.Players.LocalPlayer

-- Functions
wax.shared.gethui = gethui or function()
	return wax.shared.CoreGui
end
wax.shared.checkcaller = checkcaller or function()
	return nil
end

wax.shared.IsClickInput = function(Input: InputObject): boolean
	return Input.UserInputState == Enum.UserInputState.Begin
		and (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
end
wax.shared.IsMoveInput = function(Input: InputObject): boolean
	return Input.UserInputState == Enum.UserInputState.Change
		and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch)
end
wax.shared.IsMouseOverFrame = function(Frame: GuiObject, Position: Vector2): boolean
	local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
	return Position.X >= AbsPos.X
		and Position.X <= AbsPos.X + AbsSize.X
		and Position.Y >= AbsPos.Y
		and Position.Y <= AbsPos.Y + AbsSize.Y
end

wax.shared.Unload = function()
	for _, Connection in pairs(wax.shared.Connections) do
		wax.shared.Disconnect(Connection)
	end

	hookmetamethod(game, "__namecall", wax.shared.MetaHook)
	for Function, Original in pairs(wax.shared.Hooks) do
		hookfunction(Function, Original)
	end

	wax.shared.ScreenGui:Destroy()
end

-- Load Script
require("Window")

wax.shared.Logs = {}
wax.shared.LogRemote = function(RemoteInfo)
	local Log = wax.shared.Logs[RemoteInfo[1]]
	if not Log then
		Log = {
			Method = RemoteInfo[2],
			Calls = {},
		}
		wax.shared.Logs[RemoteInfo[1]] = Log
	end

	table.insert(Log.Calls, {
		IsExecutor = RemoteInfo[3],
		Script = RemoteInfo[4],
		Function = RemoteInfo[5],
		Line = RemoteInfo[6],
	})
end

require("Hooks/Spy")
