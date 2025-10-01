--[[
分页模块
由 deivid 编写，并由 upio 转换为模块
]]

local Pagination = {}
Pagination.__index = Pagination

--[[
	创建一个新的分页对象。
	@param Options { 
		TotalItems: number,    -- 总项目数
		ItemsPerPage: number,  -- 每页显示的项目数
		CurrentPage: number?,  -- 当前页（可选，默认为 1）
		SiblingCount: number?, -- 当前页两侧的页码显示数量（可选，默认为 2）
	}
	@return Pagination 实例
]]
function Pagination.new(Options: {
	TotalItems: number,
	ItemsPerPage: number,
	CurrentPage: number?,
	SiblingCount: number?,
})
	return setmetatable({
		TotalItems = Options.TotalItems,
		ItemsPerPage = Options.ItemsPerPage,
		CurrentPage = Options.CurrentPage or 1,
		SiblingCount = Options.SiblingCount or 2,
	}, Pagination)
end

--[[
	获取分页的基本信息
	@return { 
		TotalItems,   -- 总项目数
		ItemsPerPage, -- 每页项目数
		CurrentPage,  -- 当前页
		TotalPages    -- 总页数
	}
]]
function Pagination:GetInfo()
	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)

	return {
		TotalItems = self.TotalItems,
		ItemsPerPage = self.ItemsPerPage,
		CurrentPage = self.CurrentPage,
		TotalPages = TotalPages,
	}
end

--[[
	获取某一页对应的项目索引范围（开始和结束）。
	@param Page number? 指定页码（可选，默认为当前页）
	@return Start, End
]]
function Pagination:GetIndexRanges(Page: number?)
	Page = Page or self.CurrentPage

	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)
	if TotalPages == 0 then
		return 1, 0
	end
	assert(
		Page <= TotalPages,
		"尝试获取超出范围的页码，传入 " .. Page .. " 但最大值为 " .. TotalPages
	)

	local Start = (((Page or self.CurrentPage) - 1) * self.ItemsPerPage) + 1
	local End = Start + (self.ItemsPerPage - 1)

	return Start, End
end

--[[
	设置当前页。
	@param Page number 页码
]]
function Pagination:SetPage(Page: number)
	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)
	if TotalPages == 0 then
		self.CurrentPage = 1
		return
	end
	assert(Page <= TotalPages, "尝试设置超出范围的页码，传入 " .. Page .. " 但最大值为 " .. TotalPages)

	self.CurrentPage = Page
end

--[[
	更新分页的总项目数或每页项目数。
	@param TotalItems number? 新的总项目数（可选）
	@param ItemsPerPage number? 新的每页项目数（可选）
]]
function Pagination:Update(TotalItems: number?, ItemsPerPage: number?)
	self.TotalItems = TotalItems or self.TotalItems
	self.ItemsPerPage = ItemsPerPage or self.ItemsPerPage
end

--[[
	获取用于展示的分页信息（包含省略号 "ellipsis"）
	@param Page number? 指定页码（可选，默认为当前页）
	@return table 一个包含页码与省略号的数组，例如：{1, "ellipsis", 5, 6, 7, "ellipsis", 20}
]]
function Pagination:GetVisualInfo(Page: number?)
	Page = Page or self.CurrentPage

	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)
	if TotalPages == 0 then
		return {}
	end

	assert(
		Page <= TotalPages,
		"尝试获取超出范围的页码，传入 " .. Page .. " 但最大值为 " .. TotalPages
	)

	local MaxButtons = 5 + self.SiblingCount * 2
	local Result = table.create(MaxButtons, "none")
	if TotalPages <= MaxButtons then
		for i = 1, TotalPages do
			Result[i] = i
		end
		return Result
	end

	local LeftSibling = math.max(Page - self.SiblingCount, 1)
	local RightSibling = math.min(Page + self.SiblingCount, TotalPages)

	local FakeLeft = LeftSibling > 2
	local FakeRight = RightSibling < TotalPages - 1

	local TotalPageNumbers = math.min(2 * self.SiblingCount + 5, TotalPages)
	local ItemCount = TotalPageNumbers - 2

	if not FakeLeft and FakeRight then
		for i = 1, ItemCount do
			Result[i] = i
		end
		Result[ItemCount + 1] = "ellipsis"
		Result[ItemCount + 2] = TotalPages
		return Result
	elseif FakeLeft and not FakeRight then
		Result[1] = 1
		Result[2] = "ellipsis"

		local Index = 3
		for i = TotalPages - ItemCount + 1, TotalPages do
			Result[Index] = i
			Index += 1
		end

		return Result
	elseif FakeLeft and FakeRight then
		Result[1] = 1
		Result[2] = "ellipsis"
		local Index = 3

		for i = LeftSibling, RightSibling do
			Result[Index] = i
			Index += 1
		end

		Result[Index] = "ellipsis"
		Result[Index + 1] = TotalPages

		return Result
	end

	for i = 1, TotalPages do
		Result[i] = i
	end
	return Result
end

return Pagination
