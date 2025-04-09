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
wax.shared.Highlighter = require("Utils/Highlighter")
wax.shared.Pagination = require("Utils/Pagination")

-- Variables
wax.shared.LocalPlayer = wax.shared.Players.LocalPlayer
wax.shared.ExecutorName = string.split(identifyexecutor(), " ")[1]

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

wax.shared.DisplayArgument = function(Argument)
	if typeof(Argument) == "string" then
		return string.format('"%s"', Argument)
	elseif typeof(Argument) == "table" then
		return "{...}"
	end

	return tostring(Argument)
end

wax.shared.Unload = function()
	for _, Connection in pairs(wax.shared.Connections) do
		wax.shared.Disconnect(Connection)
	end

	hookmetamethod(game, "__namecall", wax.shared.MetaHook)
	for Function, Original in pairs(wax.shared.Hooks) do
		if restorefunction then
			restorefunction(Function)
		else
			hookfunction(Function, Original)
		end
	end

	wax.shared.Communicator:Destroy()
	wax.shared.ScreenGui:Destroy()
end

-- Load Script
wax.shared.Communicator = Instance.new("BindableEvent")

wax.shared.Log = require("Utils/Log")
wax.shared.Logs = {}

wax.shared.NewLog = function(Instance, Method)
	local Log = wax.shared.Log.new(Instance, Method)
	wax.shared.Logs[Instance] = Log
	return Log
end

require("Window")
require("Spy/Init")
