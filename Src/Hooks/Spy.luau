local NamecallMethods = { "fireserver", "invokeserver", "fire", "invoke" }
local AllowedClassNames =
	{ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent", "BindableFunction" }

wax.shared.Hooks = {}

local function getcallingfunction()
	return debug.info(4, "f")
end
local function getcallingline()
	return debug.info(4, "l")
end

-- metamethod hooks
wax.shared.MetaHook = hookmetamethod(game, "__namecall", function(self, ...)
	local Method = getnamecallmethod()

	if
		table.find(AllowedClassNames, self.ClassName)
		and self ~= wax.shared.Communicator
		and table.find(NamecallMethods, string.lower(Method))
	then
		local Log = wax.shared.Logs[self]
		if not Log then
			Log = wax.shared.NewLog(self, Method)
		end

		if Log.Blocked then
			return
		elseif not Log.Ignored then
			Log:Call({
				getcallingscript(),
				getcallingfunction(),
				getcallingline(),
			})
			wax.shared.Communicator.Fire(wax.shared.Communicator, self)
		end
	end

	return wax.shared.MetaHook(self, ...)
end)

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

	wax.shared.Hooks[Function] = hookfunction(Function, function(self, ...)
		if self ~= wax.shared.Communicator then
			local Log = wax.shared.Logs[self]
			if not Log then
				Log = wax.shared.NewLog(self, Method)
			end

			if Log.Blocked then
				return
			elseif not Log.Ignored then
				Log:Call({
					getcallingscript(),
					getcallingfunction(),
					getcallingline(),
				})
				wax.shared.Communicator:Fire(self)
			end
		end

		return wax.shared.Hooks[Function](self, ...)
	end)
end
