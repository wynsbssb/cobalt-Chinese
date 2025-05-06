local Log = {}
Log.__index = Log

function IgnoreCondition(Instance)
	-- Ignores any default Roblox BindableEvents in PlayerModule
	if not Instance.IsDescendantOf(Instance, wax.shared.PlayerScripts) then
		return false
	end

	local PlayerModule = Instance.FindFirstAncestor(Instance, "PlayerModule")
	return PlayerModule and PlayerModule.Parent == wax.shared.PlayerScripts or false
end

function Log.new(Instance, Method, Index)
	return setmetatable({
		Instance = Instance,
		Method = Method,
		Index = Index,
		Calls = {},
		Ignored = IgnoreCondition(Instance),
		Blocked = false,
		Button = nil,
	}, Log)
end

function Log:Call(Info)
	local Data = {
		Arguments = Info[1],
		Time = Info[2],
		Origin = Info[3],
		Function = Info[4],
		Line = Info[5],
		IsExecutor = Info[6],
	}

	if Info[7] then
		Data.OriginalInvokeArgs = Info[7]
	end

	table.insert(self.Calls, Data)
end

function Log:Ignore()
	self.Ignored = not self.Ignored
end

function Log:Block()
	self.Blocked = not self.Blocked
end

function Log:SetButton(Instance, Name, Calls)
	self.Button = {
		Instance = Instance,
		Name = Name,
		Calls = Calls,
	}
end

return Log
