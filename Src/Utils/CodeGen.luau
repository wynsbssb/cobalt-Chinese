local CodeGen = {
	CleanTable = { ['"'] = '\\"', ["\\"] = "\\\\" },
}

local GetNilCode = [[local function GetNil(Name, DebugId)
	for _, Object in pairs(getnilinstances()) do
		if Object.Name == Name and Object:GetDebugId() == DebugId then
			return Object
		end
	end
end]]

--// Pasted from Dex (maximum detection)
for i = 0, 31 do
	CodeGen.CleanTable[string.char(i)] = "\\" .. string.format("%03d", i)
end
for i = 127, 255 do
	CodeGen.CleanTable[string.char(i)] = "\\" .. string.format("%03d", i)
end

function CodeGen.FormatLuaString(str)
	return string.gsub(str, '["\\\0-\31\127-\255]', CodeGen.CleanTable)
end

function CodeGen.GetFullPath(Object, ExcludeCode)
	local CurrentObject = Object
	local Path = ""

	repeat
		if CurrentObject == game then
			Path = "game" .. Path
			break
		end

		local IndexName = ""

		if CurrentObject == wax.shared.LocalPlayer then
			IndexName = ".LocalPlayer"
		elseif wax.shared.LocalPlayer.Character and CurrentObject == wax.shared.LocalPlayer.Character then
			IndexName = 'game:GetService("Players").LocalPlayer.Character'
		elseif CurrentObject.Name and CurrentObject.Name == wax.shared.LocalPlayer.Name then
			IndexName = '[game:GetService("Players").LocalPlayer.Name]'
		elseif CurrentObject.ClassName then
			if string.match(CurrentObject.Name, "^[%a_][%w_]*$") then
				IndexName = "." .. CurrentObject.Name
			else
				IndexName = '["' .. CodeGen.FormatLuaString(CurrentObject.Name) .. '"]'
			end

			local Parent = CurrentObject.Parent
			if Parent then
				if Parent == game and game.FindService(game, CurrentObject.ClassName) == CurrentObject then
					IndexName = ':GetService("' .. CurrentObject.ClassName .. '")'
				end
			elseif Parent == nil then
				if ExcludeCode then
					Path = Path .. " --[[Nil Parent]]"
				else	
					Path = GetNilCode .. `\n\nGetNil("{CurrentObject.Name}", "{CurrentObject:GetDebugId()}")`
					break
				end
			end
		end
		
		Path = IndexName .. Path
		if wax.shared.LocalPlayer.Character and CurrentObject == wax.shared.LocalPlayer.Character then
			break
		end

		CurrentObject = CurrentObject.Parent
	until CurrentObject == nil

	return Path
end

return CodeGen
