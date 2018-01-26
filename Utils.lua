-- Utility functions

local Utils = {}


-- Tables
----------

-- This can obviously be done better but it works for now.
function Utils.tables_equal(t1, t2)
	return serpent.block(t1) == serpent.block(t2)
end

function Utils.table_keys(t)
	local keys = {}
	for k, _ in pairs(t) do
		keys[#keys + 1] = k
	end
	return keys
end

function Utils.is_position(arg)
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

function Utils.is_entity_position(arg)
	if not type(arg) == "table" then return false end
	local x = false 
	local y = false
	for k, v in pairs(arg) do
		if (k == 1 or k == "x") and type(v) == "number" then x = true
		elseif (k == 2 or k == "y") and type(v) == "number" then y = true
		elseif not k == "entity" then return false
		end
	end
	return x and y
end

function Utils.is_rect(arg)
	if not type(arg) == "table" then return false end
	local l_t = false
	local r_b = false
	for k, v in pairs(arg) do
		if (k == 1 or k == "left_top") and Utils.is_position(v) then l_t = true
		elseif (k == 2 or k == "right_top") and Utils.is_position(v) then r_b = true
		else return false
		end
	end
	return l_t and r_b
end


-- -- Taken from https://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value
-- function Utils.copy(obj, seen)
-- 	if type(obj) ~= 'table' then return obj end
-- 	if seen and seen[obj] then return seen[obj] end
-- 	local s = seen or {}
-- 	local res = setmetatable({}, getmetatable(obj))
-- 	s[obj] = res
-- 	for k, v in pairs(obj) do res[Utils.copy(k, s)] = Utils.copy(v, s) end
-- 	return res
-- end

-- Taken from lualib.util
function Utils.copy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        -- don't copy factorio rich objects
        elseif object.__self then
          return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

function Utils.compare_tables( tbl1, tbl2 )
    for k, v in pairs( tbl1 ) do
        if  type(v) == "table" and type(tbl2[k]) == "table" then
            if not table.compare( v, tbl2[k] )  then return false end
        else
            if ( v ~= tbl2[k] ) then return false end
        end
    end
    for k, v in pairs( tbl2 ) do
        if type(v) == "table" and type(tbl1[k]) == "table" then
            if not table.compare( v, tbl1[k] ) then return false end
        else 
            if v ~= tbl1[k] then return false end
        end
    end
    return true
end


function Utils.has_value(table, element)
	for _,v in pairs(table) do
		if v == element then
			return true
		end
	end
	return false
end

-- Yep, this is a duplicate.
function Utils.in_list(element, list)
	if not list then game.print(debug.traceback()) error("Nil argument to in_list!") end
	for _, v in pairs(list) do
		if v == element then
			return true
		end
	end
	return false
end

function Utils.default(v, w)
    if v == nil then return w end
    return v
end


-- list only
function Utils.get_minimum_index(list, lessthan_func)
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

function Utils.concat_lists(table1, table2)
	for i = 1, #table2 do
		table1[#table1+i] = table2[i]
	end
	return table1
end

function Utils.merge_tables_inplace(table1, table2)
	for k, v in pairs(table2) do
		table1[k] = v
	end
	return table1
end

function Utils.merge_tables(table1, table2)
	local t = Utils.copy(table1)
	for k, v in pairs(table2) do
		t[k] = Utils.copy(v)
	end
	return t
end



-- System 
----------

function Utils.is_module_available(name)
	if package.loaded[name] then
		return true
	else
		for _, searcher in ipairs(package.searchers or package.loaders) do
			local loader = searcher(name)
			if type(loader) == 'function' then
				return true
			end
		end
		return false
	end
end

return Utils
