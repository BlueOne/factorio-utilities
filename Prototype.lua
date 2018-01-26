require("util")
local TableUtils = require("Utils.table")


local ProtUtils = {}


local function find(elem, list, cmp)
	if not cmp then
		if type(elem) == "table" then
			cmp = table.compare
		else
			for _, other in pairs(list) do
				if elem == other then
					return true
				end
			end
			return false
		end
	end

	for _, other in pairs(list) do
		if cmp(elem, other) then
			return other
		end
	end
	return false
end

function ProtUtils.assert_prototype(type, name)
	if not data.raw[type] then error("Prototype Type not found: " .. serpent.block(type) .. ", " .. debug.traceback()) end
	if not data.raw[type][name] then error("Prototype not found: " .. serpent.block(type) .. "." .. serpent.block(name) .. ", " .. debug.traceback()) end
end

if data then
	for type, _ in pairs(data.raw) do
		ProtUtils[type] = function(name)
			if type(name) == "table" then return name end
			ProtUtils.assert_prototype(type, name)
			return data.raw[type][name]
		end
	end
end

function ProtUtils.tech(name)
	if type(name) == "table" then return name end
	ProtUtils.assert_prototype("technology", name)
	return data.raw.technology[name]
end

function ProtUtils.set_tech(name, tech)
	data.raw.technology[name] = tech
end

function ProtUtils.rename_prereq(old_name, new_name)
	for name, tech in pairs(data.raw.technology) do
		local found = false
		if tech.prerequisites then
			local i = 1
			while i <= #tech.prerequisites do
				local prereq = tech.prerequisites[i]
				if prereq == old_name then
					if not found then
						found = true
						tech.prerequisites[i] = new_name
						i = i + 1
					else
						table.remove(tech.prerequisites, i)
					end
				elseif prereq == new_name then
					if found then
						table.remove(tech.prerequisites, i)
					else
						found = true
						i = i + 1
					end
				else
					i = i + 1
				end
			end
		end
	end
end



-- Merge technologies.
-- Removes old techs from data.raw, but won't add the new one, instead it is returned.
-- Better set cost manually if merged techs need different pack types.
function ProtUtils.merge_techs(techs, new_name)
	local old_names = {}
	for i, tech in pairs(techs) do
		if type(tech) == "table" then
			table.insert(old_names, tech.name)
		else
			techs[i] = ProtUtils.tech(tech)
			table.insert(old_names, techs[i].name)
		end
	end


	-- Prepare new tech
	local new_tech = table.deepcopy(techs[1])

	if not new_name then new_name = techs[1].name end
	new_tech.name = new_name


	-- Effect handling
	local function __eq(effect, other)
		for k, v in pairs(effect) do
			if k ~= "modifier" and other[k] ~= v then
				return false
			end
		end
		return true
	end

	if not new_tech.effects then new_tech.effects = {} end

	for i, tech in pairs(techs) do
		if i ~= 1 then
			-- Handle effects
			if tech.effects then
				for _, effect in pairs(tech.effects) do
					-- Recipe Unlock
					if effect.type == "unlock-recipe" then
						table.insert(new_tech.effects, table.deepcopy(effect))
					else
						local found = false
						for _, other in pairs(new_tech.effects) do
							if __eq(effect, other) then
								found = true
								other.modifier = other.modifier + effect.modifier
							end
						end
						if not found then
							table.insert(new_tech.effects, table.deepcopy(effect))
						end
					end
				end
			end
		end
	end

	-- Costs
	for i, tech in pairs(techs) do
		if i ~= 1 then
			if new_tech.unit.count then
				new_tech.unit.count = new_tech.unit.count + tech.unit.count
			else
				new_tech.unit.count_formula = new_tech.unit.count_formula .. "+" .. tech.unit.count_formula
			end
		end
	end


	-- Adjust prerequisites of other techs
	for _, old_name in pairs(old_names) do
		ProtUtils.rename_prereq(old_name, new_name)
	end

	-- Adjust prerequisites of this tech
	if new_tech.prerequisites then
		local i = 1
		while i <= #new_tech.prerequisites do
			local prereq = new_tech.prerequisites[i]
			if find(prereq, old_names) or prereq == new_name then
				table.remove(new_tech.prerequisites, i)
			else
				i = i + 1
			end
		end
	end

	-- Delete old techs
	for _, tech in pairs(techs) do
		data.raw.technology[tech.name] = nil
	end

	data:extend{new_tech}
	return new_tech
end


-- Make entity with recipe and item.
function ProtUtils.new_entity(new_name, old_name, type)
	ProtUtils.assert_prototype(type, old_name)
	local entity_prototype = TableUtils.merge{data.raw[type][old_name], {
			name = new_name,
			minable = {result = new_name},
		}
	}

	ProtUtils.assert_prototype("item", old_name)
	local item_prototype = TableUtils.merge{data.raw.item[old_name], {
			name = new_name,
			place_result = new_name
		}
	}

	ProtUtils.assert_prototype("recipe", old_name)
	local recipe_prototype = TableUtils.merge{data.raw.recipe[old_name], {
			name = new_name,
			result = new_name,
		}
	}

	return entity_prototype, item_prototype, recipe_prototype
end

-- Delete entity with recipe and item.
function ProtUtils.remove_entity(name, type)
	data.raw[type][name] = nil
	data.raw.recipe[name] = nil
	data.raw.item[name] = nil
