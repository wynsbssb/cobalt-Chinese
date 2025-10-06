--[[
    Cobalt
    A runtime developer tool to monitor and intercept network traffic
    coming from the roblox game engine.
    
    This script is NOT intended to be modified.
    To view the source code, see the 'Src' folder on the official GitHub repository!

    Authors: deivid, upio
    GitHub: https://github.com/notpoiu/cobalt/                                      
--]]


-- ++++++++ WAX BUNDLED DATA BELOW ++++++++ --

-- Will be used later for getting flattened globals
local ImportGlobals

-- Holds direct closure data (defining this before the DOM tree for line debugging etc)
local ClosureBindings = {
    function()local wax,script,require=ImportGlobals(1)local ImportGlobals return (function(...)local FileLogger = require(script.Utils.FileLog)

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

end)() end,
    function()local wax,script,require=ImportGlobals(2)local ImportGlobals return (function(...)--[[
    Bypasses for popular roblox anticheats
]]

wax.shared.AnticheatDisabled = false
wax.shared.AnticheatName = "N/A"

local BypassState = wax.shared.SaveManager:GetState("AnticheatBypass")
local BypassEnabled = if typeof(BypassState) == "boolean" then BypassState else true
if not BypassEnabled then
	return
end

if not getreg or not getgc or not isfunctionhooked then
	return
end

local AdonisDetected = false

for _, thread in getreg() do
	if typeof(thread) ~= "thread" then
		continue
	end

	local Source = debug.info(thread, 1, "s")
	if Source and (Source:match(".Core.Anti") or Source:match(".Plugins.Anti_Cheat")) then
		AdonisDetected = true
		coroutine.close(thread)
	end
end

if not AdonisDetected then
	return
end

for _, value in getgc(true) do
	if typeof(value) ~= "table" then
		continue
	end

	local IsAdonisOrigin = typeof(rawget(value, "Detected")) == "function" and rawget(value, "RLocked")
	if IsAdonisOrigin then
		for _, DetectionFunc in value do
			-- Just in case they already loaded a custom anticheat bypass for adonis
			if typeof(DetectionFunc) ~= "function" or isfunctionhooked(DetectionFunc) then
				continue
			end
			
			wax.shared.Hooks[DetectionFunc] = wax.shared.Hooking.HookFunction(
				DetectionFunc,
				function(action, info, nocrash)
					coroutine.yield(coroutine.running())
					return task.wait(9e9)
				end
			)
		end

		wax.shared.AnticheatDisabled = true
		wax.shared.AnticheatName = "Adonis"
	end
end

end)() end,
    function()local wax,script,require=ImportGlobals(3)local ImportGlobals return (function(...)--[[
	非常轻量的检测器，用于检查各种执行器函数是否存在并能正常工作。
	部分检测还会验证函数是否按预期工作，而不仅仅是存在。
]]

local ExecutorSupport = {
	FailedChecks = {}, -- 保存失败的检测项
}

-- 检查 FFlag 值
local function CheckFFlagValue(Name: string, Value: any)
	local Success, Result = pcall(getfflag, Name)
	if not Success then
		return false
	end

	if typeof(Result) == "boolean" then
		return Result
	end

	if typeof(Result) == "string" then
		return Result == tostring(Value)
	end

	return false
end

-- 测试函数封装
local function test(name, Callback, CheckType)
	local TestFunction = not CheckType and Callback or function()
		return typeof(Callback) == "function"
	end

	local Success, Result = pcall(TestFunction)
	ExecutorSupport[name] = {
		IsWorking = Success, -- 是否可用
		Details = Result,    -- 结果信息
	}

	if not Success then
		table.insert(ExecutorSupport.FailedChecks, name)
	end
end

-- 🔹 FFlag 库检测
test("getfflag", getfflag, true)
test("setfflag", setfflag, true)

-- 🔹 Actor 库检测
test("getactors", getactors, true)
test("run_on_actor", run_on_actor, true)
test("getnilinstances", getnilinstances, true)

-- 🔹 闭包库检测
test("newcclosure", function()
	assert(typeof(newcclosure) == "function", "newcclosure 不是函数")
	local CClosure = newcclosure(function() return true end)

	assert(typeof(CClosure) == "function", "newcclosure 没有返回函数")
	assert(CClosure() == true, "未能创建新的闭包")
	
	assert(debug.info(CClosure, "s") == "[C]", "newcclosure 未能创建 C 闭包")
end, true)

test("checkcaller", checkcaller, true)
test("getcallingscript", getcallingscript, true)

-- hookfunction 测试
test("hookfunction", function()
	assert(typeof(hookfunction) == "function", "hookfunction 不是函数")
	
	local function Original(a, b)
		return a + b
	end

	local ref = hookfunction(Original, function(a, b)
		return a * b
	end)

	assert(Original(2, 3) == 6, "未能 hook 函数并改变返回值")
	assert(ref(2, 3) == 5, "未返回原始函数")
end)

-- isfunctionhooked 测试
test("isfunctionhooked", function()
	assert(typeof(isfunctionhooked) == "function", "isfunctionhooked 不是函数")
	assert(typeof(hookfunction) == "function", "此测试需要 hookfunction")
	
	local function Original(a, b)
		return a + b
	end

	assert(isfunctionhooked(Original) == false, "未 hook 的函数返回了 true")

	hookfunction(Original, function(a, b)
		return a * b
	end)

	assert(isfunctionhooked(Original) == true, "已 hook 的函数返回了 false")
end)

-- restorefunction 测试
test("restorefunction", function()
	assert(typeof(restorefunction) == "function", "restorefunction 不是函数")
	assert(typeof(hookfunction) == "function", "此测试需要 hookfunction")
	
	local function Original(a, b)
		return a + b
	end

	hookfunction(Original, function(a, b)
		return a * b
	end)

	assert(Original(2, 3) == 6, "未能 hook 函数")

	restorefunction(Original)

	assert(Original(2, 3) == 5, "restorefunction 未能恢复原始函数")
end)

-- 🔹 元方法 hook 测试
test("hookmetamethod", function()
	assert(typeof(hookmetamethod) == "function", "hookmetamethod 不是函数")
	
	local object = setmetatable({}, {
		__index = newcclosure(function() return false end),
		__metatable = "Locked!"
	})

	local ref = hookmetamethod(object, "__index", function()
		return true
	end)

	assert(object.test == true, "未能 hook metamethod 并改变返回值")
	assert(ref() == false, "未返回原始函数")
end)

-- getnamecallmethod 测试
test("getnamecallmethod", function()
	assert(typeof(getnamecallmethod) == "function", "getnamecallmethod 不是函数")

	pcall(function()
		game:TEST_NAMECALL_METHOD()
	end)

	assert(
		getnamecallmethod() == "TEST_NAMECALL_METHOD",
		"getnamecallmethod 未返回真实的方法名"
	)
end)

-- getrawmetatable 测试
test("getrawmetatable", function()
	assert(typeof(getrawmetatable) == "function", "getrawmetatable 不是函数")

	local BaseLockedMetatable = {
		__index = function() return false end,
		__metatable = "Locked!"
	}

	local TestMetatable = setmetatable({}, BaseLockedMetatable)

	local FetchedMetatable = getrawmetatable(TestMetatable)
	assert(typeof(FetchedMetatable) == "table", "getrawmetatable 未返回表")
	
	assert(FetchedMetatable.__index() == false, "未返回正确的 __index()")
	assert(FetchedMetatable.__metatable == "Locked!", "未返回正确的锁定 mt")

	assert(FetchedMetatable == BaseLockedMetatable, "未返回相同的元表")
end)

-- 🔹 实例相关函数检测
test("getcallbackvalue", function()
	assert(typeof(getcallbackvalue) == "function", "getcallbackvalue 不是函数")

	local bindable = Instance.new("BindableFunction")
	local InvokeFunction = function(value) return value * 2 end
	bindable.OnInvoke = InvokeFunction

	local FetchedInvoke = getcallbackvalue(bindable, "OnInvoke")
	bindable:Destroy()

	assert(typeof(FetchedInvoke) == "function", "未返回函数")
	assert(FetchedInvoke(5) == 10, "未返回正确结果")
	assert(FetchedInvoke == InvokeFunction, "未返回原始函数")
end)

test("getnilinstances", function()
	assert(typeof(getnilinstances) == "function", "getnilinstances 不是函数")

	local NilInstances = getnilinstances()
	assert(typeof(NilInstances) == "table", "未返回表")
end)

test("getconnections", function()
	assert(typeof(getconnections) == "function", "getconnections 不是函数")

	local Event = Instance.new("BindableEvent")
	local ConnectionFunction = function() end
	local OnceFunction = function() end
	
	Event.Event:Connect(ConnectionFunction)
	Event.Event:Once(OnceFunction)
	task.spawn(function() Event.Event:Wait() end)

	local Connections = getconnections(Event.Event)

	assert(typeof(Connections) == "table", "未返回表")
	assert(#Connections == 3, "返回的连接数量错误")

	local FoundFunctions = {}
	for _, Connection in Connections do
		local _, ConnFunc = pcall(function()
			return Connection.Function
		end)

		if typeof(ConnFunc) == "function" then
			table.insert(FoundFunctions, ConnFunc)
		end
	end

	assert(table.find(FoundFunctions, ConnectionFunction) ~= nil, "未找到正确的 [:Connect()] 连接")
	assert(table.find(FoundFunctions, OnceFunction) ~= nil, "未找到正确的 [:Once()] 连接")

	Event:Destroy()
end)

test("firesignal", function()
	assert(typeof(firesignal) == "function", "firesignal 不是函数")
	
	local event = Instance.new("BindableEvent")
	local fired = false

	event.Event:Once(function(value)
		fired = value
	end)

	firesignal(event.Event, true)
	task.wait(0.1)
	event:Destroy()

	assert(fired, "未能触发 BindableEvent")
end)

test("cloneref", function()
	assert(typeof(cloneref) == "function", "cloneref 不是函数")

	local ref = cloneref(game)
	assert(ref ~= game, "未正确克隆实例引用")
	assert(typeof(ref) == "Instance", "未返回实例")
end)

test("compareinstances", function()
	assert(typeof(compareinstances) == "function", "compareinstances 不是函数")
	assert(typeof(cloneref) == "function", "此测试需要 cloneref")

	assert(compareinstances(game, cloneref(game)) == true, "相同实例未返回 true")
	assert(compareinstances(game, workspace) == false, "不同实例未返回 false")
end)

-- 🔹 针对 Actor 和 FFlag 的补充检测
if CheckFFlagValue("DebugRunParallelLuaOnMainThread", false) and not ExecutorSupport["run_on_actor"].IsWorking then
	task.spawn(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		
		local GameUsesActors = false
		
		local CategoryToSearch = { game:GetDescendants() }
		if ExecutorSupport["getnilinstances"].IsWorking then
			table.insert(CategoryToSearch, getnilinstances())
		end

		for _, Category in CategoryToSearch do
			if GameUsesActors then
				break
			end
		
			for _, Instance in Category do
				if not Instance:IsA("Actor") then
					continue
				end
		
				GameUsesActors = true
				break
			end
		end
		
		if not GameUsesActors then
			return
		end
		
		local bindable = Instance.new("BindableFunction")
	
		function bindable.OnInvoke(response)
			if response == "Set FFlag" then
				setfflag("DebugRunParallelLuaOnMainThread", "true")
				wax.shared.StarterGui:SetCore("SendNotification", {
					Title = "Cobalt",
					Text = "请重新加入以使 FFlag 生效！",
					Duration = math.huge,
				})
			end
	
			bindable:Destroy()
		end
	
		wax.shared.StarterGui:SetCore("SendNotification", {
			Title = "Cobalt",
			Text = "检测到可能使用了 Actors，但你的执行器不支持。我们可以为你设置一个 FFlag，下次加入时即可检测到 Actor remotes。",
			Duration = math.huge,
			Callback = bindable,
			Button1 = "设置 FFlag",
			Button2 = "取消",
		})
	end)
end

return ExecutorSupport

end)() end,
    function()local wax,script,require=ImportGlobals(4)local ImportGlobals return (function(...)local Hooks = script.Parent.Hooks

-- Main Thread Hooks
for _, Hook in ipairs(Hooks.Default:GetChildren()) do
	task.spawn(require, Hook)
end

-- Actors use a different lua vm
-- This means that our main thread metatable hooks dont apply in the actor's vm
-- So we need to set up the hooks again in the actor lua vm in order to log everything
local ActorsUtils = script.Parent.Actors

local TargetActor = getactors and getactors()[1] or nil
wax.shared.ActorsEnabled = (create_comm_channel and run_on_actor and TargetActor) ~= nil

if wax.shared.ActorsEnabled then
	local ActorEnvironementCode = ActorsUtils.Environement.Value

	local CommunicationChannelID, Channel = create_comm_channel()
	wax.shared.ActorCommunicator = get_comm_channel(CommunicationChannelID)

	local UseAltHooks = wax.shared.SaveManager:GetState("UseAlternativeHooks")
	local AlternativeEnabled = typeof(UseAltHooks) == "boolean" and UseAltHooks or false

	local IgnorePlayerModule = wax.shared.SaveManager:GetState("IgnorePlayerModule")
	local IngoredRemotesDropdown = wax.shared.SaveManager:GetState("IgnoredRemotesDropdown")

	local ActorData = wax.shared.LuaEncode({
		Token = wax.shared.CobaltVerificationToken,

		IgnorePlayerModule = if typeof(IgnorePlayerModule) == "boolean" then IgnorePlayerModule else true,
		IgnoredRemotesDropdown = if typeof(IngoredRemotesDropdown) == "table"
			then IngoredRemotesDropdown
			else {
				["BindableEvent"] = true,
				["BindableFunction"] = true,
			},
		UseAlternativeHooks = AlternativeEnabled,

		ExecutorSupport = wax.shared.ExecutorSupport,
	})

	ActorEnvironementCode = ActorEnvironementCode:gsub("COBALT_ACTOR_DATA", ActorData)

	local function ReconstructTable(Info, CyclicRefs)
		local Reconstructed = {}

		for Key, Value in Info do
			if type(Value) == "table" then
				if Value["__Function"] and Value["Validation"] == wax.shared.CobaltVerificationToken then
					local FunctionData = table.clone(Value)
					FunctionData["__Function"] = nil
					FunctionData["Validation"] = nil

					Reconstructed[Key] = FunctionData
					continue
				end

				-- Check for Cobalt Created Object
				if not Value["__CyclicRef"] then
					Reconstructed[Key] = ReconstructTable(Value, CyclicRefs)
					continue
				end

				local CyclicId = Value["__Id"]

				if not CyclicRefs[CyclicId] then
					warn("CyclicRef not found: " .. CyclicId)
					continue
				end

				Reconstructed[Key] = CyclicRefs[CyclicId]
				continue
			end

			Reconstructed[Key] = Value
		end

		return Reconstructed
	end

	wax.shared.Connect(Channel.Event:Connect(function(EventType, ...)
		local LogActors = wax.shared.SaveManager:GetState("LogActors")
		local ShouldLogActors = typeof(LogActors) ~= "boolean" and true or LogActors

		if not ShouldLogActors then
			return
		end

		if EventType ~= "ActorCall" then
			return
		end

		local Instance, Type, RawInfo, CyclicRefs = ...
		local Method = wax.shared.FunctionForClasses[Type][Instance.ClassName]
		local Log = wax.shared.Logs[Type][Instance]

		if not Log then
			Log = wax.shared.NewLog(Instance, Type, Method, RawInfo.Origin)
		end

		if Log.Blocked then
			return
		elseif not Log.Ignored then
			local ReconstructedInfo = ReconstructTable(RawInfo, CyclicRefs)
			
			Log:Call(ReconstructedInfo)
			wax.shared.Communicator:Fire(Log.Instance, Type, #Log.Calls)
		end
	end))

	for _, ActorHook in ipairs(Hooks.Actors:GetChildren()) do
		run_on_actor(TargetActor, ActorEnvironementCode .. ActorHook.Value, CommunicationChannelID)
	end

	run_on_actor(TargetActor, ActorsUtils.Unload.Value, CommunicationChannelID)
end

end)() end,
    [13] = function()local wax,script,require=ImportGlobals(13)local ImportGlobals return (function(...)local ClassesToHook = {
	RemoteEvent = "OnClientEvent",
	RemoteFunction = "OnClientInvoke",
	UnreliableRemoteEvent = "OnClientEvent",
	BindableEvent = "Event",
	BindableFunction = "OnInvoke",
}

type InstancesToHook = RemoteEvent | UnreliableRemoteEvent | RemoteFunction | BindableEvent | BindableFunction
type MethodsToHook = "OnClientEvent" | "OnClientInvoke" | "Event" | "OnInvoke"

local LogConnectionFunctions = {}
local SignalMapping = setmetatable({}, { __mode = "kv" })

--[[
	Returns the calling line of the script that called the function via `debug.info`

	@return number Returns the line number of the calling script.
]]
local function getcallingline()
	for i = 4, 10 do
		local Source, Line = debug.info(i, "sl")
		if not Source then
			break
		end

		if Source == "[C]" then
			continue
		end

		return Line
	end

	return debug.info(4, "l")
end

--[[
	Individually logs an incoming remote call.

	@param Instance The instance that was called.
	@param Method The method that was called (e.g., "OnClientEvent").
	@param Function The function that was called, if applicable.
	@param Info The information about the call, including arguments and origin. Can be nil.
	@param ... The arguments passed from the server to the client.
	@return boolean Returns true if the call was blocked, false otherwise.
]]
local function LogRemote(
	Instance: InstancesToHook,
	Method: MethodsToHook,
	Function: (...any) -> ...any,
	Info: {
		Arguments: { [number]: any, n: number },
		Time: string,
		Origin: Instance,
		Function: (...any) -> ...any,
		Line: number,
		IsExecutor: boolean,
	} | nil,
	...
)
	if not wax.shared.ShouldIgnore(Instance, getcallingscript()) and not LogConnectionFunctions[Function] then
		local Log = wax.shared.Logs.Incoming[Instance]
		if not Log then
			Log = wax.shared.NewLog(Instance, "Incoming", Method, getcallingscript())
		end

		if Log.Blocked then
			return true
		elseif not Log.Ignored then
			local CallInfo = Info
				or {
					Arguments = table.pack(...),
					Time = os.date("%X"),
					Origin = getcallingscript(),
					Function = Function,
					Line = getcallingline(),
					IsExecutor = checkcaller(),
				}
			Log:Call(CallInfo)
			wax.shared.Communicator:Fire(Log.Instance, "Incoming", #Log.Calls)
		end
	end

	return false
end

--[[
	Creates a function that can be used to pass to `Connect` which will log all the incoming calls. It will additonally add the function to a ignore list (`LogConnectionFunctions`) to prevent unneccessary logging.
	
	@param Instance The instance to log.
	@param Method The method to log (e.g., "OnClientEvent").
	@return function Returns a function that logs all calls to the given instance and method.
]]
local function CreateConnectionFunction(Instance: InstancesToHook, Method: MethodsToHook)
	local ConnectionFunction = function(...)
		for _, Connection in pairs(getconnections((Instance :: any)[Method])) do
			if Connection.ForeignState then
				continue
			end

			local Function = typeof(Connection.Function) == "function" and Connection.Function or nil
			local Thread = Connection.Thread

			local Origin = nil

			if Thread and getscriptfromthread then
				Origin = getscriptfromthread(Thread)
			elseif Function then
				-- ts is unreliable because people could js set the script global to nil
				-- if only debug.getinfo(Function).source or debug.info(Function, "s") returned an Instance...

				local Script = rawget(getfenv(Function), "script")
				if typeof(Script) == "Instance" then
					Origin = Script
				end
			end

			LogRemote(Instance, Method, Function, {
				Arguments = table.pack(...),
				Time = os.date("%X"),
				Origin = Origin,
				Function = Function,
				Line = nil,
				IsExecutor = Function and isexecutorclosure(Function) or false,
			}, ...)
		end
	end

	LogConnectionFunctions[ConnectionFunction] = true
	return ConnectionFunction
end

--[[
	Handles setting up logging for the appropriate instances.

	@param Instance The instance to handle.
]]
local function HandleInstance(Instance: any)
	if not ClassesToHook[Instance.ClassName] or Instance == wax.shared.Communicator then
		return
	end

	local Method = ClassesToHook[Instance.ClassName]

	if Instance.ClassName == "RemoteEvent" or Instance.ClassName == "UnreliableRemoteEvent" then
		wax.shared.Connect(Instance.OnClientEvent:Connect(CreateConnectionFunction(Instance, Method)))

		SignalMapping[Instance.OnClientEvent] = Instance
	elseif Instance.ClassName == "BindableEvent" then
		wax.shared.Connect(Instance.Event:Connect(CreateConnectionFunction(Instance, Method)))

		SignalMapping[Instance.Event] = Instance
	elseif Instance.ClassName == "RemoteFunction" or Instance.ClassName == "BindableFunction" then
		local Success, Callback = pcall(getcallbackvalue, Instance, Method)
		local IsCallable = (
			typeof(Callback) == "function"
			or wax.shared.getrawmetatable(Callback) ~= nil and typeof(wax.shared.getrawmetatable(Callback)["__call"]) == "function"
			or false
		)

		if not Success or not IsCallable then
			return
		end

		Instance[Method] = function(...)
			if LogRemote(Instance, Method, Callback, nil, ...) then
				return
			end

			return Callback(...)
		end
	end
end

wax.shared.Connect(game.DescendantAdded:Connect(HandleInstance))

-- getinstances() was unreliable and failed to find some instances... ts pmo bro..
local CategoryToSearch = { game:GetDescendants() }
if wax.shared.ExecutorSupport["getnilinstances"].IsWorking then
	table.insert(CategoryToSearch, getnilinstances())
end

for _, Category in CategoryToSearch do
	for _, Instance in pairs(Category) do
		HandleInstance(Instance)
	end
end

wax.shared.NewIndexHook = wax.shared.Hooking.HookMetaMethod(
	game,
	"__newindex",
	wax.shared.newcclosure(function(...)
		local self, key, value = ...

		if typeof(self) ~= "Instance" or not ClassesToHook[self.ClassName] then
			return wax.shared.NewIndexHook(...)
		end

		if self.ClassName == "RemoteFunction" or self.ClassName == "BindableFunction" then
			local Method = ClassesToHook[self.ClassName]

			local IsCallable = (
				typeof(value) == "function"
				or wax.shared.getrawmetatable(value) ~= nil and typeof(wax.shared.getrawmetatable(value)["__call"]) == "function"
				or false
			)

			if key == Method and IsCallable then
				return wax.shared.NewIndexHook(self, key, function(...)
					if LogRemote(self :: InstancesToHook, Method, value, nil, ...) then
						return
					end

					return value(...)
				end)
			end
		end

		return wax.shared.NewIndexHook(...)
	end)
)

local ConnectionKeys = {
	"Connect",
	"ConnectParallel",
	"connect",
	"connectParallel",
	"once",
	"Once",
}

local SignalMetatable = wax.shared.getrawmetatable(Instance.new("Part").Touched)
wax.shared.Hooks[SignalMetatable.__index] = wax.shared.Hooking.HookFunction(SignalMetatable.__index, function(...)
	local self, key = ...

	if table.find(ConnectionKeys, key) then
		local Instance = SignalMapping[self]
		local Connect = wax.shared.Hooks[SignalMetatable.__index](...)

		if not Instance then
			return Connect
		end

		local Method = ClassesToHook[Instance.ClassName]
		wax.shared.Hooks[Connect] = wax.shared.Hooking.HookFunction(
			Connect,
			wax.shared.newcclosure(function(...)
				local _self, callback = ...

				local Result = table.pack(wax.shared.Hooks[Connect](...))
				local Log = wax.shared.Logs.Incoming[Instance]

				if Log and Log.Blocked then
					for _, Connection in pairs(getconnections(Instance[Method])) do
						if not Connection.ForeignState and Connection.Function ~= callback then
							continue
						end

						Connection:Disable()
					end
				end

				return table.unpack(Result, 1, Result.n)
			end)
		)

		return Connect
	end

	return wax.shared.Hooks[SignalMetatable.__index](...)
end)

end)() end,
    [14] = function()local wax,script,require=ImportGlobals(14)local ImportGlobals return (function(...)local NamecallMethods = {
	"FireServer",
	"InvokeServer",
	"Fire",
	"Invoke",
	"fireServer",
	"invokeServer",
	"fire",
	"invoke",
}
local AllowedClassNames =
	{ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent", "BindableFunction" }

--[[
	Returns the calling function via `debug.info`

	@return `function | nil` The calling function or nil if not found.
]]
local function getcallingfunction()
	for i = 4, 10 do
		local Function, Source = debug.info(i, "fs")
		if not Function or not Source then
			break
		end

		if Source == "[C]" then
			continue
		end

		return Function
	end

	return debug.info(4, "f")
end

--[[
	Returns the calling line of the script that called the function via `debug.info`

	@return number Returns the line number of the calling script.
]]
local function getcallingline()
	for i = 4, 10 do
		local Source, Line = debug.info(i, "sl")
		if not Source then
			break
		end

		if Source == "[C]" then
			continue
		end

		return Line
	end

	return debug.info(4, "l")
end

-- metamethod hooks
wax.shared.NamecallHook = wax.shared.Hooking.HookMetaMethod(
	game,
	"__namecall",
	wax.shared.newcclosure(function(...)
		local self = ...
		local Method = getnamecallmethod()

		if
			typeof(self) == "Instance"
			and table.find(AllowedClassNames, self.ClassName)
			and not rawequal(self, wax.shared.Communicator)
			and table.find(NamecallMethods, Method)
			and not wax.shared.ShouldIgnore(self, getcallingscript())
		then
			local Log = wax.shared.Logs.Outgoing[self]
			if not Log then
				Log = wax.shared.NewLog(self, "Outgoing", Method, getcallingscript())
			end

			if Log.Blocked then
				return
			elseif not Log.Ignored then
				local Info = {
					Arguments = table.pack(select(2, ...)),
					Time = os.date("%X"),
					Origin = getcallingscript(),
					Function = getcallingfunction(),
					Line = getcallingline(),
					IsExecutor = checkcaller(),
				}
				Log:Call(Info)
				wax.shared.Communicator.Fire(wax.shared.Communicator, Log.Instance, "Outgoing", #Log.Calls)

				-- For RemoteFunction return value (ex: local result = RemoteFunction:InvokeServer())
				if self.ClassName == "RemoteFunction" and (Method == "InvokeServer" or Method == "invokeServer") then
					Log = wax.shared.Logs.Incoming[self]
					if not Log then
						Log = wax.shared.NewLog(self, "Incoming", Method, getcallingscript())
					end

					if Log.Blocked then
						return
					end

					local Result = table.pack(wax.shared.NamecallHook(...))
					if not Log.Ignored then
						local RFResultInfo = {
							Arguments = Result,
							Time = os.date("%X"),
							Origin = getcallingscript(),
							Function = getcallingfunction(),
							Line = getcallingline(),
							IsExecutor = checkcaller(),
							OriginalInvokeArgs = table.pack(select(2, ...)),
						}
						Log:Call(RFResultInfo)
						wax.shared.Communicator:Fire(Log.Instance, "Incoming", #Log.Calls)
					end

					return table.unpack(Result, 1, Result.n)
				end
			end
		end

		return wax.shared.NamecallHook(...)
	end)
)

-- function hooks
local FunctionsToHook = {
	Instance.new("BindableFunction").Invoke,
	Instance.new("RemoteFunction").InvokeServer,
	Instance.new("BindableEvent").Fire,
	Instance.new("RemoteEvent").FireServer,
	Instance.new("UnreliableRemoteEvent").FireServer,
}

for _, Function in pairs(FunctionsToHook) do
	local Method = debug.info(Function, "n")

	wax.shared.Hooks[Function] = wax.shared.Hooking.HookFunction(
		Function,
		wax.shared.newcclosure(function(...)
			local self = ...

			if
				typeof(self) == "Instance"
				and table.find(AllowedClassNames, self.ClassName)
				and not rawequal(self, wax.shared.Communicator)
				and not wax.shared.ShouldIgnore(self, getcallingscript())
			then
				local Log = wax.shared.Logs.Outgoing[self]
				if not Log then
					Log = wax.shared.NewLog(self, "Outgoing", Method, getcallingscript())
				end

				if Log.Blocked then
					return
				elseif not Log.Ignored then
					local Info = {
						Arguments = table.pack(select(2, ...)),
						Time = os.date("%X"),
						Origin = getcallingscript(),
						Function = getcallingfunction(),
						Line = getcallingline(),
						IsExecutor = checkcaller(),
					}
					Log:Call(Info)
					wax.shared.Communicator:Fire(Log.Instance, "Outgoing", #Log.Calls)

					-- For RemoteFunction return value (ex: local result = RemoteFunction:InvokeServer())
					if
						self.ClassName == "RemoteFunction"
						and (Method == "InvokeServer" or Method == "invokeServer")
					then
						Log = wax.shared.Logs.Incoming[self]
						if not Log then
							Log = wax.shared.NewLog(self, "Incoming", Method, getcallingscript())
						end

						if Log.Blocked then
							return
						end

						local Result = table.pack(wax.shared.Hooks[Function](...))
						if not Log.Ignored then
							local RFResultInfo = {
								Arguments = Result,
								Time = os.date("%X"),
								Origin = getcallingscript(),
								Function = getcallingfunction(),
								Line = getcallingline(),
								IsExecutor = checkcaller(),
								OriginalInvokeArgs = table.pack(select(2, ...)),
							}
							Log:Call(RFResultInfo)
							wax.shared.Communicator:Fire(Log.Instance, "Incoming", #Log.Calls)
						end

						return table.unpack(Result, 1, Result.n)
					end
				end
			end

			return wax.shared.Hooks[Function](...)
		end)
	)
end

end)() end,
    [15] = function()local wax,script,require=ImportGlobals(15)local ImportGlobals return (function(...)local Hooks = script.Parent.Hooks

-- Main Thread Hooks
for _, Hook in ipairs(Hooks.Default:GetChildren()) do
	task.spawn(require, Hook)
end

-- Actors use a different lua vm
-- This means that our main thread metatable hooks dont apply in the actor's vm
-- So we need to set up the hooks again in the actor lua vm in order to log everything
local ActorsUtils = script.Parent.Actors

local TargetActor = getactors and getactors()[1] or nil
wax.shared.ActorsEnabled = (create_comm_channel and run_on_actor and TargetActor) ~= nil

if wax.shared.ActorsEnabled then
	local ActorEnvironementCode = ActorsUtils.Environement.Value

	local CommunicationChannelID, Channel = create_comm_channel()
	wax.shared.ActorCommunicator = get_comm_channel(CommunicationChannelID)

	local UseAltHooks = wax.shared.SaveManager:GetState("UseAlternativeHooks")
	local AlternativeEnabled = typeof(UseAltHooks) == "boolean" and UseAltHooks or false

	local IgnorePlayerModule = wax.shared.SaveManager:GetState("IgnorePlayerModule")
	local IngoredRemotesDropdown = wax.shared.SaveManager:GetState("IgnoredRemotesDropdown")

	local ActorData = wax.shared.LuaEncode({
		Token = wax.shared.CobaltVerificationToken,

		IgnorePlayerModule = if typeof(IgnorePlayerModule) == "boolean" then IgnorePlayerModule else true,
		IgnoredRemotesDropdown = if typeof(IngoredRemotesDropdown) == "table"
			then IngoredRemotesDropdown
			else {
				["BindableEvent"] = true,
				["BindableFunction"] = true,
			},
		UseAlternativeHooks = AlternativeEnabled,

		ExecutorSupport = wax.shared.ExecutorSupport,
	})

	ActorEnvironementCode = ActorEnvironementCode:gsub("COBALT_ACTOR_DATA", ActorData)

	local function ReconstructTable(Info, CyclicRefs)
		local Reconstructed = {}

		for Key, Value in Info do
			if type(Value) == "table" then
				if Value["__Function"] and Value["Validation"] == wax.shared.CobaltVerificationToken then
					local FunctionData = table.clone(Value)
					FunctionData["__Function"] = nil
					FunctionData["Validation"] = nil

					Reconstructed[Key] = FunctionData
					continue
				end

				-- Check for Cobalt Created Object
				if not Value["__CyclicRef"] then
					Reconstructed[Key] = ReconstructTable(Value, CyclicRefs)
					continue
				end

				local CyclicId = Value["__Id"]

				if not CyclicRefs[CyclicId] then
					warn("CyclicRef not found: " .. CyclicId)
					continue
				end

				Reconstructed[Key] = CyclicRefs[CyclicId]
				continue
			end

			Reconstructed[Key] = Value
		end

		return Reconstructed
	end

	wax.shared.Connect(Channel.Event:Connect(function(EventType, ...)
		local LogActors = wax.shared.SaveManager:GetState("LogActors")
		local ShouldLogActors = typeof(LogActors) ~= "boolean" and true or LogActors

		if not ShouldLogActors then
			return
		end

		if EventType ~= "ActorCall" then
			return
		end

		local Instance, Type, RawInfo, CyclicRefs = ...
		local Method = wax.shared.FunctionForClasses[Type][Instance.ClassName]
		local Log = wax.shared.Logs[Type][Instance]

		if not Log then
			Log = wax.shared.NewLog(Instance, Type, Method, RawInfo.Origin)
		end

		if Log.Blocked then
			return
		elseif not Log.Ignored then
			local ReconstructedInfo = ReconstructTable(RawInfo, CyclicRefs)
			
			Log:Call(ReconstructedInfo)
			wax.shared.Communicator:Fire(Log.Instance, Type, #Log.Calls)
		end
	end))

	for _, ActorHook in ipairs(Hooks.Actors:GetChildren()) do
		run_on_actor(TargetActor, ActorEnvironementCode .. ActorHook.Value, CommunicationChannelID)
	end

	run_on_actor(TargetActor, ActorsUtils.Unload.Value, CommunicationChannelID)
end

end)() end,
    [17] = function()local wax,script,require=ImportGlobals(17)local ImportGlobals return (function(...)local Animations = {
	TweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Exponential),
	Exclusions = {},
	Expectations = { In = {}, Out = {} },
}

local function GetTransparencyProperty(object)
	if table.find(Animations.Exclusions, object) then
		return nil
	end

	if object:IsA("TextButton") or object:IsA("TextLabel") or object:IsA("TextBox") then
		return { "TextTransparency" }
	elseif object:IsA("Frame") then
		return { "BackgroundTransparency" }
	elseif object:IsA("ScrollingFrame") then
		return { "ScrollBarImageTransparency" }
	elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
		return { "ImageTransparency", "BackgroundTransparency" }
	elseif object:IsA("UIStroke") then
		return { "Transparency" }
	end

	return nil
end

local function BuildPropertyTable(properties, type, object)
	if Animations.Expectations[type][object] then
		return Animations.Expectations[type][object]
	end

	local propTable = {}
	for _, prop in properties do
		propTable[prop] = type == "In" and 0 or 1
	end
	return propTable
end

function Animations.FadeOut(object, time)
	local tweenInfo = time and TweenInfo.new(time, Enum.EasingStyle.Exponential) or Animations.TweenInfo
	local properties = GetTransparencyProperty(object)
	if properties then
		wax.shared.TweenService:Create(object, tweenInfo, BuildPropertyTable(properties, "Out", object)):Play()
	end

	for _, child in object:GetDescendants() do
		local prop = GetTransparencyProperty(child)
		if not prop then
			continue
		end

		wax.shared.TweenService:Create(child, tweenInfo, BuildPropertyTable(prop, "Out", child)):Play()
	end
end

function Animations.FadeIn(object, time)
	local tweenInfo = time and TweenInfo.new(time, Enum.EasingStyle.Exponential) or Animations.TweenInfo
	local property = GetTransparencyProperty(object)
	if property then
		wax.shared.TweenService:Create(object, tweenInfo, BuildPropertyTable(property, "In", object)):Play()
	end

	for _, child in object:GetDescendants() do
		local prop = GetTransparencyProperty(child)
		if not prop then
			continue
		end

		wax.shared.TweenService:Create(child, tweenInfo, BuildPropertyTable(prop, "In", child)):Play()
	end
end

function Animations.AddFadeExclusion(object)
	local prop = GetTransparencyProperty(object)
	if not prop then
		return
	end

	table.insert(Animations.Exclusions, object)
end

function Animations.AddFadeExclusions(objects)
	for _, object in objects do
		local prop = GetTransparencyProperty(object)
		if not prop then
			continue
		end

		table.insert(Animations.Exclusions, object)
	end
end

function Animations.SetFadeExpectation(type: "In" | "Out", object: GuiBase2d, properties: { [string]: any })
	if not Animations.Expectations[type] then
		return
	end

	Animations.Expectations[type][object] = properties
end

return Animations

end)() end,
    [18] = function()local wax,script,require=ImportGlobals(18)local ImportGlobals return (function(...)local CodeGen = {
	CleanTable = { ['"'] = '\\"', ["\\"] = "\\\\" },
	IndentTemplate = string.rep(" ", 4),
}

type SupportedRemoteTypes = RemoteEvent | RemoteFunction | BindableEvent | BindableFunction | UnreliableRemoteEvent
type CallInfo = {
	Arguments: { [number]: any, n: number },
	Time: string,
	Origin: BaseScript?,
	Function: (
		...any
	) -> any | {
		Address: string,
		Name: string,
		IsC: boolean,
		Constants: { any }?,
		Upvalues: { any }?,
		Protos: { any }?,
	},
	Line: number?,
	Instance: SupportedRemoteTypes,
	Order: number,
	Type: "Incoming" | "Outgoing",
	OriginalInvokeArgs: { [number]: any, n: number }?,
	IsActor: boolean?,
}

wax.shared.FunctionForClasses = {
	Incoming = {
		RemoteEvent = "OnClientEvent",
		RemoteFunction = "OnClientInvoke",
		UnreliableRemoteEvent = "OnClientEvent",
		BindableEvent = "Event",
		BindableFunction = "OnInvoke",
	},

	Outgoing = {
		RemoteEvent = "FireServer",
		RemoteFunction = "InvokeServer",
		UnreliableRemoteEvent = "FireServer",
		BindableEvent = "Fire",
		BindableFunction = "Invoke",
	},
}

local GetNilCode = [[local function GetNil(Name, DebugId)
	for _, Object in getnilinstances() do
		if Object.Name == Name and Object:GetDebugId() == DebugId then
			return Object
		end
	end
end]]

--// Pasted from Dex (maximum detection)
for i = 0, 31 do
	CodeGen.CleanTable[string.char(i)] = "\\" .. string.format("%03d", i)
end
for i = 127, 255 do
	CodeGen.CleanTable[string.char(i)] = "\\" .. string.format("%03d", i)
end

function CodeGen.FormatLuaString(str)
	return string.gsub(str, '["\\\0-\31\127-\255]', CodeGen.CleanTable)
end

function CodeGen.GetFullPath(Object, ExcludeCode, VariableName, IsInTable)
	if rawequal(Object, game) or (wax.shared.ExecutorSupport["compareinstances"].IsWorking and compareinstances(Object, game)) then
		return "game"
	end
	
	local CurrentObject = Object
	local DidInsertNilFunction = false
	local IsNil = false
	local Path = ""

	repeat
		if typeof(CurrentObject) ~= "Instance" then
			break
		end

		if CurrentObject == game then
			Path = "game" .. Path
			break
		end

		local IndexName = ""

		if CurrentObject == wax.shared.LocalPlayer then
			IndexName = ".LocalPlayer"
		elseif wax.shared.LocalPlayer.Character and CurrentObject == wax.shared.LocalPlayer.Character then
			Path = 'game:GetService("Players").LocalPlayer.Character' .. Path
			break
		elseif CurrentObject.Name and CurrentObject.Name == wax.shared.LocalPlayer.Name then
			IndexName = '[game:GetService("Players").LocalPlayer.Name]'
		elseif CurrentObject.Name and CurrentObject.Name == tostring(wax.shared.LocalPlayer.UserId) then
			IndexName = '[game:GetService("Players").LocalPlayer.UserId]'
		elseif CurrentObject == workspace then
			Path = "workspace" .. Path
			break
		elseif CurrentObject.ClassName then
			if string.match(CurrentObject.Name, "^[%a_][%w_]*$") then
				IndexName = "." .. CurrentObject.Name
			else
				IndexName = '["' .. CodeGen.FormatLuaString(CurrentObject.Name) .. '"]'
			end

			local Parent = CurrentObject.Parent
			if Parent then
				local DirectChildPtr = Parent:FindFirstChild(CurrentObject.Name)

				if Parent == game and game:FindService(CurrentObject.ClassName) == CurrentObject then
					IndexName = ':GetService("' .. CurrentObject.ClassName .. '")'
				elseif DirectChildPtr then
					local Children = Parent:GetChildren()
					local FoundIndex = nil

					if wax.shared.ExecutorSupport["compareinstances"].IsWorking and not compareinstances(DirectChildPtr, CurrentObject) then
						for Index, Child in Children do
							if not compareinstances(Child, CurrentObject) then
								continue
							end
							
							FoundIndex = Index
							break
						end
					elseif DirectChildPtr ~= CurrentObject then
						FoundIndex = table.find(Children, CurrentObject)
					end

					if FoundIndex then
						IndexName = ":GetChildren()[" .. tostring(FoundIndex) .. "]"
					end

				end
			elseif Parent == nil then
				IsNil = true

				if ExcludeCode then
					Path = Path .. " --[[Nil Parent]]"
				else
					local Base = `GetNil("{CodeGen.FormatLuaString(CurrentObject.Name)}", "{CodeGen.FormatLuaString(
						CurrentObject:GetDebugId()
					)}")`
					DidInsertNilFunction = true
					if IsInTable then
						Path = Base
						break
					end

					Path = GetNilCode .. `\n\n{VariableName and `local {VariableName} = ` or ""}` .. Base
					break
				end
			end
		end

		Path = IndexName .. Path

		CurrentObject = CurrentObject.Parent
	until CurrentObject == nil

	if IsNil then
		return Path, DidInsertNilFunction
	end

	return `{VariableName and `local {VariableName} = ` or ""}{Path}`, DidInsertNilFunction
end

local function DoesUseCallbackValue(Instance: Instance)
	return Instance.ClassName == "RemoteFunction" or Instance.ClassName == "BindableFunction"
end

local CodeGenHeaderTemplate = [[-- This code was generated by Cobalt
-- https://github.com/notpoiu/cobalt

]]

local ClientRemoteClassNames = {
	BindableEvent = true,
	BindableFunction = true,
}

local function IndentCode(Code: string, IndentLevel: number)
	local Indent = CodeGen.IndentTemplate:rep(IndentLevel)
	local IndentedCode = Code:gsub("\n", "\n" .. Indent)
	return Indent .. IndentedCode
end

local function WrapCodeInActor(Code: string, ShouldWrap: boolean)
	if not ShouldWrap then
		return Code
	end

	return string.format(
		"-- Event originated from an Actor environement\nrun_on_actor(getactors()[1], [[\n%s\n]])",
		IndentCode(Code, 1)
	)
end

function CodeGen:BuildHookCode(CallInfo: CallInfo)
	local Type = CallInfo.Type
	local Path = self.GetFullPath(CallInfo.Instance, false, "Event")
	local IsFromActor = CallInfo.IsActor or false
	local Method = wax.shared.FunctionForClasses[Type][CallInfo.Instance.ClassName]

	local CodeGenHeader = CodeGenHeaderTemplate

	if Type == "Incoming" then
		if DoesUseCallbackValue(CallInfo.Instance) then
			-- :InvokeServer -> Returned value
			if CallInfo.OriginalInvokeArgs then
				Method = wax.shared.FunctionForClasses.Outgoing[CallInfo.Instance.ClassName]

				return CodeGenHeader
					.. WrapCodeInActor(
						string.format(
							[[%s
local mtHook; mtHook = hookmetamethod(game, "__namecall", function(...)
	local self = ...

	if rawequal(self, Event) and getnamecallmethod() == "%s" then
		local Args = table.pack(...)

		local Result = table.pack(
			mtHook(table.unpack(Args, 1, Args.n))
		)

		return table.unpack(Result, 1, Result.n)
	end

	return mtHook(self, ...)
end)

local Old%s; Old%s = hookfunction(Event.%s, function(...)
	local self = ...

	if rawequal(self, Event) then
		local Args = table.pack(...)

		local Result = table.pack(
			Old%s(table.unpack(Args, 1, Args.n))
		)

		return table.unpack(Result, 1, Result.n)
	end

	return Old%s(self, ...)
end)]],
							Path,
							Method,
							Method,
							Method,
							Method,
							Method,
							Method
						),
						IsFromActor
					)
			end

			-- Callback value
			return CodeGenHeader
				.. WrapCodeInActor(
					string.format(
						[[%s
local Callback = getcallbackvalue(Event, "%s")
Event.%s = function(...)
	print(`Intercepted (Callback) {Event.Name}.%s`, ...)
	return Callback(...)
end

local mtHook; mtHook = hookmetamethod(game, "__newindex", function(...)
	local self, key, value = ...
	
	if (
		rawequal(self, Event) and
		rawequal(key, "%s") and
		typeof(value) == "function" and
		not checkcaller()
	) then
		Callback = value
	end

	return mtHook(...)
end)]],
						Path,
						Method,
						Method,
						Method,
						Method
					),
					IsFromActor
				)
		end

		return CodeGenHeader
			.. WrapCodeInActor(
				string.format(
					[[%s
for _, Connection in getconnections(Event.%s) do
	local old; old = hookfunction(Connection.Function, function(...)
		print(`Intercepted (Connection) {Event.Name}.%s`, ...)
		return old(...)
	end)
end]],
					Path,
					Method,
					Method
				),
				IsFromActor
			)
	end

	return CodeGenHeader
		.. WrapCodeInActor(
			string.format(
				[[%s
local mtHook; mtHook = hookmetamethod(game, "__namecall", function(...)
	local self = ...

	if rawequal(self, Event) and getnamecallmethod() == "%s" then
		local Args = table.pack(...)
		
		local Result = table.pack(
			mtHook(self, table.unpack(Args, 1, Args.n))
		)

		print(`Intercepted (__namecall) {Event.Name}:%s()`, ...)

		return table.unpack(Result, 1, Result.n)
	end

	return mtHook(...)
end)

local Old%s; Old%s = hookfunction(Event.%s, function(...)
	local self = ...

	if rawequal(self, Event) then
		local Args = table.pack(...)

		local Result = table.pack(
			Old%s(table.unpack(Args, 1, Args.n))
		)

		print(`Intercepted (__index) {Event.Name}:%s()`, self, table.unpack(Result, 1, Result.n))

		return table.unpack(Result, 1, Result.n)
	end

	return Old%s(self, ...)
end)]],
				Path,
				Method,
				Method,
				Method,
				Method,
				Method,
				Method,
				Method,
				Method
			),
			IsFromActor
		)
end

function CreateArgsString(SerializedArgs: string, Args: { [number]: any, n: number }, Prefix: string?)
	if Args.n == 0 then
		return ""
	end

	return `{Prefix == nil and "" or Prefix}{string.sub(SerializedArgs, 2, #SerializedArgs - 1)}`
end

function CodeGen:BuildCallCode(CallInfo: CallInfo)
	local Type = CallInfo.Type
	local IsFromActor = CallInfo.IsActor or false
	local Path = self.GetFullPath(CallInfo.Instance, false, "Event")
	local Method = wax.shared.FunctionForClasses[Type][CallInfo.Instance.ClassName]
	local SerializedArgs, DidInsertNilFunction = wax.shared.LuaEncode(
		{ table.unpack(CallInfo.Arguments, 1, CallInfo.Arguments.n) },
		{ Prettify = true, InsertCycles = true, GetNilFunctionInsert = true }
	)

	local CodeGenHeader = CodeGenHeaderTemplate

	if Type == "Incoming" then
		if DoesUseCallbackValue(CallInfo.Instance) then
			local PrettifiedExpectedResult, DidInsertNilFunctionInExpectation = wax.shared.LuaEncode(
				{ table.unpack(CallInfo.Arguments, 1, CallInfo.Arguments.n) },
				{ Prettify = true, InsertCycles = true, GetNilFunctionInsert = true }
			)

			if CallInfo.OriginalInvokeArgs then
				local PrettifiedOutput, InsertedNilFunction = wax.shared.LuaEncode(
					{ table.unpack(CallInfo.OriginalInvokeArgs, 1, CallInfo.OriginalInvokeArgs.n) },
					{ Prettify = true, InsertCycles = true }
				)

				Method = wax.shared.FunctionForClasses.Outgoing[CallInfo.Instance.ClassName]

				return CodeGenHeader
					.. string.format(
						[[%s%s
local Result = Event:%s(%s)

local ExpectedResult = table.unpack(%s)

]],
						((InsertedNilFunction or DidInsertNilFunction or DidInsertNilFunctionInExpectation) and GetNilCode .. "\n\n" or ""),
						Path,
						Method, CreateArgsString(PrettifiedOutput, CallInfo.OriginalInvokeArgs),
						PrettifiedExpectedResult
					)
			end

			return CodeGenHeader
				.. WrapCodeInActor(
					string.format(
						[[%s%s
local Callback = getcallbackvalue(Event, "%s")
Callback(%s)

local ExpectedResult = table.unpack(%s)

]],
						(DidInsertNilFunction or DidInsertNilFunctionInExpectation and GetNilCode .. "\n\n" or ""),
						Path,
						Method, CreateArgsString(SerializedArgs, CallInfo.Arguments),

						PrettifiedExpectedResult
					),
					IsFromActor
				)
		end

		return CodeGenHeader
			.. WrapCodeInActor(
				string.format(
					[[%s%s
firesignal(Event.%s%s)]],
					(DidInsertNilFunction and GetNilCode .. "\n\n" or ""),
					Path,
					Method,
					CreateArgsString(SerializedArgs, CallInfo.Arguments, ", ")
				),
				IsFromActor
			)
	end

	return CodeGenHeader
		.. WrapCodeInActor(
			string.format(
				[[%s%s
Event:%s(%s)]],
				(DidInsertNilFunction and GetNilCode .. "\n\n" or ""),
				Path,
				Method,
				CreateArgsString(SerializedArgs, CallInfo.Arguments)
			),
			IsFromActor and ClientRemoteClassNames[CallInfo.Instance.ClassName]
		)
end

function CodeGen:BuildFunctionInfo(CallInfo: CallInfo)
	if CallInfo.IsActor and typeof(CallInfo.Function) == "table" then
		return string.format(
			[[<b>函数地址:</b> %s
<b>名称:</b> %s
<b>来源:</b> %s
<b>调用行:</b> %s
<b>来自 Actor:</b> true
%s]],
			CallInfo.Function.Address:match("0x%x+") or tostring(CallInfo.Function),
			CallInfo.Function.Name ~= "" and CallInfo.Function.Name or "Anonymous",
			CallInfo.Origin and self.GetFullPath(CallInfo.Origin, true) or wax.shared.ExecutorName,
			tostring(CallInfo.Line),

			CallInfo.Function.IsC and "<b>闭包类型</b>: C 闭包"
				or string.format(
					"<b>闭包类型</b>: Luau 闭包\n<b>常量:</b> %s\n<b>上值:</b> %s\n<b>原型:</b> %s",
					debug.getconstants and tostring(#CallInfo.Function.Constants) or "N/A",
					debug.getupvalues and tostring(#CallInfo.Function.Upvalues) or "N/A",
					debug.getprotos and tostring(#CallInfo.Function.Protos) or "N/A"
				)
		)
	end

	local FunctionName = debug.info(CallInfo.Function, "n")

	return string.format(
		[[<b>函数地址:</b> %s
<b>名称:</b> %s
<b>来源:</b> %s
<b>调用行:</b> %s
%s]],
		tostring(CallInfo.Function):match("0x%x+") or tostring(CallInfo.Function),
		FunctionName ~= "" and FunctionName or "Anonymous",
		CallInfo.Origin and self.GetFullPath(CallInfo.Origin, true) or wax.shared.ExecutorName,
		tostring(CallInfo.Line),

		iscclosure(CallInfo.Function) and "<b>闭包类型</b>: C 闭包"
			or string.format(
				"<b>闭包类型</b>: Luau 闭包\n<b>常量:</b> %s\n<b>上值:</b> %s\n<b>原型:</b> %s",
				debug.getconstants and tostring(#debug.getconstants(CallInfo.Function)) or "N/A",
				debug.getupvalues and tostring(#debug.getupvalues(CallInfo.Function)) or "N/A",
				debug.getprotos and tostring(#debug.getprotos(CallInfo.Function)) or "N/A"
			)
	)
end

wax.shared.ReplayCallInfo = function(CallInfo: CallInfo)
	local Type = CallInfo.Type
	local Method = wax.shared.FunctionForClasses[Type][CallInfo.Instance.ClassName]

	if Type == "Incoming" then
		if DoesUseCallbackValue(CallInfo.Instance) then
			if CallInfo.OriginalInvokeArgs then
				Method = wax.shared.FunctionForClasses.Outgoing[CallInfo.Instance.ClassName]

				CallInfo.Instance[Method](
					CallInfo.Instance,
					table.unpack(CallInfo.OriginalInvokeArgs, 1, CallInfo.OriginalInvokeArgs.n)
				)
				return
			end

			local Callback = getcallbackvalue(CallInfo.Instance, Method)

			if not Callback then
				return
			end

			Callback(table.unpack(CallInfo.Arguments))
			return
		end

		assert(firesignal or getconnections, "No firesignal or getconnections found")

		if firesignal then
			firesignal(CallInfo.Instance[Method], table.unpack(CallInfo.Arguments, 1, CallInfo.Arguments.n))
		elseif getconnections then
			for _, conn in getconnections(CallInfo.Instance[Method]) do
				conn:Fire(table.unpack(CallInfo.Arguments, 1, CallInfo.Arguments.n))
			end
		end

		return
	end

	CallInfo.Instance[Method](CallInfo.Instance, table.unpack(CallInfo.Arguments, 1, CallInfo.Arguments.n))
end

return CodeGen

end)() end,
    [19] = function()local wax,script,require=ImportGlobals(19)local ImportGlobals return (function(...)wax.shared.Connections = {}

wax.shared.Connect = function(Connection)
	table.insert(wax.shared.Connections, Connection)
	return Connection
end

wax.shared.Disconnect = function(Connection)
	Connection:Disconnect()

	local Index = table.find(wax.shared.Connections, Connection)
	if Index then
		table.remove(wax.shared.Connections, Index)
	end

	return true
end

end)() end,
    [20] = function()local wax,script,require=ImportGlobals(20)local ImportGlobals return (function(...)local Drag = {
	Dragging = false,
	Frame = nil,
	FramePosition = nil,
	FrameSize = nil, -- Added to store initial frame size
	StartPosition = nil,
	ChangedConnection = nil,
	Callback = nil,
}

local function DefaultCallback(_, Input: InputObject)
	local Delta = Input.Position - Drag.StartPosition
	local FramePosition: UDim2 = Drag.FramePosition

	Drag.Frame.Position = UDim2.new(
		FramePosition.X.Scale,
		FramePosition.X.Offset + Delta.X,
		FramePosition.Y.Scale,
		FramePosition.Y.Offset + Delta.Y
	)
end

function Drag.Setup(Frame: GuiObject, DragFrame: GuiObject, Callback: (Info: {}, Input: InputObject) -> ())
	Callback = Callback or DefaultCallback

	DragFrame.InputBegan:Connect(function(Input: InputObject)
		if not wax.shared.IsClickInput(Input) then
			return
		end

		Drag.Dragging = true
		Drag.Frame = Frame
		Drag.FramePosition = Frame.Position
		Drag.StartPosition = Input.Position
		Drag.FrameSize = Frame.Size
		Drag.Callback = Callback

		Drag.ChangedConnection = Input.Changed:Connect(function()
			if Input.UserInputState ~= Enum.UserInputState.End then
				return
			end

			Drag.Dragging = false
			Drag.Frame = nil
			Drag.Callback = nil

			if Drag.ChangedConnection and Drag.ChangedConnection.Connected then
				Drag.ChangedConnection:Disconnect()
				Drag.ChangedConnection = nil
			end
		end)
	end)
end

wax.shared.Connect(wax.shared.UserInputService.InputChanged:Connect(function(Input: InputObject)
	if Drag.Dragging and Drag.Callback and wax.shared.IsMoveInput(Input) then
		Drag.Callback(Drag, Input)
	end
end))

return Drag

end)() end,
    [21] = function()local wax,script,require=ImportGlobals(21)local ImportGlobals return (function(...)-- Logger
-- ActualMasterOogway
-- 2024年12月8日

--[=[
    一个简单的日志工具，可以将消息写入文件。
    支持不同的日志等级，并可配置为覆盖或追加写入日志文件。

    日志格式:  
    2024-12-04T15:28:31.131Z,0.131060,MyThread,Warning [FLog::RobloxStarter] Roblox stage ReadyForFlagFetch completed
    <时间戳>,<运行耗时>,<线程ID>,<日志等级> <日志消息>
]=]

local Logger = {}
Logger.__index = Logger

-- 日志等级
Logger.LOG_LEVELS = {
	ERROR = 1,
	WARNING = 2,
	INFO = 3,
	DEBUG = 4,
}

-- 日志等级对应的字符串
local LOG_LEVEL_STRINGS = {
	[Logger.LOG_LEVELS.ERROR] = "ERROR",
	[Logger.LOG_LEVELS.WARNING] = "WARNING",
	[Logger.LOG_LEVELS.INFO] = "INFO",
	[Logger.LOG_LEVELS.DEBUG] = "DEBUG",
}

-- 程序启动时间，用于计算运行耗时
local startTime = tick()

-- 递归创建目录
local function createDirectoryRecursive(path)
	local currentPath = ""
	for part in path:gmatch("[^\\/]+") do
		currentPath = currentPath .. part
		if not isfolder(currentPath) then
			makefolder(currentPath)
		end
		currentPath = currentPath .. "/"
	end
end

--[=[
    生成一个唯一的日志文件名。  
    文件名基于当前 JobId，确保在每个服务器实例中唯一，
    但在同一服务器的多次执行中保持一致。

    @return string 唯一的日志文件名
]=]
function Logger:GenerateFileName()
	local JobIdNumber = game.JobId:gsub("%D", "")
	local timestamp = os.date("!%Y%m%d%H%M%S")

	return `{self.logFileDirectory}/{JobIdNumber * 1.7 // 1.8}_{timestamp}.log`
end

--[=[
    创建一个新的 Logger 实例。

    @param logFilePath string 日志文件路径
    @param logLevel number 最低记录日志的等级（默认为 INFO）
    @param overwrite boolean 是否覆盖已有日志文件（默认为 false，即追加写入）
    @return Logger 新的 Logger 实例
]=]
function Logger.new(logFilePath: string, logLevel: number?, overwrite: boolean?)
	local self = setmetatable({}, Logger)
	self.logFilePath = logFilePath
	self.logFileDirectory = logFilePath:match("(.+)/")
	self.logLevel = logLevel or Logger.LOG_LEVELS.INFO
	self.overwrite = overwrite or false

	local folderPath, fileName = logFilePath:match("(.*[\\/])(.*)")

	-- 确保日志目录存在
	if folderPath and not isfolder(folderPath) then
		createDirectoryRecursive(folderPath)
	end

	-- 如果是覆盖模式，先清空日志文件
	if self.overwrite then
		local success, err = pcall(writefile, self.logFilePath, "")
		if not success then
			warn(debug.traceback(`清空日志文件失败: {self.logFilePath} - {err}`, 2))
		end
	end

	self:Info("Logger", "日志系统已初始化")

	return self
end

--[=[
    写入日志消息到文件。

    @param level number 日志等级
    @param threadId string 线程或日志来源的 ID
    @param message string 要记录的消息
]=]
function Logger:Log(level: number, threadId: string, message: string)
	if level <= self.logLevel then
		local levelStr = LOG_LEVEL_STRINGS[level]

		local timestamp = `{os.date("!%Y-%m-%dT%H:%M:%S")}{("%.3f"):format(tick() % 1)}Z`
		local elapsedTime = ("%.6f"):format(tick() - startTime)

		local logMessage = `{timestamp},{elapsedTime},{threadId},{levelStr} {message}\n`

		local success, err = pcall(appendfile, self.logFilePath, logMessage)
		if not success then
			warn(debug.traceback(`写入日志文件失败: {self.logFilePath} - {err}`, 2))
		end
	end
end

--[=[
    写入 Debug 日志。

    @param threadId string 线程或日志来源 ID
    @param message string 消息内容
]=]
function Logger:Debug(threadId: string, message: string)
	self:Log(Logger.LOG_LEVELS.DEBUG, threadId, message)
end

--[=[
    写入 Info 日志。

    @param threadId string 线程或日志来源 ID
    @param message string 消息内容
]=]
function Logger:Info(threadId: string, message: string)
	self:Log(Logger.LOG_LEVELS.INFO, threadId, message)
end

--[=[
    写入 Warning 日志。

    @param threadId string 线程或日志来源 ID
    @param message string 消息内容
]=]
function Logger:Warning(threadId: string, message: string)
	self:Log(Logger.LOG_LEVELS.WARNING, threadId, message)
end

--[=[
    写入 Error 日志。

    @param threadId string 线程或日志来源 ID
    @param message string 消息内容
]=]
function Logger:Error(threadId: string, message: string)
	self:Log(Logger.LOG_LEVELS.ERROR, threadId, message)
end

return Logger

end)() end,
    [22] = function()local wax,script,require=ImportGlobals(22)local ImportGlobals return (function(...)--[[

Luau syntax highlighter with studio colors
Based on: https://devforum.roblox.com/t/realtime-richtext-lua-syntax-highlighting/2500399

]]

local Highlighter = {
	Colors = {
		Keyword = "#f86d7c",
		String = "#adf195",
		Number = "#ffc600",
		Nil = "#ffc600",
		Boolean = "#ffc600",
		Function = "#f86d7c",
		Self = "#f86d7c",
		Local = "#f86d7c",
		Text = "#ffffff",
		LocalMethod = "#fdfbac",
		LocalProperty = "#61a1f1",
		BuiltIn = "#84d6f7",
		Comment = "#666666",
	},

	Keywords = {
		Lua = {
			"and",
			"break",
			"or",
			"else",
			"elseif",
			"if",
			"then",
			"until",
			"repeat",
			"while",
			"do",
			"for",
			"in",
			"end",
			"local",
			"return",
			"function",
			"export",
		},
		Roblox = {
			"game",
			"workspace",
			"script",
			"math",
			"string",
			"table",
			"task",
			"wait",
			"select",
			"next",
			"Enum",
			"error",
			"warn",
			"tick",
			"assert",
			"shared",
			"loadstring",
			"tonumber",
			"tostring",
			"type",
			"typeof",
			"unpack",
			"print",
			"Instance",
			"CFrame",
			"Vector3",
			"Vector2",
			"Color3",
			"UDim",
			"UDim2",
			"Ray",
			"BrickColor",
			"OverlapParams",
			"RaycastParams",
			"Axes",
			"Random",
			"Region3",
			"Rect",
			"TweenInfo",
			"collectgarbage",
			"not",
			"utf8",
			"pcall",
			"xpcall",
			"_G",
			"setmetatable",
			"getmetatable",
			"os",
			"pairs",
			"ipairs",
		},
	},
}

local function CreateKeywordSet(keywords)
	local keywordSet = {}
	for _, keyword in ipairs(keywords) do
		keywordSet[keyword] = true
	end
	return keywordSet
end

local LuaSet = CreateKeywordSet(Highlighter.Keywords.Lua)
local RobloxSet = CreateKeywordSet(Highlighter.Keywords.Roblox)

local function GetHighlightColor(tokens, index)
	local token = tokens[index]

	if tonumber(token) then
		return Highlighter.Colors.Number
	elseif token == "nil" then
		return Highlighter.Colors.Nil
	elseif token:sub(1, 2) == "--" then
		return Highlighter.Colors.Comment
	elseif LuaSet[token] then
		return Highlighter.Colors.Keyword
	elseif RobloxSet[token] or getgenv()[token] ~= nil then
		return Highlighter.Colors.BuiltIn
	elseif token:sub(1, 1) == '"' or token:sub(1, 1) == "'" then
		return Highlighter.Colors.String
	elseif token == "true" or token == "false" then
		return Highlighter.Colors.Boolean
	end

	if tokens[index + 1] == "(" then
		if tokens[index - 1] == ":" then
			return Highlighter.Colors.LocalMethod
		end
		return Highlighter.Colors.LocalMethod
	end

	if tokens[index - 1] == "." then
		if tokens[index - 2] == "Enum" then
			return Highlighter.Colors.BuiltIn
		end
		return Highlighter.Colors.LocalProperty
	end

	return nil
end

local ArgumentColors = {
	["boolean"] = Highlighter.Colors.Boolean,
	["number"] = Highlighter.Colors.Number,
	["Vector2"] = Highlighter.Colors.Number,
	["Vector3"] = Highlighter.Colors.Number,
	["CFrame"] = Highlighter.Colors.Number,
	["string"] = Highlighter.Colors.String,
	["EnumItem"] = Highlighter.Colors.BuiltIn,
	["nil"] = Highlighter.Colors.Nil,
}
function Highlighter.GetArgumentColor(Argument)
	return ArgumentColors[typeof(Argument)] or Highlighter.Colors.Text
end

function Highlighter.Run(source)
	local tokens = {}
	local currentToken = ""

	local inString = false
	local inComment = false
	local commentPersist = false

	for i = 1, #source do
		local character = source:sub(i, i)

		if inComment then
			if character == "\n" and not commentPersist then
				table.insert(tokens, currentToken)
				table.insert(tokens, character)
				currentToken = ""

				inComment = false
			elseif source:sub(i - 1, i) == "]]" and commentPersist then
				currentToken = currentToken .. "]"

				table.insert(tokens, currentToken)
				currentToken = ""

				inComment = false
				commentPersist = false
			else
				currentToken = currentToken .. character
			end
		elseif inString then
			if character == inString and source:sub(i - 1, i - 1) ~= "\\" or character == "\n" then
				currentToken = currentToken .. character
				table.insert(tokens, currentToken)
				currentToken = ""
				inString = false
			else
				currentToken = currentToken .. character
			end
		else
			if source:sub(i, i + 1) == "--" then
				table.insert(tokens, currentToken)
				currentToken = "--"
				inComment = true
				commentPersist = source:sub(i + 2, i + 3) == "[["
				i = i + 1
			elseif character == '"' or character == "'" then
				table.insert(tokens, currentToken)
				currentToken = character
				inString = character
			elseif character:match("[%p]") and character ~= "_" then
				table.insert(tokens, currentToken)
				table.insert(tokens, character)
				currentToken = ""
			elseif character:match("[%w_]") then
				currentToken = currentToken .. character
			else
				table.insert(tokens, currentToken)
				table.insert(tokens, character)
				currentToken = ""
			end
		end
	end

	if currentToken ~= "" then
		table.insert(tokens, currentToken)
	end

	for i = #tokens, 1, -1 do
		if tokens[i] == "" then
			table.remove(tokens, i)
		end
	end

	local highlighted = {}

	for i, token in ipairs(tokens) do
		local highlightColor = GetHighlightColor(tokens, i)

		if highlightColor then
			local syntax =
				string.format('<font color="%s">%s</font>', highlightColor, token:gsub("<", "&lt;"):gsub(">", "&gt;"))

			table.insert(highlighted, syntax)
		else
			table.insert(highlighted, token)
		end
	end

	return table.concat(highlighted)
end

return Highlighter

end)() end,
    [23] = function()local wax,script,require=ImportGlobals(23)local ImportGlobals return (function(...)local Hooking = {
	IncludeInStackFunctions = {},
}

local UseAltHooks = wax.shared.SaveManager:GetState("UseAlternativeHooks")
local AlternativeEnabled = typeof(UseAltHooks) == "boolean" and UseAltHooks or false
wax.shared.AlternativeEnabled = AlternativeEnabled
wax.shared.CobaltLuaSetStackHidden = false

Hooking.HookFunction = function(Original, Replacement)
	if not wax.shared.ExecutorSupport["hookfunction"].IsWorking then
		return Original
	end

	return hookfunction(Original, Replacement)
end
Hooking.HookMetaMethod = function(object, method, hook)
	if AlternativeEnabled or (not wax.shared.ExecutorSupport["hookmetamethod"].IsWorking and wax.shared.ExecutorSupport["getrawmetatable"].IsWorking) then
		local Metatable = wax.shared.getrawmetatable(object)
		local originalMethod = rawget(Metatable, method)
		
		setreadonly(Metatable, false)
		rawset(Metatable, method, hook)
		setreadonly(Metatable, true)
	
		return originalMethod
	end

	if not wax.shared.ExecutorSupport["hookmetamethod"].IsWorking then
		if method == "__index" then
			local _, Metamethod = xpcall(function()
				return object[tostring(math.random())]
			end, function(err)
				return debug.info(2, "f")
			end)

			return Metamethod
		elseif method == "__newindex" then
			local _, Metamethod = xpcall(function()
				object[tostring(math.random())] = true
			end, function(err)
				return debug.info(2, "f")
			end)

			return Metamethod
		elseif method == "__namecall" then
			local _, Metamethod = xpcall(function()
				object:Mustard()
			end, function(err)
				return debug.info(2, "f")
			end)

			return Metamethod
		end

		return nil
	end

	return hookmetamethod(object, method, hook)
end

return Hooking

end)() end,
    [24] = function()local wax,script,require=ImportGlobals(24)local ImportGlobals return (function(...)local Icons = {}

type Icon = {
	Url: string,
	Id: number,
	IconName: string,
	ImageRectOffset: Vector2,
	ImageRectSize: Vector2,
}

local Success, IconsModule = pcall(function()
	return (loadstring(
		game:HttpGet("https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua")
	) :: () -> { Icons: { string }, GetAsset: (Name: string) -> Icon? })()
end)

function Icons.GetIcon(iconName: string): Icon?
	if not Success then
		return
	end

	local Success, Icon = pcall(IconsModule.GetAsset, iconName)
	if not Success then
		return
	end

	return Icon
end

function Icons.SetIcon(imageInstance: ImageLabel, iconName: string)
	local Icon: Icon? = Icons.GetIcon(iconName)
	if not Icon then
		return
	end

	imageInstance.Image = Icon.Url
	imageInstance.ImageRectOffset = Icon.ImageRectOffset
	imageInstance.ImageRectSize = Icon.ImageRectSize
end

return Icons

end)() end,
    [25] = function()local wax,script,require=ImportGlobals(25)local ImportGlobals return (function(...)local ImageFetcher = {
	FallbackMapping = {
		Logo = "rbxassetid://91685317120520",
	},
}

if not isfolder("Cobalt/Assets") then
	makefolder("Cobalt/Assets")
end

function SafeFetch(Path: string)
	local Success, Result = pcall(function()
		return getcustomasset(Path)
	end)

	return Success and Result or nil
end

function ImageFetcher.GetRemoteImages(Images: { [string]: string })
	if not getcustomasset then
		return Images
	end

	local NewImages = {}
	for ClassName, Image in Images do
		if isfile(`Cobalt/Assets/{ClassName}.png`) then
			NewImages[ClassName] = SafeFetch(`Cobalt/Assets/{ClassName}.png`) or Image
			continue
		end

		writefile(
			`Cobalt/Assets/{ClassName}.png`,
			game:HttpGet(`https://robloxapi.github.io/ref/icons/dark/{ClassName}.png`)
		)

		NewImages[ClassName] = SafeFetch(`Cobalt/Assets/{ClassName}.png`) or Image
	end

	return NewImages
end

function ImageFetcher.GetImage(Image: string)
	if not getcustomasset then
		return ImageFetcher.FallbackMapping[Image] or Image
	end

	if isfile(`Cobalt/Assets/{Image}.png`) then
		return SafeFetch(`Cobalt/Assets/{Image}.png`) or ImageFetcher.FallbackMapping[Image] or Image
	end

	local Response = request({
		Url = `https://raw.githubusercontent.com/notpoiu/cobalt/refs/heads/main/Assets/{Image}.png`,
		Method = "GET",
	})

	if not Response.Success then
		return ImageFetcher.FallbackMapping[Image] or Image
	end

	writefile(`Cobalt/Assets/{Image}.png`, Response.Body)
	return SafeFetch(`Cobalt/Assets/{Image}.png`) or ImageFetcher.FallbackMapping[Image] or Image
end

return ImageFetcher

end)() end,
    [26] = function()local wax,script,require=ImportGlobals(26)local ImportGlobals return (function(...)local Interface = {}

local DefaultFont = Font.fromId(12187365364)
local _DefaultFontBold = Font.fromId(12187365364, Enum.FontWeight.Bold)

local DefaultProperties = {
	["Frame"] = {
		BorderSizePixel = 0,
	},
	["ScrollingFrame"] = {
		BorderSizePixel = 0,
	},
	["ImageLabel"] = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	},
	["ImageButton"] = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	},

	["TextLabel"] = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = DefaultFont,
		RichText = true,
		TextColor3 = Color3.new(1, 1, 1),
	},
	["TextButton"] = {
		AutoButtonColor = false,
		BorderSizePixel = 0,
		FontFace = DefaultFont,
		RichText = true,
		TextColor3 = Color3.new(1, 1, 1),
	},
	["TextBox"] = {
		BorderSizePixel = 0,
		FontFace = DefaultFont,
		ClipsDescendants = true,
		RichText = false,
		TextColor3 = Color3.new(1, 1, 1),
	},

	["UIListLayout"] = {
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
}

function Interface.New(ClassName: string, Properties: { [string]: any })
	local Object = Instance.new(ClassName)

	for Key, Value in pairs(DefaultProperties[ClassName] or {}) do
		if Properties and Properties[Key] ~= nil then
			continue
		end

		Object[Key] = Value
	end

	for Key, Value in pairs(Properties or {}) do
		if typeof(Value) == "table" then
			local SubObject = Interface.New(Key, Value)
			SubObject.Parent = Object

			continue
		elseif typeof(Key) ~= "string" and typeof(Value) == "Instance" then
			local SubObject = Value:Clone()
			SubObject.Parent = Object

			continue
		end

		Object[Key] = Value
	end

	return Object
end

function Interface.NewIcon(IconName: string, Properties: { [string]: any })
	local Image: ImageLabel = Interface.New("ImageLabel", Properties)
	wax.shared.Icons.SetIcon(Image, IconName)

	return Image
end

function Interface.HideCorner(Frame: GuiObject, Size: UDim2, Offset: Vector2): Frame
	local Hider = Interface.New("Frame", {
		AnchorPoint = Offset or Vector2.zero,
		BackgroundColor3 = Frame.BackgroundColor3,
		Position = UDim2.fromScale(Offset.X or 0, Offset.Y or 0),
		Size = Size,
		ZIndex = Frame.ZIndex,

		Parent = Frame,
	})

	return Hider
end

function Interface.GetScreenParent(): Instance
	local ScreenGui = wax.shared.Interface.New("ScreenGui")
	local HiddenUI = wax.shared.gethui()

	if pcall(function()
		ScreenGui.Parent = HiddenUI
		ScreenGui:Destroy()
	end) then
		return HiddenUI
	end

	return wax.shared.LocalPlayer:WaitForChild("PlayerGui")
end

return Interface

end)() end,
    [27] = function()local wax,script,require=ImportGlobals(27)local ImportGlobals return (function(...)local Log = {}
Log.__index = Log

function Log.new(Instance, Type, Method, Index, CallingScript)
	local NewLog = setmetatable({
		Instance = Instance,
		Type = Type,
		Method = Method,
		Index = Index,
		Calls = {},
		GameCalls = {},
		Ignored = false,
		Blocked = false,
		Button = nil,
	}, Log)

	return NewLog
end

function DeepClone(orig, copies)
	copies = copies or {}

	if typeof(orig) == "Instance" then
		return cloneref(orig)
	elseif type(orig) ~= "table" then
		return orig
	elseif copies[orig] then
		return copies[orig]
	end

	local copy = {}
	copies[orig] = copy
	for k, v in pairs(orig) do
		copy[DeepClone(k, copies)] = DeepClone(v, copies)
	end
	return copy
end

function Log:Call(RawInfo)
	local Info = DeepClone(RawInfo)
	local Index = #self.Calls + 1
	self.Calls[Index] = Info
	if not Info.IsExecutor then
		table.insert(self.GameCalls, Index)
	end
end

function Log:Ignore()
	if wax.shared.ActorCommunicator then
		wax.shared.ActorCommunicator:Fire("MainIgnore", self.Instance, self.Type)
	end

	self.Ignored = not self.Ignored
end

local ClassesConnectionsToggle = {
	RemoteEvent = "OnClientEvent",
	UnreliableRemoteEvent = "OnClientEvent",
	BindableEvent = "Event",
}

function Log:SetConnectionsEnabled(enabled: boolean)
	if not self.Instance or not ClassesConnectionsToggle[self.Instance.ClassName] then
		return
	end

	local ConnectionName = ClassesConnectionsToggle[self.Instance.ClassName]
	if self.Type ~= "Incoming" or not ConnectionName then
		return
	end

	for _, Connection in pairs(getconnections(self.Instance[ConnectionName])) do
		if enabled then
			Connection:Enable()
		else
			Connection:Disable()
		end
	end
end

function Log:Block()
	if wax.shared.ActorCommunicator then
		wax.shared.ActorCommunicator:Fire("MainBlock", self.Instance, self.Type)
	end

	self.Blocked = not self.Blocked
	Log:SetConnectionsEnabled(not self.Blocked)
end

function Log:SetButton(Instance, Name, Calls)
	self.Button = {
		Instance = Instance,
		Name = Name,
		Calls = Calls,
	}
end

return Log

end)() end,
    [28] = function()local wax,script,require=ImportGlobals(28)local ImportGlobals return (function(...)--[[
分页模块
由 deivid 编写，并由 upio 转换为模块
]]

local Pagination = {}
Pagination.__index = Pagination

--[[
	创建一个新的分页对象。
	@param Options { 
		TotalItems: number,    -- 总项目数
		ItemsPerPage: number,  -- 每页显示的项目数
		CurrentPage: number?,  -- 当前页（可选，默认为 1）
		SiblingCount: number?, -- 当前页两侧的页码显示数量（可选，默认为 2）
	}
	@return Pagination 实例
]]
function Pagination.new(Options: {
	TotalItems: number,
	ItemsPerPage: number,
	CurrentPage: number?,
	SiblingCount: number?,
})
	return setmetatable({
		TotalItems = Options.TotalItems,
		ItemsPerPage = Options.ItemsPerPage,
		CurrentPage = Options.CurrentPage or 1,
		SiblingCount = Options.SiblingCount or 2,
	}, Pagination)
end

--[[
	获取分页的基本信息
	@return { 
		TotalItems,   -- 总项目数
		ItemsPerPage, -- 每页项目数
		CurrentPage,  -- 当前页
		TotalPages    -- 总页数
	}
]]
function Pagination:GetInfo()
	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)

	return {
		TotalItems = self.TotalItems,
		ItemsPerPage = self.ItemsPerPage,
		CurrentPage = self.CurrentPage,
		TotalPages = TotalPages,
	}
end

--[[
	获取某一页对应的项目索引范围（开始和结束）。
	@param Page number? 指定页码（可选，默认为当前页）
	@return Start, End
]]
function Pagination:GetIndexRanges(Page: number?)
	Page = Page or self.CurrentPage

	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)
	if TotalPages == 0 then
		return 1, 0
	end
	assert(
		Page <= TotalPages,
		"尝试获取超出范围的页码，传入 " .. Page .. " 但最大值为 " .. TotalPages
	)

	local Start = (((Page or self.CurrentPage) - 1) * self.ItemsPerPage) + 1
	local End = Start + (self.ItemsPerPage - 1)

	return Start, End
end

--[[
	设置当前页。
	@param Page number 页码
]]
function Pagination:SetPage(Page: number)
	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)
	if TotalPages == 0 then
		self.CurrentPage = 1
		return
	end
	assert(Page <= TotalPages, "尝试设置超出范围的页码，传入 " .. Page .. " 但最大值为 " .. TotalPages)

	self.CurrentPage = Page
end

--[[
	更新分页的总项目数或每页项目数。
	@param TotalItems number? 新的总项目数（可选）
	@param ItemsPerPage number? 新的每页项目数（可选）
]]
function Pagination:Update(TotalItems: number?, ItemsPerPage: number?)
	self.TotalItems = TotalItems or self.TotalItems
	self.ItemsPerPage = ItemsPerPage or self.ItemsPerPage
end

--[[
	获取用于展示的分页信息（包含省略号 "ellipsis"）
	@param Page number? 指定页码（可选，默认为当前页）
	@return table 一个包含页码与省略号的数组，例如：{1, "ellipsis", 5, 6, 7, "ellipsis", 20}
]]
function Pagination:GetVisualInfo(Page: number?)
	Page = Page or self.CurrentPage

	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)
	if TotalPages == 0 then
		return {}
	end

	assert(
		Page <= TotalPages,
		"尝试获取超出范围的页码，传入 " .. Page .. " 但最大值为 " .. TotalPages
	)

	local MaxButtons = 5 + self.SiblingCount * 2
	local Result = table.create(MaxButtons, "none")
	if TotalPages <= MaxButtons then
		for i = 1, TotalPages do
			Result[i] = i
		end
		return Result
	end

	local LeftSibling = math.max(Page - self.SiblingCount, 1)
	local RightSibling = math.min(Page + self.SiblingCount, TotalPages)

	local FakeLeft = LeftSibling > 2
	local FakeRight = RightSibling < TotalPages - 1

	local TotalPageNumbers = math.min(2 * self.SiblingCount + 5, TotalPages)
	local ItemCount = TotalPageNumbers - 2

	if not FakeLeft and FakeRight then
		for i = 1, ItemCount do
			Result[i] = i
		end
		Result[ItemCount + 1] = "ellipsis"
		Result[ItemCount + 2] = TotalPages
		return Result
	elseif FakeLeft and not FakeRight then
		Result[1] = 1
		Result[2] = "ellipsis"

		local Index = 3
		for i = TotalPages - ItemCount + 1, TotalPages do
			Result[Index] = i
			Index += 1
		end

		return Result
	elseif FakeLeft and FakeRight then
		Result[1] = 1
		Result[2] = "ellipsis"
		local Index = 3

		for i = LeftSibling, RightSibling do
			Result[Index] = i
			Index += 1
		end

		Result[Index] = "ellipsis"
		Result[Index + 1] = TotalPages

		return Result
	end

	for i = 1, TotalPages do
		Result[i] = i
	end
	return Result
end

return Pagination

end)() end,
    [29] = function()local wax,script,require=ImportGlobals(29)local ImportGlobals return (function(...)local Resize = {}
Resize.__index = Resize

local HANDLE_SIZE = 6
local CORNER_HANDLE_SIZE = 20

function Resize.new(Options: {
	MainFrame: Frame,
	MinimumSize: Vector2? | UDim2?,
	MaximumSize: UDim2?,
	HandleSize: number?,
	CornerHandleSize: number?,
	Mirrored: boolean?,
	LockedPosition: boolean? | UDim2?,
})
	local MainFrame = Options.MainFrame
	local HandleSize = Options.HandleSize or HANDLE_SIZE
	local CornerHandleSize = Options.CornerHandleSize or CORNER_HANDLE_SIZE
	local Mirrored = Options.Mirrored or false
	local LockedPosition = Options.LockedPosition

	local MinimumSize
	if typeof(Options.MinimumSize) == "Vector2" then
		MinimumSize = UDim2.fromOffset(Options.MinimumSize.X, Options.MinimumSize.Y)
	elseif typeof(Options.MinimumSize) == "UDim2" then
		MinimumSize = Options.MinimumSize
	else
		MinimumSize = UDim2.fromOffset(100, 100)
	end

	local MaximumSize = Options.MaximumSize

	local self = setmetatable({
		MainFrame = MainFrame,
		ScreenGui = MainFrame:FindFirstAncestorOfClass("ScreenGui"),
		Parent = MainFrame.Parent,
	}, Resize)

	local function CalculateResizeProperties(
		initialFramePosition: UDim2,
		initialFrameSize: UDim2,
		mouseDelta: Vector2,
		resizeTypeX: string?,
		resizeTypeY: string?
	)
		if Mirrored then
			local parentAbsSize = self.Parent.AbsoluteSize

			local newSizeOffsetX = initialFrameSize.X.Offset
			local newSizeOffsetY = initialFrameSize.Y.Offset

			if resizeTypeX then
				local deltaX = 0
				if resizeTypeX == "Right" then
					deltaX = 2 * mouseDelta.X
				elseif resizeTypeX == "Left" then
					deltaX = -2 * mouseDelta.X
				end
				newSizeOffsetX = initialFrameSize.X.Offset + deltaX

				local minWidthAbs = MinimumSize.X.Scale * parentAbsSize.X + MinimumSize.X.Offset
				local maxWidthAbs = (MaximumSize and (MaximumSize.X.Scale * parentAbsSize.X + MaximumSize.X.Offset))
					or math.huge
				local scaleContributionX = initialFrameSize.X.Scale * parentAbsSize.X
				local minAllowedTotalOffsetX = minWidthAbs - scaleContributionX
				local maxAllowedTotalOffsetX = maxWidthAbs - scaleContributionX
				newSizeOffsetX = math.clamp(newSizeOffsetX, minAllowedTotalOffsetX, maxAllowedTotalOffsetX)
			end

			if resizeTypeY then
				local deltaY = 0
				if resizeTypeY == "Bottom" then
					deltaY = 2 * mouseDelta.Y
				elseif resizeTypeY == "Top" then
					deltaY = -2 * mouseDelta.Y
				end
				newSizeOffsetY = initialFrameSize.Y.Offset + deltaY

				local minHeightAbs = MinimumSize.Y.Scale * parentAbsSize.Y + MinimumSize.Y.Offset
				local maxHeightAbs = (MaximumSize and (MaximumSize.Y.Scale * parentAbsSize.Y + MaximumSize.Y.Offset))
					or math.huge
				local scaleContributionY = initialFrameSize.Y.Scale * parentAbsSize.Y
				local minAllowedTotalOffsetY = minHeightAbs - scaleContributionY
				local maxAllowedTotalOffsetY = maxHeightAbs - scaleContributionY
				newSizeOffsetY = math.clamp(newSizeOffsetY, minAllowedTotalOffsetY, maxAllowedTotalOffsetY)
			end

			local finalNewSize =
				UDim2.new(initialFrameSize.X.Scale, newSizeOffsetX, initialFrameSize.Y.Scale, newSizeOffsetY)
			local finalNewPosition = initialFramePosition
			if typeof(LockedPosition) == "UDim2" then
				finalNewPosition = LockedPosition
			end
			return finalNewSize, finalNewPosition
		else
			-- Non-mirrored logic
			local currentScreenGuiAbsSize = self.ScreenGui.AbsoluteSize
			local parentAbsSizeForMinMax = currentScreenGuiAbsSize -- As per original non-mirrored logic for min/max context

			-- These will store the final UDim offset values for position and the absolute pixel values for size calculation
			local finalPosOffsetX = initialFramePosition.X.Offset
			local finalPosOffsetY = initialFramePosition.Y.Offset

			-- Initial absolute pixel size of the frame
			local initialAbsWidthPx = initialFrameSize.X.Scale * self.Parent.AbsoluteSize.X + initialFrameSize.X.Offset
			local initialAbsHeightPx = initialFrameSize.Y.Scale * self.Parent.AbsoluteSize.Y + initialFrameSize.Y.Offset

			local newAbsWidthPx = initialAbsWidthPx
			local newAbsHeightPx = initialAbsHeightPx

			-- Min/max pixel dimensions
			local minWidthPx = MinimumSize.X.Scale * parentAbsSizeForMinMax.X + MinimumSize.X.Offset
			local minHeightPx = MinimumSize.Y.Scale * parentAbsSizeForMinMax.Y + MinimumSize.Y.Offset
			local maxWidthPx = MaximumSize and (MaximumSize.X.Scale * parentAbsSizeForMinMax.X + MaximumSize.X.Offset)
				or math.huge
			local maxHeightPx = MaximumSize and (MaximumSize.Y.Scale * parentAbsSizeForMinMax.Y + MaximumSize.Y.Offset)
				or math.huge

			-- Original edge calculation logic (assuming MainFrame.Position is center if AnchorPoint is 0.5,0.5 for these calcs)
			local initialAbsCenterX = currentScreenGuiAbsSize.X * initialFramePosition.X.Scale
				+ initialFramePosition.X.Offset
			local initialAbsSizeX_forEdgeCalc = initialFrameSize.X.Offset -- Original code used offset for this part of edge calculation
			local initialRightEdgeX = initialAbsCenterX + initialAbsSizeX_forEdgeCalc / 2
			local initialLeftEdgeX = initialAbsCenterX - initialAbsSizeX_forEdgeCalc / 2

			local initialAbsCenterY = currentScreenGuiAbsSize.Y * initialFramePosition.Y.Scale
				+ initialFramePosition.Y.Offset
			local initialAbsSizeY_forEdgeCalc = initialFrameSize.Y.Offset -- Original code used offset for this part of edge calculation
			local initialBottomEdgeY = initialAbsCenterY + initialAbsSizeY_forEdgeCalc / 2
			local initialTopEdgeY = initialAbsCenterY - initialAbsSizeY_forEdgeCalc / 2

			if resizeTypeX then
				if resizeTypeX == "Left" then
					local newLeftEdge = initialLeftEdgeX + mouseDelta.X
					newAbsWidthPx = math.clamp(initialRightEdgeX - newLeftEdge, minWidthPx, maxWidthPx)
					if newAbsWidthPx ~= (initialRightEdgeX - newLeftEdge) then -- Readjust edge if clamped
						newLeftEdge = initialRightEdgeX - newAbsWidthPx
					end
					if not LockedPosition then
						local newAbsCenterX = newLeftEdge + newAbsWidthPx / 2 -- Assuming center is halfway for position update
						finalPosOffsetX = newAbsCenterX - currentScreenGuiAbsSize.X * initialFramePosition.X.Scale
					end
				elseif resizeTypeX == "Right" then
					local newRightEdge = initialRightEdgeX + mouseDelta.X
					newAbsWidthPx = math.clamp(newRightEdge - initialLeftEdgeX, minWidthPx, maxWidthPx)
					if not LockedPosition then
						local newAbsCenterX = initialLeftEdgeX + newAbsWidthPx / 2 -- Assuming center is halfway
						finalPosOffsetX = newAbsCenterX - currentScreenGuiAbsSize.X * initialFramePosition.X.Scale
					end
				end
			end

			if resizeTypeY then
				if resizeTypeY == "Top" then
					local newTopEdge = initialTopEdgeY + mouseDelta.Y
					newAbsHeightPx = math.clamp(initialBottomEdgeY - newTopEdge, minHeightPx, maxHeightPx)
					if newAbsHeightPx ~= (initialBottomEdgeY - newTopEdge) then -- Readjust edge if clamped
						newTopEdge = initialBottomEdgeY - newAbsHeightPx
					end
					if not LockedPosition then
						local newAbsCenterY = newTopEdge + newAbsHeightPx / 2 -- Assuming center is halfway
						finalPosOffsetY = newAbsCenterY - currentScreenGuiAbsSize.Y * initialFramePosition.Y.Scale
					end
				elseif resizeTypeY == "Bottom" then
					local newBottomEdge = initialBottomEdgeY + mouseDelta.Y
					newAbsHeightPx = math.clamp(newBottomEdge - initialTopEdgeY, minHeightPx, maxHeightPx)
					if not LockedPosition then
						local newAbsCenterY = initialTopEdgeY + newAbsHeightPx / 2 -- Assuming center is halfway
						finalPosOffsetY = newAbsCenterY - currentScreenGuiAbsSize.Y * initialFramePosition.Y.Scale
					end
				end
			end

			-- Convert final absolute pixel dimensions back to UDim offsets for size
			local finalSizeOffsetX = newAbsWidthPx - (initialFrameSize.X.Scale * self.Parent.AbsoluteSize.X)
			local finalSizeOffsetY = newAbsHeightPx - (initialFrameSize.Y.Scale * self.Parent.AbsoluteSize.Y)

			local finalNewSize =
				UDim2.new(initialFrameSize.X.Scale, finalSizeOffsetX, initialFrameSize.Y.Scale, finalSizeOffsetY)
			local finalNewPosition = initialFramePosition -- Default if LockedPosition is true
			if typeof(LockedPosition) == "UDim2" then
				finalNewPosition = LockedPosition
			elseif not LockedPosition then -- Only update if not locked (boolean false)
				finalNewPosition = UDim2.new(
					initialFramePosition.X.Scale,
					finalPosOffsetX,
					initialFramePosition.Y.Scale,
					finalPosOffsetY
				)
			end
			return finalNewSize, finalNewPosition
		end
	end

	local function createDragHandler(resizeTypeX, resizeTypeY)
		return function(Info, Input: InputObject)
			local mouseDelta = Input.Position - Info.StartPosition
			local newSize, newPosition =
				CalculateResizeProperties(Info.FramePosition, Info.FrameSize, mouseDelta, resizeTypeX, resizeTypeY)

			MainFrame.Size = newSize
			MainFrame.Position = newPosition
		end
	end

	local LeftSide = wax.shared.Interface.New("Frame", {
		Size = UDim2.new(0, HandleSize, 1, -CornerHandleSize * 2),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6,
	})
	wax.shared.Drag.Setup(MainFrame, LeftSide, createDragHandler("Left", nil))

	local RightSide = wax.shared.Interface.New("Frame", {
		Size = UDim2.new(0, HandleSize, 1, -CornerHandleSize * 2),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6,
	})
	wax.shared.Drag.Setup(MainFrame, RightSide, createDragHandler("Right", nil))

	local TopSide = wax.shared.Interface.New("Frame", {
		Size = UDim2.new(1, -CornerHandleSize * 2, 0, HandleSize),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6,
	})
	wax.shared.Drag.Setup(MainFrame, TopSide, createDragHandler(nil, "Top"))

	local BottomSide = wax.shared.Interface.New("Frame", {
		Size = UDim2.new(1, -CornerHandleSize * 2, 0, HandleSize),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6,
	})
	wax.shared.Drag.Setup(MainFrame, BottomSide, createDragHandler(nil, "Bottom"))

	local TopLeftCorner = wax.shared.Interface.New("Frame", {
		Size = UDim2.fromOffset(CornerHandleSize, CornerHandleSize),
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6 + 1,
	})
	wax.shared.Drag.Setup(MainFrame, TopLeftCorner, createDragHandler("Left", "Top"))

	local TopRightCorner = wax.shared.Interface.New("Frame", {
		Size = UDim2.fromOffset(CornerHandleSize, CornerHandleSize),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6 + 1,
	})
	wax.shared.Drag.Setup(MainFrame, TopRightCorner, createDragHandler("Right", "Top"))

	local BottomLeftCorner = wax.shared.Interface.New("Frame", {
		Size = UDim2.fromOffset(CornerHandleSize, CornerHandleSize),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6 + 1,
	})
	wax.shared.Drag.Setup(MainFrame, BottomLeftCorner, createDragHandler("Left", "Bottom"))

	local BottomRightCorner = wax.shared.Interface.New("Frame", {
		Size = UDim2.fromOffset(CornerHandleSize, CornerHandleSize),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6 + 1,
	})
	wax.shared.Drag.Setup(MainFrame, BottomRightCorner, createDragHandler("Right", "Bottom"))

	return self
end

return Resize

end)() end,
    [30] = function()local wax,script,require=ImportGlobals(30)local ImportGlobals return (function(...)if not isfolder("Cobalt") then
	makefolder("Cobalt")
end

if not isfile("Cobalt/Settings.json") then
	writefile("Cobalt/Settings.json", "{}")
end

local SaveManager = {
	State = {},
}

local Success, Error = pcall(function()
	SaveManager.State = wax.shared.HttpService:JSONDecode(readfile("Cobalt/Settings.json"))
end)

if not Success then
	warn("Failed to load settings: " .. Error)
end

function SaveManager:SetState(Idx, Value)
	SaveManager.State[Idx] = Value
	pcall(writefile, "Cobalt/Settings.json", wax.shared.HttpService:JSONEncode(SaveManager.State))
end

function SaveManager:GetState(Idx)
	return SaveManager.State[Idx]
end

return SaveManager

end)() end,
    [32] = function()local wax,script,require=ImportGlobals(32)local ImportGlobals return (function(...)-- LuaEncode - Fast Table Serialization Library for Pure Luau/Lua 5.1+
-- Copyright (c) 2022-2024 reggie@latte.to | MIT License
-- https://github.com/regginator/LuaEncode

--!optimize 2
--!native

local table, string, next, pcall, game, workspace, tostring, tonumber, getmetatable =
	table, string, next, pcall, game, workspace, tostring, tonumber, getmetatable

local string_format = string.format
local string_char = string.char
local string_gsub = string.gsub
local string_match = string.match
local string_rep = string.rep
local string_pack = string.pack
local string_byte = string.byte
local string_gmatch = string.gmatch

local table_concat = table.concat

local Type = typeof or type

local function LookupTable(array)
	local Out = {}
	for _, Value in next, array do
		Out[Value] = true
	end

	return Out
end

-- Used to properly serialize NaN values
local NumberCorrection = {
	[string_pack(">n", 0 / 0)] = "0/0",
	[string_pack(">n", -(0 / 0))] = "-(0/0)",
	[string_pack(">n", tonumber("nan"))] = 'tonumber("nan")',
	[string_pack(">n", tonumber("-nan"))] = 'tonumber("-nan")',
}

-- Used for checking direct getfield syntax; Lua keywords can't be used as keys without being a str
-- FYI; `continue` is Luau only (in Lua it's actually a global function)
local LuaKeywords = LookupTable({
	"and",
	"break",
	"do",
	"else",
	"elseif",
	"end",
	"false",
	"for",
	"function",
	"if",
	"in",
	"local",
	"nil",
	"not",
	"or",
	"repeat",
	"return",
	"then",
	"true",
	"until",
	"while",
	"continue",
})

-- Type names that can be used as manual key indexes (i.e. non-reference types)
local KeyIndexTypes = LookupTable({
	"number",
	"string",
	"boolean",
	"Enum",
	"EnumItem",
	"Enums",
})

-- Returns the length of the array part (including holes) and if it's a pure array
local function GetIsArrayAndLength(tbl)
	local maxIndex = 0
	local count = 0
	for k, _ in pairs(tbl) do
		if type(k) == "number" and k > 0 and math.floor(k) == k then
			if k > maxIndex then
				maxIndex = k
			end
			count = count + 1
		else
			return 0, false
		end
	end
	return maxIndex, true
end

-- Simple function for directly checking the type on values, with their input, variable name,
-- and desired type name(s) to check
local function CheckType(inputData, dataName, ...)
	local ValidTypes = { ... }
	local ValidTypesLookup = LookupTable(ValidTypes)
	local InputType = Type(inputData)

	if not ValidTypesLookup[InputType] then
		error(
			string_format(
				"LuaEncode: Incorrect type for `%s`: `%s` expected, got `%s`",
				dataName,
				table_concat(ValidTypes, ", "), -- For if multiple types are accepted
				InputType
			),
			0
		)
	end

	return inputData -- Return back input directly
end

-- This re-serializes a string back into Lua, for the interpreter AND humans to read. This fixes
-- `string_format("%q")` only outputting in system encoding, instead of explicit Lua byte escapes
local SerializeString
do
	-- These are control characters to be encoded in a certain way in Lua rather than just a byte escape
	local SpecialCharacters = {
		['"'] = '\\"',
		["\\"] = "\\\\",
		-- Special ASCII control char codes
		["\a"] = "\\a",
		["\b"] = "\\b",
		["\t"] = "\\t",
		["\n"] = "\\n",
		["\v"] = "\\v",
		["\f"] = "\\f",
		["\r"] = "\\r",
	}

	-- We need to assign all extra normal byte escapes for runtime optimization
	for Index = 0, 255 do
		local Character = string_char(Index)

		if not SpecialCharacters[Character] and (Index < 32 or Index > 126) then
			SpecialCharacters[Character] = string_format("\\x%02X", Index)
		end
	end

	function SerializeString(inputString)
		-- FYI; We can't do "\0-\31" in Lua 5.1 (Only Luau/Lua 5.2+) due to an embedded zeros in pattern
		-- issue. See: https://stackoverflow.com/a/22962409
		return table_concat({ '"', string_gsub(inputString, '[%z\\"\1-\31\127-\255]', SpecialCharacters), '"' })
	end
end

-- Escape warning messages and such for comment block inserts
local function CommentBlock(inputString)
	local Padding = ""
	for Match in string_gmatch(inputString, "%](=*)%]") do
		if #Match >= #Padding then
			Padding = Match .. "="
		end
	end

	return "--[" .. Padding .. "[" .. inputString .. "]" .. Padding .. "]"
end

--[[
LuaEncode(inputTable: {[any]: any}, options: {[string]: any}): string

    ---------- OPTIONS: ----------

    Prettify <boolean:false> | Whether or not the output should use pretty printing

    IndentCount <number:0> | The amount of "spaces" that should be indented per entry (*Note:
    If `Prettify` is set to true and this is unspecified, it'll be set to `4` automatically*)

    InsertCycles <boolean:false> | If there are cyclic references in your table, the output
    will be wrapped in an anonymous function that manually sets paths to those references.
    **NOTE: If a key in the index path to the cycle is a reference type (e.g. `table`,
    `function`), the codegen can't externally set that path, and will be ignored.**

    OutputWarnings <boolean:true> | If "warnings" should be placed to the output (as
    comments); It's recommended to keep this enabled, however this can be disabled at ease

    FunctionsReturnRaw <boolean:false> | If functions in said table return back a "raw"
    value to place in the output as the key/value

    UseInstancePaths <boolean:true> | If `Instance` reference objects should return their
    Lua-accessable path for encoding. If the instance is parented under `nil` or isn't under
    `game`/`workspace`, it'll always fall back to `Instance.new(ClassName)` as before

    SerializeMathHuge <boolean:true> | If numbers calculated as "infinite" (or negative-inf)
    numbers should be serialized with "math.huge". (uses the `math` import, as opposed to just
    a direct data type) If false, "`1/0`" or "`-1/0`" will be serialized, which is supported
    on all target versions

]]

local function LuaEncode(inputTable, options)
	options = options or {}

	-- Check main args
	CheckType(inputTable, "inputTable", "table")
	CheckType(options, "options", "table")

	-- Check options
	CheckType(options.Prettify, "options.Prettify", "boolean", "nil")
	CheckType(options.PrettyPrinting, "options.PrettyPrinting", "boolean", "nil") -- Alias for `Options.Prettify`
	CheckType(options.IndentCount, "options.IndentCount", "number", "nil")
	CheckType(options.InsertCycles, "options.InsertCycles", "boolean", "nil")
	CheckType(options.OutputWarnings, "options.OutputWarnings", "boolean", "nil")
	CheckType(options.FunctionsReturnRaw, "options.FunctionsReturnRaw", "boolean", "nil")
	CheckType(options.UseInstancePaths, "options.UseInstancePaths", "boolean", "nil")
	CheckType(options.GetNilFunctionInsert, "options.GetNilFunctionInsert", "boolean", "nil")
	CheckType(options.SerializeMathHuge, "options.SerializeMathHuge", "boolean", "nil")

	CheckType(options._StackLevel, "options._StackLevel", "number", "nil")
	CheckType(options._VisitedTables, "options._VisitedTables", "table", "nil")

	local Prettify = (options.Prettify == nil and options.PrettyPrinting == nil and false)
		or (options.Prettify ~= nil and options.Prettify)
		or (options.PrettyPrinting and options.PrettyPrinting)
	local IndentCount = options.IndentCount or (Prettify and 4) or 0
	local InsertCycles = (options.InsertCycles == nil and false) or options.InsertCycles
	local OutputWarnings = (options.OutputWarnings == nil and true) or options.OutputWarnings
	local GetNilFunctionInsert = (options.GetNilFunctionInsert == nil and false) or options.GetNilFunctionInsert
	local UseInstancePaths = (options.UseInstancePaths == nil and true) or options.UseInstancePaths
	local SerializeMathHuge = (options.SerializeMathHuge == nil and true) or options.SerializeMathHuge

	local RefMaps = options._RefMaps or { [inputTable] = "" } -- [Ref: table] = ".example["ref path"]'
	local CycleMaps = options._CycleMaps or {} -- ['.example["ref path"]'] = '.another["ref path"]'

	local StackLevel = options._StackLevel or 1
	local EntryStackLevel = options._StackLevel or 1
	local VisitedTables = options._VisitedTables or {} -- [Ref: table] = true
	local DidInsertNilFunction = options._DidInsertNilFunction or false

	-- Lazy serialization reference values
	local PositiveInf = (SerializeMathHuge and "math.huge") or "1/0"
	local NegativeInf = (SerializeMathHuge and "-math.huge") or "-1/0"
	local NewEntryString = (Prettify and "\n") or ""
	local CodegenNewline = (Prettify and "\n") or " "
	local ValueSeperator = (Prettify and ", ") or ","
	local BlankSeperator = (Prettify and " ") or ""
	local EqualsSeperator = (Prettify and " = ") or "="

	-- For pretty printing we need to keep track of the current stack level, then repeat IndentString by that count
	local IndentStringBase = string_rep(" ", IndentCount)

	-- Calculated in the walk loop, based on the current StackLevel
	local IndentString = nil
	local EndingIndentString = nil

	--IndentString = (Prettify and string_rep(IndentString, StackLevel)) or IndentString
	--local EndingIndentString = (#IndentString > 0 and string_sub(IndentString, 1, -IndentCount - 1)) or ""

	-- For number key values, we want to explicitly serialize the index num ONLY when it needs to be
	local KeyNumIndex = 1

	-- Cases for encoding values, then end setup. Functions are all expected to return a (EncodedKey: string, EncloseInBrackets: boolean)
	local TypeCases = {}
	do
		-- Basic func for getting the direct value of an encoded type without weird table.pack()[1] syntax
		local function TypeCase(typeName, value)
			-- Each of these funcs return a tuple, so it'd be annoying to do case-by-case
			local EncodedValue = TypeCases[typeName](value, false) -- False to label as NOT `isKey`
			return EncodedValue
		end

		-- For "tuple" args specifically, so there isn't a bunch of re-used code
		local function Args(...)
			local EncodedValues = {}

			for _, Arg in next, { ... } do
				EncodedValues[#EncodedValues + 1] = TypeCase(Type(Arg), Arg)
			end

			return table_concat(EncodedValues, ValueSeperator)
		end

		-- For certain Roblox data types, we use a custom serialization method for filling out params etc
		local function Params(newData, params)
			return "(function(v, p) for pn, pv in next, p do v[pn] = pv end return v end)("
				.. table_concat({ newData, TypeCase("table", params) }, ValueSeperator)
				.. ")"
		end

		TypeCases["number"] = function(value, isKey)
			-- If the number isn't the current real index of the table, we DO want to
			-- explicitly define it in the serialization no matter what for accuracy
			if isKey and value == KeyNumIndex then
				-- ^^ What's EXPECTED unless otherwise explicitly defined, if so, return no encoded num
				KeyNumIndex = KeyNumIndex + 1
				return nil, true
			end

			-- Lua's internal `tostring` handling will denote positive/negativie-infinite number TValues as "inf", which
			-- makes certain numbers not encode properly. We also just want to make the output precise
			if value == 1 / 0 then
				return PositiveInf
			elseif value == -1 / 0 then
				return NegativeInf
			elseif value == math.pi then
				return "math.pi"
			end

			-- Provided by felixdm
			local NumberPacked = string_pack(">n", value) -- gameguy is a boss
			local CorrectedNumber = NumberCorrection[NumberPacked]
			if CorrectedNumber then
				return CorrectedNumber
			end

			if value ~= value then
				return string_format(
					'(string.unpack(">n", "\\%*\\%*\\%*\\%*\\%*\\%*\\%*\\%*"))',
					string_byte(NumberPacked, 1, 8)
				)
			end

			-- Return fixed-formatted precision num
			return string_format("%.14g", value)
		end

		TypeCases["string"] = function(value, isKey)
			if isKey and not LuaKeywords[value] and string_match(value, "^[A-Za-z_][A-Za-z0-9_]*$") then
				-- ^^ Then it's a syntaxically-correct variable, doesn't need explicit string def
				return value, true
			end

			return SerializeString(value)
		end

		-- This is NOT used for normal table depth, only tables-as-keys and Roblox data types that use tables as
		-- arguments for constructor functions
		TypeCases["table"] = function(value, isKey)
			-- Primarily for tables-as-keys
			if VisitedTables[value] and OutputWarnings then
				return "{--[[LuaEncode: Duplicate reference]]}"
			end

			local NewOptions = setmetatable({}, { __index = options })
			do
				NewOptions.Prettify = (isKey and false) or Prettify
				NewOptions.IndentCount = (isKey and ((not Prettify and IndentCount) or 1)) or IndentCount
				NewOptions._StackLevel = (isKey and 1) or StackLevel + 1
				NewOptions._VisitedTables = VisitedTables
				NewOptions._DidInsertNilFunction = DidInsertNilFunction
				NewOptions._RefMaps = RefMaps
				NewOptions._CycleMaps = CycleMaps
				NewOptions.InsertCycles = InsertCycles
			end

			local Result, InsertedNilFunction = LuaEncode(value, NewOptions)

			if InsertedNilFunction then
				DidInsertNilFunction = true
			end

			return Result
		end

		TypeCases["boolean"] = function(value)
			return value and "true" or "false"
		end

		TypeCases["nil"] = function(value)
			return "nil"
		end

		TypeCases["function"] = function(value)
			-- We can't serialize functions so we just return a comment block with function information
			local FunctionName, ArgumentCount, VarArg, Line = debug.info(value, "nal")

			local Arguments = {}
			for Index = 1, ArgumentCount do
				Arguments[Index] = string_format("arg%d", Index)
			end

			return string_format(
				[[function(%s)%s%s%s%s%sreturn%send]],
				`{table_concat(Arguments, ", ")}{VarArg and `{Arguments[1] and ", " or ""}...` or ""}`,

				`{CodegenNewline}{IndentString}{IndentStringBase}-- Name: {FunctionName == "" and "Anonymous Function" or FunctionName} | Line: {Line}`,

				`{CodegenNewline}{IndentString}{IndentStringBase}-- {islclosure(value) and `Upvalues: {#debug.getupvalues(
					value
				)}` or "Upvalues: N/A (C Closure)"}`,

				`{CodegenNewline}{IndentString}{IndentStringBase}-- `
					.. (
						getfunctionhash
							and `{islclosure(value) and `Function Hash: {getfunctionhash(value)}` or "Function Hash: N/A (C Closure)"}`
						or "Function Hash: N/A (getfunctionhash == nil)"
					),

				OutputWarnings
						and `{CodegenNewline}{IndentString}{IndentStringBase}-- LuaEncode: Unable to serialize function`
					or "",

				`{CodegenNewline}{IndentString}{IndentStringBase}`,
				`{CodegenNewline}{IndentString}`
			)
		end

		---------- ROBLOX CUSTOM DATA TYPES BELOW ----------

		TypeCases["Axes"] = function(value)
			local EncodedArgs = {}
			local EnumValues = {
				["Enum.Axis.X"] = value.X,
				["Enum.Axis.Y"] = value.Y,
				["Enum.Axis.Z"] = value.Z,
			}

			for EnumValue, IsEnabled in next, EnumValues do
				if IsEnabled then
					EncodedArgs[#EncodedArgs + 1] = EnumValue
				end
			end

			return "Axes.new(" .. table_concat(EncodedArgs, ValueSeperator) .. ")"
		end

		TypeCases["BrickColor"] = function(value)
			-- BrickColor.Number (Its enum ID) will be slightly more efficient in all cases in deser,
			-- so we'll use it if Options.Prettify is false
			return "BrickColor.new(" .. (Prettify and TypeCase("string", value.Name)) or value.Number .. ")"
		end

		TypeCases["CFrame"] = function(value)
			if value == CFrame.identity then
				return "CFrame.identity"
			end

			return "CFrame.new(" .. Args(value:components()) .. ")"
		end

		TypeCases["CatalogSearchParams"] = function(value)
			return Params("CatalogSearchParams.new()", {
				SearchKeyword = value.SearchKeyword,
				MinPrice = value.MinPrice,
				MaxPrice = value.MaxPrice,
				SortType = value.SortType, -- EnumItem
				CategoryFilter = value.CategoryFilter, -- EnumItem
				BundleTypes = value.BundleTypes, -- table
				AssetTypes = value.AssetTypes, -- table
			})
		end

		TypeCases["Color3"] = function(value)
			-- Using floats for RGB values, most accurate for direct serialization
			return "Color3.new(" .. Args(value.R, value.G, value.B) .. ")"
		end

		TypeCases["ColorSequence"] = function(value)
			return "ColorSequence.new(" .. TypeCase("table", value.Keypoints) .. ")"
		end

		TypeCases["ColorSequenceKeypoint"] = function(value)
			return "ColorSequenceKeypoint.new(" .. Args(value.Time, value.Value) .. ")"
		end

		-- We're using fromUnixTimestamp to serialize the object
		TypeCases["DateTime"] = function(value)
			-- Always an int, we don't need to do anything special
			return "DateTime.fromUnixTimestamp(" .. value.UnixTimestamp .. ")"
		end

		-- Properties seem to throw an error on index if the scope isn't a Studio plugin, so we're
		-- directly getting values! (so fun!!!!)
		TypeCases["DockWidgetPluginGuiInfo"] = function(value)
			-- e.g.: "InitialDockState:Right InitialEnabled:0 InitialEnabledShouldOverrideRestore:0 FloatingXSize:0 FloatingYSize:0 MinWidth:0 MinHeight:0"
			local ValueString = tostring(value)

			return "DockWidgetPluginGuiInfo.new("
				.. Args(
					-- InitialDockState (Enum.InitialDockState)
					Enum.InitialDockState[string_match(ValueString, "InitialDockState:(%w+)")], -- Enum.InitialDockState.Right
					-- InitialEnabled and InitialEnabledShouldOverrideRestore (boolean as number; `0` or `1`)
					string_match(ValueString, "InitialEnabled:(%w+)") == "1", -- false
					string_match(ValueString, "InitialEnabledShouldOverrideRestore:(%w+)") == "1", -- false
					-- FloatingXSize/FloatingYSize (numbers)
					tonumber(string_match(ValueString, "FloatingXSize:(%w+)")), -- 0
					tonumber(string_match(ValueString, "FloatingYSize:(%w+)")), -- 0
					-- MinWidth/MinHeight (numbers)
					tonumber(string_match(ValueString, "MinWidth:(%w+)")), -- 0
					tonumber(string_match(ValueString, "MinHeight:(%w+)")) -- 0
				)
				.. ")"
		end

		-- e.g. `Enum.UserInputType`
		TypeCases["Enum"] = function(value)
			return "Enum." .. tostring(value)
		end

		-- e.g. `Enum.UserInputType.Gyro`
		TypeCases["EnumItem"] = function(value)
			return tostring(value) -- Returns the full enum index for now (e.g. "Enum.UserInputType.Gyro")
		end

		-- i.e. the `Enum` global return
		TypeCases["Enums"] = function(value)
			return "Enum"
		end

		TypeCases["Faces"] = function(value)
			local EncodedArgs = {}
			local EnumValues = {
				["Enum.NormalId.Top"] = value.Top, -- These return bools
				["Enum.NormalId.Bottom"] = value.Bottom,
				["Enum.NormalId.Left"] = value.Left,
				["Enum.NormalId.Right"] = value.Right,
				["Enum.NormalId.Back"] = value.Back,
				["Enum.NormalId.Front"] = value.Front,
			}

			for EnumValue, IsEnabled in next, EnumValues do
				if IsEnabled then
					EncodedArgs[#EncodedArgs + 1] = EnumValue
				end
			end

			return "Faces.new(" .. table_concat(EncodedArgs, ValueSeperator) .. ")"
		end

		TypeCases["FloatCurveKey"] = function(value)
			return "FloatCurveKey.new(" .. Args(value.Time, value.Value, value.Interpolation) .. ")"
		end

		TypeCases["Font"] = function(value)
			return "Font.new(" .. Args(value.Family, value.Weight, value.Style) .. ")"
		end

		-- Instance refs can be evaluated to their paths (optional), but if parented to
		-- nil or some DataModel not under `game`, it'll just return nil
		TypeCases["Instance"] = function(value)
			if UseInstancePaths then
				local InstancePath, NilFunctionInserted =
					wax.shared.CodeGen.GetFullPath(value, false, nil, GetNilFunctionInsert)

				if NilFunctionInserted then
					DidInsertNilFunction = true
				end

				if InstancePath then
					return InstancePath
				end

				-- ^^ Now, if the path isn't accessable, falls back to the return below anyway
			end

			return "nil"
				.. BlankSeperator
				.. CommentBlock("Instance.new(" .. TypeCase("string", value.ClassName) .. ")")
		end

		TypeCases["NumberRange"] = function(value)
			return "NumberRange.new(" .. Args(value.Min, value.Max) .. ")"
		end

		TypeCases["NumberSequence"] = function(value)
			return "NumberSequence.new(" .. TypeCase("table", value.Keypoints) .. ")"
		end

		TypeCases["NumberSequenceKeypoint"] = function(value)
			return "NumberSequenceKeypoint.new(" .. Args(value.Time, value.Value, value.Envelope) .. ")"
		end

		TypeCases["OverlapParams"] = function(value)
			return Params("OverlapParams.new()", {
				FilterDescendantsInstances = value.FilterDescendantsInstances,
				FilterType = value.FilterType,
				MaxParts = value.MaxParts,
				CollisionGroup = value.CollisionGroup,
				RespectCanCollide = value.RespectCanCollide,
			})
		end

		TypeCases["PathWaypoint"] = function(value)
			return "PathWaypoint.new(" .. Args(value.Position, value.Action, value.Label) .. ")"
		end

		TypeCases["PhysicalProperties"] = function(value)
			return "PhysicalProperties.new("
				.. Args(value.Density, value.Friction, value.Elasticity, value.FrictionWeight, value.ElasticityWeight)
				.. ")"
		end

		TypeCases["Random"] = function()
			return "Random.new()"
		end

		TypeCases["Ray"] = function(value)
			return "Ray.new(" .. Args(value.Origin, value.Direction) .. ")"
		end

		TypeCases["RaycastParams"] = function(value)
			return Params("RaycastParams.new()", {
				FilterDescendantsInstances = value.FilterDescendantsInstances,
				FilterType = value.FilterType,
				IgnoreWater = value.IgnoreWater,
				CollisionGroup = value.CollisionGroup,
				RespectCanCollide = value.RespectCanCollide,
			})
		end

		TypeCases["Rect"] = function(value)
			return "Rect.new(" .. Args(value.Min, value.Max) .. ")"
		end

		-- Roblox doesn't provide read properties for min/max on `Region3`, but they do on Region3int16.. Anyway,
		-- we CAN calculate the min/max of a Region3 from just .CFrame and .Size.. Thanks to wally for linking me
		-- the thread for this method lol
		TypeCases["Region3"] = function(value)
			local ValueCFrame = value.CFrame
			local ValueSize = value.Size

			return "Region3.new("
				.. Args(
					ValueCFrame * CFrame.new(-ValueSize / 2), -- Minimum
					ValueCFrame * CFrame.new(ValueSize / 2) -- Maximum
				)
				.. ")"
		end

		TypeCases["Region3int16"] = function(value)
			return "Region3int16.new(" .. Args(value.Min, value.Max) .. ")"
		end

		TypeCases["TweenInfo"] = function(value)
			return "TweenInfo.new("
				.. Args(
					value.Time,
					value.EasingStyle,
					value.EasingDirection,
					value.RepeatCount,
					value.Reverses,
					value.DelayTime
				)
				.. ")"
		end

		-- CURRENTLY UNDOCUMENTED*
		TypeCases["RotationCurveKey"] = function(value)
			return "RotationCurveKey.new(" .. Args(value.Time, value.Value, value.Interpolation) .. ")"
		end

		TypeCases["UDim"] = function(value)
			return "UDim.new(" .. Args(value.Scale, value.Offset) .. ")"
		end

		TypeCases["UDim2"] = function(value)
			if value.X.Offset == 0 and value.Y.Offset == 0 then
				return "UDim2.fromScale(" .. Args(value.X.Scale, value.Y.Scale) .. ")"
			end

			if value.X.Scale == 0 and value.Y.Scale == 0 then
				return "UDim2.fromOffset(" .. Args(value.X.Offset, value.Y.Offset) .. ")"
			end

			return "UDim2.new("
				.. Args(
					-- Not directly using X and Y UDims for better output (i.e. would be
					-- UDim2.new(UDim.new(1, 0), UDim.new(1, 0)) if I did)
					value.X.Scale,
					value.X.Offset,
					value.Y.Scale,
					value.Y.Offset
				)
				.. ")"
		end

		local Vector2Replacements = {
			[Vector2.zero] = "Vector2.zero",
			[Vector2.one] = "Vector2.one",
			[Vector2.xAxis] = "Vector2.xAxis",
			[Vector2.yAxis] = "Vector2.yAxis",
		}

		TypeCases["Vector2"] = function(value)
			if Vector2Replacements[value] then
				return Vector2Replacements[value]
			end

			return "Vector2.new(" .. Args(value.X, value.Y) .. ")"
		end

		TypeCases["Vector2int16"] = function(value)
			return "Vector2int16.new(" .. Args(value.X, value.Y) .. ")"
		end

		local Vector3Replacements = {
			[Vector3.zero] = "Vector3.zero",
			[Vector3.one] = "Vector3.one",
			[Vector3.xAxis] = "Vector3.xAxis",
			[Vector3.yAxis] = "Vector3.yAxis",
			[Vector3.zAxis] = "Vector3.zAxis",
		}

		TypeCases["Vector3"] = function(value)
			if Vector3Replacements[value] then
				return Vector3Replacements[value]
			end

			return "Vector3.new(" .. Args(value.X, value.Y, value.Z) .. ")"
		end

		TypeCases["Vector3int16"] = function(value)
			return "Vector3int16.new(" .. Args(value.X, value.Y, value.Z) .. ")"
		end

		TypeCases["buffer"] = function(value)
			if wax.shared.SaveManager:GetState("PreferBufferFromString") then
				return `buffer.fromstring("{SerializeString(buffer.tostring(value))}")`
			end

			local Bytes = {}
			for i = 1, buffer.len(value) do
				table.insert(Bytes, buffer.readu8(value, i - 1))
			end

			return table_concat({
				"(function(bytes) ",
				CommentBlock("Type: buffer"),
				NewEntryString,
				IndentString,
				IndentStringBase,
				"local b = buffer.create(#bytes)",
				NewEntryString,
				IndentString,
				IndentStringBase,
				"for i = 1, #bytes do",
				NewEntryString,
				IndentString,
				IndentStringBase,
				IndentStringBase,
				"buffer.writeu8(b, i - 1, bytes[i])",
				NewEntryString,
				IndentString,
				IndentStringBase,
				"end",
				NewEntryString,
				IndentStringBase,
				IndentString,
				"return b",
				NewEntryString,
				IndentString,
				"end)({ ",
				table_concat(Bytes, ", "),
				" })",
			})
		end

		-- With userdata, just encode directly
		TypeCases["userdata"] = function(value)
			if getmetatable(value) ~= nil then -- Has mt
				return "newproxy(true)"
			else
				return "newproxy()" -- newproxy() defaults to false (no mt)
			end
		end
	end

	-- Setup for final output, which will be concat together
	local Output = {}

	local TablePointer = inputTable
	local NextKey = nil -- Used with TableStack so the TablePointer loop knows where to continue from upon stack pop
	local IsNewTable = true -- Used with table stack push/pop to identify when an opening curly brace should be added

	-- Stack array for table depth
	local TableStack = {} -- [Depth: number] = {TablePointer: table, NextKey: any, KeyNumIndex: number}

	while TablePointer do
		-- Update StackLevel for formatting
		StackLevel = EntryStackLevel + #TableStack
		IndentString = (Prettify and string_rep(IndentStringBase, StackLevel)) or ""
		if Prettify and StackLevel > 1 then
			EndingIndentString = string_rep(IndentStringBase, StackLevel - 1)
		else
			EndingIndentString = ""
		end

		-- Only append an opening brace to the table if this isn't just a continution up the stack
		if IsNewTable then
			Output[#Output + 1] = "{"
		elseif next(TablePointer, NextKey) == nil then -- Formatting for the next entry still needs to be added like any other value
			Output[#Output + 1] = NewEntryString .. EndingIndentString
		else
			Output[#Output + 1] = ","
		end

		VisitedTables[TablePointer] = true

		local ArrayLength, IsArray = GetIsArrayAndLength(TablePointer)
		if IsArray and ArrayLength > 0 then
			for i = 1, ArrayLength do
				if Prettify then
					Output[#Output + 1] = NewEntryString .. IndentString
				end
				local Value = TablePointer[i]
				local ValueType = Type(Value)

				if ValueType == "table" then
					local RootIndexPath
					if InsertCycles and RefMaps[TablePointer] then
						local EncodedKeyAsValue = TypeCases["number"](i, false)
						RootIndexPath = table_concat({ "[", EncodedKeyAsValue, "]" })
					end

					if VisitedTables[Value] then
						local IndexPath
						if InsertCycles and RefMaps[TablePointer] and RootIndexPath then
							IndexPath = RefMaps[TablePointer] .. RootIndexPath
						end

						local EncodedValueOrError =
							string_format("{%s}", (OutputWarnings and "--[[LuaEncode: Duplicate reference]]") or "")

						if IndexPath and RefMaps[Value] then
							CycleMaps[IndexPath] = RefMaps[Value]
						end

						Output[#Output + 1] = EncodedValueOrError

						continue
					end

					if InsertCycles and RefMaps[TablePointer] and RootIndexPath then
						RefMaps[Value] = RefMaps[TablePointer] .. RootIndexPath
					end

					-- Create a new options table for the recursive call
					local Encoded, InsertedNilFunction = LuaEncode(
						Value,
						setmetatable({
							Prettify = Prettify,
							IndentCount = IndentCount,
							_StackLevel = StackLevel + 1,
							_VisitedTables = VisitedTables,
							_DidInsertNilFunction = DidInsertNilFunction,
							_RefMaps = RefMaps,
							_CycleMaps = CycleMaps,
							InsertCycles = InsertCycles,
						}, { __index = options })
					)

					if InsertedNilFunction then
						DidInsertNilFunction = true
					end

					Output[#Output + 1] = Encoded
				elseif TypeCases[ValueType] then
					local ValueEncodedSuccess, EncodedValueOrError = pcall(TypeCases[ValueType], Value, false)
					if ValueEncodedSuccess and EncodedValueOrError then
						Output[#Output + 1] = EncodedValueOrError
					else
						Output[#Output + 1] = `nil{OutputWarnings and " " .. CommentBlock(
							string.format(
								"LuaEncode: Failed to encode value of data type %s: %s",
								ValueType,
								SerializeString(EncodedValueOrError)
							)
						) or ""}`
					end
				else
					Output[#Output + 1] = `nil{OutputWarnings and " " .. CommentBlock(
						string.format("LuaEncode: Serialization of data type %s is not supported", ValueType)
					) or ""}`
				end

				if i < ArrayLength then
					Output[#Output + 1] = ","
				end
			end
			Output[#Output + 1] = NewEntryString .. EndingIndentString .. "}"
			if #TableStack > 0 then
				local TableUp = TableStack[#TableStack]
				TableStack[#TableStack] = nil
				TablePointer, NextKey, KeyNumIndex = TableUp[1], TableUp[2], TableUp[3] -- Reverted to TablePointer, NextKey, KeyNumIndex (from outer scope)
				IsNewTable = false
			else
				break
			end

			continue
		end

		-- Just because of control flow restrictions with Lua compatibility
		local SkipStackPop = false

		for Key, Value in next, TablePointer, NextKey do
			local KeyType = Type(Key)
			local ValueType = Type(Value)

			local ValueIsTable = ValueType == "table"

			if TypeCases[KeyType] and TypeCases[ValueType] then
				if Prettify then
					Output[#Output + 1] = NewEntryString .. IndentString
				end

				local ValueWasEncoded = false -- Keeping track of this for adding a "," to the output if needed

				-- Evaluate output for key
				local KeyEncodedSuccess, EncodedKeyOrError, DontEncloseKeyInBrackets =
					pcall(TypeCases[KeyType], Key, true) -- The `true` represents if it's a key or not, here it is

				-- Evaluate output for value, ignoring 2nd arg (`DontEncloseInBrackets`) because this isn't the key
				local ValueEncodedSuccess, EncodedValueOrError
				if not ValueIsTable then
					ValueEncodedSuccess, EncodedValueOrError = pcall(TypeCases[ValueType], Value, false)
				end

				-- Ignoring `if EncodedKeyOrError` because the key doesn't actually need to ALWAYS
				-- be explicitly encoded, like if it's a number of the current key index!
				if KeyEncodedSuccess and (ValueIsTable or (ValueEncodedSuccess and EncodedValueOrError)) then
					-- Append explicit key if necessary
					if EncodedKeyOrError then
						if DontEncloseKeyInBrackets then
							Output[#Output + 1] = EncodedKeyOrError
						else
							Output[#Output + 1] = table_concat({ "[", EncodedKeyOrError, "]" })
						end

						Output[#Output + 1] = EqualsSeperator
					end

					-- Of course, recursive tables are handled differently and use the stack system
					if ValueIsTable then
						local IndexPath
						if InsertCycles and KeyIndexTypes[KeyType] and RefMaps[TablePointer] then
							if
								KeyType == "string"
								and not LuaKeywords[Key]
								and string_match(Key, "^[A-Za-z_][A-Za-z0-9_]*$")
							then
								IndexPath = "." .. Key
							else
								local EncodedKeyAsValue = TypeCases[KeyType](Key)
								IndexPath = table_concat({ "[", EncodedKeyAsValue, "]" })
							end
						end

						if not VisitedTables[Value] then
							if IndexPath then
								RefMaps[Value] = RefMaps[TablePointer] .. IndexPath
							end

							TableStack[#TableStack + 1] = { TablePointer, Key, KeyNumIndex }

							TablePointer = Value
							NextKey = nil
							KeyNumIndex = 1

							IsNewTable = true
							SkipStackPop = true
							break
						else
							EncodedValueOrError =
								string_format("{%s}", (OutputWarnings and "--[[LuaEncode: Duplicate reference]]") or "")

							if IndexPath then
								CycleMaps[IndexPath] = RefMaps[Value]
							end
						end
					end

					-- Append value like normal
					Output[#Output + 1] = EncodedValueOrError

					ValueWasEncoded = true
				elseif OutputWarnings then -- Then `Encoded(Key/Value)OrError` is the error msg
					-- ^^ Then either the key or value wasn't properly checked or encoded, and there
					-- was an error we need to log!
					local ErrorMessage = string_format(
						"LuaEncode: Failed to encode %s of data type %s: %s",
						(not KeyEncodedSuccess and "key") or (not ValueEncodedSuccess and "value") or "key/value",
						ValueType,
						(not KeyEncodedSuccess and SerializeString(EncodedKeyOrError))
							or (not ValueEncodedSuccess and SerializeString(EncodedValueOrError))
							or "(Failed to get error message)"
					)

					Output[#Output + 1] = CommentBlock(ErrorMessage)
				end

				if next(TablePointer, Key) == nil then
					-- If there isn't another value after the current index, add ending formatting
					Output[#Output + 1] = NewEntryString .. EndingIndentString
				elseif ValueWasEncoded then
					Output[#Output + 1] = ","
				end
			end
		end

		-- Vanilla Lua control flow is fun
		if not SkipStackPop then
			Output[#Output + 1] = "}"

			if #TableStack > 0 then
				local TableUp = TableStack[#TableStack]
				TableStack[#TableStack] = nil -- Pop off the table stack

				TablePointer, NextKey, KeyNumIndex = TableUp[1], TableUp[2], TableUp[3]
				IsNewTable = false
			else
				break
			end
		end
	end

	if InsertCycles and StackLevel == 1 then
		local CycleMapsOut = {}
		for CycleIndex, CycleMap in next, CycleMaps do
			CycleMapsOut[#CycleMapsOut + 1] = IndentString
				.. "t"
				.. CycleIndex
				.. EqualsSeperator
				.. "t"
				.. CycleMap
				.. CodegenNewline
		end

		if #CycleMapsOut > 0 then
			return table_concat({
				"(function(t)",
				NewEntryString,
				table_concat(CycleMapsOut),
				NewEntryString,
				IndentString,
				"return t",
				CodegenNewline,
				"end)(",
				table_concat(Output),
				")",
			}),
				DidInsertNilFunction
		end
	end

	return table_concat(Output), DidInsertNilFunction
end

return LuaEncode

end)() end,
    [33] = function()local wax,script,require=ImportGlobals(33)local ImportGlobals return (function(...)--[[[
Sonner 的 Luau 移植版（由 upio 制作）
原版 Sonner 作者：Emil Kowalski (https://sonner.emilkowal.ski/)

TODO（几乎不会实现的功能）:
 - 添加一种方式查看历史通知（比如鼠标悬停时显示，但我懒得写）
 - 处理过多通知导致 UI 崩坏的问题
 - 修复通知定位不一致的问题
]]

local Sonner = {
	Queue = {}, -- 通知队列
	TweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential), -- 动画信息
	Wrapper = nil, -- UI 容器
}

--[[
	内部函数：创建一个通知对象
	@param zindex number 图层顺序
	@param image string? 图标（可以是 Roblox 资产 ID 或自定义 icon 名）
	@param text string 通知文本
	@return Frame 通知 UI 对象
]]
local function InternalCreateNotificationObject(zindex, image, text)
	local NotificationTemplate = wax.shared.Interface.New("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(0, 250, 0, 50),
		Position = UDim2.new(0.5, 0, 1, 50),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		ZIndex = zindex,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIStroke"] = {
			Color = Color3.fromRGB(39, 42, 42),
		},

		["UIScale"] = {},
	})

	local ImageLabel = wax.shared.Interface.New("ImageLabel", {
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.new(0, 20, 0, 20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ZIndex = zindex + 1,
		Parent = NotificationTemplate,
	})

	if image then
		if image:find("rbxasset") then
			ImageLabel.Image = image
		else
			wax.shared.Icons.SetIcon(ImageLabel, image)
		end
	else
		ImageLabel.Visible = false
	end

	-- 定义淡入淡出动画
	wax.shared.Animations.SetFadeExpectation("In", ImageLabel, {
		ImageTransparency = 0,
	})
	wax.shared.Animations.SetFadeExpectation("Out", ImageLabel, {
		ImageTransparency = 1,
	})

	local Frame = wax.shared.Interface.New("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(1, -50, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = zindex + 1,
		Parent = NotificationTemplate,
	})

	wax.shared.Animations.AddFadeExclusion(Frame)

	-- 文本标签
	wax.shared.Interface.New("TextLabel", {
		BorderSizePixel = 0,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 200, 0, 50),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		Text = text,
		ZIndex = zindex + 1,
		Parent = Frame,
		TextWrapped = true,
	})

	return NotificationTemplate
end

--[[
	显示一个通知
	@param image string? 图标（可选）
	@param text string 通知文本
	@param internalTime number? 显示时长（默认 4.5 秒）
	@param removeCallback function? 自定义移除逻辑（可选）
]]
local function toast(image, text, internalTime, removeCallback)
	assert(Sonner.Wrapper, "Sonner 未初始化")
	assert(typeof(image) == "string" or image == nil, "Image 必须是字符串或 nil")
	assert(typeof(text) == "string", "必须提供 Text")
	assert(typeof(internalTime) == "number" or internalTime == nil, "Time 必须是数字或 nil")

	local time = internalTime or 4.5

	local Notif = InternalCreateNotificationObject(500, image, text)

	Notif.Position = UDim2.new(0.5, 0, 1, 30)
	Notif.Parent = Sonner.Wrapper

	table.insert(Sonner.Queue, Notif)

	local ScaleMultiplier = 0.9
	local RemovalQueue = {}

	-- 调整已有通知的布局
	for index, object in Sonner.Queue do
		if object == Notif then
			continue
		end

		object.ZIndex = 500 - (#Sonner.Queue - index)

		-- 向下偏移并缩小
		wax.shared.TweenService
			:Create(object.UIScale, Sonner.TweenInfo, {
				Scale = object.UIScale.Scale * ScaleMultiplier,
			})
			:Play()

		wax.shared.TweenService
			:Create(object, Sonner.TweenInfo, {
				Position = object.Position - UDim2.fromOffset(0, object.AbsoluteSize.Y * 0.35),
			})
			:Play()

		-- 如果通知超过 3 个，就强制移除旧的
		if ((#Sonner.Queue - index) + 1) >= 4 then
			wax.shared.Animations.FadeOut(object)
			task.delay(0.5, function()
				object:Destroy()
			end)
			table.insert(RemovalQueue, object)
		end
	end

	-- 清理被移除的对象
	for _, obj in RemovalQueue do
		table.remove(Sonner.Queue, table.find(Sonner.Queue, obj))
	end

	-- 新通知弹出动画
	wax.shared.TweenService
		:Create(Notif, Sonner.TweenInfo, {
			Position = UDim2.new(0.5, 0, 1, -20),
		})
		:Play()
	wax.shared.Animations.FadeIn(Notif)

	-- 移除逻辑
	if removeCallback then
		task.spawn(removeCallback, Notif, time)
	else
		task.delay(time, function()
			if not table.find(Sonner.Queue, Notif) then
				return
			end
			table.remove(Sonner.Queue, table.find(Sonner.Queue, Notif))

			wax.shared.Animations.FadeOut(Notif, 0.35)
			wax.shared.TweenService
				:Create(Notif, Sonner.TweenInfo, {
					Position = UDim2.new(0.5, 0, 1, 50),
				})
				:Play()
			task.wait(0.5)
			Notif:Destroy()
		end)
	end
end

-- 预设类型的通知
function Sonner.info(text, internalTime)
	toast("info", text, internalTime)
end

function Sonner.success(text, internalTime)
	toast("circle-check", text, internalTime)
end

function Sonner.warning(text, internalTime)
	toast("triangle-alert", text, internalTime)
end

function Sonner.error(text, internalTime)
	toast("circle-alert", text, internalTime)
end

function Sonner.toast(text, internalTime)
	toast(nil, text, internalTime)
end

--[[
	显示带有异步结果的通知（类似 promise）
	@param func function 要执行的函数
	@param options { loadingText, successText, errorText, time }
]]
function Sonner.promise(func, options)
	local loadingText = options.loadingText or "Loading..."
	local successText = options.successText or "Success!"
	local errorText = options.errorText or "Error!"
	local internalTime = options.time or 4.5

	toast("loader-circle", loadingText, internalTime, function(notif, time)
		local success, resultOrError = nil, nil

		-- 旋转加载图标
		local spinnerThread = task.spawn(function()
			repeat
				wax.shared.RunService.RenderStepped:Wait()
				local icon = notif:FindFirstChild("ImageLabel")
				if not icon then
					continue
				end
				icon.Rotation = (icon.Rotation + 1) % 360
			until success == false or resultOrError ~= nil
		end)

		-- 执行异步函数
		success, resultOrError = pcall(func)

	   	task.spawn(function()
			setthreadidentity(8)

			-- 移除加载图标
			wax.shared.Animations.FadeOut(notif.ImageLabel, 0.15)
			wax.shared.TweenService
				:Create(notif.ImageLabel, TweenInfo.new(0.25, Enum.EasingStyle.Exponential), {
					Size = UDim2.new(0, 0, 0, 0),
				})
				:Play()
			task.wait(0.15)

			if coroutine.status(spinnerThread) ~= "dead" then
				coroutine.close(spinnerThread)
			end
			notif.ImageLabel.Rotation = 0

			-- 成功 / 失败消息
			if success then
				wax.shared.Icons.SetIcon(notif.ImageLabel, "check")
				local message = (
					typeof(successText) == "string" and successText
					or typeof(successText) == "function" and successText(resultOrError)
					or "Success!"
				)

				if message:match("%s") then
					notif.Frame.TextLabel.Text = string.format(message, tostring(resultOrError))
				else
					notif.Frame.TextLabel.Text = message
				end
			else
				wax.shared.Icons.SetIcon(notif.ImageLabel, "circle-alert")
				notif.Frame.TextLabel.Text = (
					typeof(errorText) == "string" and errorText
					or typeof(errorText) == "function" and errorText(resultOrError)
					or "Error!"
				)
			end

			-- 显示结果图标
			wax.shared.Animations.FadeIn(notif.ImageLabel)
			wax.shared.TweenService
				:Create(notif.ImageLabel, TweenInfo.new(0.25, Enum.EasingStyle.Exponential), {
					Size = UDim2.new(0, 20, 0, 20),
				})
				:Play()

			-- 延迟销毁
			task.delay(time, function()
				if not table.find(Sonner.Queue, notif) then
					return
				end
				table.remove(Sonner.Queue, table.find(Sonner.Queue, notif))

				wax.shared.Animations.FadeOut(notif, 0.35)
				wax.shared.TweenService
					:Create(notif, Sonner.TweenInfo, {
						Position = UDim2.new(0.5, 0, 1, 50),
					})
					:Play()

				task.wait(0.5)
				notif:Destroy()
			end)
		end)
	end)
end

--[[
	显示自定义通知
	@param options { image, text, time }
]]
function Sonner.rawtoast(options)
	local image = options.image
	local text = options.text or "No Text Provided"
	local internalTime = options.time or 4.5

	toast(image, text, internalTime)
end

-- 初始化，设置通知容器
function Sonner.init(wrapper)
	Sonner.Wrapper = wrapper
end

return Sonner

end)() end,
    [34] = function()local wax,script,require=ImportGlobals(34)local ImportGlobals return (function(...)local PaginationHelper = wax.shared.Pagination.new({
	ItemsPerPage = 20,
	TotalItems = 0,
})

local Tabs = {}
local CurrentPage = {}
local CurrentInfo, CurrentTab, CurrentLog

local LogsList
local ShowPagination, ShowCalls

local DefaultTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Exponential)

type SupportedRemoteTypes = RemoteEvent | RemoteFunction | BindableEvent | BindableFunction | UnreliableRemoteEvent
local ClassOrder = {
	"RemoteEvent",
	"UnreliableRemoteEvent",
	"RemoteFunction",
	"BindableEvent",
	"BindableFunction",
}

local Images = {
	RemoteEvent = "rbxassetid://110803789420086",
	UnreliableRemoteEvent = "rbxassetid://126244162339059",
	RemoteFunction = "rbxassetid://108537517159060",
	BindableEvent = "rbxassetid://116839398727495",
	BindableFunction = "rbxassetid://112264959079193",
}

-- Functions
local function UpdateLogNameSize(Log)
	local TextSizeX, _TextSizeY =
		wax.shared.GetTextBounds("x" .. #Log.Calls, Log.Button.Calls.FontFace, Log.Button.Calls.TextSize)
	Log.Button.Name.Size = UDim2.new(1, -(TextSizeX + 24), 1, 0)
end

-- ContentProvider PreloadAsync bypass
Images = wax.shared.ImageFetcher.GetRemoteImages(Images)

local CobaltLogo = wax.shared.ImageFetcher.GetImage("Logo")

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

local ShowButton = wax.shared.Interface.New("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.fromRGB(15, 15, 15),
	Position = UDim2.new(0.5, 0, 0, 36),
	Size = UDim2.fromOffset(36, 36),
	Text = "",
	Visible = false,

	["ImageLabel"] = {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = CobaltLogo,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -10, 1, -10),
	},

	["UIStroke"] = {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.new(1, 1, 1),
	},

	MainUICorner,
	Parent = ScreenGui,
})
do
	ShowButton.MouseButton1Click:Connect(function()
		ShowButton.Visible = false
		MainFrame.Visible = true
	end)
end

-- Resizing
wax.shared.Resize.new({
	MainFrame = MainFrame,

	MinimumSize = Vector2.new(585, 220),

	CornerHandleSize = 20,
	HandleSize = 6,
})

-- Context Menus
local CurrentContext
local ContextMenu = wax.shared.Interface.New("Frame", {
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	Size = UDim2.fromScale(0, 0),
	ZIndex = 10000,
	Visible = false,

	["UICorner"] = {
		CornerRadius = UDim.new(0, 6),
	},

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 0),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	},

	["UIStroke"] = {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(25, 25, 25),
		Thickness = 1,
	},

	Parent = ScreenGui,
})

local function CreateContextMenu(Parent: GuiObject, Options: {}, MouseOnCursorPosition: boolean?)
	local ContextData = {
		Parent = Parent,
		Options = {},
	}

	local function BuildContextMenu(Options: {})
		for Order, Data in pairs(Options) do
			local TextButton = wax.shared.Interface.New("TextButton", {
				BackgroundColor3 = Color3.fromRGB(25, 25, 25),
				BackgroundTransparency = 1,
				LayoutOrder = Order,
				Size = UDim2.new(1, 0, 0, 30),
				Text = "",

				["UICorner"] = {
					CornerRadius = UDim.new(0, 6),
				},

				["UIPadding"] = {
					PaddingBottom = UDim.new(0, 6),
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 6),
					PaddingTop = UDim.new(0, 6),
				},
			})

			local IconToSet = Data.Icon
			if typeof(IconToSet) == "function" then
				IconToSet = IconToSet()
			end

			local ItemIcon
			if tostring(IconToSet):match("rbxasset") then
				ItemIcon = wax.shared.Interface.New("ImageLabel", {
					Image = IconToSet,
					Size = UDim2.fromScale(1, 1),
					SizeConstraint = Enum.SizeConstraint.RelativeYY,

					Parent = TextButton,
				})
			else
				ItemIcon = wax.shared.Interface.NewIcon(IconToSet, {
					Size = UDim2.fromScale(1, 1),
					SizeConstraint = Enum.SizeConstraint.RelativeYY,

					Parent = TextButton,
				})
			end

			local TextToSet = Data.Text
			if typeof(TextToSet) == "function" then
				TextToSet = TextToSet()
			end

			local ItemText = wax.shared.Interface.New("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromOffset(26, 0),
				Size = UDim2.fromScale(0, 1),
				Text = TextToSet,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,

				Parent = TextButton,
			})

			if Data.TextProperties then
				local Properties = typeof(Data.TextProperties) == "function" and Data.TextProperties()
					or Data.TextProperties
				for Property, Value in pairs(Properties) do
					ItemText[Property] = Value
				end
			end

			TextButton.MouseEnter:Connect(function()
				wax.shared.TweenService
					:Create(TextButton, DefaultTweenInfo, {
						BackgroundTransparency = 0,
					})
					:Play()
			end)
			TextButton.MouseLeave:Connect(function()
				wax.shared.TweenService
					:Create(TextButton, DefaultTweenInfo, {
						BackgroundTransparency = 1,
					})
					:Play()
			end)
			TextButton.MouseButton1Click:Connect(function()
				TextButton.BackgroundTransparency = 1

				if Data.Callback then
					Data.Callback()
				end

				if Data.CloseOnClick ~= false then
					ContextData:Close()
				else
					for _, Option in pairs(ContextData.Options) do
						Option:Display()
					end
				end
			end)

			function Data:Display()
				if typeof(Data.Text) == "function" then
					ItemText.Text = Data.Text()
				end

				if typeof(Data.Icon) == "function" then
					IconToSet = Data.Icon()

					if tostring(IconToSet):match("rbxasset") then
						ItemIcon.ImageRectOffset = Vector2.new(0, 0)
						ItemIcon.ImageRectSize = Vector2.new(0, 0)
						ItemIcon.Image = IconToSet
					else
						wax.shared.Icons.SetIcon(ItemIcon, IconToSet)
					end
				end

				if Data.TextProperties then
					local Properties = typeof(Data.TextProperties) == "function" and Data.TextProperties()
						or Data.TextProperties
					for Property, Value in pairs(Properties) do
						ItemText[Property] = Value
					end
				end
			end

			ContextData.Options[TextButton] = Data
		end
	end

	function ContextData:Open()
		if CurrentContext == ContextData then
			return
		end

		if CurrentContext then
			CurrentContext:Close()
		end

		CurrentContext = ContextData
		for Object, Data in pairs(ContextData.Options) do
			if Data.Condition and not Data.Condition() then
				continue
			end
			Object.Parent = ContextMenu
			Data:Display()
		end

		if MouseOnCursorPosition then
			ContextMenu.Position = UDim2.fromOffset(
				wax.shared.UserInputService:GetMouseLocation().X,
				wax.shared.UserInputService:GetMouseLocation().Y - 45
			)
		else
			ContextMenu.Position =
				UDim2.fromOffset(Parent.AbsolutePosition.X, Parent.AbsolutePosition.Y + Parent.AbsoluteSize.Y)
		end
		ContextMenu.Visible = true
	end

	function ContextData:Toggle()
		if CurrentContext == ContextData then
			ContextData:Close()
			return
		end

		ContextData:Open()
	end

	function ContextData:Close()
		if CurrentContext ~= ContextData then
			return
		end

		ContextMenu.Visible = false
		for Object, _ in pairs(ContextData.Options) do
			Object.Parent = nil
		end
		CurrentContext = nil
	end

	function ContextData:SetContextMenu(Options: { any })
		for Object, Data in pairs(ContextData.Options) do
			Object:Destroy()
		end
		ContextData.Options = {}
		BuildContextMenu(Options)
	end

	BuildContextMenu(Options)
	return ContextData
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
local OpenedModal
local ModalBackground = wax.shared.Interface.New("TextButton", {
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.5,
	Size = UDim2.fromScale(1, 1),
	Text = "",
	Visible = false,
	ZIndex = 2,

	MainUICorner,
	Parent = MainFrame,
})

local function OpenModal(Parent)
	OpenedModal = Parent

	OpenedModal.Visible = true
	ModalBackground.Visible = true
end

local function CloseModal()
	if OpenedModal then
		OpenedModal.Visible = false
		OpenedModal = nil
	end

	ModalBackground.Visible = false
end

ModalBackground.MouseButton1Click:Connect(CloseModal)

local function ConnectCloseButton(Button, Image, Parent)
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
	Button.MouseButton1Click:Connect(CloseModal)
end

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
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
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
	local CloseImage = wax.shared.Interface.NewIcon("x", {
		ImageTransparency = 0.5,
		Size = UDim2.fromOffset(22, 22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		Parent = CloseButton,
	})

	ConnectCloseButton(CloseButton, CloseImage, Parent)

	wax.shared.Interface.New("Frame", {
		Parent = Parent,
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 36),
	})

	return ModalTitle, ModalIcon
end

-- Settings
local SettingsFrame = wax.shared.Interface.New("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.65, 0, 0, 285),
	Text = "",
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

wax.shared.Resize.new({
	MainFrame = SettingsFrame,

	MaximumSize = UDim2.new(1, -2, 1, -2),
	MinimumSize = UDim2.fromScale(0.65, 0.712),
	Mirrored = true,
	LockedPosition = true,

	CornerHandleSize = 20,
	HandleSize = 6,
})

CreateModalTop("设置", "settings", SettingsFrame)

local SettingsScrollingFrame = wax.shared.Interface.New("ScrollingFrame", {
	AnchorPoint = Vector2.new(0, 1),
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 1, -37),
	ClipsDescendants = true,
	ScrollBarThickness = 2,
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
	},
})

local function CreateSettingsSection(SectionName: string)
	local Section = wax.shared.Interface.New("Frame", {
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

	return Section
end

local function CreateSettingsButton(Text: string, Callback: () -> (), Section: Frame, TextSize: number?)
	local Button = wax.shared.Interface.New("TextButton", {
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 15,
		Text = "",
		Parent = Section,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIStroke"] = {
			Color = Color3.fromRGB(25, 25, 25),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},

		["TextLabel"] = {
			Text = Text,
			TextSize = TextSize or 16,
			TextTransparency = 0.5,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, -1),
		},
	})

	Button.MouseButton1Click:Connect(function()
		if Callback then
			Callback()
		end
	end)

	return Button
end

local function CreateSettingsCheckbox(
	Idx: string,
	Options: {
		Text: string,
		Callback: (boolean) -> () | nil,
		Default: boolean?,
		Section: Frame,
	}
)
	local Checkbox = {
		Default = Options.Default or false,
		Value = if typeof(wax.shared.SaveManager:GetState(Idx)) == "boolean"
			then wax.shared.SaveManager:GetState(Idx)
			else (Options.Default or false),
	}

	local CheckboxUI = wax.shared.Interface.New("TextButton", {
		Text = Options.Text,
		TextSize = 16,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Options.Section,
	})

	local CheckContainer = wax.shared.Interface.New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Parent = CheckboxUI,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIStroke"] = {
			Color = Color3.fromRGB(25, 25, 25),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		},
	})

	local CheckImage = wax.shared.Interface.NewIcon("check", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ImageTransparency = Checkbox.Value and 0 or 1,
		Parent = CheckContainer,
	})

	CheckboxUI.MouseButton1Click:Connect(function()
		Checkbox:SetValue(not Checkbox.Value)
	end)

	function Checkbox:Reset()
		Checkbox:SetValue(Checkbox.Default)
	end

	function Checkbox:SetValue(NewValue)
		if wax.shared.ActorCommunicator then
			wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, NewValue)
		end

		wax.shared.SaveManager:SetState(Idx, NewValue)

		Checkbox.Value = NewValue

		wax.shared.TweenService
			:Create(CheckImage, DefaultTweenInfo, {
				ImageTransparency = Checkbox.Value and 0 or 1,
			})
			:Play()

		if Options.Callback then
			Options.Callback(Checkbox.Value)
		end
	end

	if wax.shared.ActorCommunicator then
		wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, Checkbox.Value)
	end
	wax.shared.Settings[Idx] = Checkbox
	return Checkbox
end

local function CreateSettingsDropdown(
	Idx: string,
	Options: {
		Multi: boolean?,
		AllowNull: boolean?,
		Values: { any },
		Default: any | { any },
		Callback: (any) -> () | nil,
		Text: string,
		Section: Frame,
	}
)
	local AllowNull = Options.AllowNull or false
	assert(AllowNull or Options.Default ~= nil, "当AllowNull为false时，必须提供默认值")

	local function CreateLookupTable(Values: { any })
		local LookupTable = {}
		for _, Value in Values do
			LookupTable[Value] = true
		end
		return LookupTable
	end

	local Dropdown = {
		Values = Options.Values or {},
		Default = Options.Default and CreateLookupTable(Options.Default)
			or Options.AllowNull and (Options.Multi and {} or Options.Values[1])
			or {},
		Value = wax.shared.SaveManager:GetState(Idx)
			or Options.Default and CreateLookupTable(Options.Default)
			or Options.AllowNull and (Options.Multi and {} or Options.Values[1])
			or {},
		Multi = Options.Multi or false,
	}

	local DropdownUI = wax.shared.Interface.New("TextButton", {
		Text = Options.Text,
		TextSize = 16,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Options.Section,
	})

	local DropdownIcon = wax.shared.Interface.NewIcon("chevron-down", {
		Size = UDim2.fromScale(1, 1),
		ImageTransparency = 0.5,
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		Parent = DropdownUI,
	})

	local function BuildDropdownContext()
		local Options = {}
		for Index, Object in Dropdown.Values do
			local IsArray = typeof(Index) == "number"

			local ContextOption = {
				Text = tostring(Object),
				CloseOnClick = not Dropdown.Multi,
				Callback = function()
					local Value = IsArray and Object or Index

					if Dropdown.Multi then
						Dropdown.Value[Value] = not (Dropdown.Value[Value] or false)
					else
						Dropdown.Value = Value
					end

					if wax.shared.ActorCommunicator then
						wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, Dropdown.Value)
					end

					wax.shared.SaveManager:SetState(Idx, Dropdown.Value)
				end,
				TextProperties = function()
					local Value = IsArray and Object or Index

					if Dropdown.Multi and Dropdown.Value[Value] then
						return {
							TextTransparency = 0,
						}
					elseif not Dropdown.Multi and Dropdown.Value == Value then
						return {
							TextTransparency = 0,
						}
					end

					return {
						TextTransparency = 0.5,
					}
				end,
			}

			if not IsArray then
				ContextOption.Text = Index
				ContextOption.Icon = Object
			end

			table.insert(Options, ContextOption)
		end
		return Options
	end

	local ContextMenu = CreateContextMenu(DropdownIcon, BuildDropdownContext())

	DropdownUI.MouseButton1Click:Connect(ContextMenu.Toggle)

	function Dropdown:Reset()
		for k, v in pairs(Dropdown.Default) do
			warn(k, v)
		end
		Dropdown:SetValue(Dropdown.Default)
	end

	function Dropdown:SetValue(NewValue)
		if wax.shared.ActorCommunicator then
			wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, NewValue)
		end

		wax.shared.SaveManager:SetState(Idx, NewValue)

		ContextMenu:Close()

		for Image, Object in pairs(Dropdown.Values) do
			local IsArray = typeof(Image) == "number"
			local Value = IsArray and Object or Image

			if Dropdown.Multi then
				Dropdown.Value[Value] = NewValue[Value]
			else
				Dropdown.Value = NewValue
			end
		end
	end

	if wax.shared.ActorCommunicator then
		wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, Dropdown.Default)
	end

	wax.shared.Settings[Idx] = Dropdown
	return Dropdown
end

local function CreateSettingsRemoteList(
	Idx: string,
	Options: {
		Text: string,
		Callback: (any) -> () | nil,
		Section: Frame,
		NullMessage: string,
	}
)
	local RemoteList = {
		Value = {},
		InfoMapping = {},
	}

	local RemoveIgnored

	local RemoteListContainer = wax.shared.Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		Parent = Options.Section,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 8),
		},

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 6),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		},

		["UIStroke"] = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(25, 25, 25),
			Thickness = 1,
		},
	})

	local NoRemotesText = wax.shared.Interface.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 100),
		TextTransparency = 0.5,
		Text = Options.NullMessage,
		TextSize = 14,
		Visible = true,
		Parent = RemoteListContainer,
	})

	function RemoteList:Display()
		for _, Object in pairs(RemoteListContainer:GetChildren()) do
			if not Object:IsA("Frame") then
				continue
			end
			Object:Destroy()
		end

		NoRemotesText.Visible = (#self.Value == 0)
		RemoveIgnored.Visible = (#self.Value > 0)

		for _, remoteData in self.Value do
			local remote = remoteData.Instance
			if not remote then
				continue
			end

			local ListElement = wax.shared.Interface.New("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				Size = UDim2.new(1, 0, 0, 32),
				Parent = RemoteListContainer,

				["UICorner"] = {
					CornerRadius = UDim.new(0, 4),
				},

				["UIStroke"] = {
					Color = Color3.fromRGB(25, 25, 25),
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				},

				["Frame"] = {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,

					["UIListLayout"] = {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 4),
					},

					["UIPadding"] = {
						PaddingLeft = UDim.new(0, 5),
					},

					["ImageLabel"] = {
						Size = UDim2.new(1, -8, 1, -8),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
						Image = Images[remote.ClassName],
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						LayoutOrder = 1,
					},

					["TextLabel"] = {
						Text = `{remote.Name} ({remoteData.Type})`,
						Size = UDim2.fromScale(1, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						TextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Left,
						BackgroundTransparency = 1,
						LayoutOrder = 2,
					},
				},
			})

			local RemoveButton = wax.shared.Interface.New("ImageButton", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.new(1, -12, 1, -12),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				ImageTransparency = 0.5,
				Parent = ListElement,
			})

			wax.shared.Icons.SetIcon(RemoveButton, "trash")

			RemoveButton.MouseEnter:Connect(function()
				wax.shared.TweenService
					:Create(RemoveButton, DefaultTweenInfo, {
						ImageTransparency = 0,
					})
					:Play()
			end)

			RemoveButton.MouseLeave:Connect(function()
				wax.shared.TweenService
					:Create(RemoveButton, DefaultTweenInfo, {
						ImageTransparency = 0.5,
					})
					:Play()
			end)

			RemoveButton.MouseButton1Click:Connect(function()
				self:RemoveFromList(remoteData)
				if Options.Callback then
					Options.Callback(remoteData)
				end
			end)
		end
	end

	function RemoteList:AddToList(remote)
		table.insert(self.Value, remote)

		self:Display()
	end

	function RemoteList:RemoveFromList(remote)
		local index = table.find(self.Value, remote)
		if not index then
			return
		end

		table.remove(self.Value, index)

		self:Display()
	end

	function RemoteList:SetList(remotes: { SupportedRemoteTypes })
		self.Value = remotes

		self:Display()
	end

	RemoveIgnored = CreateSettingsButton("清除所有", function()
		if not Options.Callback then
			return
		end

		local ToRemove = {}
		for _, remote in RemoteList.Value do
			Options.Callback(remote)
			table.insert(ToRemove, remote)
		end

		for _, remote in ToRemove do
			RemoteList:RemoveFromList(remote)
		end
		wax.shared.Sonner.success("已清除所有远程")
	end, Options.Section)
	RemoveIgnored.Visible = false

	RemoteList:Display()

	wax.shared.Settings[Idx] = RemoteList
	return RemoteList
end


local ExecSupportSection = CreateSettingsSection("支持信息")
do
	wax.shared.Interface.New("TextLabel", {
		Text = table.concat({
			`注入器: <b>{wax.shared.ExecutorName}</b>`,
			`支持: {#wax.shared.ExecutorSupport.FailedChecks == 0 and "<b>完全</b>" or "<b>部分</b> (" .. #wax.shared.ExecutorSupport.FailedChecks .. " check(s) failed)"}`,
		}, "\n"),
		TextSize = 16,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = ExecSupportSection,
		TextWrapped = true,

		["UIPadding"] = {
			PaddingBottom = UDim.new(0, 2),
		},
	})

	local PartialSupportText = ""
	local SupportSuffix = "\n\n"
	for _, Name in wax.shared.ExecutorSupport.FailedChecks do
		PartialSupportText ..= `❌ <b><font color="#ff0000">{Name}</font></b>\n<i><font size="14" transparency="0.5">{wax.shared.ExecutorSupport[Name].Details}</font></i>{SupportSuffix}`
	end

	PartialSupportText = PartialSupportText:sub(1, (#SupportSuffix * -1) - 1)

	if #wax.shared.ExecutorSupport.FailedChecks > 0 then
		wax.shared.Interface.New("TextLabel", {
			Text = PartialSupportText,
			TextSize = 16,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Parent = ExecSupportSection,
			TextWrapped = true,
		})
	end
end


local MainSection = CreateSettingsSection("常规")

CreateSettingsCheckbox("ExecuteOnTeleport", {
    Text = "传送时执行",
    Default = false,
    Section = MainSection,
})

CreateSettingsCheckbox("UseAlternativeHooks", {
    Text = "使用替代元方法钩子",
    Default = false,
    Section = MainSection,
})

CreateSettingsCheckbox("AnticheatBypass", {
    Text = "内置反作弊绕过",
    Default = true,
    Section = MainSection,
})

if wax.shared.AnticheatDisabled then
    wax.shared.Interface.New("TextLabel", {
        Text = `检测到反作弊：<b>{wax.shared.AnticheatName}</b>`,
        TextSize = 16,
        Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = MainSection,
		TextWrapped = true,
	})
end

CreateSettingsButton("清空所有日志", function()
	for _, Logs in pairs(wax.shared.Logs) do
		for Index, Log in pairs(Logs) do
			if Log.Button then
				Log.Button.Instance:Destroy()
				Log.Button = nil
			end

			CurrentPage[Log] = nil
			Logs[Index] = nil
		end

		table.clear(Logs)
	end

	CleanLogsList()
	CurrentLog = nil

    wax.shared.Sonner.success("已成功清空所有日志")
end, MainSection)

local CodeGenSection = CreateSettingsSection("代码生成")

CreateSettingsCheckbox("PreferBufferFromString", {
    Text = "优先使用 buffer.fromstring",
    Default = false,
    Section = CodeGenSection,
})

local FilterSection = CreateSettingsSection("筛选")

CreateSettingsDropdown("IgnoredRemotesDropdown", {
    Text = "忽略远程",
    Values = Images,
    Default = { "BindableEvent", "BindableFunction" },
	AllowNull = true,
	Multi = true,
	Section = FilterSection,
})

CreateSettingsCheckbox("LogActors", {
    Text = "记录 Actor 的事件",
    Default = true,
    Section = FilterSection,
})

CreateSettingsCheckbox("IgnorePlayerModule", {
    Text = "忽略 Player 模块远程",
    Default = true,
    Section = FilterSection,
})
CreateSettingsCheckbox("ShowExecutorLogs", {
    Text = `显示 {wax.shared.ExecutorName} 日志`,
    Default = true,
    Section = FilterSection,
	Callback = function()
		if not CurrentLog then
			return
		end

		PaginationHelper:Update(#CurrentLog.Calls)
		PaginationHelper:SetPage(1)
		CurrentPage[CurrentLog] = 1

    ShowLog(CurrentLog)
    end,
})
CreateSettingsButton("重置筛选为默认", function()
	wax.shared.Settings.IgnoredRemotesDropdown:Reset()
	wax.shared.Settings.IgnoreSpammyRemotes:Reset()
	wax.shared.Settings.IgnorePlayerModule:Reset()
	wax.shared.Settings.ShowExecutorLogs:Reset()

    wax.shared.Sonner.success("已成功重置远程筛选为默认")
end, FilterSection)

local IgnoredSection = CreateSettingsSection("已忽略")

CreateSettingsRemoteList("IgnoredRemotes", {
    Text = "已忽略的远程",
    NullMessage = "尚未忽略任何远程。",
    Section = IgnoredSection,
    Callback = function(Remote)
        Remote.Ignored = false
    end,
})

local BlockedSection = CreateSettingsSection("已阻止")

CreateSettingsRemoteList("BlockedRemotes", {
    Text = "已阻止的远程",
    NullMessage = "尚未阻止任何远程。",
    Section = BlockedSection,
    Callback = function(Remote)
        Remote.Blocked = false
	end,
})

local LoggingSection = CreateSettingsSection("Logging")
local SessionLog

CreateSettingsCheckbox("EnableLogging", {
	Text = `启用文件日志`,
	Default = false,
	Section = LoggingSection,
	Callback = function(value)
		if not value then
			wax.shared.LogConnection:Disconnect()
			wax.shared.LogConnection = nil
			wax.shared.LogFileName = nil
			SessionLog.Text = `当前会话日志: <b>未记录</b>`
			wax.shared.Sonner.success("成功禁用了文件日志记录")
			return
		end

		local LogConnection = wax.shared.SetupLoggingConnection()
		SessionLog.Text = `当前会话日志: <b>{wax.shared.LogFileName:gsub("Cobalt/Logs/", "")}</b>`
		wax.shared.LogConnection = wax.shared.Connect(wax.shared.Communicator.Event:Connect(LogConnection))

		wax.shared.Sonner.success("成功禁用了文件日志记录")
	end,
})

SessionLog = wax.shared.Interface.New("TextLabel", {
	Text = `当前会话日志: <b>{wax.shared.Settings.EnableLogging.Value and wax.shared.LogFileName:gsub(
		"Cobalt/Logs/",
		""
	) or "不记录"}</b>`,
	TextSize = 16,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundTransparency = 1,
	Parent = LoggingSection,
	TextWrapped = true,
})

wax.shared.Interface.New("TextLabel", {
	Text = `日志路径: <b>Cobalt/Logs</b>`,
	TextSize = 16,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundTransparency = 1,
	Parent = LoggingSection,
	TextWrapped = true,
})

local SessionButtons = wax.shared.Interface.New("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = LoggingSection,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 8),
	},

	["UIPadding"] = {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
	},
})
local CopySessionName = CreateSettingsButton("复制会话名称", function()
	if not wax.shared.Settings.EnableLogging.Value then
		wax.shared.Sonner.error("文件日志功能未开启")
		return
	end

	local ActualLogFileName = wax.shared.LogFileName:gsub("Cobalt/Logs/", "")
	local Success, Error = pcall(setclipboard, ActualLogFileName)

	if not Success then
		warn(Error)
		wax.shared.Sonner.error("无法复制会话名称")
		return
	end

	wax.shared.Sonner.success("成功复制会话名称到剪贴板")
end, SessionButtons, 14)
CopySessionName.Size = UDim2.new(0.5, -4, 0, 24)

local CopyFullSessionPath = CreateSettingsButton("复制完整路径", function()
	if not wax.shared.Settings.EnableLogging.Value then
		wax.shared.Sonner.error("文件日志功能未开启")
		return
	end

	local Success, Error = pcall(setclipboard, wax.shared.LogFileName)

	if not Success then
		warn(Error)
		wax.shared.Sonner.error("无法复制日志路径")
		return
	end

	wax.shared.Sonner.success("成功复制日志路径到剪贴板")
end, SessionButtons, 14)
CopyFullSessionPath.Size = UDim2.new(0.5, -4, 0, 24)

local CreditsSection = CreateSettingsSection("Credits")

local Credits = {
	{
		Credit = "upio",
		Description = "Cobalt 开发者",
	},
	{
		Credit = "deivid",
		Description = "Cobalt 开发者",
	},
	{
		Credit = "wynsbssb",
		Description = "汉化者"
	},
	{
		Credit = "shadcn",
		Description = 'UI 设计灵感 (<font color="#3798ff">https://ui.shadcn.com/</font>)',
	},
	{
		Credit = "lucide",
		Description = '一致且简洁的图标 (<font color="#3798ff">https://lucide.dev/</font>)',
	},
	{
		Credit = "Emil Kowalski",
		Description = 'Sonner 组件的创建者 (<font color="#3798ff">https://sonner.emilkowal.ski/</font>)',
	},
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
	},
})

for Order, Data in pairs(Credits) do
	wax.shared.Interface.New("TextLabel", {
		Text = `<b>{Data.Credit}</b>\n{Data.Description}`,
		Size = UDim2.fromScale(1, 0),
		TextSize = 14,
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = Order,
		Parent = CreditsWrapper,
	})
end

-- Info
local InfoFrame = wax.shared.Interface.New("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.65, 0.712),
	Text = "",
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

wax.shared.Resize.new({
	MainFrame = InfoFrame,

	MaximumSize = UDim2.new(1, -2, 1, -2),
	MinimumSize = UDim2.fromScale(0.65, 0.712),
	Mirrored = true,
	LockedPosition = true,

	CornerHandleSize = 20,
	HandleSize = 6,
})

local InfoTitle, InfoIcon = CreateModalTop("...", Images["RemoteEvent"], InfoFrame)
local InfoModalTab = {}

local InfoTabs = wax.shared.Interface.New("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 6, 0, 44),
	Size = UDim2.new(1, -12, 0, 36),
	Parent = InfoFrame,

	["UIListLayout"] = {
		Padding = UDim.new(0, 6),
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	},
})

local CurrentInfoTab = nil
local function CreateInfoTab(Icon: string, Title: string, TabContents: Frame?)
	if not CurrentInfoTab then
		CurrentInfoTab = Title
	end

	local IsTabSelected = CurrentInfoTab == Title

	if TabContents then
		TabContents.Parent = InfoFrame
		TabContents.Visible = IsTabSelected
	end

	local ButtonColor = IsTabSelected and Color3.fromRGB(25, 25, 25) or Color3.fromRGB(0, 0, 0)
	local TabButton = wax.shared.Interface.New("TextButton", {
		BackgroundColor3 = ButtonColor,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		Parent = InfoTabs,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 8),
		},

		["UIStroke"] = {
			Color = Color3.fromRGB(25, 25, 25),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},

		["Frame"] = {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0.5),
			BackgroundColor3 = ButtonColor,
		},
	})

	InfoModalTab[Title] = {
		TabButton = TabButton,
		TabContents = TabContents,
	}

	local TextWrapper = wax.shared.Interface.New("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		Parent = TabButton,

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 5),
		},

		["UIPadding"] = {
			PaddingRight = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
		},

		["TextLabel"] = {
			Text = Title,
			TextSize = 15,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 2,
			ZIndex = 2,
		},
	})

	wax.shared.Interface.NewIcon(Icon, {
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.fromOffset(16, 16),
		LayoutOrder = 1,
		ZIndex = 2,

		Parent = TextWrapper,
	})

	wax.shared.Connect(TabButton.MouseButton1Click:Connect(function()
		local OldTab = InfoModalTab[CurrentInfoTab]
		local OldTabButton = OldTab.TabButton
		local OldTabContents = OldTab.TabContents

		OldTabButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		OldTabButton.Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		OldTabContents.Visible = false

		CurrentInfoTab = Title

		TabButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		TabButton.Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)

		if TabContents then
			TabContents.Visible = true
		end
	end))
end

local function CreateTabContent()
	local Container = wax.shared.Interface.New("Frame", {
		Position = UDim2.fromOffset(6, 71),
		Size = UDim2.new(1, -12, 1, -118),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),

		["UICorner"] = {
			CornerRadius = UDim.new(0, 6),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},

		["UIStroke"] = {
			Color = Color3.fromRGB(25, 25, 25),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
	})

	return Container,
		wax.shared.Interface.New("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			AutomaticCanvasSize = Enum.AutomaticSize.XY,
			CanvasSize = UDim2.fromScale(0, 0),
			ScrollBarThickness = 0,
			HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			ScrollingDirection = Enum.ScrollingDirection.XY,
			Parent = Container,
		})
end

local ArgumentInfoUI, ArgumentScrollingFrame = CreateTabContent()
CreateInfoTab("ellipsis", "Arguments", ArgumentInfoUI)
ArgumentScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local ArgumentsInfoFrame = wax.shared.Interface.New("Frame", {
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),

	["UIListLayout"] = {
		Padding = UDim.new(0, 6),
	},

	MainUICorner,

	Parent = ArgumentScrollingFrame,
})

local CodeInfoUI, CodeScrollingFrame = CreateTabContent()
CreateInfoTab("code", "Code", CodeInfoUI)
CodeScrollingFrame.ScrollBarThickness = 3
CodeScrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.None

local CodeTextLabels = {}
for i = 1, 5 do
	CodeTextLabels[i] = wax.shared.Interface.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		FontFace = Font.fromId(16658246179),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Text = "",
		Parent = CodeScrollingFrame,
	})
end

function SetCodeText(Code: string)
	for _, Label in CodeTextLabels do
		Label.Text = ""
	end

	local HighlightedCode = wax.shared.Highlighter.Run(Code)
	local Lines = HighlightedCode:split("\n")
	local CurrentCharacterCount = 0
	local TextContents = {}
	local CurrentLabel = 1

	for _, Line in Lines do
		if CurrentCharacterCount + #Line > 200000 then
			CurrentLabel += 1
			CurrentCharacterCount = 0
			continue
		end

		CurrentCharacterCount += #Line
		if not TextContents[CurrentLabel] then
			TextContents[CurrentLabel] = {}
		end

		table.insert(TextContents[CurrentLabel], Line)
	end

	for Idx, Content in TextContents do
		if not CodeTextLabels[Idx] then
			CodeTextLabels[Idx] = wax.shared.Interface.New("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				TextSize = 16,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				FontFace = Font.fromId(16658246179),
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				Text = wax.shared.Highlighter.Run("-- 加载..."),
				Parent = CodeScrollingFrame,
			})
		end

		CodeTextLabels[Idx].Text = table.concat(Content, "\n")
	end
end

local FunctionInfoUI, FunctionScrollingFrame = CreateTabContent()
CreateInfoTab("parentheses", "Function Info", FunctionInfoUI)

local FunctionInfoText = wax.shared.Interface.New("TextLabel", {
	AutomaticSize = Enum.AutomaticSize.XY,
	TextSize = 16,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	FontFace = Font.fromId(16658246179),
	TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundTransparency = 1,
	Text = "",
	Parent = FunctionScrollingFrame,
})

local InfoButtons = wax.shared.Interface.New("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 6, 1, -7),
	Size = UDim2.new(1, -12, 0, 32),
	Parent = InfoFrame,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
	},
})

local function CreateInfoDropdownButton(Icon: string, Title: string, Options: {})
	local Button = wax.shared.Interface.New("TextButton", {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0, 1),
		Text = "",

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
		},

		Parent = InfoButtons,
	})

	wax.shared.Interface.NewIcon(Icon, {
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		Parent = Button,
	})

	local Menu = CreateContextMenu(Button, Options)

	Button.MouseEnter:Connect(function()
		wax.shared.TweenService
			:Create(Button, DefaultTweenInfo, {
				BackgroundTransparency = 0,
			})
			:Play()
	end)
	Button.MouseLeave:Connect(function()
		wax.shared.TweenService
			:Create(Button, DefaultTweenInfo, {
				BackgroundTransparency = 1,
			})
			:Play()
	end)
	Button.MouseButton1Click:Connect(Menu.Toggle)
	return Menu
end

CreateInfoDropdownButton("code", "代码", {
	{
        Text = "调用代码",
        Icon = "forward",
		Callback = function()
			if not CurrentInfo then
				return
			end

			local Code = wax.shared.CodeGen:BuildCallCode(CurrentInfo)
			local Success, Error = pcall(setclipboard, Code)

            if Success then
                wax.shared.Sonner.success("已复制代码到剪贴板")
            else
                wax.shared.Sonner.error("复制代码到剪贴板失败")
                warn("无法将代码复制到剪贴板", Error)
            end
        end,
    },
    {
        Text = "拦截代码",
        Icon = "shield-alert",
		Callback = function()
			if not CurrentInfo then
				return
			end

			local Code = wax.shared.CodeGen:BuildHookCode(CurrentInfo)
			local Success, Error = pcall(setclipboard, Code)

            if Success then
                wax.shared.Sonner.success("已复制代码到剪贴板")
            else
                wax.shared.Sonner.error("复制代码到剪贴板失败")
                warn("无法将代码复制到剪贴板", Error)
            end
        end,
    },
    {
        Text = "函数信息",
        Icon = "parentheses",
		Callback = function()
			if not CurrentInfo then
				return
			end

			local Info = {
				Function = typeof(CurrentInfo.Function) == "function" and {
					Name = CurrentInfo.Function and debug.info(CurrentInfo.Function, "n") or "Unknown",
					Type = CurrentInfo.Function
							and (iscclosure(CurrentInfo.Function) and "C Closure" or "Luau function")
						or "N/A",
					Address = tostring(CurrentInfo.Function),
					Arguments = table.unpack(CurrentInfo.Arguments, 1, wax.shared.GetTableLength(CurrentInfo.Arguments)),
				} or CurrentInfo.Function,
				Script = CurrentInfo.Origin,
				Line = CurrentInfo.Line,
			}

			if typeof(CurrentInfo.Function) == "function" and islclosure(CurrentInfo.Function) then
				local FunctionInfo = {
					Constants = debug.getconstants,
					Upvalues = debug.getupvalues,
					Protos = debug.getprotos,
				}

				for Type, Func in pairs(FunctionInfo) do
					if not Func then
						continue
					end

					Info.Function[Type] = Func(CurrentInfo.Function)
				end
			end

			local Success, Error = pcall(setclipboard, `local Info = {wax.shared.LuaEncode(Info, { Prettify = true })}`)
            if Success then
                wax.shared.Sonner.success("已复制函数信息到剪贴板")
            else
                wax.shared.Sonner.error("复制函数信息到剪贴板失败")
                warn("无法将函数信息复制到剪贴板", Error)
            end
        end,
    },
})

CreateInfoDropdownButton("scroll-text", "来源", {
	{
        Text = "远程路径",
        Icon = "package-search",
		Callback = function()
			if not CurrentInfo then
				return
			end

			local Success, Error =
				pcall(setclipboard, wax.shared.CodeGen.GetFullPath(CurrentInfo.Instance, false, "Event"))
            if Success then
                wax.shared.Sonner.success("已复制远程路径到剪贴板")
            else
                wax.shared.Sonner.error("复制远程路径到剪贴板失败")
                warn("无法将远程路径复制到剪贴板", Error)
            end
        end,
    },
    {
        Text = "脚本路径",
        Icon = "file-search",
		Condition = function()
			return CurrentInfo and typeof(CurrentInfo.Origin) == "Instance"
		end,
		Callback = function()
			if not (CurrentInfo and typeof(CurrentInfo.Origin) == "Instance") then
				return
			end

			local Success, Error = pcall(setclipboard, wax.shared.CodeGen.GetFullPath(CurrentInfo.Origin))
            if Success then
                wax.shared.Sonner.success("已复制脚本路径到剪贴板")
            else
                wax.shared.Sonner.error("复制脚本路径到剪贴板失败")
                warn("无法将脚本路径复制到剪贴板", Error)
            end
        end,
    },
    {
        Text = "反编译脚本",
        Icon = "file-text",
		Condition = function()
			return CurrentInfo and typeof(CurrentInfo.Origin) == "Instance" and typeof(decompile) == "function"
		end,
		Callback = function()
			if not (CurrentInfo and typeof(CurrentInfo.Origin) == "Instance" and typeof(decompile) == "function") then
				return
			end

			local Decompiled, Result = pcall(decompile, CurrentInfo.Origin)
			if Decompiled then
				local Success, Error = pcall(setclipboard, Result)
                if Success then
                    wax.shared.Sonner.success("已复制反编译脚本到剪贴板")
                else
                    wax.shared.Sonner.error("复制反编译脚本到剪贴板失败")
                    warn("无法将反编译脚本复制到剪贴板", Error)
                end
            else
                wax.shared.Sonner.error("反编译脚本失败")
                warn("无法反编译脚本", Result)
            end
        end,
    },
})

CreateInfoDropdownButton("network", "事件", {
	{
        Text = "重放",
        Icon = "play",
		Callback = function()
			if not CurrentInfo then
				return
			end

            wax.shared.Sonner.promise(function()
                wax.shared.ReplayCallInfo(CurrentInfo, CurrentTab.Name)
            end, {
                loadingText = "正在重放事件...",
                successText = "事件重放成功！",
                errorText = "事件重放失败",
                time = 4.5,
            })
        end,
    },
	{
		Text = function()
			if not CurrentLog then
				return "Ignore"
			end

			return CurrentLog.Ignored and "Unignore" or "Ignore"
		end,
		Icon = function()
			if not CurrentLog then
				return "eye"
			end

			return CurrentLog.Ignored and "eye" or "eye-off"
		end,
		Callback = function()
			if not CurrentLog then
				return
			end

			CurrentLog:Ignore()

			local IgnoredRemoteList = wax.shared.Settings["IgnoredRemotes"]
			if IgnoredRemoteList then
				if CurrentLog.Ignored then
					IgnoredRemoteList:AddToList(CurrentLog)
				else
					IgnoredRemoteList:RemoveFromList(CurrentLog)
				end
			end

			wax.shared.Sonner.success(`{CurrentLog.Ignored and "Started" or "Stopped"} ignoring event`)
		end,
	},
	{
		Text = function()
			if not CurrentLog then
				return "Block"
			end

			return CurrentLog.Blocked and "Unblock" or "Block"
		end,
		Icon = function()
			if not CurrentLog then
				return "lock"
			end

			return CurrentLog.Blocked and "lock" or "lock-open"
		end,
		Callback = function()
			if not CurrentLog then
				return
			end

			CurrentLog:Block()

			local BlockedRemoteList = wax.shared.Settings["BlockedRemotes"]
			if BlockedRemoteList then
				if CurrentLog.Blocked then
					BlockedRemoteList:AddToList(CurrentLog)
				else
					BlockedRemoteList:RemoveFromList(CurrentLog)
				end
			end

    wax.shared.Sonner.success(`{CurrentLog.Blocked and "开始" or "停止"}阻止事件`)
		end,
	},
    {
        Text = "清空日志",
        Icon = "trash",
		Callback = function()
			if not CurrentLog then
				return
			end

			CurrentLog.Calls = {}
			PaginationHelper:Update(#CurrentLog.Calls)
			PaginationHelper:SetPage(1)
			CurrentPage[CurrentLog] = 1

			CleanLogsList()

			CurrentLog.Button.Calls.Text = "x" .. #CurrentLog.Calls
			UpdateLogNameSize(CurrentLog)

			ShowPagination(CurrentLog)
			ShowCalls(CurrentLog, 1)

			CloseModal()

            wax.shared.Sonner.success("已成功清空该事件的日志！")
        end,
    },
})

-- Search
local ResultInfo = {}
local CurrentResults = {}
local SelectedResult = -1

local SearchFrame = wax.shared.Interface.New("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.5, 0, 0.8, 0),
	Text = "",
	Visible = false,
	Parent = ModalBackground,

	["UICorner"] = {
		CornerRadius = UDim.new(0, 6),
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
    PlaceholderText = "搜索日志...",
	TextXAlignment = Enum.TextXAlignment.Left,
	PlaceholderColor3 = Color3.fromRGB(127, 127, 127),
	Text = "",
	TextSize = 17,
	Parent = SearchTop,
})

local SearchCloseButton = wax.shared.Interface.New("ImageButton", {
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.fromScale(1, 0),
	AnchorPoint = Vector2.new(1, 0),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	Parent = SearchTop,
})
local SearchCloseImage = wax.shared.Interface.NewIcon("x", {
	ImageTransparency = 0.5,
	Size = UDim2.fromOffset(22, 22),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,

	Parent = SearchCloseButton,
})

ConnectCloseButton(SearchCloseButton, SearchCloseImage, SearchFrame)

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
local ExcludeSearchClass = {}
local SearchFilterButtons = {}

local FilterAllButton = wax.shared.Interface.New("TextButton", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.fromScale(0, 1),
	AutomaticSize = Enum.AutomaticSize.X,
	TextSize = 15,
    Text = "全部",
    Parent = SearchFilterList,

	["UICorner"] = {
		CornerRadius = UDim.new(0, 4),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 0),
		PaddingBottom = UDim.new(0, 0),
	},
})

