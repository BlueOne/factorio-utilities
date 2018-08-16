local Table = require("Utils.Table")

local ScenarioUtils = {}

function ScenarioUtils.create_item_chests(surface, position, force, items, chest_type)
    local chest
    local created_chests = {}
    if not chest_type then chest_type = "steel-chest" end
    local function create_chest()
        local pos = surface.find_non_colliding_position(chest_type, position, 10, 0.5)
        chest = surface.create_entity{name=chest_type, force = force, position = pos}
        table.insert(created_chests, chest)
    end
    create_chest()

    for item, count in pairs(items) do
        -- Insert into current chest, then create new ones and insert until all of this type is inserted.
        local all_inserted = false
        while not all_inserted do
            local inserted = chest.get_inventory(defines.inventory.chest).insert{name=item, count=count}
            count = count - inserted
            if count > 0 then
                create_chest()
            else
                all_inserted = true
            end
        end
    end
    return created_chests
end

function ScenarioUtils.spawn_player(player, surface, position, items)
    if player.character then player.character.destroy() end
    local pos = surface.find_non_colliding_position("player", position, 30, 1.3)
    player.teleport(pos, surface)
    player.create_character()
    for item_type, item_param in pairs(items or {}) do
        if type(item_param) == "number" then
            player.insert{name=item_type, count=item_param}
        else
            -- Armor
            if type(item_param) == "table" and item_param.type == "armor" then
                local inv = player.get_inventory(defines.inventory.player_armor)
                inv.insert{name=item_type}
                local grid = inv[1].grid
                for _, item in pairs(item_param.equipment) do
                    if type(item) == "string" then
                        grid.put{name=item}
                    else
                        if item.count == "fill" then
                            local added = true
                            while added do
                                added = grid.put{name=item.name, position=item.position}
                            end
                        else
                            for _=1, item.count or 1 do
                                grid.put{name=item.name, position=item.position}
                            end
                        end
                    end
                end
            end
        end
    end
end

return ScenarioUtils