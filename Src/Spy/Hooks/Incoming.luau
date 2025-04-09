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
end

wax.shared.Connect(game.DescendantAdded:Connect(HandleInstance))

for _, Instance in pairs(getinstances()) do
	HandleInstance(Instance)
end