FilterAllButton.MouseButton1Click:Connect(function()
	ExcludeSearchClass = {}
	FilterAllButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	for _, Button in pairs(SearchFilterButtons) do
		Button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	end
	UpdateSearch()
end)

for Order, ClassName in pairs(ClassOrder) do
	local ClassNameFilterButton = wax.shared.Interface.New("TextButton", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 15,
		Text = "",
		LayoutOrder = Order,
		Parent = SearchFilterList,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 0),
			PaddingBottom = UDim.new(0, 0),
		},

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		},

		["TextLabel"] = {
			LayoutOrder = 1,
			Text = ClassName,
			TextSize = 15,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
		},
	})

	local ImageLabel = wax.shared.Interface.New("ImageLabel", {
		Image = Images[ClassName],
		Size = UDim2.new(1, -8, 1, -8),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(0.5, 0),
		Parent = ClassNameFilterButton,
	})

	ClassNameFilterButton.MouseButton1Click:Connect(function()
		local FoundIndex = table.find(ExcludeSearchClass, ClassName)
		if FoundIndex then
			table.remove(ExcludeSearchClass, FoundIndex)
			ClassNameFilterButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)

			if #ExcludeSearchClass == 0 then
				FilterAllButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			end

			UpdateSearch()
			return
		end

		table.insert(ExcludeSearchClass, ClassName)
		ClassNameFilterButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
		FilterAllButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
		UpdateSearch()
	end)

	table.insert(SearchFilterButtons, ClassNameFilterButton)
