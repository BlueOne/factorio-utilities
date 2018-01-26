
-- Entity related
------------------

local Maths = require("Utils.Maths")
local Utils = require("Utils.Utils")
local Str = require("Utils.String")

local EntityUtils = {}

if global then 
    if not global.EntityUtils then global.EntityUtils = { entity_recipe = {} } end
    global.EntityUtils.collision_box_cache = {}
end


-- works for name or entity or table {name=..., position=..., direction=...}
function EntityUtils.collision_box(entity)
	local cache_key
	if type(entity) == "string" then 
		cache_key = entity
	else
		local x, y = Maths.get_coordinates(entity.position)
		cache_key = "_" .. entity.name .. "_" .. x .. "_" .. y .. "_" .. (entity.direction or "")
	end
	if global.EntityUtils.collision_box_cache[cache_key] then
		return global.EntityUtils.collision_box_cache[cache_key]
	end

	if not entity then game.print(debug.traceback()) error("Called collision_box with parameter nil!") end

	local rect = nil
	if type(entity) == "string" then
		local ret_val = game.entity_prototypes[entity].collision_box
		global.EntityUtils.collision_box_cache[cache_key] = ret_val
		return ret_val
	end
	pcall(function()
		if entity.prototype then
			rect = Utils.copy(entity.prototype.collision_box)
		end
	end)
	if not rect then rect = Utils.copy(game.entity_prototypes[entity.name].collision_box) end

	-- Note: copy outputs a rect as {left_top=..., right_bottom=...}, rotate_rect handles this and returns {[1]=..., [2]=...}.
	rect = Maths.rotate_rect(rect, Str.rotation_stringtoint(entity.direction))

	local ret_val = {Maths.translate(rect[1], entity.position), Maths.translate(rect[2], entity.position)}
	global.EntityUtils.collision_box_cache[cache_key] = ret_val	
	return ret_val
end


-- Check if a prototype can appear in a blueprint.
function EntityUtils.prototype_blueprintable (prototype)
    return (prototype.has_flag("placeable-neutral") or prototype.has_flag("placeable-player")) and prototype.has_flag("player-creation") and not prototype.has_flag("not-blueprintable") and not prototype.has_flag("not-on-map") and not prototype.has_flag("pushable")
end

-- Note this should only be called for entities that are actually on a surface.
function EntityUtils.get_recipe_name(entity)
	if not entity then game.print(debug.traceback()) error("Trying to access recipe of nil entity!") end
	local x, y = Maths.get_coordinates(entity.position)
	local recipe
	pcall(function() recipe = entity.recipe end)
	if entity.type == "furnace" then
		if recipe then
			global.EntityUtils.entity_recipe[x .. "_" .. y] = recipe.name
			return recipe.name
		end
		pcall(function() recipe = entity.previous_recipe end)
		if recipe then
			global.EntityUtils.entity_recipe[x .. "_" .. y] = recipe.name
			return recipe.name
		end
		if global.EntityUtils.entity_recipe[x .. "_" .. y] then return global.EntityUtils.entity_recipe[x .. "_" .. y] end

		local stack = entity.get_output_inventory()[1]
		if stack and stack.valid_for_read then
			return stack.name
		else
			return nil
		end
	elseif entity.type == "assembling-machine" then
		return recipe.name
	else
		error("Called get_recipe for entity without recipe.")
	end
end

function EntityUtils.craft_interpolate(entity, ticks)
	local craft_speed = entity.prototype.crafting_speed
	local recipe = EntityUtils.get_recipe_name(entity)
	local energy = game.recipe_prototypes[recipe].energy
	local progress = entity.crafting_progress

	return math.floor((ticks / 60 * craft_speed) / energy + progress)
end


-- Returns true if the player can craft at least one. 
-- craft is a table {name = <item_name>}
function EntityUtils.can_craft(craft, player, need_intermediates)
	if not player.force.recipes[craft.name].enabled then
		return false
	end
	if need_intermediates then
		local recipe = game.recipe_prototypes[craft.name]

		if need_intermediates then
			for _, ingr in pairs(recipe.ingredients) do
				if (need_intermediates == true or Utils.has_value(need_intermediates, ingr.name)) and player.get_item_count(ingr.name) < ingr.amount then
					return false
				end
			end
		end
	end

	return player.get_craftable_count(craft.name) >= 1
