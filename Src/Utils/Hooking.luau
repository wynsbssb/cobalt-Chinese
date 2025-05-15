local Hooking = {}

local UseAltHooks = wax.shared.SaveManager:GetState("UseAlternativeHooks")
local AlternativeEnabled = typeof(UseAltHooks) == "boolean" and UseAltHooks or false
wax.shared.AlternativeEnabled = AlternativeEnabled

Hooking.HookFunction = hookfunction
Hooking.HookMetaMethod = function(object, method, hook)
	if AlternativeEnabled then
		local Metatable = wax.shared.getrawmetatable(object)
		local originalMethod = rawget(Metatable, method)

		setreadonly(Metatable, false)
		rawset(Metatable, method, wax.shared.newcclosure(hook))
		setreadonly(Metatable, true)

		return originalMethod
	end

	return hookmetamethod(object, method, hook)
end

return Hooking
