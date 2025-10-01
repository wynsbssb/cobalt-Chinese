local FileLogger = require(script.Utils.FileLog)

-- 🔹 环境初始化
for _, Service in pairs({
	"ContentProvider",
	"CoreGui",
	"TweenService",
	"Players",
	"RunService",
	"HttpService",
	"UserInputService",
	"TextService",
	"StarterGui",
}) do
	wax.shared[Service] = cloneref(game:GetService(Service))
end

wax.shared.CobaltVerificationToken = wax.shared.HttpService:GenerateGUID()
wax.shared.SaveManager = require("Utils/SaveManager")
wax.shared.Settings = {}
wax.shared.Hooks = {}

-- 🔹 执行器支持模块
wax.shared.ExecutorSupport = require("ExecutorSupport")

-- 🔹 UI 相关模块
require("Utils/Connect")
wax.shared.ImageFetcher = require("Utils/ImageFetch")
wax.shared.LuaEncode = require("Utils/Serializer/LuaEncode")
wax.shared.Drag = require("Utils/Drag")
wax.shared.Interface = require("Utils/Interface")
wax.shared.Icons = require("Utils/Icons")
wax.shared.Animations = require("Utils/Animations")
wax.shared.Sonner = require("Utils/Sonner")
wax.shared.Highlighter = require("Utils/Highlighter")
wax.shared.Pagination = require("Utils/Pagination")
wax.shared.CodeGen = require("Utils/CodeGen")
wax.shared.Resize = require("Utils/Resize")
wax.shared.Hooking = require("Utils/Hooking")

-- 🔹 玩家相关变量
if not wax.shared.Players.LocalPlayer then
	wax.shared.Players.PlayerAdded:Wait()
end
wax.shared.LocalPlayer = wax.shared.Players.LocalPlayer
wax.shared.PlayerScripts = cloneref(wax.shared.LocalPlayer:WaitForChild("PlayerScripts"))
wax.shared.ExecutorName = identifyexecutor()

-- 🔹 常用函数包装
wax.shared.gethui = gethui or function()
	return wax.shared.CoreGui
end
wax.shared.checkcaller = checkcaller or function()
	return nil
end

-- 恢复 Hooked 函数
wax.shared.restorefunction = function(Function: (...any) -> ...any, Silent: boolean?)
	local Original = wax.shared.Hooks[Function]

	if Silent and not Original then
		return
	end
	assert(Original, "函数未被 Hook")

	if restorefunction and isfunctionhooked(Function) then
		restorefunction(Function)
	else
		wax.shared.Hooking.HookFunction(Function, Original)
	end

	wax.shared.Hooks[Function] = nil
end

-- 兼容性处理：getrawmetatable
wax.shared.getrawmetatable = wax.shared.ExecutorSupport["getrawmetatable"].IsWorking 
	and (getrawmetatable or debug.getmetatable) 
	or function()
		return setmetatable({}, {
			__index = function() return function() end end
		})
	end

-- 特殊执行器的 newcclosure 适配
wax.shared.newcclosure = wax.shared.ExecutorName == "AWP"
		and function(f)
			local env = getfenv(f)
			local x = setmetatable({ __F = f }, { __index = env, __newindex = env })

			local nf = function(...) return __F(...) end
			setfenv(nf, x) -- 设置函数环境
			return newcclosure(nf)
		end
	or newcclosure

wax.shared.queue_on_teleport = queue_on_teleport or queueonteleport or function(...) end

-- 🔹 输入检测函数
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
	return Position.X >= AbsPos.X and Position.X <= AbsPos.X + AbsSize.X
		and Position.Y >= AbsPos.Y and Position.Y <= AbsPos.Y + AbsSize.Y
end

-- 🔹 判断是否属于 PlayerModule 的远程
wax.shared.IsPlayerModule = function(Origin: LocalScript | ModuleScript, Instance: Instance): boolean
	if Instance and Instance.ClassName ~= "BindableEvent" then
		return false
	end

	if not Origin or typeof(Origin) ~= "Instance" or not Origin.IsA(Origin, "LuaSourceContainer") then
		return false
	end

	local PlayerModule = Origin and Origin.FindFirstAncestor(Origin, "PlayerModule") or nil
	if not PlayerModule then return false end
	if PlayerModule.Parent == nil then return true end

	return compareinstances(PlayerModule.Parent, wax.shared.PlayerScripts)
