local NamecallMethods = { "fireserver", "invokeserver", "fire", "invoke" }
local AllowedClassNames =
	{ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent", "BindableFunction" }

local Hooks = {}

-- metamethod hooks
Hooks["namecall"] = hookmetamethod(game, "__namecall", function(self, ...)
	local method = getnamecallmethod():lower()

	if table.find(NamecallMethods, method) and table.find(AllowedClassNames, self.ClassName) then
	end
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

	local Hook
	Hook = hookfunction(Function, function(self, ...) end)
end
