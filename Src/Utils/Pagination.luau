--[[

Pagination Module
made by deivid and turned into module by upio

]]

local Pagination = {}

function Pagination.new(options: {
	ItemsPerPage: number,
	TotalItems: number,
	CurrentPage: number?,
	SiblingCount: number?,
	MaximumButtonCount: number?,
})
	return setmetatable({
		ItemsPerPage = options.ItemsPerPage,
		TotalItems = options.TotalItems,
		CurrentPage = options.CurrentPage or 1,
		SiblingCount = options.SiblingCount or 2,
		MaximumButtonCount = options.MaximumButtonCount or 5,
	}, { __index = Pagination })
end

function Pagination:Update(options: {
	ItemsPerPage: number?,
	TotalItems: number?,
})
	self.ItemsPerPage = options.ItemsPerPage or self.ItemsPerPage
	self.TotalItems = options.TotalItems or self.TotalItems
end

function Pagination:SetPage(page: number)
	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)
	assert(page <= TotalPages, "Atempted to set page out of range, got " .. page .. " but max is " .. TotalPages)

	self.CurrentPage = page
end

function Pagination:GetInfo()
	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)

	return {
		TotalPages = TotalPages,
		CurrentPage = self.CurrentPage,
		TotalItems = self.TotalItems,
		ItemsPerPage = self.ItemsPerPage,
	}
end

function Pagination:GetIndexRanges(pageArgument: number?)
	local page = pageArgument or self.CurrentPage

	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)
	assert(
		page <= TotalPages,
		"Atempted to get invalid page out of range, got " .. page .. " but max is " .. TotalPages
	)

	local Start = (((page or self.CurrentPage) - 1) * self.ItemsPerPage) + 1
	local End = Start + (self.ItemsPerPage - 1)

	return Start, End
end

local function CreateArray(first, final)
	local array = {}
	for i = first, final do
		table.insert(array, i)
	end
	return array
end

local function MergeTables(...)
	local result = {}
	for _, info in pairs({ ... }) do
		if typeof(info) == "table" then
			for _, subInfo in pairs(info) do
				table.insert(result, subInfo)
			end
		else
			table.insert(result, info)
		end
	end
	return result
end

function Pagination:GetPaginationVisualInfo(pageArgument: number?)
	local page = pageArgument or self.CurrentPage

	local TotalPages = math.ceil(self.TotalItems / self.ItemsPerPage)
	assert(
		page <= TotalPages,
		"Atempted to get invalid page out of range, got " .. page .. " but max is " .. TotalPages
	)

	local LeftSibling = math.max(page - self.SiblingCount, 1)
	local RightSibling = math.min(page + self.SiblingCount, TotalPages)

	local FakeLeft = LeftSibling > 1 + 1
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
