require("util")
local Table = require("Utils.Table")


local ProtUtils = {}


-- General

-- All of these happened ...
function ProtUtils.correct_item(s)
	local fix = {
		["gear-wheel"] = "iron-gear-wheel",
		["iron-gearwheel"] = "iron-gear-wheel",
		["machine-gun"] = "submachine-gun",
		ammo = "firearm-magazine",
		assembler = "assembling-machine-1",
		["assembling-machine"] = "assembling-machine-1",
		["mining-drill"] = "electric-mining-drill",
		["engine"] = "engine-unit",
		["electric-engine"] = "electric-engine-unit",
		["small-power-pole"] = "small-electric-pole",
		["medium-power-pole"] = "medium-electric-pole",
		["big-power-pole"] = "big-electric-pole",
		["lamp"] = "small-lamp",
		["portable-solar-panel"] = "solar-panel-equipment",
		["small-worm"] = "small-worm-turret",
		["medium-worm"] = "medium-worm-turret",
		["big-worm"] = "big-worm-turret"
	}
	return fix[s] or s
end

function ProtUtils.assert_prototype(type, name)
	if not data.raw[type] then error("Prototype Type not found: " .. serpent.block(type) .. ", " .. debug.traceback()) end
	if not data.raw[type][name] then error("Prototype not found: " .. serpent.block(type) .. "." .. serpent.block(name) .. ", " .. debug.traceback()) end
end

if data then
	for t, _ in pairs(data.raw) do
		ProtUtils[t] = function(name)
			if type(name) == "table" then return name end
			ProtUtils.assert_prototype(t, name)
			return data.raw[t][name]
		end
	end
end

function ProtUtils.tech(name)
	if type(name) == "table" then return name end
	ProtUtils.assert_prototype("technology", name)
	return data.raw.technology[name]
end


function ProtUtils.generic_recipe(name)
	return {
		type = "recipe",
		name = name,
		enabled = true,
		ingredients = {},
		result = name,
	}
end

function ProtUtils.generic_item(name, t)
	local item = {
		type = "item",
		name = name,
		icon = "alien-artifact-goo",
		icon_size = 32,
		flags = {"goes-to-main-inventory"},
		subgroup = "raw-material",
		order = "g",
		place_result = name,
		stack_size = 100
	}


	if t then
		for k, v in pairs(t) do
			item[k] = v
		end
	end

	return item
end

-- Make entity with recipe and item.
function ProtUtils.new_entity(new_name, old_name, type)
	ProtUtils.assert_prototype(type, old_name)
	local entity_prototype = Table.merge{data.raw[type][old_name], {
			name = new_name,
			minable = {result = new_name},
		}
	}

	ProtUtils.assert_prototype("item", old_name)
	local item_prototype = Table.merge{data.raw.item[old_name], {
			name = new_name,
			place_result = new_name
		}
	}

	local recipe_prototype = data.raw.recipe[old_name]
	if recipe_prototype then
		Table.merge{
			recipe_prototype,
			{
				name = new_name,
				result = new_name,
			}
		}
	else
		-- Generic Recipe
		recipe_prototype = ProtUtils.generic_recipe(new_name)
	end

	return entity_prototype, item_prototype, recipe_prototype
end

-- Delete entity with recipe and item.
function ProtUtils.remove_entity(name, type)
	data.raw[type][name] = nil
	data.raw.recipe[name] = nil
	data.raw.item[name] = nil
end




-- Technology
--------------

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
	local new_tech = Table.deepcopy(techs[1])

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
						table.insert(new_tech.effects, Table.deepcopy(effect))
					else
						local found = false
						for _, other in pairs(new_tech.effects) do
							if __eq(effect, other) then
								found = true
								other.modifier = other.modifier + effect.modifier
							end
						end
						if not found then
							table.insert(new_tech.effects, Table.deepcopy(effect))
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
			if Table.find(prereq, old_names) or prereq == new_name then
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


-- Split the technology in two equal techs.
function ProtUtils.duplicate_tech(tech, new_name)
	local name = tech.name
	local new_tech = Table.merge({tech,
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
		if t.prerequisites and Table.find(tech.name, t.prerequisites) then
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
		["6"] = "high-tech-science-pack",
		["y"] = "high-tech-science-pack",
		["h"] = "high-tech-science-pack",
		["7"] = "space-science-pack",
		["s"] = "space-science-pack",
		["w"] = "space-science-pack",
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
	Table.insert(tech, "effects", {type="unlock-recipe", recipe=recipe})
end


function ProtUtils.del_recipe_unlock(tech, recipe)
	tech = ProtUtils.tech(tech)
	Table.remove(tech, "effects", {type="unlock-recipe", recipe=recipe})
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
				i = i + 1
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




-- Recipe
----------

-- Replaces an ingredient in all recipes with a different ingredient
function ProtUtils.recipe_replace_ingredient_all(name, new_name)
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



-- Set name and unlock it in all techs that also unlock the original.
function ProtUtils.duplicate_recipe(recipe, new_name)
	recipe = Table.deepcopy(ProtUtils.recipe(recipe))
	local old_name = recipe.name
	recipe.name = new_name

	if recipe.enabled then return recipe end
	for _, tech in pairs(data.raw.technology) do
		if tech.effects and Table.find({type="unlock-recipe", recipe=old_name}, tech.effects) then
			table.insert(tech.effects, {type="unlock-recipe", recipe=new_name})
		end
	end
	return recipe
end


function ProtUtils.recipe_replace_ingredient(recipe, old_ingredient, new_ingredient, factor)
	factor = factor or 1
	for _, ingr in pairs(recipe.ingredients) do
		if ingr[1] == old_ingredient then
			ingr[1] = new_ingredient
			ingr[2] = ingr[2] * factor
		end
	end
end

function ProtUtils.recipe_remove_ingredient(recipe, old_ingredient)
	local i = 1
	while i <= #recipe.ingredients do
		local ingr = recipe.ingredients[i]
		if ingr[1] == old_ingredient then
			table.remove(recipe.ingredients, i)
		else
			i = i + 1
		end
	end
end


return ProtUtils