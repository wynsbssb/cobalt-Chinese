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
	print("inserted call lol")

	table.insert(self.Calls, {
		Time = os.date("%X"),
		Origin = Info[1],
		Function = Info[2],
		Line = Info[3],
	})
end

function Log:Ignore()
	self.Ignored = not self.Ignored
end

function Log:Block()
	self.Blocked = not self.Blocked
end

return Log
