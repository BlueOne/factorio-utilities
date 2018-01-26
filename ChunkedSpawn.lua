
local Utils = require("Utils/Utils")
local Maths = require("Utils/Maths")
local EntityUtils = require("Utils/EntityUtils")
local Chunked = require("Utils/Chunked")

-- TODO: Bug, I found a chunk where entities werent created.

local Spawn = {}

local CHUNKSIZE = 8
Spawn.remove_types_natural = { "tree", "unit-spawner", "turret", "simple-entity", "resource", "unit", "fish"}
Spawn.remove_types_natural_no_res = { "tree", "unit-spawner", "turret", "simple-entity", "unit", "fish"}


global.Spawn = global.Spawn or { 
    chunked_entities = {},
    chunked_tiles = {},
    enqueued_chunks = {},
}


local function spawn_chunk_entities(surface, chunk_position)
    local chunk_entity_data = global.Spawn.chunked_entities[surface.index]
    local entities = Chunked.get_chunk_entries_at_chunk(chunk_entity_data, chunk_position)

    if not entities then 
        return 0 
    end
    
    local removed_types = {}

    local x, y = Maths.get_coordinates(chunk_position)
    local chunk_box = {{x * CHUNKSIZE, y * CHUNKSIZE}, {(x+1)*CHUNKSIZE, (y+1)*CHUNKSIZE}}
    local expanded_chunk_box = Maths.expand_rect(chunk_box, 4)
    local corpse_cache = {}

    for _, entity_task in pairs(entities) do
        -- local collision_box = Utils.collision_box(entity_task.entity)

        -- Remove trees etc.
        if entity_task.remove_types then
            local to_remove = Utils.copy(entity_task.remove_types)
            for _, t in pairs(removed_types) do
                to_remove[t] = nil
            end

            if next(to_remove) then
                local surroundings = surface.find_entities_filtered{area = expanded_chunk_box}
                for _, other in pairs(surroundings) do
                    if Utils.in_list(other.type, to_remove) then 
                        other.destroy()
                    end
                end

                for _, t in pairs(to_remove) do
                    table.insert(removed_types, t)
                end
            end
        end

        -- spawn as ghosts?
        if entity_task.as_ghost then 
            entity_task.entity.inner_name = entity_task.entity.name
            entity_task.entity.name = "entity-ghost"
            entity_task.entity.expires = false
        end

        if not entity_task.spawn_chance or entity_task.items or math.random() < entity_task.spawn_chance then 
            local entity = surface.create_entity(entity_task.entity)
            if entity_task.postprocess_func and entity_task.postprocess_data then 
                entity_task.postprocess_func(entity, entity_task.postprocess_data)
            end
        elseif entity_task.spawn_chance then
            local corpse_name
            if corpse_cache[entity_task.entity.name] == nil then 
                local corpses = game.entity_prototypes[entity_task.entity.name].corpses
                if corpses then 
                    corpse_name = (next(corpses))
                    corpse_cache[entity_task.entity.name] = corpse_name
                else
                    corpse_cache[entity_task.entity.name] = false
                end
            elseif corpse_cache[entity_task.entity.name] then
                corpse_name = corpse_cache[entity_task.entity.name]
            end
            if corpse_name then
                entity_task.entity.name = corpse_name
                surface.create_entity(entity_task.entity)
            end
        end   
    end

    Chunked.remove_chunk(chunk_entity_data, chunk_position)

    return #entities
end