end

wax.shared.Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.new(1, 0, 0, 1),
	Position = UDim2.fromOffset(0, 72),
	Parent = SearchFrame,
})

local SearchResults = wax.shared.Interface.New("ScrollingFrame", {
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	Position = UDim2.fromOffset(0, 73),
	ScrollBarThickness = 3,
	Size = UDim2.new(1, 0, 1, -73),

	Parent = SearchFrame,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.Name,
	},

	["UIPadding"] = {
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
	},
})

local function CreateSearchResult(Instance: Instance, Type: string)
	local SearchResult = wax.shared.Interface.New("TextButton", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		BackgroundTransparency = 1,
		Name = Instance.Name,
		Size = UDim2.new(1, 0, 0, 36),
		Text = "",

		["UICorner"] = {
			CornerRadius = UDim.new(0, 6),
		},

		["UIPadding"] = {
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
		},

		["TextLabel"] = {
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.new(1, -30, 1, 0),
			Text = Instance.Name,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
		},
	})
	do
		SearchResult.MouseEnter:Connect(function()
			local Index = table.find(CurrentResults, SearchResult)
			if Index then
				SelectResult(Index)
			end
		end)
		SearchResult.MouseButton1Click:Connect(function()
			local Index = table.find(CurrentResults, SearchResult)
			if Index then
				EnterResult(Index)
			end
		end)
	end

	local Image = wax.shared.Interface.New("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Images[Instance.ClassName],
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Parent = SearchResult,
	})

	local TypeLabel = wax.shared.Interface.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = Type,
		TextSize = 15,
		TextTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Right,

		Parent = SearchResult,
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
		Image = CobaltLogo,
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
CreateTopButton("minus", 3, function()
	MainFrame.Visible = false
	ShowButton.Visible = true
end)
CreateTopSeperator(2)
CreateTopButton("settings", 1, function()
	OpenModal(SettingsFrame)
end)
CreateTopButton("search", 0, function()
	OpenSearch()
end)