end

-- Replaces an ingredient in all recipes with a different ingredient
function ProtUtils.replace_ingredient(name, new_name)
	for _, recipe in pairs(data.raw.recipe) do
		for _, set in pairs{recipe, recipe.normal, recipe.expensive} do
			if set and set.ingredients then
				for _, ing  in pairs(set.ingredients) do
					if ing[1] == name then
						ing[1] = new_name
					end
				end
			end
		end
	end
end



-- Split the technology in two equal techs.
function ProtUtils.duplicate_tech(tech, new_name)
	local name = tech.name
	local new_tech = TableUtils.merge({tech, 
		{
			name = new_name,
			order = tech.order .. new_name,
		}
	})

	for _, other_tech in pairs(data.raw.technology) do
		if other_tech.prerequisites then
			local found = false
			for _, prereq in pairs(other_tech.prerequisites) do
				if prereq == name then
					found = true
				end
			end

			if found then table.insert(other_tech.prerequisites, new_name) end
		end
	end

	return new_tech
end

-- Collapse the tech in the prereq graph i.e. make all its prerequisites become prerequisites of its successors instead.
function ProtUtils.remove_tech_prereq(tech)
	if type(tech) == "string" then
		tech = ProtUtils.tech(tech)
	end

	if not tech.prerequisites then return end

	for _, t in pairs(data.raw.technology) do
		if t.prerequisites and find(tech.name, t.prerequisites) then
			ProtUtils.del_prereq(t, tech.name)
			for _, p in pairs(tech.prerequisites) do 
				ProtUtils.add_prereq(t, p)
			end
		end
	end
end

function ProtUtils.multiply_effects(tech, factor)
	for _, effect in pairs(tech.effects) do
		if effect.modifier then
			effect.modifier = effect.modifier * factor
		end
	end
end


function ProtUtils.decode_ingredient_string(packs, factor)
	local ingredients = {}
	local pack_keys = {
		["1"] = "science-pack-1",
		["r"] = "science-pack-1",
		["2"] = "science-pack-2",
		["g"] = "science-pack-2",
		["3"] = "science-pack-3",
		["b"] = "science-pack-3",
		["4"] = "military-science-pack",
		["m"] = "military-science-pack",
		["5"] = "production-science-pack",
		["p"] = "production-science-pack",
		["6"] = "hightech-science-pack",
		["y"] = "hightech-science-pack",
		["7"] = "space-science-pack",
		["s"] = "space-science-pack",
	}

	for i = 1, #packs do
		local c = packs:sub(i, i)
		local found = false
		if pack_keys[c] then
			local added_pack = pack_keys[c]
			for _, pack in pairs(ingredients) do
				if pack[1] == added_pack then
					pack[2] = pack[2] + 1
					found = true
					break
				end
			end
			if not found then 
				table.insert(ingredients, {added_pack, factor or 1})
			end
		else
			error("Pack cost error. >" .. c .. "<. " .. debug.traceback())
		end
	end

	return ingredients
end


function ProtUtils.add_recipe_unlock(tech, recipe)
	tech = ProtUtils.tech(tech)
	TableUtils.insert(tech, "effects", {type="unlock-recipe", recipe=recipe})
end


function ProtUtils.del_recipe_unlock(tech, recipe)
	tech = ProtUtils.tech(tech)
	TableUtils.remove(tech, "effects", {type="unlock-recipe", recipe=recipe})
end


function ProtUtils.pack_unit(packs, count, time, factor)
	local ingredients = ProtUtils.decode_ingredient_string(packs, factor)

	return {
		count = count,
		ingredients = ingredients,
		time = time or 60
	}
end


function ProtUtils.add_prereq(tech, prereq)
	if type(tech) == "string" then
		tech = ProtUtils.tech(tech)
	end

	if not tech.prerequisites then tech.prerequisites = {} end
	table.insert(tech.prerequisites, prereq)
end


function ProtUtils.del_prereq(tech, prereq)
	if type(tech) == "string" then
		tech = ProtUtils.tech(tech)
	end
	if tech.prerequisites then
		local i = 1
		while i < #tech.prerequisites do
			local p = tech.prerequisites[i]
			if p == prereq then
				table.remove(tech.prerequisites, i)
			else
				i = i +1 
			end
		end
	end
end


function ProtUtils.tech_cost(ingredients)
	if type(ingredients) == "string" then
		ingredients = ProtUtils.decode_ingredient_string(ingredients)
	end
	local pack_costs = { -- Costs of science packs as (iron,copper ore) + (stone, coal, oil/10)
		["science-pack-1"] = 3,
		["science-pack-2"] = 7,
		["science-pack-3"] = 44+3,
		["military-science-pack"] = 35 + 5,
		["production-science-pack"] = 63 + 19,
		["high-tech-science-pack"] = 128 + 20,
		["space-science-pack"] = 187 + 42
	}

	local s = 0
	for _, ing in pairs(ingredients) do
		if not pack_costs[ing[1]] then error("Pack not found: " .. serpent.block(ing[1])) end
		s = s + pack_costs[ing[1]] * ing[2]
	end
	return s
end

function ProtUtils.set_tech_cost(tech, packs, count, time, factor)
	tech = ProtUtils.tech(tech)
	tech.unit = ProtUtils.pack_unit(packs, count, time, factor)
end

return ProtUtils