local ClassesToHook = {
	RemoteEvent = "OnClientEvent",
	RemoteFunction = "OnClientInvoke",
	UnreliableRemoteEvent = "OnClientEvent",
	BindableEvent = "Event",
	BindableFunction = "OnInvoke",
}

local SignalMapping = {}

local function getcallingfunction()
	return debug.info(4, "f")
end
local function getcallingline()
	return debug.info(4, "l")
end

local function ListenToFunction(Instance, Function, Method)
	wax.shared.Hooks[Function] = hookfunction(
		Function,
		newcclosure(function(...)
			local Log = wax.shared.Logs.Incoming[Instance]
			if not Log then
				Log = wax.shared.NewLog(Instance, Method, "Incoming")
			end

			if Log.Blocked then
				return
			elseif not Log.Ignored then
				local Info = {
					{ ... },
					os.date("%X"),
					getcallingscript(),
					getcallingfunction(),
					getcallingline(),
				}
				Log:Call(Info)
				wax.shared.Communicator:Fire(Log.Instance, "Incoming", Info, #Log.Calls)
			end
			return wax.shared.Hooks[Function](...)
		end)
	)
end

local function HandleInstance(Instance: any)
	if not ClassesToHook[Instance.ClassName] or Instance == wax.shared.Communicator then
		return
	end

	local Method = ClassesToHook[Instance.ClassName]

	if Instance.ClassName == "RemoteEvent" or Instance.ClassName == "UnreliableRemoteEvent" then
		for _, Connection in pairs(getconnections(Instance.OnClientEvent)) do
			local Function = Connection.Function
			if not Function then
				continue
			end

			ListenToFunction(Instance, Function, Method)
		end

		SignalMapping[Instance.OnClientEvent] = Instance
	elseif Instance.ClassName == "BindableEvent" then
		for _, Connection in pairs(getconnections(Instance.Event)) do
			local Function = Connection.Function
			if not Function then
				continue
			end

			ListenToFunction(Instance, Function, Method)
		end

		SignalMapping[Instance.Event] = Instance
	elseif Instance.ClassName == "RemoteFunction" or Instance.ClassName == "BindableFunction" then
		local Success, Callback = pcall(getcallbackvalue, Instance, Method)
		if not Success or typeof(Callback) ~= "function" then
			return
		end

		ListenToFunction(Instance, Callback, Method)
	end
end

wax.shared.NewIndexHook = hookmetamethod(
	game,
	"__newindex",
	newcclosure(function(self, key, value)
		if not ClassesToHook[self.ClassName] then
			return wax.shared.NewIndexHook(self, key, value)
		end

		if self.ClassName == "RemoteFunction" or self.ClassName == "BindableFunction" then
			local Method = ClassesToHook[self.ClassName]

			if key == Method and typeof(value) == "function" then
				local Success, Callback = pcall(getcallbackvalue, self, Method)
				if Success and typeof(Callback) ~= "function" then
					wax.shared.restorefunction(Callback, true)
				end

				ListenToFunction(self, value, Method)
			end
		end

		return wax.shared.NewIndexHook(self, key, value)
	end)
)

wax.shared.Connect(game.DescendantAdded:Connect(HandleInstance))

for _, Instance in pairs(getinstances()) do
	HandleInstance(Instance)
end

local SignalMetatable = getrawmetatable(Instance.new("Part").Touched)
wax.shared.Hooks[SignalMetatable.__index] = hookfunction(SignalMetatable.__index, function(self, key)
	if key == "Connect" then
		local Instance = SignalMapping[self]
		local Connect = wax.shared.Hooks[SignalMetatable.__index](self, key)

		if not Instance then
			return Connect
		end

		local Method = ClassesToHook[Instance.ClassName]
		wax.shared.Hooks[Connect] = hookfunction(
			Connect,
			newcclosure(function(self, callback)
				ListenToFunction(Instance, callback, Method)
				return wax.shared.Hooks[Connect](self, callback)
			end)
		)

		return Connect
	end

	return wax.shared.Hooks[SignalMetatable.__index](self, key)
end)