wax.shared.Drag.Setup(MainFrame, TopBar)
wax.shared.Drag.Setup(ShowButton, ShowButton)

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
	ScrollBarThickness = 2,
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
		UpdateLogNameSize(Log)
		Log.Button.Instance.Parent = RemoteList
	end
end

function CleanLogsList()
	for _, Object in pairs(LogsList:GetChildren()) do
		if Object.ClassName == "TextButton" then
			Object:Destroy()
		end
	end
end

function ShowLog(Log)
	CleanLogsList()
	if not Log then
		return
	end

	if CurrentLog ~= Log then
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

ShowCalls = function(Log, Page)
	local Start, End = PaginationHelper:GetIndexRanges(Page)

	for Index = Start, End do
		local Call
		if wax.shared.Settings.ShowExecutorLogs.Value then
			Call = Log.Calls[Index]
		else
			Call = Log.Calls[Log.GameCalls[Index]]
		end

		if not Call then
			break
		end

		local Data = setmetatable({
			Instance = Log.Instance,
			Type = Log.Type,
			Order = Index,
		}, {
			__index = Call,
		})

		CreateCallFrame(Data)
	end
end

function CreatePaginationEllipsis(Order: number, Visible: boolean)
	local Ellipsis = {
		Ellipsis = wax.shared.Interface.New("TextBox", {
			BackgroundColor3 = Color3.fromRGB(25, 25, 25),
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			LayoutOrder = Order,
			PlaceholderText = "-",
			Text = "",
			TextSize = 15,
			RichText = false,
			Parent = Visible and LogsPagination or nil,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 4),
			},
		}),
	}

	function Ellipsis:SetVisible(Visible: boolean)
		if not Visible then
			self.Ellipsis.Text = ""
		end
		self.Ellipsis.Parent = Visible and LogsPagination or nil
	end

	Ellipsis.Ellipsis.FocusLost:Connect(function(EnterPressed)
		if not EnterPressed then
			return
		end

		local Page = tonumber(Ellipsis.Ellipsis.Text)
		if not Page then
			wax.shared.Sonner.error("提供的页面无效！")
			Ellipsis.Text = ""
			return
		end

		if math.floor(Page) ~= Page then
			wax.shared.Sonner.error("提供的页面无效！")
			Ellipsis.Ellipsis.Text = ""
			return
		end

		if math.abs(Page) ~= Page or Page == 0 then
			wax.shared.Sonner.error("提供的页面无效！")
			Ellipsis.Ellipsis.Text = ""
			return
		end

		local Success = pcall(function()
			PaginationHelper:SetPage(Page)
			CurrentPage[CurrentLog] = Page
			ShowLog(CurrentLog)
		end)

		if not Success then
			wax.shared.Sonner.error("提供的页面无效！")
		end

		Ellipsis.Ellipsis.Text = ""
	end)

	return Ellipsis
