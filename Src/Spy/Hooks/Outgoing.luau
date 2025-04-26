local NamecallMethods = { "fireserver", "invokeserver", "fire", "invoke" }
local AllowedClassNames =
	{ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent", "BindableFunction" }

local function getcallingfunction()
	return debug.info(4, "f")
end
local function getcallingline()
	return debug.info(4, "l")
end

-- metamethod hooks
wax.shared.NamecallHook = hookmetamethod(
	game,
	"__namecall",
	wax.shared.newcclosure(function(self, ...)
		local Method = getnamecallmethod()

		if
			table.find(AllowedClassNames, self.ClassName)
			and self ~= wax.shared.Communicator
			and table.find(NamecallMethods, string.lower(Method))
		then
			local Log = wax.shared.Logs.Outgoing[self]
			if not Log then
				Log = wax.shared.NewLog(self, Method, "Outgoing")
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
				wax.shared.Communicator.Fire(wax.shared.Communicator, Log.Instance, "Outgoing", Info, #Log.Calls)
				
				-- For RemoteFunction return value (ex: local result = RemoteFunction:InvokeServer())
				if self.ClassName == "RemoteFunction" then
					local Result = { wax.shared.NamecallHook(self, ...) }
					local RFResultInfo = {
						Result,
						os.date("%X"),
						getcallingscript(),
						getcallingfunction(),
						getcallingline(),
					}

					Log:Call(RFResultInfo)
					wax.shared.Communicator.Fire(wax.shared.Communicator, Log.Instance, "Incoming", RFResultInfo, #Log.Calls)

					return table.unpack(Result)
				end
			end

		end

		return wax.shared.NamecallHook(self, ...)
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

	wax.shared.Hooks[Function] = hookfunction(
		Function,
		wax.shared.newcclosure(function(self, ...)
			if self ~= wax.shared.Communicator then
				local Log = wax.shared.Logs.Outgoing[self]
				if not Log then
					Log = wax.shared.NewLog(self, Method, "Outgoing")
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
					wax.shared.Communicator:Fire(Log.Instance, "Outgoing", Info, #Log.Calls)
				end
			end

			return wax.shared.Hooks[Function](self, ...)
		end)
	)
end
