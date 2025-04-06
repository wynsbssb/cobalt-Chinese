local NamecallMethods = { "fireserver", "invokeserver", "fire", "invoke" }
local AllowedClassNames =
	{ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent", "BindableFunction" }

wax.shared.Hooks = {}
wax.shared.Ignored = {}
wax.shared.Blocked = {}

local function getcallingfunction()
	return debug.info(4, "f")
end
local function getcallingline()
	return debug.info(4, "l")
end

-- metamethod hooks
wax.shared.MetaHook = hookmetamethod(game, "__namecall", function(self, ...)
	local Method = getnamecallmethod()

	if table.find(AllowedClassNames, self.ClassName) and table.find(NamecallMethods, string.lower(Method)) then
		local Data = {
			self,
			Method,
			wax.shared.checkcaller(),
			getcallingscript(),
			getcallingfunction(),
			getcallingline(),
		}
		wax.shared.LogEvent(Data)
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
		local Line = getcallingline()
		print("What??", self.Name, Method, Line)

		return wax.shared.Hooks[Method](self, ...)
	end)
end