end

function CreatePaginationButton(Order: number, Active: boolean, Visible: boolean)
	local ButtonData = {
		Button = wax.shared.Interface.New("TextButton", {
			BackgroundColor3 = Active and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25),
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Text = tostring(1),
			LayoutOrder = Order,
			TextSize = 15,
			Parent = Visible and LogsPagination or nil,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 4),
			},
		}),
	}

	function ButtonData:SetActive(Active: boolean)
		self.Button.BackgroundColor3 = Active and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
	end

	function ButtonData:SetText(Text: string)
		self.Button.Text = Text
	end

	function ButtonData:SetVisible(Visible: boolean)
		self.Button.Parent = Visible and LogsPagination or nil
	end

	ButtonData.Button.MouseButton1Click:Connect(function()
		local Page = tonumber(ButtonData.Button.Text)

		PaginationHelper:SetPage(Page)
		CurrentPage[CurrentLog] = Page
		ShowLog(CurrentLog)
	end)

	return ButtonData
end

local MaxButtons = (5 + PaginationHelper.SiblingCount * 2)
local PaginationElements = {
	Buttons = {},
	Ellipsis = {
		[2] = CreatePaginationEllipsis(1, false),
		[MaxButtons - 1] = CreatePaginationEllipsis(MaxButtons - 1, false),
	},
}

