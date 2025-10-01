-- Logger
-- ActualMasterOogway
-- 2024年12月8日

--[=[
    一个简单的日志工具，可以将消息写入文件。
    支持不同的日志等级，并可配置为覆盖或追加写入日志文件。

    日志格式:  
    2024-12-04T15:28:31.131Z,0.131060,MyThread,Warning [FLog::RobloxStarter] Roblox stage ReadyForFlagFetch completed
    <时间戳>,<运行耗时>,<线程ID>,<日志等级> <日志消息>
]=]

local Logger = {}
Logger.__index = Logger

-- 日志等级
Logger.LOG_LEVELS = {
	ERROR = 1,
	WARNING = 2,
	INFO = 3,
	DEBUG = 4,
}

-- 日志等级对应的字符串
local LOG_LEVEL_STRINGS = {
	[Logger.LOG_LEVELS.ERROR] = "ERROR",
	[Logger.LOG_LEVELS.WARNING] = "WARNING",
	[Logger.LOG_LEVELS.INFO] = "INFO",
	[Logger.LOG_LEVELS.DEBUG] = "DEBUG",
}

-- 程序启动时间，用于计算运行耗时
local startTime = tick()

-- 递归创建目录
local function createDirectoryRecursive(path)
	local currentPath = ""
	for part in path:gmatch("[^\\/]+") do
		currentPath = currentPath .. part
		if not isfolder(currentPath) then
			makefolder(currentPath)
		end
		currentPath = currentPath .. "/"
	end
end

--[=[
    生成一个唯一的日志文件名。  
    文件名基于当前 JobId，确保在每个服务器实例中唯一，
    但在同一服务器的多次执行中保持一致。

    @return string 唯一的日志文件名
]=]
function Logger:GenerateFileName()
	local JobIdNumber = game.JobId:gsub("%D", "")
	local timestamp = os.date("!%Y%m%d%H%M%S")

	return `{self.logFileDirectory}/{JobIdNumber * 1.7 // 1.8}_{timestamp}.log`
end

--[=[
    创建一个新的 Logger 实例。

    @param logFilePath string 日志文件路径
    @param logLevel number 最低记录日志的等级（默认为 INFO）
    @param overwrite boolean 是否覆盖已有日志文件（默认为 false，即追加写入）
    @return Logger 新的 Logger 实例
]=]
function Logger.new(logFilePath: string, logLevel: number?, overwrite: boolean?)
	local self = setmetatable({}, Logger)
	self.logFilePath = logFilePath
	self.logFileDirectory = logFilePath:match("(.+)/")
	self.logLevel = logLevel or Logger.LOG_LEVELS.INFO
	self.overwrite = overwrite or false

	local folderPath, fileName = logFilePath:match("(.*[\\/])(.*)")

	-- 确保日志目录存在
	if folderPath and not isfolder(folderPath) then
		createDirectoryRecursive(folderPath)
	end

	-- 如果是覆盖模式，先清空日志文件
	if self.overwrite then
		local success, err = pcall(writefile, self.logFilePath, "")
		if not success then
			warn(debug.traceback(`清空日志文件失败: {self.logFilePath} - {err}`, 2))
		end
	end

	self:Info("Logger", "日志系统已初始化")

	return self
end

--[=[
    写入日志消息到文件。

    @param level number 日志等级
    @param threadId string 线程或日志来源的 ID
    @param message string 要记录的消息
]=]
function Logger:Log(level: number, threadId: string, message: string)
	if level <= self.logLevel then
		local levelStr = LOG_LEVEL_STRINGS[level]

		local timestamp = `{os.date("!%Y-%m-%dT%H:%M:%S")}{("%.3f"):format(tick() % 1)}Z`
		local elapsedTime = ("%.6f"):format(tick() - startTime)

		local logMessage = `{timestamp},{elapsedTime},{threadId},{levelStr} {message}\n`

		local success, err = pcall(appendfile, self.logFilePath, logMessage)
		if not success then
			warn(debug.traceback(`写入日志文件失败: {self.logFilePath} - {err}`, 2))
		end
	end
end

--[=[
    写入 Debug 日志。

    @param threadId string 线程或日志来源 ID
    @param message string 消息内容
]=]
function Logger:Debug(threadId: string, message: string)
	self:Log(Logger.LOG_LEVELS.DEBUG, threadId, message)
end

--[=[
    写入 Info 日志。

    @param threadId string 线程或日志来源 ID
    @param message string 消息内容
]=]
function Logger:Info(threadId: string, message: string)
	self:Log(Logger.LOG_LEVELS.INFO, threadId, message)
end

--[=[
    写入 Warning 日志。

    @param threadId string 线程或日志来源 ID
    @param message string 消息内容
]=]
function Logger:Warning(threadId: string, message: string)
	self:Log(Logger.LOG_LEVELS.WARNING, threadId, message)
end

--[=[
    写入 Error 日志。

    @param threadId string 线程或日志来源 ID
    @param message string 消息内容
]=]
function Logger:Error(threadId: string, message: string)
	self:Log(Logger.LOG_LEVELS.ERROR, threadId, message)
end

return Logger
