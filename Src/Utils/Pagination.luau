--[[

Pagination Module
made by deivid and turned into module by upio

]]

local Pagination = {}
Pagination.__index = Pagination

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

function Pagination:GetInfo()
	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)

	return {
		TotalItems = self.TotalItems,
		ItemsPerPage = self.ItemsPerPage,
		CurrentPage = self.CurrentPage,
		TotalPages = TotalPages,
	}
end

function Pagination:GetIndexRanges(Page: number?)
	Page = Page or self.CurrentPage

	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)
	if TotalPages == 0 then
		return 1, 0
	end
	assert(
		Page <= TotalPages,
		"Attempted to get invalid page out of range, got " .. Page .. " but max is " .. TotalPages
	)

	local Start = (((Page or self.CurrentPage) - 1) * self.ItemsPerPage) + 1
	local End = Start + (self.ItemsPerPage - 1)

	return Start, End
end

function Pagination:SetPage(Page: number)
	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)
	if TotalPages == 0 then
		self.CurrentPage = 1
		return
	end
	assert(Page <= TotalPages, "Attempted to set page out of range, got " .. Page .. " but max is " .. TotalPages)

	self.CurrentPage = Page
end

function Pagination:Update(TotalItems: number?, ItemsPerPage: number?)
	self.TotalItems = TotalItems or self.TotalItems
	self.ItemsPerPage = ItemsPerPage or self.ItemsPerPage
end

local function CreateArray(Start, End)
	local Array = {}
	for Number = Start, End do
		table.insert(Array, Number)
	end
	return Array
end
local function MergeTables(...)
	local Result = {}
	for _, Value in pairs({ ... }) do
		if typeof(Value) == "table" then
			for _, SubValue in pairs(Value) do
				table.insert(Result, SubValue)
			end
		else
			table.insert(Result, Value)
		end
	end
	return Result
end

function Pagination:GetVisualInfo(Page: number?)
	Page = Page or self.CurrentPage

	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)
	if TotalPages == 0 then
		return {}
	end

	assert(
		Page <= TotalPages,
		"Attempted to get invalid page out of range, got " .. Page .. " but max is " .. TotalPages
	)

	local MaxButtons = 5 + self.SiblingCount * 2
	if TotalPages <= MaxButtons then
		return CreateArray(1, TotalPages)
	end

	local LeftSibling = math.max(Page - self.SiblingCount, 1)
	local RightSibling = math.min(Page + self.SiblingCount, TotalPages)

	local FakeLeft = LeftSibling > 2
	local FakeRight = RightSibling < TotalPages - 1

	local TotalPageNumbers = math.min(2 * self.SiblingCount + 5, TotalPages)
	local ItemCount = TotalPageNumbers - 2

	if not FakeLeft and FakeRight then
		local LeftRange = CreateArray(1, ItemCount)
		return MergeTables(LeftRange, "ellipsis", TotalPages)
	elseif FakeLeft and not FakeRight then
		local RightRange = CreateArray(TotalPages - ItemCount + 1, TotalPages)
		return MergeTables(1, "ellipsis", RightRange)
	elseif FakeLeft and FakeRight then
		local MiddleRange = CreateArray(LeftSibling, RightSibling)
		return MergeTables(1, "ellipsis", MiddleRange, "ellipsis", TotalPages)
	end

	return CreateArray(1, TotalPages)
end

return Pagination