for i = 1, MaxButtons do
	table.insert(PaginationElements.Buttons, CreatePaginationButton(i, false, false))
end

ShowPagination = function(Log)
	local Pages = PaginationHelper:GetVisualInfo(nil, LogsList.AbsoluteSize.X)
	for Order, Info in pairs(Pages) do
		if Info == "none" then
			local Ellipsis = PaginationElements.Ellipsis[Order]
			if Ellipsis then
				Ellipsis:SetVisible(false)
			end

			local Button = PaginationElements.Buttons[Order]
			if Button then
				Button:SetVisible(false)
			end

			continue
		elseif Info == "ellipsis" then
			local Ellipsis = PaginationElements.Ellipsis[Order]
			if Ellipsis and Ellipsis.Parent == nil then
				Ellipsis:SetVisible(true)
			end

			local Button = PaginationElements.Buttons[Order]
			if Button then
				Button:SetVisible(false)
			end

			continue
		end

		local Ellipsis = PaginationElements.Ellipsis[Order]
		if Ellipsis then
			Ellipsis:SetVisible(false)
		end

		local Button = PaginationElements.Buttons[Order]
		if Button then
			Button:SetVisible(true)
			Button:SetText(tostring(Info))
			Button:SetActive(CurrentPage[Log] == Info)
		end
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
	Tabs[TabName] = Tab

	if Active then
		CurrentTab = Tab
	end

	Button.MouseButton1Click:Connect(function()
		if CurrentTab == Tab then
			return
		end

		ShowTab(Tab)
	end)

	return Button
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
	})

	local Text = wax.shared.Interface.New("TextLabel", {
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,

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

	local LogContextMenu = CreateContextMenu(Button, {
		{
			Text = function()
				if not Log then
					return "Ignore"
				end

				return Log.Ignored and "Unignore" or "Ignore"
			end,
			Icon = function()
				if not Log then
					return "eye"
				end

				return Log.Ignored and "eye" or "eye-off"
			end,
			Callback = function()
				Log:Ignore()

				local IgnoredRemoteList = wax.shared.Settings["IgnoredRemotes"]
				if IgnoredRemoteList then
					if Log.Ignored then
						IgnoredRemoteList:AddToList(Log)
					else
						IgnoredRemoteList:RemoveFromList(Log)
					end
				end

				wax.shared.Sonner.success(`{Log.Ignored and "Started" or "Stopped"} ignoring event`)
			end,
		},
		{
			Text = function()
				if not Log then
					return "Block"
				end

				return Log.Blocked and "Unblock" or "Block"
			end,
			Icon = function()
				if not Log then
					return "lock"
				end

				return Log.Blocked and "lock" or "lock-open"
			end,
			Callback = function()
				Log:Block()

				local BlockedRemoteList = wax.shared.Settings["BlockedRemotes"]
				if BlockedRemoteList then
					if Log.Blocked then
						BlockedRemoteList:AddToList(Log)
					else
						BlockedRemoteList:RemoveFromList(Log)
					end
				end

				wax.shared.Sonner.success(`{Log.Blocked and "Started" or "Stopped"} blocking event`)
			end,
		},
		{
			Text = "清空日志",
			Icon = "trash",
			Callback = function()
				if not Log then
					return
				end

				Log.Calls = {}
				CurrentPage[Log] = 1
				Log.Button.Calls.Text = "x" .. #Log.Calls
				UpdateLogNameSize(Log)

				if CurrentLog == Log then
					PaginationHelper:Update(#Log.Calls)
					PaginationHelper:SetPage(1)

					CleanLogsList()

					ShowPagination(Log)
					ShowCalls(Log, 1)
				end

				wax.shared.Sonner.success("成功清空日志！")
			end,
		},
	}, true)

	Button.MouseButton2Click:Connect(LogContextMenu.Toggle)

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
		TextYAlignment = Enum.TextYAlignment.Top,

		Parent = Holder,
	})

	local TypeLabel = wax.shared.Interface.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = typeof(Value),
		TextSize = 15,
		TextTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,

		Parent = Holder,
	})
	local TypeX = wax.shared.GetTextBounds(TypeLabel.Text, TypeLabel.FontFace, TypeLabel.TextSize)

	local TextLabel = wax.shared.Interface.New("TextLabel", {
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -(TypeX + 22), 1, 0),
		TextColor3 = Color3.fromHex(wax.shared.Highlighter.GetArgumentColor(Value)),
		Text = tostring(wax.shared.DisplayArgument(Value)):gsub("<", "&lt;"):gsub(">", "&gt;"),
		RichText = true,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,

		Parent = Holder,
	})
	local _, TextY =
		wax.shared.GetTextBounds(TextLabel.Text, TextLabel.FontFace, TextLabel.TextSize, TextLabel.AbsoluteSize.X)
	Holder.Size = UDim2.new(1, 0, 0, TextY + 12)

	return Holder
end

function CreateCallFrame(CallInfo)
	if not wax.shared.Settings.ShowExecutorLogs.Value and not CallInfo.Origin then
		return
	end

	local CallFrame = wax.shared.Interface.New("TextButton", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		LayoutOrder = CallInfo.Order,
		Size = UDim2.fromScale(1, 0),
		Text = "",

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

		Parent = LogsList,
	})

	local HighlightStroke = wax.shared.Interface.New("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(75, 75, 75),
		Thickness = 2,
		Transparency = 1,

		Parent = CallFrame,
	})
	do
		local CallFrameContextMenu = CreateContextMenu(CallFrame, {
			{
				Text = "复制调用代码",
				Icon = "forward",
				Callback = function()
					local Code = wax.shared.CodeGen:BuildCallCode(CallInfo)
					local Success, Error = pcall(setclipboard, Code)

					if Success then
						wax.shared.Sonner.success("已将代码复制到剪贴板")
					else
						wax.shared.Sonner.error("无法将代码复制到剪贴板")
						warn("无法将代码复制到剪贴板", Error)
					end
				end,
			},
			{
				Text = "复制拦截代码",
				Icon = "shield-alert",
				Callback = function()
					local Code = wax.shared.CodeGen:BuildHookCode(CallInfo, CurrentTab.Name)
					local Success, Error = pcall(setclipboard, Code)

					if Success then
						wax.shared.Sonner.success("已将代码复制到剪贴板")
					else
						wax.shared.Sonner.error("无法将代码复制到剪贴板")
						warn("无法将代码复制到剪贴板", Error)
					end
				end,
			},
			{
				Text = "复制远程路径",
				Icon = "package-search",
				Callback = function()
					if not CallInfo then
						return
					end

					local Success, Error =
						pcall(setclipboard, wax.shared.CodeGen.GetFullPath(CallInfo.Instance, false, "Event"))

					if Success then
						wax.shared.Sonner.success("已将远程路径复制到剪贴板")
					else
						wax.shared.Sonner.error("无法将远程路径复制到剪贴板")
						warn("无法将远程路径复制到剪贴板", Error)
					end
				end,
			},
			{
				Text = "复制脚本路径",
				Icon = "file-search",
				Condition = function()
					return CallInfo and typeof(CallInfo.Origin) == "Instance"
				end,
				Callback = function()
					if not CallInfo then
						return
					end

					local Success, Error = pcall(setclipboard, wax.shared.CodeGen.GetFullPath(CallInfo.Origin))
					if Success then
						wax.shared.Sonner.success("已将脚本路径复制到剪贴板")
					else
						wax.shared.Sonner.error("无法将脚本路径复制到剪贴板")
						warn("无法将脚本路径复制到剪贴板", Error)
					end
				end,
			},
			{
				Text = "重放",
				Icon = "play",
				Callback = function()
					if not CallInfo then
						return
					end

					wax.shared.Sonner.promise(function()
						wax.shared.ReplayCallInfo(CallInfo, CurrentTab.Name)
					end, {
						loadingText = "正在重放事件...",
						successText = "成功重放事件！",
						errorText = "重放事件失败",
						time = 4.5,
					})
				end,
			},
		}, true)

		CallFrame.MouseEnter:Connect(function()
			wax.shared.TweenService
				:Create(HighlightStroke, DefaultTweenInfo, {
					Transparency = 0,
				})
				:Play()
		end)
		CallFrame.MouseLeave:Connect(function()
			wax.shared.TweenService
				:Create(HighlightStroke, DefaultTweenInfo, {
					Transparency = 1,
				})
				:Play()
		end)
		CallFrame.MouseButton1Click:Connect(function()
			OpenInfo(CallInfo)
		end)
		CallFrame.MouseButton2Click:Connect(CallFrameContextMenu.Open)
	end

	local ArgumentsFrame = wax.shared.Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		Size = UDim2.fromScale(1, 0),
		Visible = wax.shared.GetTableLength(CallInfo.Arguments) > 0,

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
		for Index = 1, wax.shared.GetTableLength(CallInfo.Arguments) do
			if Index % 15 == 0 then
				task.wait()
			end

			local Value = CallInfo.Arguments[Index]
			CreateArgHolder(Index, Value, ArgumentsFrame)
		end
	end

	wax.shared.Interface.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),

		wax.shared.Interface.NewIcon(CallInfo.IsExecutor and "terminal" or "gamepad-2", {
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
            Text = CallInfo.IsExecutor and wax.shared.ExecutorName
                or CallInfo.Origin and CallInfo.Origin.Name
                or "未知",
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 0.5,
		}),

		wax.shared.Interface.New("TextLabel", {
			AnchorPoint = Vector2.one,
			Position = UDim2.new(1, -2, 1, 0),
			Size = UDim2.new(0.5, -2, 0, 22),
			BackgroundTransparency = 1,
            Text = "时间：" .. CallInfo.Time,
			TextSize = 16,
			TextTransparency = 0.5,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),

		Parent = CallFrame,
	})

	return CallFrame
end

-- UI Handling
CreateRemoteTab("发送", true, wax.shared.Logs.Outgoing)
CreateRemoteTab("接收", false, wax.shared.Logs.Incoming)

-- Search Functions
function OpenSearch()
	OpenModal(SearchFrame)
	UpdateSearch()
	SearchBox:CaptureFocus()
end
function HandleSearch(Text, Type)
	for Instance, Log in pairs(wax.shared.Logs[Type]) do
		if not Log.SearchResult then
			local SearchResult = CreateSearchResult(Instance, Type)
			Log.SearchResult = SearchResult
			ResultInfo[SearchResult] = {
				Type = Type,
				Callback = function()
					ShowLog(Log)
				end,
			}
		end

		local LoweredName = string.lower(Instance.Name)
		if not LoweredName:match(Text) or table.find(ExcludeSearchClass, Instance.ClassName) then
			Log.SearchResult.Parent = nil
			continue
		end

		Log.SearchResult.BackgroundTransparency = 1
		Log.SearchResult.Parent = SearchResults
		table.insert(CurrentResults, Log.SearchResult)
	end
end