local function spawn_chunk_tiles(surface, chunk_position)
    local chunk_tile_data = global.Spawn.chunked_tiles[surface.index]
    if not chunk_tile_data then return 0 end
    local tiles = chunk_tile_data[Chunked.key_from_chunk_position(chunk_position)]
    if not tiles then return 0 end

    
    local new_tiles = {}
    local new_grass_tiles = {}

    for x, y_tiles in pairs(tiles) do
        for y, tile_weight in pairs(y_tiles) do
            if tile_weight > 2.5 then
                table.insert(new_tiles, {position={x, y}, name="concrete"})
                table.insert(new_grass_tiles, {position={x, y}, name="grass"})
            elseif tile_weight >= 0.8 then
                table.insert(new_tiles, {position={x, y}, name="stone-path"})
                table.insert(new_grass_tiles, {position={x, y}, name="grass"})
            end
        end
    end

    surface.set_tiles(new_grass_tiles)
    surface.set_tiles(new_tiles)
    
    chunk_tile_data[Chunked.key_from_chunk_position(chunk_position)] = nil

    return #new_tiles
end


local function enqueue_chunk_spawn(surface_id, chunk_position)
    table.insert(global.Spawn.enqueued_chunks, {surface_id, Utils.copy(chunk_position)})
end


-- Spawn entities. 
-- The entities are given in a list like they would be in a blueprint. The spawner can clean trees and biter nests near the constructed building and set the ground nearby to land. It will delay spawning until the chunk is generated if necessary.
function Spawn.spawn_entities(surface, entities, offset, rotation, force, build_options, remove_types, set_ground)
    -- Prepare parameters
    local as_ghost = (build_options and build_options.as_ghost)
    local spawn_chance = (build_options and build_options.spawn_chance)
    offset = offset or {0, 0}
    rotation = rotation or 0
    if remove_types == true then remove_types = Spawn.remove_types_natural end

    -- Prepare internal data
    local added_chunks = {}
    if not global.Spawn.chunked_entities[surface.index] then 
        global.Spawn.chunked_entities[surface.index] = Chunked.new(CHUNKSIZE) 
        global.Spawn.chunked_tiles[surface.index] = {}
    end 

    -- Save all entity creation and tile creation tasks.
    for _, entity_ in pairs(entities) do
        -- Prepare entity
        local entity = Utils.copy(entity_)
        entity.position = Maths.translate(Maths.rotate_orthogonal(entity.position, rotation), offset)    
        if rotation then
            entity.direction = ((entity.direction or 0) + rotation) % 8
        end
        if force then entity.force = force end
        
        -- Save that we changed this chunk.
        added_chunks[Chunked.key_from_position({chunk_size=CHUNKSIZE}, entity.position)] = true

        -- Save entity creation task
        Chunked.create_entry(global.Spawn.chunked_entities[surface.index], entity.position, {
            position = Utils.copy(entity.position),
            entity = entity, 
            as_ghost = as_ghost,
            spawn_chance = spawn_chance,            
            remove_types = remove_types,
            postprocess_data = entity.postprocess_data,
            postprocess_func = entity.postprocess_func,
        })

        if entity.postprocess_data and entity.postprocess_func then
            entity.postprocess_data = nil
            entity.postprocess_func = nil
        end

        -- Set ground tiles
        if set_ground then 
            -- Iterate over collision-box
            local ground_tile_radius = 4

            local collision_box = EntityUtils.collision_box(entity)
            local extended_collision_box = Maths.expand_rect(collision_box, ground_tile_radius)
            local xmin, ymin = Maths.get_coordinates(extended_collision_box[1] or extended_collision_box.left_top)
            local xmax, ymax = Maths.get_coordinates(extended_collision_box[2] or extended_collision_box.right_bottom)
            local center = {(xmax + xmin) / 2, (ymax + ymin) / 2}

            local chunk_data = global.Spawn.chunked_tiles[surface.index]
            if not chunk_data then
                global.Spawn.chunked_tiles[surface.index] = {}
                chunk_data = global.Spawn.chunked_tiles[surface.index]
            end

            local x, y = math.floor(xmin) + 1, math.floor(ymin) + 1
            while x <= xmax do
                while y <= ymax do 
                    local r = (Maths.sqdistance(center, {x, y}))^0.5
                    if r < 1 then r = 1 end
                    local position = {x, y}

                    if not chunk_data[Chunked.key_from_position({chunk_size = CHUNKSIZE}, position)] then 
                        chunk_data[Chunked.key_from_position({chunk_size = CHUNKSIZE}, position)] = {}
                    end
                    local this_chunk = chunk_data[Chunked.key_from_position({chunk_size = CHUNKSIZE}, position)]
                    if not this_chunk[x] then this_chunk[x] = {} end
                    if not this_chunk[x][y] then this_chunk[x][y] = 0 end

                    local inc = 2/r

                    if x - xmin < ground_tile_radius or xmax - x < ground_tile_radius or y - ymin < ground_tile_radius or ymax - y < ground_tile_radius then
                        inc = inc / 3
                    end

                    if entity_.name == "curved-rail" or entity_.name == "oil-refinery" then
                        inc = inc * 5
                    elseif entity_.name == "straight-rail" then 
                        inc = inc * 2
                    end

                    inc = inc * (1+math.random()/2.5 - 0.2)

                    this_chunk[x][y] = this_chunk[x][y] + inc

                    y = y + 1
                end
                y = math.floor(ymin)
                x = x + 1
            end
        end
    end

    -- Queue already generated chunks right now.
    for chunk_pos_str, _ in pairs(added_chunks) do
        local _, _, x, y = string.find(chunk_pos_str, "(.*)_(.*)")
        local chunk_pos = {tonumber(x), tonumber(y)}
        local is_generated = surface.is_chunk_generated(chunk_pos)
        if is_generated then 
            enqueue_chunk_spawn(surface.index, chunk_pos)
        end
    end
