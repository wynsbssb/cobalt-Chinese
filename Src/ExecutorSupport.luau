if run_on_actor and getactors then
	return
end

if not (getfflag and setfflag) then
	return
end

function CheckFlagValue(Name: string, Value: any)
	local Success, Result = pcall(getfflag, Name)
	if not Success then
		return false
	end

	if typeof(Result) == "boolean" then
		return Result
	end

	if typeof(Result) == "string" then
		return Result == tostring(Value)
	end

	return false
end

if CheckFlagValue("DebugRunParallelLuaOnMainThread", true) then
	return
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local GameUsesActors = false

for _, Category in { game:GetDescendants(), getnilinstances() } do
	if GameUsesActors then
		break
	end

	for _, Instance in Category do
		if not Instance:IsA("Actor") then
			continue
		end

		GameUsesActors = true
		break
	end
end

if GameUsesActors then
	local bindable = Instance.new("BindableFunction")

	function bindable.OnInvoke(response)
		if response == "Set FFlag" then
			setfflag("DebugRunParallelLuaOnMainThread", "true")
			wax.shared.StarterGui:SetCore("SendNotification", {
				Title = "Cobalt",
				Text = "Please rejoin for the FFlag to take effect!",
				Duration = math.huge,
			})
		end

		bindable:Destroy()
	end

	wax.shared.StarterGui:SetCore("SendNotification", {
		Title = "Cobalt",
		Text = "Detected the possible use of Actors but your exec does not support this. We can set a FFlag for you so after rejoining it detects actor remotes.",
		Duration = math.huge,
		Callback = bindable,
		Button1 = "Set FFlag",
		Button2 = "Dismiss",
	})
end
