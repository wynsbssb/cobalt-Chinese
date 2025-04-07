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
	print("call:", Info[1][1])

	table.insert(self.Calls, {
		Arguments = Info[1],
		Time = os.date("%X"),
		Origin = Info[2],
		Function = Info[3],
		Line = Info[4],
	})
end

function Log:Ignore()
	self.Ignored = not self.Ignored
end

function Log:Block()
	self.Blocked = not self.Blocked
end

return Log
