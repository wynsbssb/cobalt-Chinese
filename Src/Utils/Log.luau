local Log = {}
Log.__index = Log

function Log.new(Instance, Method, Index)
	return setmetatable({
		Instance = Instance,
		Method = Method,
		Index = Index,
		Calls = {},
		Ignored = false,
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
	}

	if Info[6] then
		Data.OriginalInvokeArgs = Info[6]
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
