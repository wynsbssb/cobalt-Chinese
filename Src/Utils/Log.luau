local Log = {}
Log.__index = Log

function Log.new(Instance, Method)
	return setmetatable({
		Instance = Instance,
		Method = Method,
		Calls = {},
		Ignored = false,
		Blocked = false,
		Button = nil,
	}, Log)
end

function Log:Call(Info)
	table.insert(self.Calls, {
		Arguments = Info[1],
		Time = Info[2],
		Origin = Info[3],
		Function = Info[4],
		Line = Info[5],
	})
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
