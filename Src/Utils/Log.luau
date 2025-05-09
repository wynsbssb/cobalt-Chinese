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

	local Index = #self.Calls + 1
	self.Calls[Index] = Data
	if not Data.IsExecutor then
		table.insert(self.GameCalls, Index)
	end
end

function Log:Ignore(FromActor: boolean?)
	if wax.shared.ActorCommunicator and not FromActor then
		wax.shared.ActorCommunicator:Fire("MainIgnore", self.Instance, self.Type)
	end

	self.Ignored = not self.Ignored
end

function Log:Block(FromActor: boolean?)
	if wax.shared.ActorCommunicator and not FromActor then
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
