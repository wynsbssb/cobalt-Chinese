local Hooking = {
	IgnoreStackFunctions = {},
}

local UseAltHooks = wax.shared.SaveManager:GetState("UseAlternativeHooks")
local AlternativeEnabled = typeof(UseAltHooks) == "boolean" and UseAltHooks or false
wax.shared.AlternativeEnabled = AlternativeEnabled

Hooking.HookFunction = function(Original, Replacement)
	Hooking.IgnoreStackFunctions[Original] = true
	return hookfunction(Original, Replacement)
end
Hooking.HookMetaMethod = function(object, method, hook)
	local Metatable = wax.shared.getrawmetatable(object)
	local originalMethod = rawget(Metatable, method)

	Hooking.IgnoreStackFunctions[originalMethod] = true

	if AlternativeEnabled then
		setreadonly(Metatable, false)
		rawset(Metatable, method, hook)
		setreadonly(Metatable, true)

		return originalMethod
	end

	return hookmetamethod(object, method, hook)
end

return Hooking