end

wax.shared.ShouldIgnore = function(Instance, Origin)
	return wax.shared.Settings.IgnoredRemotesDropdown.Value[Instance.ClassName] == true
		or (wax.shared.Settings.IgnorePlayerModule.Value and wax.shared.IsPlayerModule(Origin, Instance))
end

-- 🔹 格式化输出
wax.shared.DisplayNumber = function(Number: number)
	if Number % 1 ~= 0 then
		return string.format("%.3f", Number)
	elseif Number == 1 / 0 then
		return "math.huge"
	elseif Number == -1 / 0 then
		return "-math.huge"
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
		return string.format("%s, %s, %s",
			wax.shared.DisplayNumber(Argument.X),
			wax.shared.DisplayNumber(Argument.Y),
			wax.shared.DisplayNumber(Argument.Z)
		)
	elseif typeof(Argument) == "CFrame" then
		local Components = { Argument:GetComponents() }
		for Index, Value in pairs(Components) do
			Components[Index] = wax.shared.DisplayNumber(Value)
		end
		return table.concat(Components, ", ")
	elseif typeof(Argument) == "table" then
		return "{...}"
	elseif typeof(Argument) == "Instance" then
		return wax.shared.CodeGen.GetFullPath(Argument, true)
	elseif typeof(Argument) == "userdata" then
		return "newproxy(" .. getmetatable(Argument) and "true" or "false" .. ")"
	end
	return tostring(Argument)
end

-- 🔹 工具函数
wax.shared.GetTableLength = function(Table)
	if Table["n"] then return Table.n end
	local Length = 0
	for _, _ in pairs(Table) do Length += 1 end
	return Length
end

wax.shared.GetTextBounds = function(Text: string, Font: Font, Size: number, Width: number?): (number, number)
	local Params = Instance.new("GetTextBoundsParams")
	Params.Text = Text
	Params.RichText = true
	Params.Font = Font
	Params.Size = Size
	Params.Width = Width or workspace.CurrentCamera.ViewportSize.X - 32

	local Bounds = wax.shared.TextService:GetTextBoundsAsync(Params)
	return Bounds.X, Bounds.Y
end

-- 🔹 卸载逻辑
wax.shared.Unloaded = false
wax.shared.Unload = function()
	for _, Connection in pairs(wax.shared.Connections) do
		wax.shared.Disconnect(Connection)
	end

	local gameMetatable = wax.shared.getrawmetatable(game)

	if restorefunction and not wax.shared.AlternativeEnabled then
		pcall(restorefunction, gameMetatable.__namecall)
		pcall(restorefunction, gameMetatable.__newindex)
	else
		wax.shared.Hooking.HookMetaMethod(game, "__namecall", wax.shared.NamecallHook)
		wax.shared.Hooking.HookMetaMethod(game, "__newindex", wax.shared.NewIndexHook)
	end

	for Function, Original in pairs(wax.shared.Hooks) do
		task.spawn(pcall, wax.shared.restorefunction, Function, true)
	end

	if wax.shared.ActorCommunicator then
		wax.shared.ActorCommunicator:Fire("Unload")
	end

	wax.shared.Communicator:Destroy()
	wax.shared.ScreenGui:Destroy()
	wax.shared.Unloaded = true
end

require("Bypass")

-- 🔹 脚本加载与日志系统
wax.shared.Communicator = Instance.new("BindableEvent")

