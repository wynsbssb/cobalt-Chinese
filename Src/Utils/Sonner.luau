--[[[
Sonner 的 Luau 移植版（由 upio 制作）
原版 Sonner 作者：Emil Kowalski (https://sonner.emilkowal.ski/)

TODO（几乎不会实现的功能）:
 - 添加一种方式查看历史通知（比如鼠标悬停时显示，但我懒得写）
 - 处理过多通知导致 UI 崩坏的问题
 - 修复通知定位不一致的问题
]]

local Sonner = {
	Queue = {}, -- 通知队列
	TweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential), -- 动画信息
	Wrapper = nil, -- UI 容器
}

--[[
	内部函数：创建一个通知对象
	@param zindex number 图层顺序
	@param image string? 图标（可以是 Roblox 资产 ID 或自定义 icon 名）
	@param text string 通知文本
	@return Frame 通知 UI 对象
]]
local function InternalCreateNotificationObject(zindex, image, text)
	local NotificationTemplate = wax.shared.Interface.New("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(0, 250, 0, 50),
		Position = UDim2.new(0.5, 0, 1, 50),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		ZIndex = zindex,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIStroke"] = {
			Color = Color3.fromRGB(39, 42, 42),
		},

		["UIScale"] = {},
	})

	local ImageLabel = wax.shared.Interface.New("ImageLabel", {
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.new(0, 20, 0, 20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ZIndex = zindex + 1,
		Parent = NotificationTemplate,
	})

	if image then
		if image:find("rbxasset") then
			ImageLabel.Image = image
		else
			wax.shared.Icons.SetIcon(ImageLabel, image)
		end
	else
		ImageLabel.Visible = false
	end

	-- 定义淡入淡出动画
	wax.shared.Animations.SetFadeExpectation("In", ImageLabel, {
		ImageTransparency = 0,
	})
	wax.shared.Animations.SetFadeExpectation("Out", ImageLabel, {
		ImageTransparency = 1,
	})

	local Frame = wax.shared.Interface.New("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(1, -50, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = zindex + 1,
		Parent = NotificationTemplate,
	})

	wax.shared.Animations.AddFadeExclusion(Frame)

	-- 文本标签
	wax.shared.Interface.New("TextLabel", {
		BorderSizePixel = 0,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 200, 0, 50),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		Text = text,
		ZIndex = zindex + 1,
		Parent = Frame,
		TextWrapped = true,
	})

	return NotificationTemplate
end

