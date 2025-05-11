wax.shared.Hooks = {}

local Hooks = script.Parent.Hooks

-- Main Thread Hooks
for _, Hook in ipairs(Hooks.Default:GetChildren()) do
	task.spawn(require, Hook)
end

-- Actors use a different lua vm
-- This means that our main thread metatable hooks dont apply in the actor's vm
-- So we need to set up the hooks again in the actor lua vm in order to log everything
local TargetActor = getactors and getactors()[1] or nil
wax.shared.ActorsEnabled = (create_comm_channel and run_on_actor and TargetActor) ~= nil

if wax.shared.ActorsEnabled then
	local ActorsUtils = script.Parent.Actors
	local ActorEnvironementCode = ActorsUtils.Environement.Value

	ActorEnvironementCode = ActorEnvironementCode:gsub(
		"CobaltDynamicValue_IgnorePlayerModule",
		tostring(wax.shared.SavedSettings.IgnorePlayerModule or true)
	)

	ActorEnvironementCode = ActorEnvironementCode:gsub(
		"CobaltDynamicValue_IgnoredRemotesDropdown",
		wax.shared.LuaEncode(wax.shared.SavedSettings.IgnoredRemotesDropdown or {
			"BindableEvent",
			"BindableFunction",
		})
	)

	local CommunicationChannelID, Channel = create_comm_channel()
	local RawBindableEvent = Channel

	-- RawBindableEvent is a table in some executors
	if typeof(RawBindableEvent) == "table" then
		for _, v in pairs(RawBindableEvent) do
			if typeof(v) ~= "Instance" then
				continue
			end

			RawBindableEvent = v
			break
		end
	end

	wax.shared.ActorCommunicator = RawBindableEvent

	wax.shared.Connect(Channel.Event:Connect(function(EventType, ...)
		if EventType == "ActorCall" then
			local Instance, Type, Info = ...
			local Log = wax.shared.Logs[Type][Instance]

			if not Log then
				Log = wax.shared.NewLog(
					Instance,
					Type,
					wax.shared.FunctionForClasses[Type][Instance.ClassName],
					Info.Origin
				)
			end

			if Log.Blocked then
				return
			elseif not Log.Ignored then
				Log:Call(Info)
				wax.shared.Communicator:Fire(Log.Instance, Type, Info, #Log.Calls)
			end
		elseif EventType == "ActorIgnore" then
			local Instance, Type = ...
			local Log = wax.shared.Logs[Type][Instance]

			if Log then
				Log:Ignore(true)
			end
		elseif EventType == "ActorBlock" then
			local Instance, Type = ...
			local Log = wax.shared.Logs[Type][Instance]

			if Log then
				Log:Block(true)
			end
		end
	end))

	for _, ActorHook in ipairs(Hooks.Actors:GetChildren()) do
		run_on_actor(TargetActor, ActorEnvironementCode .. ActorHook.Value, CommunicationChannelID)
	end

	run_on_actor(TargetActor, ActorsUtils.Unload.Value, CommunicationChannelID)
end
