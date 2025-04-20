local CodeGen = {
	CleanTable = { ['"'] = '\\"', ["\\"] = "\\\\" },
}

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

function CodeGen.GetFullPath(Object, ExcludeComment)
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
				Path = Path .. (ExcludeComment and "" or " --[[Nil Parent]]")
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
