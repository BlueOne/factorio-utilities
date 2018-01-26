

local TableUtils = {}



function TableUtils.find(elem, list, cmp)
	if not cmp then
		if type(elem) == "table" then
			cmp = table.compare
		else
			for k, other in pairs(list) do
				if elem == other then
					return k
				end
			end
			return false
		end
	end

	for k, other in pairs(list) do
		if cmp(elem, other) then
			return k, other
		end
	end
	return false
end


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
			local u = t[i]
			if (u and (type(item) == "table") and table.compare(u, item)) or (u == item) then
				table.remove(t[key], i)
				found = true
			else
				i = i + 1
			end
		end
		return found
	end
end


function TableUtils.merge(tables)
	local ret = {}
	for i, tab in ipairs(tables) do
		for k, v in pairs(tab) do
			if (type(v) == "table") and (type(ret[k] or false) == "table") then
				ret[k] = TableUtils.merge{ret[k], v}
			elseif type(v == "table") then
				ret[k] = table.deepcopy(v)
			else
				ret[k] = v
			end
		end
	end
	return ret
end
  

return TableUtils