end

function Spawn.set_entity_post_process(surface, position, postprocess_func, postprocess_data)
    local chunk_entity_data = global.Spawn.chunked_entities[surface.index]
    local entity_task = Chunked.get_entry_at(chunk_entity_data, position)
    entity_task.postprocess_func = postprocess_func
    entity_task.postprocess_data = postprocess_data
end


function Spawn.on_chunk_generated(event)
    local left_top = event.area[1] or event.area.left_top
    local chunk_position
    

    local chunked_entities = global.Spawn.chunked_entities[event.surface.index]
    local chunked_tiles = global.Spawn.chunked_tiles[event.surface.index]

    local x, y = 0, 0
    while x < 32 / CHUNKSIZE do
        while y < 32 / CHUNKSIZE do
            chunk_position =  Maths.translate(Chunked.get_chunk_position(CHUNKSIZE, left_top), {x, y})
            if chunked_entities and Chunked.get_chunk_entries_at_chunk(chunked_entities, chunk_position) then
                enqueue_chunk_spawn(event.surface.index, chunk_position)
            elseif chunked_tiles and chunked_tiles[Chunked.key_from_chunk_position(chunk_position)] then
                enqueue_chunk_spawn(event.surface.index, chunk_position)
            end
            y = y + 1
        end
        y = 0
        x = x + 1
    end
end

function Spawn.controlled_spawn()
    local enqueued_chunk = global.Spawn.enqueued_chunks[1]
    if not enqueued_chunk then return end
    local surface_id, chunk_position
    local other_id
    local surface

    local time = 0
    while time < 250 do
        surface_id, chunk_position = enqueued_chunk[1], enqueued_chunk[2]
        if surface_id ~= other_id then 
            surface = game.surfaces[surface_id]
            other_id = surface_id
        end

        time = time + spawn_chunk_entities(surface, chunk_position)
        time = time + spawn_chunk_tiles(surface, chunk_position)

        table.remove(global.Spawn.enqueued_chunks, 1)
        enqueued_chunk = global.Spawn.enqueued_chunks[1]
        if not enqueued_chunk then break end
    end
end


Event.register(defines.events.on_tick, Spawn.controlled_spawn)
Event.register(defines.events.on_chunk_generated, Spawn.on_chunk_generated)


return Spawn