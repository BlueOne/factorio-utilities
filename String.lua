local Str = {}

local Maths = require("Maths")

-- String Processing
---------------------

function Str.namespace_prefix(name, command_group)
	if not name then
		return nil
	end

	if not string.find(name, "%.") then
		return command_group .. "." .. name
	else
		return name
	end
end


function Str.format_number(amount, append_suffix)
	local suffix = ""
	if append_suffix then
		local suffix_list =
		{
			["T"] = 1000000000000,
			["B"] = 1000000000,
			["M"] = 1000000,
			["k"] = 1000
		}
		for letter, limit in pairs (suffix_list) do
			if math.abs(amount) >= limit then
				amount = math.floor(amount/(limit/10))/10
				suffix = letter
				break
			end
		end
	end
	local formatted = amount
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if (k==0) then
			break
		end
	end
	return formatted..suffix
end


function Str.string_to_position(data)
	local _, _, x, y = string.find(data, "{(.*),(.*)}")
	return {tonumber(x), tonumber(y)}
end


local direction_ints = {N = 0, NE = 1, E = 2, SE = 3, S = 4, SW = 5, W = 6, NW = 7}
function Str.rotation_stringtoint(rot)
	if type(rot) == "int" then
		return rot
	else
		return direction_ints[rot]
	end
end

function Str.printable(v)
	if v == nil then return "nil"
	elseif v == true then return "true"
	elseif v == false then return "false"
	elseif type(v) == "number" then return Maths.roundn(v, 1)
	elseif type(v) == "function" then return "<function>"
	elseif type(v) == "table" then
		local pos_string = ", "
		local one = false
		local two = false
		if v.__self then return "<Factorio Data>" end
		for key, value in pairs(v) do
			if (key == 1 or key == "x") and type(value) == "number" then
				one = true
				pos_string = "{" .. Maths.roundn(value) .. pos_string
			elseif (key == 2 or key == "y") and type(value) == "number" then
				two = true
				pos_string = pos_string .. Maths.roundn(value) .. "}"
			else
				return "{…}"
			end
		end
		if one and two then
			return pos_string
		elseif not one and not two then
			return "{}"
		else
			return "{…}"
		end
	else
		return v
	end
end

return Str