function SelectResult(NewResult, UpdateCanvasPosition)
	if SelectedResult > 0 and CurrentResults[SelectedResult] then
		CurrentResults[SelectedResult].BackgroundTransparency = 1
	end
	if NewResult == -1 or #CurrentResults == 0 then
		SelectedResult = -1
		return
	end

	SelectedResult = math.clamp(NewResult, 1, #CurrentResults)
	CurrentResults[SelectedResult].BackgroundTransparency = 0

	if UpdateCanvasPosition then
		local ScrollSize = SearchResults.AbsoluteSize.Y

		local SelectedMin = CurrentResults[SelectedResult].AbsolutePosition.Y - SearchResults.AbsolutePosition.Y
		local SelectedMax = SelectedMin + CurrentResults[SelectedResult].AbsoluteSize.Y

		if SelectedMin < 0 then
			SearchResults.CanvasPosition += Vector2.new(0, SelectedMin - 6)
		elseif SelectedMax > ScrollSize then
			SearchResults.CanvasPosition += Vector2.new(0, SelectedMax - ScrollSize + 6)
		end
	end
end
function EnterResult(ResultIndex)
	local Info = ResultInfo[CurrentResults[SelectedResult]]
	if not Info then
		CloseModal()
		return
	end

	pcall(ShowTab, Tabs[Info.Type])
	pcall(Info.Callback)

	CloseModal()
end
function HandleResults()
	if #CurrentResults == 0 then
		return
	end

	table.sort(CurrentResults, function(a, b)
		return a.AbsolutePosition.Y < b.AbsolutePosition.Y
	end)

	SelectResult(1, true)
end
function UpdateSearch()
	table.clear(CurrentResults)
	SelectResult(-1)

	local Text = string.lower(SearchBox.Text)
	HandleSearch(Text, "Outgoing")
	HandleSearch(Text, "Incoming")

	HandleResults()
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(UpdateSearch)

-- Call Functions
function OpenInfo(CallInfo)
	InfoTitle.Text = CallInfo.Instance.Name
	InfoIcon.Image = Images[CallInfo.Instance.ClassName]

	CurrentInfo = CallInfo

	SetCodeText(wax.shared.CodeGen:BuildCallCode(CallInfo))

	xpcall(function()
		FunctionInfoText.Text = wax.shared.CodeGen:BuildFunctionInfo(CallInfo)
	end, function(Error)
		FunctionInfoText.Text =
			`获取函数信息失败.\nCalling Function: {CallInfo.Function} (type: {typeof(
				CallInfo.Function
			)})\n\nError: {Error}`
	end)
	do
		for _, Object in pairs(ArgumentsInfoFrame:GetChildren()) do
			if Object.ClassName ~= "Frame" then
				continue
			end
			Object:Destroy()
		end

		for Index = 1, wax.shared.GetTableLength(CallInfo.Arguments) do
			if Index % 25 == 0 then
				task.wait()
			end

			local Value = CallInfo.Arguments[Index]
			CreateArgHolder(Index, Value, ArgumentsInfoFrame)
		end
	end

	for _, tab in pairs({ "Function Info", "Code" }) do
		local OldTab = InfoModalTab[tab]
		if not OldTab then
			continue
		end

		local OldTabButton = OldTab.TabButton
		local OldTabContent = OldTab.TabContents

		OldTabButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		OldTabButton.Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

		OldTabContent.Visible = false
	end

	CurrentInfoTab = "Arguments"
	if InfoModalTab["Arguments"] then
		local TabButton = InfoModalTab["Arguments"].TabButton
		local TabContent = InfoModalTab["Arguments"].TabContents

		TabButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		TabButton.Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		TabContent.Visible = true
	end

	if CurrentContext then
		CurrentContext:Close()
	end

	OpenModal(InfoFrame)
end

wax.shared.Drag.Setup(RemoteListLine, RemoteListResize, function(Info, Input: InputObject)
	local Delta = Input.Position - Info.StartPosition
	local FramePosition: UDim2 = Info.FramePosition
	local Offset = math.clamp(FramePosition.X.Offset + Delta.X, 120, (MainFrame.AbsoluteSize.X - 2) / 2)

	Info.Frame.Position = UDim2.new(FramePosition.X.Scale, Offset, FramePosition.Y.Scale, FramePosition.Y.Offset)

	LeftList.Size = UDim2.new(0, Offset, 1, -36)
	LogsWrapper.Size = UDim2.new(1, -(Offset + 2), 1, -36)
end)

wax.shared.Connect(wax.shared.Communicator.Event:Connect(function(Instance, Type, CallIndex)
	if not (CurrentTab and CurrentTab.Name == Type) then
		return
	end

	local Log = wax.shared.Logs[Type][Instance]
	if not Log then
		return
	end

	local CallInfo = Log.Calls[CallIndex]

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
	UpdateLogNameSize(Log)
	Log.Button.Calls.Text = "x" .. #Log.Calls
	Log.Button.Instance.Parent = RemoteList

	if CurrentLog == Log then
		PaginationHelper:Update(#Log.Calls)

		local Start, End = PaginationHelper:GetIndexRanges(Page)
		if not wax.shared.Settings.ShowExecutorLogs.Value then
			CallIndex = Log.GameCalls[CallIndex]
			if not CallIndex then
				return
			end
		end

		if CallIndex < Start or CallIndex > End then
			ShowPagination(Log)
			return
		end

		local Data = setmetatable({
			Instance = Instance,
			Type = Type,
			Order = CallIndex,
		}, {
			__index = CallInfo,
		})

		CreateCallFrame(Data)
	end
end))

wax.shared.Connect(wax.shared.UserInputService.InputBegan:Connect(function(Input: InputObject)
	if wax.shared.IsClickInput(Input) then
		if
			CurrentContext
			and not (
				wax.shared.IsMouseOverFrame(ContextMenu, Input.Position)
				or wax.shared.IsMouseOverFrame(CurrentContext.Parent, Input.Position)
			)
		then
			CurrentContext:Close()
		end
	elseif Input.KeyCode == Enum.KeyCode.K and wax.shared.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		OpenSearch()
	elseif OpenedModal == SearchFrame then
		if Input.KeyCode == Enum.KeyCode.Return then
			EnterResult(SelectedResult)
		elseif Input.KeyCode == Enum.KeyCode.Up then
			SelectResult(SelectedResult - 1, true)
		elseif Input.KeyCode == Enum.KeyCode.Down then
			SelectResult(SelectedResult + 1, true)
		end
	end
end))

end)() end
} -- [RefId] = Closure