end


-- Does not check for ghosts currently.
function EntityUtils.can_fast_replace_entities(entity, other_entity)
	-- Can't fast replace buildings owned by someone else.
	-- if entity.force ~= other_entity.force and entity.force ~= nil and other_entity.force ~= nil then
	-- 	return false
	-- end

	if game.entity_prototypes[other_entity.name].fast_replaceable_group == nil or game.entity_prototypes[other_entity.name].fast_replaceable_group ~= game.entity_prototypes[entity.name].fast_replaceable_group then 
		return false
	end

	-- If the entities aren't on the same position they can't fast-replace each other
	if not (Maths.sqdistance(entity.position, other_entity.position) < 0.1) then
		return false
	end
	
	-- If the direction is same and id is same, the fast replace wouldn't change anything
	if entity.name == other_entity.name and entity.direction == other_entity.direction then 
		return false
	end	
  
	return true
end

function EntityUtils.can_fast_replace(entity)
	local prototype = game.entity_prototypes[entity.name]
	local blocking_entity = EntityUtils.get_entity_from_pos(entity.position, entity, prototype.type)
	if not blocking_entity then
		return false
	elseif EntityUtils.can_fast_replace_entities(entity, blocking_entity) then
		return true
	else
		return false, blocking_entity
	end
end


-- Check if a player can place entity.
-- surface is the target surface.
-- entity = {name=..., position=..., direction=..., force=...} is a table that describes the entity we wish to describe
function EntityUtils.can_player_place(myplayer, entity)
	-- local name = entity.name
	-- local position = entity.position
	-- local direction = entity.direction
	-- local force = entity.force or "player"

	local target_collision_box = EntityUtils.collision_box(entity)

	if Maths.distance_from_rect(myplayer.position, target_collision_box) >= myplayer.build_distance + 0.1 then
		return false
	end

	-- Remove Items on ground

	if Maths.inside_rect(myplayer.position, target_collision_box) then 
		return false 
	end
	local items = myplayer.surface.find_entities_filtered {area = target_collision_box, type = "item-entity"}
	local items_saved = {}
	if not entity.surface then entity.surface = myplayer.surface end

	for _, item in pairs(items) do
		table.insert(items_saved, {name = item.stack.name, position = item.position, count = item.stack.count})
		item.destroy()
	end

	-- Check if we can actually place the entity at this tile
	local can_place = myplayer.surface.can_place_entity(entity)

	-- Put items back.
	for _, item in pairs(items_saved) do
		myplayer.surface.create_entity {
			name = "item-on-ground",
			position = item.position,
			stack = {name = item.name, count = item.count}
		}
	end
	
	local replace = false

	if not can_place then -- maybe we can fast-replace
		if EntityUtils.can_fast_replace(entity) then
			can_place = true
			replace = true
		end
	end
	
	return can_place, replace
end



function EntityUtils.get_entity_from_pos(pos, myplayer, types, epsilon)
	if (not pos) or (type(pos) ~= type({})) then game.print(debug.traceback()) end
	local x, y = Maths.get_coordinates(pos)

	if not epsilon then
		epsilon = 0.2
	end

	if not myplayer.surface then game.print(debug.traceback()) error("Called get_entity_from_pos with invalid myplayer param.") end
	-- if type == "resource" and x == math.floor(x) then
	-- 	x = x + 0.5
	-- 	y = y + 0.5
	-- end

	local accepted_types

	if type(types) == type("") then
		accepted_types = {types}
	elseif type(types) == type({}) then
		accepted_types = types
	else
		accepted_types = {"furnace", "assembling-machine", "container", "car", "cargo-wagon", "mining-drill", "boiler",
			"resource", "simple-entity", "tree", "lab", "rocket-silo", "transport-belt", "underground-belt", "splitter", "inserter"}
	end

	local entity = nil

	for _,ent in pairs(myplayer.surface.find_entities_filtered({area = {{-epsilon + x, -epsilon + y}, {epsilon + x, epsilon + y}}})) do
		if Utils.has_value(accepted_types, ent.type) then
			entity = ent
		end
	end

	return entity
end


return EntityUtils