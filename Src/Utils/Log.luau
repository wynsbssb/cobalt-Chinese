local Log = {}
Log.__index = Log

function Log.new(Instance, Type, Method, Index, CallingScript)
	local NewLog = setmetatable({
		Instance = Instance,
		Type = Type,
		Method = Method,
		Index = Index,
		Calls = {},
		GameCalls = {},
		Ignored = false,
		Blocked = false,
		Button = nil,
	}, Log)

	return NewLog
end

function Log:Call(Info)
	local Index = #self.Calls + 1
	self.Calls[Index] = Info
	if not Info.IsExecutor then
		table.insert(self.GameCalls, Index)
	end
end

function Log:Ignore()
	if wax.shared.ActorCommunicator then
		wax.shared.ActorCommunicator:Fire("MainIgnore", self.Instance, self.Type)
	end

	self.Ignored = not self.Ignored
end

function Log:Block()
	if wax.shared.ActorCommunicator then
		wax.shared.ActorCommunicator:Fire("MainBlock", self.Instance, self.Type)
	end

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
