local AllowedClassNames =
	{ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent", "BindableFunction" }

local function getcallingfunction()
	return debug.info(4, "f")
end
local function getcallingline()
	return debug.info(4, "l")
end

local function HandleInstance(Instance: Instance)
	if not table.find(AllowedClassNames, Instance.ClassName) then
		return
	end

	local metatable = debug.getmetatable(Instance)
	if Instance.ClassName == "RemoteEvent" then
		wax.shared.Connect(Instance.OnClientEvent:Connect(function(...)
			-- do smthn i forgot
		end))

		-- we can hook debug.getmetatable(remoteevent.OnClientEvent) and check if it indexed/namecalled Connect to check for newer connections
		for _, Connection in pairs(getconnections(Instance.OnClientEvent)) do
			-- something
		end
	elseif Instance.ClassName == "RemoteFunction" then
		wax.shared.Connect(Instance.OnClientInvoke:Connect(function(...)
			-- do smthn i forgot
		end))

		-- we can hook debug.getmetatable(remotefunction.OnClientInvoke) and check if it indexed/namecalled Connect to check for newer connections
		for _, Connection in pairs(getconnections(Instance.OnClientInvoke)) do
			-- something
		end
	elseif Instance.ClassName == "BindableEvent" then
		wax.shared.Connect(Instance.Event:Connect(function(...)
			-- do smthn i forgot
		end))

		-- we can hook debug.getmetatable(bindableevent.Event) and check if it indexed/namecalled Connect to check for newer connections
		for _, Connection in pairs(getconnections(Instance.Event)) do
			-- something
		end
	elseif Instance.ClassName == "BindableFunction" then
		wax.shared.Hooks[Instance.OnInvoke] = hookfunction(Instance.OnInvoke, function(...)
			-- do smthn i forgot
		end)

		-- we can hook debug.getmetatable(bindablefunction.OnInvoke) and check for __newindex
		wax.shared.Hooks[metatable.__newindex] = hookfunction(metatable.__newindex, function(key, value)
			-- do smthn i forgot
			if key == "OnInvoke" and typeof(value) == "function" then
				wax.shared.Hooks[Instance.OnInvoke] = hookfunction(value, function(...)
					-- do smthn i forgot
				end)
			end

			return wax.shared.Hooks[metatable.__newindex](key, value)
		end)
	end
end

wax.shared.Connect(game.DescendantAdded:Connect(HandleInstance))

for _, Instance in pairs(getinstances()) do
	HandleInstance(Instance)
end