--[[
	显示一个通知
	@param image string? 图标（可选）
	@param text string 通知文本
	@param internalTime number? 显示时长（默认 4.5 秒）
	@param removeCallback function? 自定义移除逻辑（可选）
]]
local function toast(image, text, internalTime, removeCallback)
	assert(Sonner.Wrapper, "Sonner 未初始化")
	assert(typeof(image) == "string" or image == nil, "Image 必须是字符串或 nil")
	assert(typeof(text) == "string", "必须提供 Text")
	assert(typeof(internalTime) == "number" or internalTime == nil, "Time 必须是数字或 nil")

	local time = internalTime or 4.5

	local Notif = InternalCreateNotificationObject(500, image, text)

	Notif.Position = UDim2.new(0.5, 0, 1, 30)
	Notif.Parent = Sonner.Wrapper

	table.insert(Sonner.Queue, Notif)

	local ScaleMultiplier = 0.9
	local RemovalQueue = {}

	-- 调整已有通知的布局
	for index, object in Sonner.Queue do
		if object == Notif then
			continue
		end

		object.ZIndex = 500 - (#Sonner.Queue - index)

		-- 向下偏移并缩小
		wax.shared.TweenService
			:Create(object.UIScale, Sonner.TweenInfo, {
				Scale = object.UIScale.Scale * ScaleMultiplier,
			})
			:Play()

		wax.shared.TweenService
			:Create(object, Sonner.TweenInfo, {
				Position = object.Position - UDim2.fromOffset(0, object.AbsoluteSize.Y * 0.35),
			})
			:Play()

		-- 如果通知超过 3 个，就强制移除旧的
		if ((#Sonner.Queue - index) + 1) >= 4 then
			wax.shared.Animations.FadeOut(object)
			task.delay(0.5, function()
				object:Destroy()
			end)
			table.insert(RemovalQueue, object)
		end
	end

	-- 清理被移除的对象
	for _, obj in RemovalQueue do
		table.remove(Sonner.Queue, table.find(Sonner.Queue, obj))
	end

	-- 新通知弹出动画
	wax.shared.TweenService
		:Create(Notif, Sonner.TweenInfo, {
			Position = UDim2.new(0.5, 0, 1, -20),
		})
		:Play()
	wax.shared.Animations.FadeIn(Notif)

	-- 移除逻辑
	if removeCallback then
		task.spawn(removeCallback, Notif, time)
	else
		task.delay(time, function()
			if not table.find(Sonner.Queue, Notif) then
				return
			end
			table.remove(Sonner.Queue, table.find(Sonner.Queue, Notif))

			wax.shared.Animations.FadeOut(Notif, 0.35)
			wax.shared.TweenService
				:Create(Notif, Sonner.TweenInfo, {
					Position = UDim2.new(0.5, 0, 1, 50),
				})
				:Play()
			task.wait(0.5)
			Notif:Destroy()
		end)
	end
end

-- 预设类型的通知
function Sonner.info(text, internalTime)
	toast("info", text, internalTime)
end

function Sonner.success(text, internalTime)
	toast("circle-check", text, internalTime)
end

function Sonner.warning(text, internalTime)
	toast("triangle-alert", text, internalTime)
end

function Sonner.error(text, internalTime)
	toast("circle-alert", text, internalTime)
end

function Sonner.toast(text, internalTime)
	toast(nil, text, internalTime)
end

--[[
	显示带有异步结果的通知（类似 promise）
	@param func function 要执行的函数
	@param options { loadingText, successText, errorText, time }
]]
function Sonner.promise(func, options)
	local loadingText = options.loadingText or "Loading..."
	local successText = options.successText or "Success!"
	local errorText = options.errorText or "Error!"
	local internalTime = options.time or 4.5

	toast("loader-circle", loadingText, internalTime, function(notif, time)
		local success, resultOrError = nil, nil

		-- 旋转加载图标
		local spinnerThread = task.spawn(function()
			repeat
				wax.shared.RunService.RenderStepped:Wait()
				local icon = notif:FindFirstChild("ImageLabel")
				if not icon then
					continue
				end
				icon.Rotation = (icon.Rotation + 1) % 360
			until success == false or resultOrError ~= nil
		end)

		-- 执行异步函数
		success, resultOrError = pcall(func)

	   	task.spawn(function()
			setthreadidentity(8)

			-- 移除加载图标
			wax.shared.Animations.FadeOut(notif.ImageLabel, 0.15)
			wax.shared.TweenService
				:Create(notif.ImageLabel, TweenInfo.new(0.25, Enum.EasingStyle.Exponential), {
					Size = UDim2.new(0, 0, 0, 0),
				})
				:Play()
			task.wait(0.15)

			if coroutine.status(spinnerThread) ~= "dead" then
				coroutine.close(spinnerThread)
			end
			notif.ImageLabel.Rotation = 0

			-- 成功 / 失败消息
			if success then
				wax.shared.Icons.SetIcon(notif.ImageLabel, "check")
				local message = (
					typeof(successText) == "string" and successText
					or typeof(successText) == "function" and successText(resultOrError)
					or "Success!"
				)

				if message:match("%s") then
					notif.Frame.TextLabel.Text = string.format(message, tostring(resultOrError))
				else
					notif.Frame.TextLabel.Text = message
				end
			else
				wax.shared.Icons.SetIcon(notif.ImageLabel, "circle-alert")
				notif.Frame.TextLabel.Text = (
					typeof(errorText) == "string" and errorText
					or typeof(errorText) == "function" and errorText(resultOrError)
					or "Error!"
				)
			end

			-- 显示结果图标
			wax.shared.Animations.FadeIn(notif.ImageLabel)
			wax.shared.TweenService
				:Create(notif.ImageLabel, TweenInfo.new(0.25, Enum.EasingStyle.Exponential), {
					Size = UDim2.new(0, 20, 0, 20),
				})
				:Play()

			-- 延迟销毁
			task.delay(time, function()
				if not table.find(Sonner.Queue, notif) then
					return
				end
				table.remove(Sonner.Queue, table.find(Sonner.Queue, notif))

				wax.shared.Animations.FadeOut(notif, 0.35)
				wax.shared.TweenService
					:Create(notif, Sonner.TweenInfo, {
						Position = UDim2.new(0.5, 0, 1, 50),
					})
					:Play()

				task.wait(0.5)
				notif:Destroy()
			end)
		end)
	end)
end

--[[
	显示自定义通知
	@param options { image, text, time }
]]
function Sonner.rawtoast(options)
	local image = options.image
	local text = options.text or "No Text Provided"
	local internalTime = options.time or 4.5

	toast(image, text, internalTime)
end

-- 初始化，设置通知容器
function Sonner.init(wrapper)
	Sonner.Wrapper = wrapper
end

return Sonner
