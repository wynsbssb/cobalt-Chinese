local ClassesToHook = {
	RemoteEvent = "OnClientEvent",
	RemoteFunction = "OnClientInvoke",
	UnreliableRemoteEvent = "OnClientEvent",
	BindableEvent = "Event",
	BindableFunction = "OnInvoke",
}

local function getcallingfunction()
	return debug.info(4, "f")
end
local function getcallingline()
	return debug.info(4, "l")
end

local function HandleInstance(Instance: RemoteEvent | any)
	if not ClassesToHook[Instance.ClassName] then
		return
	end

	-- local metatable = debug.getmetatable(Instance)
	if Instance.ClassName == "RemoteEvent" then
		local Method = ClassesToHook[Instance.ClassName]

		for _, Connection in pairs(getconnections(Instance.OnClientEvent)) do
			local Function = Connection.Function

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
		--[[
	elseif Instance.ClassName == "RemoteFunction" then
		local Success, Callback = pcall(getcallbackvalue, Instance, "OnClientInvoke")
		if not Success then
			print("no callback", Instance:GetFullName())
			return
		end
		wax.shared.Hooks[Callback] = hookfunction(Callback, function(...)
			return wax.shared.Hooks[Callback](...)
		end)
	elseif Instance.ClassName == "BindableEvent" then
		for _, Connection in pairs(getconnections(Instance.Event)) do
			print("client got connection", Connection.Function)
		end
	elseif Instance.ClassName == "BindableFunction" then
		local Success, Callback = pcall(getcallbackvalue, Instance, "OnInvoke")
		if not Success then
			print("no callback", Instance:GetFullName())
			return
		end
		wax.shared.Hooks[Callback] = hookfunction(Callback, function(...)
			-- do smthn i forgot
			print("Hello world", ...)
			return wax.shared.Hooks[Callback](...)
		end)]]
	end
end

wax.shared.Connect(game.DescendantAdded:Connect(HandleInstance))

for _, Instance in pairs(getinstances()) do
	HandleInstance(Instance)
end
