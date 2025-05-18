--[[
    Bypasses for popular roblox anticheats
]]

wax.shared.AnticheatDisabled = false
wax.shared.AnticheatName = "N/A"

local BypassState = wax.shared.SaveManager:GetState("AnticheatBypass")
local ShouldntBypass = typeof(BypassState) == "boolean" and BypassState or false
if ShouldntBypass then
	return
end

local AdonisDetected = false

for _, thread in getreg() do
	if typeof(thread) ~= "thread" then
		continue
	end

	local Source = debug.info(thread, 1, "s")
	if Source == ".Core.Anti" or Source == ".Plugins.Anti_Cheat" then
		AdonisDetected = true
		break
	end
end

if AdonisDetected then
	for _, value in getgc(true) do
		if typeof(value) ~= "table" then
			continue
		end

		local DetectedFunction = rawget(value, "Detected")
		if typeof(DetectedFunction) == "function" and debug.info(DetectedFunction, "s") == ".Core.Anti" then
			wax.shared.Hooks[DetectedFunction] = wax.shared.Hooking.HookFunction(
				DetectedFunction,
				function(action, info, nocrash)
					return task.wait(9e9)
				end
			)

			wax.shared.AnticheatDisabled = true
			wax.shared.AnticheatName = "Adonis"
		end
	end
end
