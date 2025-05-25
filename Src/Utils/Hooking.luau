local Hooking = {
	IncludeInStackFunctions = {},
}

local UseAltHooks = wax.shared.SaveManager:GetState("UseAlternativeHooks")
local AlternativeEnabled = typeof(UseAltHooks) == "boolean" and UseAltHooks or false
wax.shared.AlternativeEnabled = AlternativeEnabled
wax.shared.CobaltLuaSetStackHidden = false

Hooking.SetStackHidden = sethiddenstack
	or setstackhidden
	or (function()
		if AlternativeEnabled then
			return function() end
		end

		wax.shared.CobaltLuaSetStackHidden = true

		local OldDebugTraceback, OldDebugInfo = debug.traceback, debug.info

		local function setstackhidden(functionOrLevel: ((...any) -> ...any) | number, hidden: boolean)
			local Success, CallingFunction = pcall(function()
				if typeof(functionOrLevel) == "number" then
					return OldDebugInfo(functionOrLevel + 2, "f")
				end

				return functionOrLevel
			end)

			assert(
				Success or not CallingFunction,
				`invalid argument #1 to 'setstackhidden' ({typeof(functionOrLevel) == "number" and "level out of range" or `function or number expected, got {typeof(
					functionOrLevel
				)}`})`
			)
			assert(
				typeof(hidden) == "boolean",
				"invalid argument #2 to 'setstackhidden' (boolean expected, got " .. typeof(hidden) .. ")"
			)

			Hooking.IncludeInStackFunctions[CallingFunction] = not hidden
		end

		if restorefunction then
			for _, callback in pairs({ OldDebugTraceback, OldDebugInfo }) do
				if not isfunctionhooked(callback) then
					continue
				end

				pcall(restorefunction, callback)
			end
		elseif shared.CobaltSetStackHiddenLuau then
			return setstackhidden
		end

		shared.CobaltSetStackHiddenLuau = true

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

		--[[
	
		getfenv hook breaks due to luraph integrity checks,
		setmetatable(getfenv(), { __index = getrenv() })) shows a __index chain error
		so for now ill just not hook getfenv

		OldFenv = hookfunction(getrenv().getfenv, function(...)
			if checkcaller() then
				return OldFenv(...)
			end

			local ToInspect: (...any) -> (...any) | number = ...

			local Success, ResultingEnv = pcall(function()
				if typeof(ToInspect) == "number" then
					return OldFenv(ToInspect + 3)
				end

				return OldFenv(ToInspect)
			end)

			if ToInspect == nil or ToInspect == 0 or not Success or typeof(ToInspect) == "function" then
				return setmetatable(ResultingEnv, {
					__index = getrenv()
				})
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
						Environement = setmetatable(ResultingEnv, {
							__index = getrenv()
						})
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
		end)]]

		return setstackhidden
	end)()

Hooking.HookFunction = function(Original, Replacement)
	Hooking.SetStackHidden(Original, false)
	return hookfunction(Original, Replacement)
end
Hooking.HookMetaMethod = function(object, method, hook)
	local Metatable = wax.shared.getrawmetatable(object)
	local originalMethod = rawget(Metatable, method)

	Hooking.SetStackHidden(originalMethod, false)

	if AlternativeEnabled then
		setreadonly(Metatable, false)
		rawset(Metatable, method, hook)
		setreadonly(Metatable, true)

		return originalMethod
	end

	return hookmetamethod(object, method, hook)
end

return Hooking