-- Holds the actual DOM data
local ObjectTree = {
    {
        1,
        4,
        {
            "cobalt"
        },
        {
            {
                34,
                2,
                {
                    "Window"
                }
            },
            {
                2,
                2,
                {
                    "Bypass"
                }
            },
            {
                16,
                1,
                {
                    "Utils"
                },
                {
                    {
                        31,
                        1,
                        {
                            "Serializer"
                        },
                        {
                            {
                                32,
                                2,
                                {
                                    "LuaEncode"
                                }
                            }
                        }
                    },
                    {
                        33,
                        2,
                        {
                            "Sonner"
                        }
                    },
                    {
                        25,
                        2,
                        {
                            "ImageFetch"
                        }
                    },
                    {
                        26,
                        2,
                        {
                            "Interface"
                        }
                    },
                    {
                        30,
                        2,
                        {
                            "SaveManager"
                        }
                    },
                    {
                        21,
                        2,
                        {
                            "FileLog"
                        }
                    },
                    {
                        29,
                        2,
                        {
                            "Resize"
                        }
                    },
                    {
                        24,
                        2,
                        {
                            "Icons"
                        }
                    },
                    {
                        23,
                        2,
                        {
                            "Hooking"
                        }
                    },
                    {
                        22,
                        2,
                        {
                            "Highlighter"
                        }
                    },
                    {
                        19,
                        2,
                        {
                            "Connect"
                        }
                    },
                    {
                        27,
                        2,
                        {
                            "Log"
                        }
                    },
                    {
                        18,
                        2,
                        {
                            "CodeGen"
                        }
                    },
                    {
                        28,
                        2,
                        {
                            "Pagination"
                        }
                    },
                    {
                        20,
                        2,
                        {
                            "Drag"
                        }
                    },
                    {
                        17,
                        2,
                        {
                            "Animations"
                        }
                    }
                }
            },
            {
                4,
                2,
                {
                    "Spy"
                },
                {
                    {
                        5,
                        1,
                        {
                            "Actors"
                        },
                        {
                            {
                                7,
                                5,
                                {
                                    "Unload",
                                    Value = "local RelayChannel = get_comm_channel(...)\r\n\r\nlocal getrawmetatable = getrawmetatable or debug.getmetatable\r\n\r\nRelayChannel.Event:Connect(function(Type, ...)\r\n\tif Type ~= \"Unload\" then\r\n\t\treturn\r\n\tend\r\n\r\n\tlocal gameMetatable = getrawmetatable(game)\r\n\r\n\tif restorefunction then\r\n\t\tpcall(restorefunction, gameMetatable.__namecall)\r\n\t\tpcall(restorefunction, gameMetatable.__newindex)\r\n\tend\r\nend)\r\n"
                                }
                            },
                            {
                                6,
                                5,
                                {
                                    "Environement",
                                    Value = "--[[\r\n    \228\184\186 actor \231\142\175\229\162\131\229\164\141\229\136\187\231\154\132 Wax \231\142\175\229\162\131\r\n]]\r\n\r\ntype ActorData = {\r\n\tToken: string,\r\n\r\n\tIgnorePlayerModule: boolean,\r\n\tUseAlternativeHooks: boolean,\r\n\tIgnoredRemotesDropdown: { [string]: boolean },\r\n\r\n\tExecutorSupport: { [string]: { IsWorking: boolean } },\r\n}\r\n\r\nlocal Data: ActorData = COBALT_ACTOR_DATA\r\n\r\nlocal RelayChannel = get_comm_channel(...)\r\n\r\nlocal wax = { shared = {} }\r\n\r\nwax.shared.ExecutorSupport = Data.ExecutorSupport\r\n\r\nfor _, Service in pairs({\r\n\t\"Players\",\r\n\t\"HttpService\",\r\n}) do\r\n\twax.shared[Service] = cloneref(game:GetService(Service))\r\nend\r\n\r\nwax.shared.LocalPlayer = wax.shared.Players.LocalPlayer\r\nwax.shared.PlayerScripts = cloneref(wax.shared.LocalPlayer:WaitForChild(\"PlayerScripts\"))\r\nwax.shared.ExecutorName = string.split(identifyexecutor(), \" \")[1]\r\n\r\nwax.shared.newcclosure = wax.shared.ExecutorName == \"AWP\"\r\n\t\tand function(f)\r\n\t\t\tlocal env = getfenv(f)\r\n\t\t\tlocal x = setmetatable({\r\n\t\t\t\t__F = f,\r\n\t\t\t}, {\r\n\t\t\t\t__index = env,\r\n\t\t\t\t__newindex = env,\r\n\t\t\t})\r\n\r\n\t\t\tlocal nf = function(...)\r\n\t\t\t\treturn __F(...)\r\n\t\t\tend\r\n\t\t\tsetfenv(nf, x) -- \232\174\190\231\189\174\229\135\189\230\149\176\231\142\175\229\162\131\239\188\136nf \231\154\132\231\142\175\229\162\131\228\188\154\232\162\171\229\142\187\228\188\152\229\140\150\239\188\137\r\n\t\t\treturn newcclosure(nf)\r\n\t\tend\r\n\tor newcclosure\r\n\r\nwax.shared.getrawmetatable = wax.shared.ExecutorSupport[\"getrawmetatable\"].IsWorking and (getrawmetatable or debug.getmetatable) or function()\r\n\treturn setmetatable({}, {\r\n\t\t__index = function() return function() end end\r\n\t})\r\nend\r\n\r\nwax.shared.restorefunction = function(Function: (...any) -> ...any, Silent: boolean?)\r\n\tlocal Original = wax.shared.Hooks[Function]\r\n\r\n\tif Silent and not Original then\r\n\t\treturn\r\n\tend\r\n\r\n\tassert(Original, \"\229\135\189\230\149\176\230\156\170\232\162\171 hook\")\r\n\r\n\tif restorefunction and isfunctionhooked(Function) then\r\n\t\trestorefunction(Function)\r\n\telse\r\n\t\twax.shared.Hooking.HookFunction(Function, Original)\r\n\tend\r\n\r\n\twax.shared.Hooks[Function] = nil\r\nend\r\n\r\nlocal Hooking = {}\r\n\r\nHooking.HookFunction = function(Original, Replacement)\r\n\tif not wax.shared.ExecutorSupport[\"hookfunction\"].IsWorking then\r\n\t\treturn Original\r\n\tend\r\n\r\n\treturn hookfunction(Original, Replacement)\r\nend\r\n\r\nwax.shared.AlternativeEnabled = Data.UseAlternativeHooks\r\n\r\nHooking.HookMetaMethod = function(object, method, hook)\r\n\tif Data.UseAlternativeHooks or (not wax.shared.ExecutorSupport[\"hookmetamethod\"].IsWorking and wax.shared.ExecutorSupport[\"getrawmetatable\"].IsWorking) then\r\n\t\tlocal Metatable = wax.shared.getrawmetatable(object)\r\n\t\tlocal originalMethod = rawget(Metatable, method)\r\n\t\t\r\n\t\tsetreadonly(Metatable, false)\r\n\t\trawset(Metatable, method, hook)\r\n\t\tsetreadonly(Metatable, true)\r\n\t\r\n\t\treturn originalMethod\r\n\tend\r\n\r\n\tif not wax.shared.ExecutorSupport[\"hookmetamethod\"].IsWorking then\r\n\t\tif method == \"__index\" then\r\n\t\t\tlocal _, Metamethod = xpcall(function()\r\n\t\t\t\treturn object[tostring(math.random())]\r\n\t\t\tend, function(err)\r\n\t\t\t\treturn debug.info(2, \"f\")\r\n\t\t\tend)\r\n\r\n\t\t\treturn Metamethod\r\n\t\telseif method == \"__newindex\" then\r\n\t\t\tlocal _, Metamethod = xpcall(function()\r\n\t\t\t\tobject[tostring(math.random())] = true\r\n\t\t\tend, function(err)\r\n\t\t\t\treturn debug.info(2, \"f\")\r\n\t\t\tend)\r\n\r\n\t\t\treturn Metamethod\r\n\t\telseif method == \"__namecall\" then\r\n\t\t\tlocal _, Metamethod = xpcall(function()\r\n\t\t\t\tobject:Mustard()\r\n\t\t\tend, function(err)\r\n\t\t\t\treturn debug.info(2, \"f\")\r\n\t\t\tend)\r\n\r\n\t\t\treturn Metamethod\r\n\t\tend\r\n\r\n\t\treturn nil\r\n\tend\r\n\r\n\treturn hookmetamethod(object, method, hook)\r\nend\r\n\r\nwax.shared.Hooking = Hooking\r\n\r\nwax.shared.Hooks = {}\r\nwax.shared.Settings = {\r\n\tIgnorePlayerModule = { Value = Data.IgnorePlayerModule },\r\n\tIgnoredRemotesDropdown = { Value = Data.IgnoredRemotesDropdown },\r\n}\r\n\r\nwax.shared.IsPlayerModule = function(Origin: LocalScript | ModuleScript, Instance: Instance): boolean\r\n\tif Instance and Instance.ClassName ~= \"BindableEvent\" then\r\n\t\treturn false\r\n\tend\r\n\r\n\tlocal PlayerModule = Origin and Origin.FindFirstAncestor(Origin, \"PlayerModule\") or nil\r\n\tif not PlayerModule then\r\n\t\treturn false\r\n\tend\r\n\r\n\tif PlayerModule.Parent == nil then\r\n\t\treturn true\r\n\tend\r\n\r\n\treturn compareinstances(PlayerModule.Parent, wax.shared.PlayerScripts)\r\nend\r\nwax.shared.ShouldIgnore = function(Instance, Origin)\r\n\treturn wax.shared.Settings.IgnoredRemotesDropdown.Value[Instance.ClassName] == true\r\n\t\tor (wax.shared.Settings.IgnorePlayerModule.Value and wax.shared.IsPlayerModule(Origin, Instance))\r\nend\r\n\r\nwax.shared.Connections = {}\r\n\r\nwax.shared.Connect = function(Connection)\r\n\ttable.insert(wax.shared.Connections, Connection)\r\n\treturn Connection\r\nend\r\n\r\nwax.shared.Disconnect = function(Connection)\r\n\tConnection:Disconnect()\r\n\r\n\tlocal Index = table.find(wax.shared.Connections, Connection)\r\n\tif Index then\r\n\t\ttable.remove(wax.shared.Connections, Index)\r\n\tend\r\n\r\n\treturn true\r\nend\r\n\r\nlocal OnUnload\r\n\r\nlocal RelayConnection\r\nRelayConnection = RelayChannel.Event:Connect(function(Type, ...)\r\n\tif Type == \"Unload\" then\r\n\t\tRelayConnection:Disconnect()\r\n\t\twax.shared.Unloaded = true\r\n\t\tfor _, Connection in pairs(wax.shared.Connections) do\r\n\t\t\twax.shared.Disconnect(Connection)\r\n\t\tend\r\n\r\n\t\tif OnUnload then\r\n\t\t\tOnUnload()\r\n\t\tend\r\n\telseif Type == \"MainBlock\" then\r\n\t\tlocal Instance, EventType = ...\r\n\t\tlocal Log = wax.shared.Logs[EventType][Instance]\r\n\t\tif Log then\r\n\t\t\tLog:Block()\r\n\t\tend\r\n\telseif Type == \"MainIgnore\" then\r\n\t\tlocal Instance, EventType = ...\r\n\t\tlocal Log = wax.shared.Logs[EventType][Instance]\r\n\t\tif Log then\r\n\t\t\tLog:Ignore()\r\n\t\tend\r\n\telseif Type == \"MainSettingsSync\" then\r\n\t\tlocal Setting, Value = ...\r\n\t\tif wax.shared.Settings[Setting] then\r\n\t\t\twax.shared.Settings[Setting].Value = Value\r\n\t\tend\r\n\tend\r\nend)\r\n\r\nwax.shared.Unloaded = false\r\nwax.shared.Communicator = RelayChannel\r\n\r\nwax.shared.Log = {}\r\ndo\r\n\tlocal Log = wax.shared.Log\r\n\tLog.__index = Log\r\n\r\n\tfunction Log.new(Instance, Type, Method, Index, CallingScript)\r\n\t\tlocal NewLog = setmetatable({\r\n\t\t\tInstance = Instance,\r\n\t\t\tType = Type,\r\n\t\t\tMethod = Method,\r\n\t\t\tIndex = Index,\r\n\t\t\tCalls = {},\r\n\t\t\tIgnored = false,\r\n\t\t\tBlocked = false,\r\n\t\t}, Log)\r\n\r\n\t\treturn NewLog\r\n\tend\r\n\r\n\tlocal FunctionToMetatadata\r\n\r\n\tlocal GenerateUUID = wax.shared.HttpService.GenerateGUID\r\n\tlocal function GenerateId()\r\n\t\treturn GenerateUUID(wax.shared.HttpService, false)\r\n\tend\r\n\r\n\tlocal function FixTable(Table, Refs)\r\n\t\tif not Table then\r\n\t\t\treturn nil\r\n\t\tend\r\n\r\n\t\tlocal CyclicRefs = Refs or {}\r\n\t\tlocal Visited = {}\r\n\t\tlocal OutputTable = {}\r\n\t\tlocal ContainsCyclicRef = false\r\n\r\n\t\tfor Key, Value in Table do\r\n\t\t\tif type(Value) == \"table\" then\r\n\t\t\t\tif Visited[Value] then\r\n\t\t\t\t\tContainsCyclicRef = true\r\n\r\n\t\t\t\t\tOutputTable[Key] = {\r\n\t\t\t\t\t\t__CyclicRef = true,\r\n\t\t\t\t\t\t__Id = CyclicRefs[Value],\r\n\t\t\t\t\t}\r\n\t\t\t\t\tcontinue\r\n\t\t\t\tend\r\n\r\n\t\t\t\tif getmetatable(Value) then\r\n\t\t\t\t\tOutputTable[Key] =\r\n\t\t\t\t\t\t\"Cobalt: \230\151\160\230\179\149\229\176\134\229\184\166\230\156\137\229\133\131\232\161\168\231\154\132\232\161\168\228\187\142 actor \231\142\175\229\162\131\230\161\165\230\142\165\229\136\176\228\184\187\231\142\175\229\162\131\"\r\n\t\t\t\tend\r\n\r\n\t\t\t\tlocal Result, CycleMetadata, ContainsCyclic = FixTable(Value, CyclicRefs)\r\n\t\t\t\tif not Result then\r\n\t\t\t\t\tcontinue\r\n\t\t\t\tend\r\n\r\n\t\t\t\tif not ContainsCyclic then\r\n\t\t\t\t\tOutputTable[Key] = Result\r\n\t\t\t\t\tcontinue\r\n\t\t\t\tend\r\n\r\n\t\t\t\t-- \229\144\136\229\185\182\229\190\170\231\142\175\229\188\149\231\148\168\229\133\131\230\149\176\230\141\174\r\n\t\t\t\tfor k, v in pairs(CycleMetadata) do\r\n\t\t\t\t\tOutputTable[k] = v\r\n\t\t\t\tend\r\n\r\n\t\t\t\t-- \229\136\155\229\187\186\230\150\176\231\154\132\229\190\170\231\142\175\229\188\149\231\148\168\r\n\t\t\t\tlocal CycleId = GenerateId()\r\n\r\n\t\t\t\tOutputTable[Key] = {\r\n\t\t\t\t\t__CyclicRef = true,\r\n\t\t\t\t\t__Id = CycleId,\r\n\t\t\t\t}\r\n\r\n\t\t\t\tCyclicRefs[CycleId] = Value\r\n\r\n\t\t\t\tVisited[Value] = true\r\n\t\t\telseif type(Value) == \"function\" then\r\n\t\t\t\tOutputTable[Key] = FunctionToMetatadata(Value)\r\n\t\t\telse\r\n\t\t\t\tOutputTable[Key] = Value\r\n\t\t\tend\r\n\t\tend\r\n\r\n\t\treturn OutputTable, CyclicRefs, ContainsCyclicRef\r\n\tend\r\n\r\n\tFunctionToMetatadata = function(Function)\r\n\t\tif not Function then\r\n\t\t\treturn nil\r\n\t\tend\r\n\r\n\t\tlocal Metadata = {\r\n\t\t\tAddress = tostring(Function),\r\n\t\t\tName = debug.info(Function, \"n\"),\r\n\t\t\tIsC = iscclosure(Function),\r\n\t\t}\r\n\r\n\t\tif not iscclosure(Function) then\r\n\t\t\tMetadata[\"Upvalues\"] = debug.getupvalues(Function)\r\n\t\t\tMetadata[\"Constants\"] = debug.getconstants(Function)\r\n\t\t\tMetadata[\"Protos\"] = debug.getprotos(Function)\r\n\t\tend\r\n\r\n\t\t-- \231\148\168\228\186\142\233\170\140\232\175\129\230\173\164\229\135\189\230\149\176\230\152\175\231\148\177 FunctionToMetatadata \231\148\159\230\136\144\231\154\132\r\n\t\tMetadata[\"Validation\"] = Data.Token\r\n\t\tMetadata[\"__Function\"] = true\r\n\r\n\t\treturn Metadata\r\n\tend\r\n\r\n\tfunction DeepClone(orig, copies)\r\n\t\tcopies = copies or {}\r\n\t\tif type(orig) ~= \"table\" then\r\n\t\t\treturn orig\r\n\t\telseif copies[orig] then\r\n\t\t\treturn copies[orig]\r\n\t\tend\r\n\r\n\t\tlocal copy = {}\r\n\t\tcopies[orig] = copy\r\n\t\tfor k, v in pairs(orig) do\r\n\t\t\tcopy[DeepClone(k, copies)] = DeepClone(v, copies)\r\n\t\tend\r\n\t\treturn copy\r\n\tend\r\n\r\n\tlocal ClassesConnectionsToggle = {\r\n\t\tRemoteEvent = \"OnClientEvent\",\r\n\t\tUnreliableRemoteEvent = \"OnClientEvent\",\r\n\t\tBindableEvent = \"Event\",\r\n\t}\r\n\r\n\tfunction Log:SetConnectionsEnabled(enabled: boolean)\r\n\t\tif not self.Instance or not ClassesConnectionsToggle[self.Instance.ClassName] then\r\n\t\t\treturn\r\n\t\tend\r\n\r\n\t\tlocal ConnectionName = ClassesConnectionsToggle[self.Instance.ClassName]\r\n\t\tif self.Type ~= \"Incoming\" or not ConnectionName then\r\n\t\t\treturn\r\n\t\tend\r\n\r\n\t\tfor _, Connection in pairs(getconnections(self.Instance[ConnectionName])) do\r\n\t\t\tif enabled then\r\n\t\t\t\tConnection:Enable()\r\n\t\t\telse\r\n\t\t\t\tConnection:Disable()\r\n\t\t\tend\r\n\t\tend\r\n\tend\r\n\r\n\tfunction Log:Call(RawInfo)\r\n\t\tRawInfo[\"IsActor\"] = true\r\n\t\tlocal Info = DeepClone(RawInfo)\r\n\t\twax.shared.Communicator.Fire(wax.shared.Communicator, \"ActorCall\", self.Instance, self.Type, FixTable(Info))\r\n\tend\r\n\r\n\tfunction Log:Ignore()\r\n\t\tself.Ignored = not self.Ignored\r\n\tend\r\n\r\n\tfunction Log:Block()\r\n\t\tself.Blocked = not self.Blocked\r\n\t\tself:SetConnectionsEnabled(not self.Blocked)\r\n\tend\r\nend\r\n\r\nwax.shared.Logs = {\r\n\tOutgoing = {},\r\n\tIncoming = {},\r\n}\r\n\r\nwax.shared.NewLog = function(Instance, Type, Method, Index, CallingScript)\r\n\tlocal NewLog = wax.shared.Log.new(Instance, Type, Method, Index, CallingScript)\r\n\twax.shared.Logs[Type][Instance] = NewLog\r\n\treturn NewLog\r\nend\r\n"
                                }
                            }
                        }
                    },
                    {
                        8,
                        1,
                        {
                            "Hooks"
                        },
                        {
                            {
                                9,
                                1,
                                {
                                    "Actors"
                                },
                                {
                                    {
                                        11,
                                        5,
                                        {
                                            "Outgoing",
                                            Value = "local NamecallMethods = {\r\n\t\"FireServer\",\r\n\t\"InvokeServer\",\r\n\t\"Fire\",\r\n\t\"Invoke\",\r\n\t\"fireServer\",\r\n\t\"invokeServer\",\r\n\t\"fire\",\r\n\t\"invoke\",\r\n}\r\nlocal AllowedClassNames =\r\n\t{ \"RemoteEvent\", \"RemoteFunction\", \"UnreliableRemoteEvent\", \"BindableEvent\", \"BindableFunction\" }\r\n\r\n--[[\r\n\t\233\128\154\232\191\135 `debug.info` \232\142\183\229\143\150\232\176\131\231\148\168\229\135\189\230\149\176\r\n\r\n\t@return `function | nil` \232\176\131\231\148\168\231\154\132\229\135\189\230\149\176\239\188\140\229\166\130\230\158\156\230\137\190\228\184\141\229\136\176\229\136\153\232\191\148\229\155\158 nil\227\128\130\r\n]]\r\nlocal function getcallingfunction()\r\n\tfor i = 4, 10 do\r\n\t\tlocal Function, Source = debug.info(i, \"fs\")\r\n\t\tif not Function or not Source then\r\n\t\t\tbreak\r\n\t\tend\r\n\r\n\t\tif Source == \"[C]\" then\r\n\t\t\tcontinue\r\n\t\tend\r\n\r\n\t\treturn Function\r\n\tend\r\n\r\n\treturn debug.info(4, \"f\")\r\nend\r\n\r\n--[[\r\n\t\233\128\154\232\191\135 `debug.info` \232\142\183\229\143\150\232\176\131\231\148\168\232\175\165\229\135\189\230\149\176\231\154\132\232\132\154\230\156\172\230\137\128\229\156\168\231\154\132\232\161\140\229\143\183\r\n\r\n\t@return number \232\191\148\229\155\158\232\176\131\231\148\168\232\175\165\229\135\189\230\149\176\231\154\132\232\132\154\230\156\172\231\154\132\232\161\140\229\143\183\227\128\130\r\n]]\r\nlocal function getcallingline()\r\n\tfor i = 4, 10 do\r\n\t\tlocal Source, Line = debug.info(i, \"sl\")\r\n\t\tif not Source then\r\n\t\t\tbreak\r\n\t\tend\r\n\r\n\t\tif Source == \"[C]\" then\r\n\t\t\tcontinue\r\n\t\tend\r\n\r\n\t\treturn Line\r\n\tend\r\n\r\n\treturn debug.info(4, \"l\")\r\nend\r\n\r\n-- \229\133\131\230\150\185\230\179\149\233\146\169\229\173\144\239\188\136hook metamethods\239\188\137\r\nwax.shared.NamecallHook = wax.shared.Hooking.HookMetaMethod(\r\n\tgame,\r\n\t\"__namecall\",\r\n\twax.shared.newcclosure(function(...)\r\n\t\tlocal self = ...\r\n\t\tlocal Method = getnamecallmethod()\r\n\r\n\t\t-- \230\163\128\230\159\165\230\152\175\229\144\166\228\184\186\229\143\151\230\148\175\230\140\129\231\154\132\232\191\156\231\168\139\229\175\185\232\177\161\239\188\136\229\185\182\228\184\148\228\184\141\230\152\175\229\134\133\233\131\168\233\128\154\228\191\161\229\153\168\239\188\137\r\n\t\tif\r\n\t\t\ttypeof(self) == \"Instance\"\r\n\t\t\tand table.find(AllowedClassNames, self.ClassName)\r\n\t\t\tand not rawequal(self, wax.shared.Communicator)\r\n\t\t\tand table.find(NamecallMethods, Method)\r\n\t\t\tand not wax.shared.ShouldIgnore(self, getcallingscript())\r\n\t\tthen\r\n\t\t\tlocal Log = wax.shared.Logs.Outgoing[self]\r\n\t\t\tif not Log then\r\n\t\t\t\tLog = wax.shared.NewLog(self, \"Outgoing\", Method, getcallingscript())\r\n\t\t\tend\r\n\r\n\t\t\tif Log.Blocked then\r\n\t\t\t\treturn\r\n\t\t\telseif not Log.Ignored then\r\n\t\t\t\tlocal Info = {\r\n\t\t\t\t\tArguments = table.pack(select(2, ...)),\r\n\t\t\t\t\tTime = os.date(\"%X\"),\r\n\t\t\t\t\tOrigin = getcallingscript(),\r\n\t\t\t\t\tFunction = getcallingfunction(),\r\n\t\t\t\t\tLine = getcallingline(),\r\n\t\t\t\t\tIsExecutor = checkcaller(),\r\n\t\t\t\t}\r\n\t\t\t\tLog:Call(Info)\r\n\r\n\t\t\t\t-- \233\146\136\229\175\185 RemoteFunction \231\154\132\232\191\148\229\155\158\229\128\188\232\191\155\232\161\140\229\164\132\231\144\134\239\188\136\228\190\139\229\166\130\239\188\154local result = RemoteFunction:InvokeServer()\239\188\137\r\n\t\t\t\tif self.ClassName == \"RemoteFunction\" and (Method == \"InvokeServer\" or Method == \"invokeServer\") then\r\n\t\t\t\t\tLog = wax.shared.Logs.Incoming[self]\r\n\t\t\t\t\tif not Log then\r\n\t\t\t\t\t\tLog = wax.shared.NewLog(self, \"Incoming\", Method, getcallingscript())\r\n\t\t\t\t\tend\r\n\r\n\t\t\t\t\tif Log.Blocked then\r\n\t\t\t\t\t\treturn\r\n\t\t\t\t\tend\r\n\r\n\t\t\t\t\tlocal Result = table.pack(wax.shared.NamecallHook(...))\r\n\t\t\t\t\tif not Log.Ignored then\r\n\t\t\t\t\t\tlocal RFResultInfo = {\r\n\t\t\t\t\t\t\tArguments = Result,\r\n\t\t\t\t\t\t\tTime = os.date(\"%X\"),\r\n\t\t\t\t\t\t\tOrigin = getcallingscript(),\r\n\t\t\t\t\t\t\tFunction = getcallingfunction(),\r\n\t\t\t\t\t\t\tLine = getcallingline(),\r\n\t\t\t\t\t\t\tIsExecutor = checkcaller(),\r\n\t\t\t\t\t\t\tOriginalInvokeArgs = table.pack(select(2, ...)),\r\n\t\t\t\t\t\t}\r\n\t\t\t\t\t\tLog:Call(RFResultInfo)\r\n\t\t\t\t\tend\r\n\r\n\t\t\t\t\treturn table.unpack(Result, 1, Result.n)\r\n\t\t\t\tend\r\n\t\t\tend\r\n\t\tend\r\n\r\n\t\treturn wax.shared.NamecallHook(...)\r\n\tend)\r\n)\r\n\r\n-- \230\153\174\233\128\154\229\135\189\230\149\176\233\146\169\229\173\144\239\188\136function hooks\239\188\137\r\nlocal FunctionsToHook = {\r\n\tInstance.new(\"BindableFunction\").Invoke,\r\n\tInstance.new(\"RemoteFunction\").InvokeServer,\r\n\tInstance.new(\"BindableEvent\").Fire,\r\n\tInstance.new(\"RemoteEvent\").FireServer,\r\n\tInstance.new(\"UnreliableRemoteEvent\").FireServer,\r\n}\r\n\r\nfor _, Function in pairs(FunctionsToHook) do\r\n\tlocal Method = debug.info(Function, \"n\")\r\n\r\n\twax.shared.Hooks[Function] = wax.shared.Hooking.HookFunction(\r\n\t\tFunction,\r\n\t\twax.shared.newcclosure(function(...)\r\n\t\t\tlocal self = ...\r\n\r\n\t\t\tif\r\n\t\t\t\ttypeof(self) == \"Instance\"\r\n\t\t\t\tand table.find(AllowedClassNames, self.ClassName)\r\n\t\t\t\tand not rawequal(self, wax.shared.Communicator)\r\n\t\t\t\tand not wax.shared.ShouldIgnore(self, getcallingscript())\r\n\t\t\tthen\r\n\t\t\t\tlocal Log = wax.shared.Logs.Outgoing[self]\r\n\t\t\t\tif not Log then\r\n\t\t\t\t\tLog = wax.shared.NewLog(self, \"Outgoing\", Method, getcallingscript())\r\n\t\t\t\tend\r\n\r\n\t\t\t\tif Log.Blocked then\r\n\t\t\t\t\treturn\r\n\t\t\t\telseif not Log.Ignored then\r\n\t\t\t\t\tlocal Info = {\r\n\t\t\t\t\t\tArguments = table.pack(select(2, ...)),\r\n\t\t\t\t\t\tTime = os.date(\"%X\"),\r\n\t\t\t\t\t\tOrigin = getcallingscript(),\r\n\t\t\t\t\t\tFunction = getcallingfunction(),\r\n\t\t\t\t\t\tLine = getcallingline(),\r\n\t\t\t\t\t\tIsExecutor = checkcaller(),\r\n\t\t\t\t\t}\r\n\t\t\t\t\tLog:Call(Info)\r\n\r\n\t\t\t\t\t-- \233\146\136\229\175\185 RemoteFunction \231\154\132\232\191\148\229\155\158\229\128\188\232\191\155\232\161\140\229\164\132\231\144\134\239\188\136\228\190\139\229\166\130\239\188\154local result = RemoteFunction:InvokeServer()\239\188\137\r\n\t\t\t\t\tif\r\n\t\t\t\t\t\tself.ClassName == \"RemoteFunction\"\r\n\t\t\t\t\t\tand (Method == \"InvokeServer\" or Method == \"invokeServer\")\r\n\t\t\t\t\tthen\r\n\t\t\t\t\t\tLog = wax.shared.Logs.Incoming[self]\r\n\t\t\t\t\t\tif not Log then\r\n\t\t\t\t\t\t\tLog = wax.shared.NewLog(self, \"Incoming\", Method, getcallingscript())\r\n\t\t\t\t\t\tend\r\n\r\n\t\t\t\t\t\tif Log.Blocked then\r\n\t\t\t\t\t\t\treturn\r\n\t\t\t\t\t\tend\r\n\r\n\t\t\t\t\t\tlocal Result = table.pack(wax.shared.Hooks[Function](...))\r\n\t\t\t\t\t\tif not Log.Ignored then\r\n\t\t\t\t\t\t\tlocal RFResultInfo = {\r\n\t\t\t\t\t\t\t\tArguments = Result,\r\n\t\t\t\t\t\t\t\tTime = os.date(\"%X\"),\r\n\t\t\t\t\t\t\t\tOrigin = getcallingscript(),\r\n\t\t\t\t\t\t\t\tFunction = getcallingfunction(),\r\n\t\t\t\t\t\t\t\tLine = getcallingline(),\r\n\t\t\t\t\t\t\t\tIsExecutor = checkcaller(),\r\n\t\t\t\t\t\t\t\tOriginalInvokeArgs = table.pack(select(2, ...)),\r\n\t\t\t\t\t\t\t}\r\n\t\t\t\t\t\t\tLog:Call(RFResultInfo)\r\n\t\t\t\t\t\tend\r\n\r\n\t\t\t\t\t\treturn table.unpack(Result, 1, Result.n)\r\n\t\t\t\t\tend\r\n\t\t\t\tend\r\n\t\t\tend\r\n\r\n\t\t\treturn wax.shared.Hooks[Function](...)\r\n\t\tend)\r\n\t)\r\nend\r\n"
                                        }
                                    },
                                    {
                                        10,
                                        5,
                                        {
                                            "Incoming",
                                            Value = "local ClassesToHook = {\r\n\tRemoteEvent = \"OnClientEvent\",\r\n\tRemoteFunction = \"OnClientInvoke\",\r\n\tUnreliableRemoteEvent = \"OnClientEvent\",\r\n\tBindableEvent = \"Event\",\r\n\tBindableFunction = \"OnInvoke\",\r\n}\r\n\r\ntype InstancesToHook = RemoteEvent | UnreliableRemoteEvent | RemoteFunction | BindableEvent | BindableFunction\r\ntype MethodsToHook = \"OnClientEvent\" | \"OnClientInvoke\" | \"Event\" | \"OnInvoke\"\r\n\r\nlocal LogConnectionFunctions = {}\r\nlocal SignalMapping = setmetatable({}, { __mode = \"kv\" })\r\n\r\n--[[\r\n\t\232\191\148\229\155\158\232\176\131\231\148\168\229\135\189\230\149\176\231\154\132\232\132\154\230\156\172\230\137\128\229\156\168\231\154\132\232\161\140\229\143\183\239\188\140\228\189\191\231\148\168 `debug.info`\r\n\r\n\t@return number \232\191\148\229\155\158\232\176\131\231\148\168\232\132\154\230\156\172\231\154\132\232\161\140\229\143\183\r\n]]\r\nlocal function getcallingline()\r\n\tfor i = 4, 10 do\r\n\t\tlocal Source, Line = debug.info(i, \"sl\")\r\n\t\tif not Source then\r\n\t\t\tbreak\r\n\t\tend\r\n\r\n\t\tif Source == \"[C]\" then\r\n\t\t\tcontinue\r\n\t\tend\r\n\r\n\t\treturn Line\r\n\tend\r\n\r\n\treturn debug.info(4, \"l\")\r\nend\r\n\r\n--[[\r\n\t\229\141\149\231\139\172\232\174\176\229\189\149\228\184\128\230\172\161\230\142\165\230\148\182\229\136\176\231\154\132\232\191\156\231\168\139\232\176\131\231\148\168\227\128\130\r\n\r\n\t@param Instance \232\162\171\232\176\131\231\148\168\231\154\132\229\174\158\228\190\139\r\n\t@param Method \232\162\171\232\176\131\231\148\168\231\154\132\230\150\185\230\179\149 (\228\190\139\229\166\130 \"OnClientEvent\")\r\n\t@param Function \232\162\171\232\176\131\231\148\168\231\154\132\229\135\189\230\149\176\239\188\140\229\166\130\230\158\156\230\156\137\231\154\132\232\175\157\r\n\t@param Info \229\133\179\228\186\142\232\176\131\231\148\168\231\154\132\228\191\161\230\129\175\239\188\140\229\140\133\230\139\172\229\143\130\230\149\176\229\146\140\230\157\165\230\186\144\227\128\130\229\143\175\228\187\165\228\184\186 nil\r\n\t@param ... \228\187\142\230\156\141\229\138\161\231\171\175\228\188\160\231\187\153\229\174\162\230\136\183\231\171\175\231\154\132\229\143\130\230\149\176\r\n\t@return boolean \229\166\130\230\158\156\232\176\131\231\148\168\232\162\171\230\139\166\230\136\170\229\136\153\232\191\148\229\155\158 true\239\188\140\229\144\166\229\136\153\232\191\148\229\155\158 false\r\n]]\r\nlocal function LogRemote(\r\n\tInstance: InstancesToHook,\r\n\tMethod: MethodsToHook,\r\n\tFunction: (...any) -> ...any,\r\n\tInfo: {\r\n\t\tArguments: { [number]: any, n: number },\r\n\t\tTime: string,\r\n\t\tOrigin: Instance,\r\n\t\tFunction: (...any) -> ...any,\r\n\t\tLine: number,\r\n\t\tIsExecutor: boolean,\r\n\t} | nil,\r\n\t...\r\n)\r\n\tif not wax.shared.ShouldIgnore(Instance, getcallingscript()) and not LogConnectionFunctions[Function] then\r\n\t\tlocal Log = wax.shared.Logs.Incoming[Instance]\r\n\t\tif not Log then\r\n\t\t\tLog = wax.shared.NewLog(Instance, \"Incoming\", Method, getcallingscript())\r\n\t\tend\r\n\r\n\t\tif Log.Blocked then\r\n\t\t\treturn true\r\n\t\telseif not Log.Ignored then\r\n\t\t\tlocal CallInfo = Info\r\n\t\t\t\tor {\r\n\t\t\t\t\tArguments = table.pack(...),\r\n\t\t\t\t\tTime = os.date(\"%X\"),\r\n\t\t\t\t\tOrigin = getcallingscript(),\r\n\t\t\t\t\tFunction = Function,\r\n\t\t\t\t\tLine = getcallingline(),\r\n\t\t\t\t\tIsExecutor = checkcaller(),\r\n\t\t\t\t}\r\n\t\t\tLog:Call(CallInfo)\r\n\t\tend\r\n\tend\r\n\r\n\treturn false\r\nend\r\n\r\n--[[\r\n\t\229\136\155\229\187\186\228\184\128\228\184\170\229\135\189\230\149\176\239\188\140\231\148\168\228\186\142\228\188\160\233\128\146\231\187\153 `Connect`\239\188\140\229\174\131\228\188\154\232\174\176\229\189\149\230\137\128\230\156\137\232\191\155\229\133\165\231\154\132\232\176\131\231\148\168\227\128\130  \r\n\t\229\144\140\230\151\182\228\188\154\229\176\134\232\175\165\229\135\189\230\149\176\230\183\187\229\138\160\229\136\176\229\191\189\231\149\165\229\136\151\232\161\168 (`LogConnectionFunctions`)\239\188\140\228\187\165\233\129\191\229\133\141\228\184\141\229\191\133\232\166\129\231\154\132\233\135\141\229\164\141\232\174\176\229\189\149\227\128\130\r\n\t\r\n\t@param Instance \232\166\129\232\174\176\229\189\149\231\154\132\229\174\158\228\190\139\r\n\t@param Method \232\166\129\232\174\176\229\189\149\231\154\132\230\150\185\230\179\149 (\228\190\139\229\166\130 \"OnClientEvent\")\r\n\t@return function \232\191\148\229\155\158\228\184\128\228\184\170\229\135\189\230\149\176\239\188\140\232\175\165\229\135\189\230\149\176\228\188\154\232\174\176\229\189\149\230\137\128\230\156\137\232\175\165\229\174\158\228\190\139\229\146\140\230\150\185\230\179\149\231\154\132\232\176\131\231\148\168\r\n]]\r\nlocal function CreateConnectionFunction(Instance: InstancesToHook, Method: MethodsToHook)\r\n\tlocal ConnectionFunction = function(...)\r\n\t\tfor _, Connection in pairs(getconnections((Instance :: any)[Method])) do\r\n\t\t\tif Connection.ForeignState then\r\n\t\t\t\tcontinue\r\n\t\t\tend\r\n\r\n\t\t\tlocal Function = typeof(Connection.Function) == \"function\" and Connection.Function or nil\r\n\t\t\tlocal Thread = Connection.Thread\r\n\r\n\t\t\tlocal Origin = nil\r\n\r\n\t\t\tif Thread and getscriptfromthread then\r\n\t\t\t\tOrigin = getscriptfromthread(Thread)\r\n\t\t\telseif Function then\r\n\t\t\t\t-- ts\239\188\136ThreadScript\239\188\137\228\184\141\229\143\175\233\157\160\239\188\140\229\155\160\228\184\186\229\143\175\232\131\189\230\156\137\228\186\186\231\155\180\230\142\165\230\138\138\229\133\168\229\177\128 script \231\189\174\228\184\186 nil\r\n\t\t\t\t-- \229\166\130\230\158\156 debug.getinfo(Function).source \230\136\150 debug.info(Function, \"s\") \232\131\189\232\191\148\229\155\158 Instance \229\176\177\229\165\189\228\186\134...\r\n\r\n\t\t\t\tlocal Script = rawget(getfenv(Function), \"script\")\r\n\t\t\t\tif typeof(Script) == \"Instance\" then\r\n\t\t\t\t\tOrigin = Script\r\n\t\t\t\tend\r\n\t\t\tend\r\n\r\n\t\t\tLogRemote(Instance, Method, Function, {\r\n\t\t\t\tArguments = table.pack(...),\r\n\t\t\t\tTime = os.date(\"%X\"),\r\n\t\t\t\tOrigin = Origin,\r\n\t\t\t\tFunction = Function,\r\n\t\t\t\tLine = nil,\r\n\t\t\t\tIsExecutor = Function and isexecutorclosure(Function) or false,\r\n\t\t\t}, ...)\r\n\t\tend\r\n\tend\r\n\r\n\tLogConnectionFunctions[ConnectionFunction] = true\r\n\treturn ConnectionFunction\r\nend\r\n\r\n--[[\r\n\t\229\164\132\231\144\134\230\159\144\228\184\170\229\174\158\228\190\139\231\154\132\230\151\165\229\191\151\230\140\130\233\146\169\232\174\190\231\189\174\r\n\r\n\t@param Instance \232\166\129\229\164\132\231\144\134\231\154\132\229\174\158\228\190\139\r\n]]\r\nlocal function HandleInstance(Instance: any)\r\n\tif not ClassesToHook[Instance.ClassName] or Instance == wax.shared.Communicator then\r\n\t\treturn\r\n\tend\r\n\r\n\tlocal Method = ClassesToHook[Instance.ClassName]\r\n\r\n\tif Instance.ClassName == \"RemoteEvent\" or Instance.ClassName == \"UnreliableRemoteEvent\" then\r\n\t\twax.shared.Connect(Instance.OnClientEvent:Connect(CreateConnectionFunction(Instance, Method)))\r\n\r\n\t\tSignalMapping[Instance.OnClientEvent] = Instance\r\n\telseif Instance.ClassName == \"BindableEvent\" then\r\n\t\twax.shared.Connect(Instance.Event:Connect(CreateConnectionFunction(Instance, Method)))\r\n\r\n\t\tSignalMapping[Instance.Event] = Instance\r\n\telseif Instance.ClassName == \"RemoteFunction\" or Instance.ClassName == \"BindableFunction\" then\r\n\t\tlocal Success, Callback = pcall(getcallbackvalue, Instance, Method)\r\n\t\tlocal IsCallable = (\r\n\t\t\ttypeof(Callback) == \"function\"\r\n\t\t\tor wax.shared.getrawmetatable(Callback) ~= nil and typeof(wax.shared.getrawmetatable(Callback)[\"__call\"]) == \"function\"\r\n\t\t\tor false\r\n\t\t)\r\n\r\n\t\tif not Success or not IsCallable then\r\n\t\t\treturn\r\n\t\tend\r\n\r\n\t\tInstance[Method] = function(...)\r\n\t\t\tif LogRemote(Instance, Method, Callback, nil, ...) then\r\n\t\t\t\treturn\r\n\t\t\tend\r\n\r\n\t\t\treturn Callback(...)\r\n\t\tend\r\n\tend\r\nend\r\n\r\nwax.shared.Connect(game.DescendantAdded:Connect(HandleInstance))\r\n\r\n-- getinstances() \228\184\141\229\143\175\233\157\160\239\188\140\230\188\143\230\142\137\228\186\134\228\184\128\228\186\155\229\174\158\228\190\139... ts \229\133\132\229\188\159\231\156\159\229\157\145\r\nlocal CategoryToSearch = { game:GetDescendants() }\r\nif wax.shared.ExecutorSupport[\"getnilinstances\"].IsWorking then\r\n\ttable.insert(CategoryToSearch, getnilinstances())\r\nend\r\n\r\nfor _, Category in CategoryToSearch do\r\n\tfor _, Instance in pairs(Category) do\r\n\t\tHandleInstance(Instance)\r\n\tend\r\nend\r\n\r\nwax.shared.NewIndexHook = wax.shared.Hooking.HookMetaMethod(\r\n\tgame,\r\n\t\"__newindex\",\r\n\twax.shared.newcclosure(function(...)\r\n\t\tlocal self, key, value = ...\r\n\r\n\t\tif typeof(self) ~= \"Instance\" or not ClassesToHook[self.ClassName] then\r\n\t\t\treturn wax.shared.NewIndexHook(...)\r\n\t\tend\r\n\r\n\t\tif self.ClassName == \"RemoteFunction\" or self.ClassName == \"BindableFunction\" then\r\n\t\t\tlocal Method = ClassesToHook[self.ClassName]\r\n\r\n\t\t\tlocal IsCallable = (\r\n\t\t\t\ttypeof(value) == \"function\"\r\n\t\t\t\tor wax.shared.getrawmetatable(value) ~= nil and typeof(wax.shared.getrawmetatable(value)[\"__call\"]) == \"function\"\r\n\t\t\t\tor false\r\n\t\t\t)\r\n\r\n\t\t\tif key == Method and IsCallable then\r\n\t\t\t\treturn wax.shared.NewIndexHook(self, key, function(...)\r\n\t\t\t\t\tif LogRemote(self :: InstancesToHook, Method, value, nil, ...) then\r\n\t\t\t\t\t\treturn\r\n\t\t\t\t\tend\r\n\r\n\t\t\t\t\treturn value(...)\r\n\t\t\t\tend)\r\n\t\t\tend\r\n\t\tend\r\n\r\n\t\treturn wax.shared.NewIndexHook(...)\r\n\tend)\r\n)\r\n\r\nlocal ConnectionKeys = {\r\n\t\"Connect\",\r\n\t\"ConnectParallel\",\r\n\t\"connect\",\r\n\t\"connectParallel\",\r\n\t\"once\",\r\n\t\"Once\",\r\n}\r\n\r\nlocal SignalMetatable = wax.shared.getrawmetatable(Instance.new(\"Part\").Touched)\r\nwax.shared.Hooks[SignalMetatable.__index] = wax.shared.Hooking.HookFunction(SignalMetatable.__index, function(...)\r\n\tlocal self, key = ...\r\n\r\n\tif table.find(ConnectionKeys, key) then\r\n\t\tlocal Instance = SignalMapping[self]\r\n\t\tlocal Connect = wax.shared.Hooks[SignalMetatable.__index](...)\r\n\r\n\t\tif not Instance then\r\n\t\t\treturn Connect\r\n\t\tend\r\n\r\n\t\tlocal Method = ClassesToHook[Instance.ClassName]\r\n\t\twax.shared.Hooks[Connect] = wax.shared.Hooking.HookFunction(\r\n\t\t\tConnect,\r\n\t\t\twax.shared.newcclosure(function(...)\r\n\t\t\t\tlocal _self, callback = ...\r\n\r\n\t\t\t\tlocal Result = table.pack(wax.shared.Hooks[Connect](...))\r\n\t\t\t\tlocal Log = wax.shared.Logs.Incoming[Instance]\r\n\r\n\t\t\t\tif Log and Log.Blocked then\r\n\t\t\t\t\tfor _, Connection in pairs(getconnections(Instance[Method])) do\r\n\t\t\t\t\t\tif not Connection.ForeignState and Connection.Function ~= callback then\r\n\t\t\t\t\t\t\tcontinue\r\n\t\t\t\t\t\tend\r\n\r\n\t\t\t\t\t\tConnection:Disable()\r\n\t\t\t\t\tend\r\n\t\t\t\tend\r\n\r\n\t\t\t\treturn table.unpack(Result, 1, Result.n)\r\n\t\t\tend)\r\n\t\t)\r\n\r\n\t\treturn Connect\r\n\tend\r\n\r\n\treturn wax.shared.Hooks[SignalMetatable.__index](...)\r\nend)\r\n"
                                        }
                                    }
                                }
                            },
                            {
                                12,
                                1,
                                {
                                    "Default"
                                },
                                {
                                    {
                                        14,
                                        2,
                                        {
                                            "Outgoing"
                                        }
                                    },
                                    {
                                        13,
                                        2,
                                        {
                                            "Incoming"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    {
                        15,
                        2,
                        {
                            "Init"
                        }
                    }
                }
            },
            {
                3,
                2,
                {
                    "ExecutorSupport"
                }
            }
        }
    }
}

-- Line offsets for debugging (only included when minifyTables is false)
local LineOffsets = {
    8,
    345,
    408,
    731,
    [13] = 850,
    [14] = 1123,
    [15] = 1331,
    [17] = 1450,
    [18] = 1553,
    [19] = 2109,
    [20] = 2128,
    [21] = 2191,
    [22] = 2353,
    [23] = 2608,
    [24] = 2672,
    [25] = 2715,
    [26] = 2781,
    [27] = 2897,
    [28] = 2997,
    [29] = 3176,
    [30] = 3467,
    [32] = 3499,
    [33] = 4544,
    [34] = 4882
}

-- Misc AOT variable imports
local WaxVersion = "0.4.1"
local EnvName = "Cobalt"

-- ++++++++ RUNTIME IMPL BELOW ++++++++ --

-- Localizing certain libraries and built-ins for runtime efficiency
local string, task, setmetatable, error, next, table, unpack, coroutine, script, type, require, pcall, tostring, tonumber, _VERSION =
      string, task, setmetatable, error, next, table, unpack, coroutine, script, type, require, pcall, tostring, tonumber, _VERSION

local table_insert = table.insert
local table_remove = table.remove
local table_freeze = table.freeze or function(t) return t end -- lol

local coroutine_wrap = coroutine.wrap

local string_sub = string.sub
local string_match = string.match
local string_gmatch = string.gmatch

-- The Lune runtime has its own `task` impl, but it must be imported by its builtin
-- module path, "@lune/task"
if _VERSION and string_sub(_VERSION, 1, 4) == "Lune" then
    local RequireSuccess, LuneTaskLib = pcall(require, "@lune/task")
    if RequireSuccess and LuneTaskLib then
        task = LuneTaskLib
    end
end

local task_defer = task and task.defer

-- If we're not running on the Roblox engine, we won't have a `task` global
local Defer = task_defer or function(f, ...)
    coroutine_wrap(f)(...)
end

-- ClassName "IDs"
local ClassNameIdBindings = {
    [1] = "Folder",
    [2] = "ModuleScript",
    [3] = "Script",
    [4] = "LocalScript",
    [5] = "StringValue",
}

local RefBindings = {} -- [RefId] = RealObject

local ScriptClosures = {}
local ScriptClosureRefIds = {} -- [ScriptClosure] = RefId
local StoredModuleValues = {}
local ScriptsToRun = {}

-- wax.shared __index/__newindex
local SharedEnvironment = {}

-- We're creating 'fake' instance refs soley for traversal of the DOM for require() compatibility
-- It's meant to be as lazy as possible
local RefChildren = {} -- [Ref] = {ChildrenRef, ...}

-- Implemented instance methods
local InstanceMethods = {
    GetFullName = { {}, function(self)
        local Path = self.Name
        local ObjectPointer = self.Parent

        while ObjectPointer do
            Path = ObjectPointer.Name .. "." .. Path

            -- Move up the DOM (parent will be nil at the end, and this while loop will stop)
            ObjectPointer = ObjectPointer.Parent
        end

        return Path
    end},

    GetChildren = { {}, function(self)
        local ReturnArray = {}

        for Child in next, RefChildren[self] do
            table_insert(ReturnArray, Child)
        end

        return ReturnArray
    end},

    GetDescendants = { {}, function(self)
        local ReturnArray = {}

        for Child in next, RefChildren[self] do
            table_insert(ReturnArray, Child)

            for _, Descendant in next, Child:GetDescendants() do
                table_insert(ReturnArray, Descendant)
            end
        end

        return ReturnArray
    end},

    FindFirstChild = { {"string", "boolean?"}, function(self, name, recursive)
        local Children = RefChildren[self]

        for Child in next, Children do
            if Child.Name == name then
                return Child
            end
        end

        if recursive then
            for Child in next, Children do
                -- Yeah, Roblox follows this behavior- instead of searching the entire base of a
                -- ref first, the engine uses a direct recursive call
                return Child:FindFirstChild(name, true)
            end
        end
    end},

    FindFirstAncestor = { {"string"}, function(self, name)
        local RefPointer = self.Parent
        while RefPointer do
            if RefPointer.Name == name then
                return RefPointer
            end

            RefPointer = RefPointer.Parent
        end
    end},

    -- Just to implement for traversal usage
    WaitForChild = { {"string", "number?"}, function(self, name)
        return self:FindFirstChild(name)
    end},
}

-- "Proxies" to instance methods, with err checks etc
local InstanceMethodProxies = {}
for MethodName, MethodObject in next, InstanceMethods do
    local Types = MethodObject[1]
    local Method = MethodObject[2]

    local EvaluatedTypeInfo = {}
    for ArgIndex, TypeInfo in next, Types do
        local ExpectedType, IsOptional = string_match(TypeInfo, "^([^%?]+)(%??)")
        EvaluatedTypeInfo[ArgIndex] = {ExpectedType, IsOptional}
    end

    InstanceMethodProxies[MethodName] = function(self, ...)
        if not RefChildren[self] then
            error("Expected ':' not '.' calling member function " .. MethodName, 2)
        end

        local Args = {...}
        for ArgIndex, TypeInfo in next, EvaluatedTypeInfo do
            local RealArg = Args[ArgIndex]
            local RealArgType = type(RealArg)
            local ExpectedType, IsOptional = TypeInfo[1], TypeInfo[2]

            if RealArg == nil and not IsOptional then
                error("Argument " .. RealArg .. " missing or nil", 3)
            end

            if ExpectedType ~= "any" and RealArgType ~= ExpectedType and not (RealArgType == "nil" and IsOptional) then
                error("Argument " .. ArgIndex .. " expects type \"" .. ExpectedType .. "\", got \"" .. RealArgType .. "\"", 2)
            end
        end

        return Method(self, ...)
    end
end

local function CreateRef(className, name, parent)
    -- `name` and `parent` can also be set later by the init script if they're absent

    -- Extras
    local StringValue_Value

    -- Will be set to RefChildren later aswell
    local Children = setmetatable({}, {__mode = "k"})

    -- Err funcs
    local function InvalidMember(member)
        error(member .. " is not a valid (virtual) member of " .. className .. " \"" .. name .. "\"", 3)
    end
    local function ReadOnlyProperty(property)
        error("Unable to assign (virtual) property " .. property .. ". Property is read only", 3)
    end

    local Ref = {}
    local RefMetatable = {}

    RefMetatable.__metatable = false

    RefMetatable.__index = function(_, index)
        if index == "ClassName" then -- First check "properties"
            return className
        elseif index == "Name" then
            return name
        elseif index == "Parent" then
            return parent
        elseif className == "StringValue" and index == "Value" then
            -- Supporting StringValue.Value for Rojo .txt file conv
            return StringValue_Value
        else -- Lastly, check "methods"
            local InstanceMethod = InstanceMethodProxies[index]

            if InstanceMethod then
                return InstanceMethod
            end
        end

        -- Next we'll look thru child refs
        for Child in next, Children do
            if Child.Name == index then
                return Child
            end
        end

        -- At this point, no member was found; this is the same err format as Roblox
        InvalidMember(index)
    end

    RefMetatable.__newindex = function(_, index, value)
        -- __newindex is only for props fyi
        if index == "ClassName" then
            ReadOnlyProperty(index)
        elseif index == "Name" then
            name = value
        elseif index == "Parent" then
            -- We'll just ignore the process if it's trying to set itself
            if value == Ref then
                return
            end

            if parent ~= nil then
                -- Remove this ref from the CURRENT parent
                RefChildren[parent][Ref] = nil
            end

            parent = value

            if value ~= nil then
                -- And NOW we're setting the new parent
                RefChildren[value][Ref] = true
            end
        elseif className == "StringValue" and index == "Value" then
            -- Supporting StringValue.Value for Rojo .txt file conv
            StringValue_Value = value
        else
            -- Same err as __index when no member is found
            InvalidMember(index)
        end
    end

    RefMetatable.__tostring = function()
        return name
    end

    setmetatable(Ref, RefMetatable)

    RefChildren[Ref] = Children

    if parent ~= nil then
        RefChildren[parent][Ref] = true
    end

    return Ref
end

-- Create real ref DOM from object tree
local function CreateRefFromObject(object, parent)
    local RefId = object[1]
    local ClassNameId = object[2]
    local Properties = object[3] -- Optional
    local Children = object[4] -- Optional

    local ClassName = ClassNameIdBindings[ClassNameId]

    local Name = Properties and table_remove(Properties, 1) or ClassName

    local Ref = CreateRef(ClassName, Name, parent) -- 3rd arg may be nil if this is from root
    RefBindings[RefId] = Ref

    if Properties then
        for PropertyName, PropertyValue in next, Properties do
            Ref[PropertyName] = PropertyValue
        end
    end

    if Children then
        for _, ChildObject in next, Children do
            CreateRefFromObject(ChildObject, Ref)
        end
    end

    return Ref
end

local RealObjectRoot = CreateRef("Folder", "[" .. EnvName .. "]")
for _, Object in next, ObjectTree do
    CreateRefFromObject(Object, RealObjectRoot)
end

-- Now we'll set script closure refs and check if they should be ran as a BaseScript
for RefId, Closure in next, ClosureBindings do
    local Ref = RefBindings[RefId]

    ScriptClosures[Ref] = Closure
    ScriptClosureRefIds[Ref] = RefId

    local ClassName = Ref.ClassName
    if ClassName == "LocalScript" or ClassName == "Script" then
        table_insert(ScriptsToRun, Ref)
    end
end

local function LoadScript(scriptRef)
    local ScriptClassName = scriptRef.ClassName

    -- First we'll check for a cached module value (packed into a tbl)
    local StoredModuleValue = StoredModuleValues[scriptRef]
    if StoredModuleValue and ScriptClassName == "ModuleScript" then
        return unpack(StoredModuleValue)
    end

    local Closure = ScriptClosures[scriptRef]

    local function FormatError(originalErrorMessage)
        originalErrorMessage = tostring(originalErrorMessage)

        local VirtualFullName = scriptRef:GetFullName()

        -- Check for vanilla/Roblox format
        local OriginalErrorLine, BaseErrorMessage = string_match(originalErrorMessage, "[^:]+:(%d+): (.+)")

        if not OriginalErrorLine or not LineOffsets then
            return VirtualFullName .. ":*: " .. (BaseErrorMessage or originalErrorMessage)
        end

        OriginalErrorLine = tonumber(OriginalErrorLine)

        local RefId = ScriptClosureRefIds[scriptRef]
        local LineOffset = LineOffsets[RefId]

        local RealErrorLine = OriginalErrorLine - LineOffset + 1
        if RealErrorLine < 0 then
            RealErrorLine = "?"
        end

        return VirtualFullName .. ":" .. RealErrorLine .. ": " .. BaseErrorMessage
    end

    -- If it's a BaseScript, we'll just run it directly!
    if ScriptClassName == "LocalScript" or ScriptClassName == "Script" then
        local RunSuccess, ErrorMessage = xpcall(Closure, function(msg)
            return msg
        end)
        if not RunSuccess then
            error(FormatError(ErrorMessage), 0)
        end
    else
        local PCallReturn = {xpcall(Closure, function(msg)
            return msg
        end)}

        local RunSuccess = table_remove(PCallReturn, 1)
        if not RunSuccess then
            local ErrorMessage = table_remove(PCallReturn, 1)
            error(FormatError(ErrorMessage), 0)
        end

        StoredModuleValues[scriptRef] = PCallReturn
        return unpack(PCallReturn)
    end
end

-- We'll assign the actual func from the top of this output for flattening user globals at runtime
-- Returns (in a tuple order): wax, script, require
function ImportGlobals(refId)
    local ScriptRef = RefBindings[refId]

    local function RealCall(f, ...)
        local PCallReturn = {xpcall(f, function(msg)
            return debug.traceback(msg, 2)
        end, ...)}

        local CallSuccess = table_remove(PCallReturn, 1)
        if not CallSuccess then
            error(PCallReturn[1], 3)
        end

        return unpack(PCallReturn)
    end

    -- `wax.shared` index
    local WaxShared = table_freeze(setmetatable({}, {
        __index = SharedEnvironment,
        __newindex = function(_, index, value)
            SharedEnvironment[index] = value
        end,
        __len = function()
            return #SharedEnvironment
        end,
        __iter = function()
            return next, SharedEnvironment
        end,
    }))

    local Global_wax = table_freeze({
        -- From AOT variable imports
        version = WaxVersion,
        envname = EnvName,

        shared = WaxShared,

        -- "Real" globals instead of the env set ones
        script = script,
        require = require,
    })

    local Global_script = ScriptRef

    local function Global_require(module, ...)
        local ModuleArgType = type(module)

        local ErrorNonModuleScript = "Attempted to call require with a non-ModuleScript"
        local ErrorSelfRequire = "Attempted to call require with self"

        if ModuleArgType == "table" and RefChildren[module]  then
            if module.ClassName ~= "ModuleScript" then
                error(ErrorNonModuleScript, 2)
            elseif module == ScriptRef then
                error(ErrorSelfRequire, 2)
            end

            return LoadScript(module)
        elseif ModuleArgType == "string" and string_sub(module, 1, 1) ~= "@" then
            -- The control flow on this SUCKS

            if #module == 0 then
                error("Attempted to call require with empty string", 2)
            end

            local CurrentRefPointer = ScriptRef

            if string_sub(module, 1, 1) == "/" then
                CurrentRefPointer = RealObjectRoot
            elseif string_sub(module, 1, 2) == "./" then
                module = string_sub(module, 3)
            end

            local PreviousPathMatch
            for PathMatch in string_gmatch(module, "([^/]*)/?") do
                local RealIndex = PathMatch
                if PathMatch == ".." then
                    RealIndex = "Parent"
                end

                -- Don't advance dir if it's just another "/" either
                if RealIndex ~= "" then
                    local ResultRef = CurrentRefPointer:FindFirstChild(RealIndex)
                    if not ResultRef then
                        local CurrentRefParent = CurrentRefPointer.Parent
                        if CurrentRefParent then
                            ResultRef = CurrentRefParent:FindFirstChild(RealIndex)
                        end
                    end

                    if ResultRef then
                        CurrentRefPointer = ResultRef
                    elseif PathMatch ~= PreviousPathMatch and PathMatch ~= "init" and PathMatch ~= "init.server" and PathMatch ~= "init.client" then
                        error("Virtual script path \"" .. module .. "\" not found", 2)
                    end
                end

                -- For possible checks next cycle
                PreviousPathMatch = PathMatch
            end

            if CurrentRefPointer.ClassName ~= "ModuleScript" then
                error(ErrorNonModuleScript, 2)
            elseif CurrentRefPointer == ScriptRef then
                error(ErrorSelfRequire, 2)
            end

            return LoadScript(CurrentRefPointer)
        end

        return RealCall(require, module, ...)
    end

    -- Now, return flattened globals ready for direct runtime exec
    return Global_wax, Global_script, Global_require
end

for _, ScriptRef in next, ScriptsToRun do
    Defer(LoadScript, ScriptRef)
end
