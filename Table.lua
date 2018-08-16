
local util = require("util")

local TableUtils = {}


TableUtils.compare = util.table.compare
TableUtils.deepcopy = util.table.deepcopy
TableUtils.copy = util.table.deepcopy
TableUtils.merge = util.merge

-- Finding

-- Example calls:
-- find(elem, list)
-- find(elem, list, equal_func)
-- find(list, identifier_func)
-- Returns key, value or false.

function TableUtils.find(arg1, arg2, arg3)
-- find(list, identifier_func)
	if type(arg1) == "table" and type(arg2) == "function" then
		for k, v in pairs(arg1) do
			if arg2(v) then
				return k, v
			end
		end
		return false
	end

	-- find(elem, list)
	if not arg3 then
		if type(arg1) == "table" then
			arg3 = TableUtils.compare
		else
			for k, other in pairs(arg2) do
				if arg1 == other then
					return k, other
				end
			end
			return false
		end
	end

	-- find(elem, list, equal_func)
	for k, other in pairs(arg2) do
		if arg3(arg1, other) then
			return k, other
		end
	end
	return false
end

function TableUtils.find_minimum(list, lessthan_func)
	if #list == 0 then return 0 end
	local index = 1
	local min_value = list[index]
	for i, value in ipairs(list) do
		if lessthan_func then
			if lessthan_func(value, min_value) then
				index = i
				min_value = value
			end
		else
			if value < min_value then
				index = i
				min_value = value
			end
		end
	end
	return index, min_value
end


-- Merging
function TableUtils.concat_lists(tables)
	local table1 = tables[1]
	for j, t in pairs(tables) do
		if j ~= 1 then
			for i = 1, #t do
				table1[#table1+i] = t[i]
			end
		end
	end
	return table1
end


function TableUtils.merge_inplace(tables)
	if not tables or not tables[1] then error("Bogus argument for table merge. " .. debug.traceback()) end
	local table1 = tables[1]
	for i, t in pairs(tables) do
		if i ~= 1 then
			for k, v in pairs(t) do
				if type(v) == "table" and (table1[k] or false) == "table" then
					table1[k] = TableUtils.merge_inplace_recursive{table1[k], v}
				else
					table1[k] = TableUtils.deepcopy(v)
				end
			end
		end
	end

	return table1
end


-- merge, no duplicates
function TableUtils.set_merge(tables)
	local table1 = tables[1]
	for j, t in pairs(tables) do
		if j ~= 1 then
			for i = 1, #t do
				local elem = t[i]
				if not TableUtils.find(elem, table1) then
					table.insert(table1, elem)
				end
			end
		end
	end
end


function TableUtils.keys(t)
	local keys = {}
	for k, _ in pairs(t) do
		keys[#keys + 1] = k
	end
	return keys
end


-- Common Type Checks
function TableUtils.is_position(arg)
	if not type(arg) == "table" then return false end
	local x = false
	local y = false
	for k, v in pairs(arg) do
		if (k == 1 or k == "x") and type(v) == "number" then x = true
		elseif (k == 2 or k == "y") and type(v) == "number" then y = true
		else return false end
	end
	return x and y
end


function TableUtils.is_rect(arg)
	if not type(arg) == "table" then return false end
	local l_t = false
	local r_b = false
	for k, v in pairs(arg) do
		if (k == 1 or k == "left_top") and TableUtils.is_position(v) then l_t = true
		elseif (k == 2 or k == "right_top") and TableUtils.is_position(v) then r_b = true
		else return false
		end
	end
	return l_t and r_b
end


-- Leftover from tas-mod
-- function Utils.is_entity_position(arg)
-- 	if not type(arg) == "table" then return false end
-- 	local x = false
-- 	local y = false
-- 	for k, v in pairs(arg) do
-- 		if (k == 1 or k == "x") and type(v) == "number" then x = true
-- 		elseif (k == 2 or k == "y") and type(v) == "number" then y = true
-- 		elseif not k == "entity" then return false
-- 		end
-- 	end
-- 	return x and y
-- end


-- Add or Remove
function TableUtils.insert(t, key, item)
	if t[key] then
		if not TableUtils.find(item, t[key]) then
			table.insert(t[key], item)
		end
	else
		t[key] = {item}
	end
end


function TableUtils.remove(t, key, item)
	if not t[key] or #t[key] < 1 then
		return
	else
		local found = false
		local i = 1
		while i < #t[key] do
			local u = t[key][i]
			if (u and (type(item) == "table") and TableUtils.compare(u, item)) or (u == item) then
				table.remove(t[key], i)
				found = true
			else
				i = i + 1
			end
		end
		return found
	end
end


function TableUtils.increment(t, k, v)
	if not t[k] then
		t[k] = v or 1
	else
		t[k] = t[k] + (v or 1)
	end
end

function TableUtils.decrement(t, k, v)
	if not t[k] then
		t[k] = -(v or 1)
	else
		t[k] = t[k] - (v or 1)
	end
end


return TableUtils