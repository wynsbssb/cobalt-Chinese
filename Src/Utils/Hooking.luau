local Hooking = {
	IncludeInStackFunctions = {},
}

local UseAltHooks = wax.shared.SaveManager:GetState("UseAlternativeHooks")
local AlternativeEnabled = typeof(UseAltHooks) == "boolean" and UseAltHooks or false
wax.shared.AlternativeEnabled = AlternativeEnabled
wax.shared.CobaltLuaSetStackHidden = false

Hooking.HookFunction = function(Original, Replacement)
	return hookfunction(Original, Replacement)
end
Hooking.HookMetaMethod = function(object, method, hook)
	local Metatable = wax.shared.getrawmetatable(object)
	local originalMethod = rawget(Metatable, method)

	if AlternativeEnabled then
		setreadonly(Metatable, false)
		rawset(Metatable, method, hook)
		setreadonly(Metatable, true)

		return originalMethod
	end

	return hookmetamethod(object, method, hook)
end

return Hooking
