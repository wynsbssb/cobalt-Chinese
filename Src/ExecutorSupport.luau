--[[
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