wax.shared.SetupLoggingConnection = function()
	if wax.shared.LogConnection then
		wax.shared.LogConnection:Disconnect()
	end

	wax.shared.LogFileName = `Cobalt/Logs/{DateTime.now():ToIsoDate():gsub(":", "_")}.log`
	local FileLog = FileLogger.new(wax.shared.LogFileName, FileLogger.LOG_LEVELS.INFO, true)

	return function(RemoteInstance, Type, CallOrderInLog)
		local LogEntry = wax.shared.Logs[Type][RemoteInstance]
		if not LogEntry then return end

		local CallDataFromHook = LogEntry.Calls[CallOrderInLog]

		local success, err = pcall(function()
			local generatedCode = wax.shared.CodeGen:BuildCallCode(setmetatable({
				Instance = RemoteInstance,
				Type = Type,
			}, { __index = CallDataFromHook }))

			local comprehensiveDataToSerialize = {
				RemoteInstanceInfo = {
					Name = RemoteInstance and RemoteInstance.Name,
					ClassName = RemoteInstance and RemoteInstance.ClassName,
					Path = RemoteInstance and wax.shared.CodeGen.GetFullPath(RemoteInstance, true),
				},
				EventType = Type,
				CallOrderInLog = CallOrderInLog,
				DataFromHook = CallDataFromHook,
			}

			local serializedEventData = wax.shared.LuaEncode(
				comprehensiveDataToSerialize,
				{ Prettify = true, InsertCycles = true, UseInstancePaths = true }
			)

			local instanceName = RemoteInstance and RemoteInstance.Name or "UnknownInstance"
			local instanceClassName = RemoteInstance and RemoteInstance.ClassName or "UnknownClass"
			local instancePath = RemoteInstance and wax.shared.CodeGen.GetFullPath(RemoteInstance, true) or "UnknownPath"

			local logParts = {
				("Instance: %s (%s)"):format(instanceName, instanceClassName),
				("Path: %s"):format(instancePath),
				("Call Order In Log: %s"):format(CallOrderInLog or "N/A"),
				"-------------------- 事件数据 --------------------",
				serializedEventData,
				"-------------------- 生成代码 --------------------",
				generatedCode,
			}
			local logMessage = table.concat(logParts, "\n\t")
			local threadId = ("%s:%s"):format(Type or "S", instanceName)

			FileLog:Info(threadId, logMessage)
		end)

		if not success then
			local instanceNameForError = RemoteInstance and RemoteInstance.Name or "Unknown"
			FileLog:Error("Logger",
				("记录远程通信失败 %s:%s - %s"):format(Type or "UnknownType", instanceNameForError, tostring(err))
			)
			warn(("Cobalt: 记录远程通信失败 %s:%s - %s"):format(Type or "UnknownType", instanceNameForError, tostring(err)))
		end
	end
end

-- 启用日志记录
if wax.shared.SaveManager:GetState("EnableLogging") then
	local LogConnection = wax.shared.SetupLoggingConnection()
	wax.shared.LogConnection = wax.shared.Connect(wax.shared.Communicator.Event:Connect(LogConnection))
end

-- 🔹 日志系统对象
wax.shared.Log = require("Utils/Log")
wax.shared.Logs = { Outgoing = {}, Incoming = {} }

wax.shared.NewLog = function(Instance, Type, Method, CallingScript)
	local Log = wax.shared.Log.new(Instance, Type, Method, wax.shared.GetTableLength(wax.shared.Logs[Type]) + 1, CallingScript)
	wax.shared.Logs[Type][Instance] = Log
	return Log
end

require("Window")
require("Spy/Init")

-- 🔹 传送时自动执行脚本
wax.shared.Connect(wax.shared.LocalPlayer.OnTeleport:Connect(function()
	if not wax.shared.SaveManager:GetState("ExecuteOnTeleport") then
		return
	end

	local CobaltURL = getgenv().COBALT_LATEST_URL or "https://github.com/notpoiu/cobalt/releases/latest/download/Cobalt.luau"
	wax.shared.queue_on_teleport(string.format([[
		if getgenv().CobaltAutoExecuted then return end
		getgenv().CobaltAutoExecuted = true
		loadstring(game:HttpGet("%s"))()
	]], CobaltURL))
end))

-- 🔹 反作弊提示
task.wait(1)
if wax.shared.AnticheatDisabled then
	wax.shared.Sonner.success(`Cobalt 已绕过 {wax.shared.AnticheatName} (检测到反作弊)`)
end
