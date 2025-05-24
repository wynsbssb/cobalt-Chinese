--[[
    Bypasses for popular roblox anticheats
]]

wax.shared.AnticheatDisabled = false
wax.shared.AnticheatName = "N/A"

local BypassState = wax.shared.SaveManager:GetState("AnticheatBypass")
local BypassEnabled = if typeof(BypassState) == "boolean" then BypassState else true
if not BypassEnabled then
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
			-- Just in case they already loaded a custom anticheat bypass for adonis
			if not isfunctionhooked(DetectedFunction) then
				wax.shared.Hooks[DetectedFunction] = wax.shared.Hooking.HookFunction(
					DetectedFunction,
					function(action, info, nocrash)
						return task.wait(9e9)
					end
				)
			end

			wax.shared.AnticheatDisabled = true
			wax.shared.AnticheatName = "Adonis"
		end
	end

	return
end

-- If no bypass is detected, we default to a generic bypass
if wax.shared.AlternativeEnabled or shared.CobaltDebugHooked then
	return
end

shared.CobaltDebugHooked = true

local OldDebugTraceback, OldDebugInfo, OldFenv = debug.traceback, debug.info, getfenv

local function ValidTraceback(s)
	local dotPos = string.find(s, "%.")
	local colonPos = string.find(s, ":")

	if not dotPos then
		return false
	end

	if not colonPos then
		return true
	end

	return dotPos < colonPos
end

local function TracebackLines(str)
	local pos = 1
	return function()
		if not pos then
			return nil
		end
		local p1, p2 = string.find(str, "\r?\n", pos)
		local line
		if p1 then
			line = str:sub(pos, p1 - 1)
			pos = p2 + 1
		else
			line = str:sub(pos)
			pos = nil
		end
		return line
	end
end

OldDebugTraceback = hookfunction(getrenv().debug.traceback, function()
	if checkcaller() then
		return OldDebugTraceback()
	end

	local Traceback = OldDebugTraceback()
	local NewTraceback = {}

	for Line in TracebackLines(Traceback) do
		if not ValidTraceback(Line) then
			continue
		end

		table.insert(NewTraceback, Line)
	end

	return table.concat(NewTraceback, "\n")
end)

OldDebugInfo = hookfunction(getrenv().debug.info, function(...)
	local ToInspect, LevelOrInfo, _ThreadInfo = ...

	if
		checkcaller()
		or typeof(ToInspect) == "function"
		or typeof(ToInspect) == "thread"
		or not pcall(function(LevelOrInfo) -- Validate arguments
			OldDebugInfo(function() end, LevelOrInfo)
		end, LevelOrInfo)
	then
		return OldDebugInfo(...)
	end

	local ReconstructedConstructedStack = {}
	for Level = 2, 19997 do
		local Function, Source, Line, Name, NumberOfArgs, Varargs = OldDebugInfo(Level, "fslna")

		if not Function or not Source or not Line or not Name then
			break
		end

		if isexecutorclosure(Function) and not wax.shared.Hooking.IncludeInStackFunctions[Function] then
			continue
		end

		table.insert(ReconstructedConstructedStack, {
			f = Function,
			s = Source,
			l = Line,
			n = Name,
			a = { NumberOfArgs, Varargs },
		})
	end

	local InfoLevel = ReconstructedConstructedStack[ToInspect]

	if not InfoLevel then
		-- Max level is 19997 so this guarantees that it will return nothing
		return OldDebugInfo(3e4, LevelOrInfo)
	end

	local ReturnResult = {}
	for idx, info in string.split(LevelOrInfo, "") do
		local Value = InfoLevel[info]

		if typeof(Value) == "table" then
			for _, v in Value do
				table.insert(ReturnResult, v)
			end

			continue
		end

		table.insert(ReturnResult, Value)
	end

	return table.unpack(ReturnResult, 1, #ReturnResult)
end)

OldFenv = hookfunction(getrenv().getfenv, function(...)
	if checkcaller() then
		return OldFenv(...)
	end

	local ToInspect: (...any) -> (...any) | number = ...

	if ToInspect == 0 then
		return getrenv()
	elseif ToInspect == nil then
		return OldFenv(...)
	end

	local Success, ResultingEnv = pcall(function()
		if typeof(ToInspect) == "number" then
			return OldFenv(ToInspect + 3)
		end

		return OldFenv(ToInspect)
	end)

	if not Success then
		return OldFenv(...)
	end

	if typeof(ToInspect) == "function" then
		if typeof(ResultingEnv["getgenv"]) == "function" and isexecutorclosure(ResultingEnv["getgenv"]) then
			return getrenv()
		end

		return ResultingEnv
	end

	local ReconstructedConstructedStack = {}
	for Level = 2, 19997 do
		local StackInfoSuccess, Data = pcall(function()
			return {
				Environement = OldFenv(Level + 3),
				Function = OldDebugInfo(Level + 3, "f"),
			}
		end)

		if not StackInfoSuccess or not Data then
			break
		end

		local Environement = Data.Environement
		local Function = Data.Function

		if typeof(Environement["getgenv"]) == "function" and isexecutorclosure(Environement["getgenv"]) then
			if wax.shared.Hooking.IncludeInStackFunctions[Function] then
				Environement = getrenv()
			else
				continue
			end
		end

		table.insert(ReconstructedConstructedStack, Environement)
	end

	local InfoLevel = ReconstructedConstructedStack[ToInspect]

	if not InfoLevel then
		-- Max level is 19997 so this guarantees that it will return error
		return OldFenv(3e4)
	end

	return InfoLevel
end)
