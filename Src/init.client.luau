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
wax.shared.CodeGen = require("Utils/CodeGen")

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
wax.shared.restorefunction = function(Function: (...any) -> ...any, Silent: boolean?)
	local Original = wax.shared.Hooks[Function]

	if Silent and not Original then
		return
	end

	assert(Original, "Function not hooked")

	if restorefunction then
		restorefunction(Function)
	else
		hookfunction(Function, Original)
	end

	wax.shared.Hooks[Function] = nil
end
wax.shared.getrawmetatable = getrawmetatable or debug.getmetatable
wax.shared.newcclosure = wax.shared.ExecutorName == "AWP"
		and function(f)
			local env = getfenv(f)
			local x = setmetatable({
				__F = f,
			}, {
				__index = env,
				__newindex = env,
			})

			local nf = function(...)
				return __F(...)
			end
			setfenv(nf, x) -- set func env (env of nf gets deoptimized)
			return newcclosure(nf)
		end
	or newcclosure

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

wax.shared.DisplayNumber = function(Number: number)
	if Number % 1 ~= 0 then
		return string.format("%.3f", Number)
	end
	return Number
end
wax.shared.DisplayArgument = function(Argument)
	if typeof(Argument) == "string" then
		return string.format('"%s"', Argument)
	elseif typeof(Argument) == "number" then
		return wax.shared.DisplayNumber(Argument)
	elseif typeof(Argument) == "Vector2" then
		return string.format("%s, %s", wax.shared.DisplayNumber(Argument.X), wax.shared.DisplayNumber(Argument.Y))
	elseif typeof(Argument) == "Vector3" then
		return string.format(
			"%s, %s, %s",
			wax.shared.DisplayNumber(Argument.X),
			wax.shared.DisplayNumber(Argument.Y),
			wax.shared.DisplayNumber(Argument.Z)
		)
	elseif typeof(Argument) == "table" then
		return "{...}"
	elseif typeof(Argument) == "Instance" then
		return wax.shared.CodeGen.GetFullPath(Argument)
	end

	return tostring(Argument)
end

wax.shared.GetTableLength = function(Table)
	local Length = 0
	for _, _ in pairs(Table) do
		Length += 1
	end
	return Length
end

wax.shared.Unload = function()
	for _, Connection in pairs(wax.shared.Connections) do
		wax.shared.Disconnect(Connection)
	end

	hookmetamethod(game, "__namecall", wax.shared.NamecallHook)
	hookmetamethod(game, "__newindex", wax.shared.NewIndexHook)

	for Function, Original in pairs(wax.shared.Hooks) do
		wax.shared.restorefunction(Function, true)
	end

	wax.shared.Communicator:Destroy()
	wax.shared.ScreenGui:Destroy()
end

-- Load Script
wax.shared.Communicator = Instance.new("BindableEvent")

wax.shared.Log = require("Utils/Log")
wax.shared.Logs = {
	Outgoing = {},
	Incoming = {},
}

wax.shared.NewLog = function(Instance, Method, Type)
	local Log = wax.shared.Log.new(Instance, Method, wax.shared.GetTableLength(wax.shared.Logs[Type]) + 1)
	wax.shared.Logs[Type][Instance] = Log
	return Log
end

require("Window")
require("Spy/Init")
