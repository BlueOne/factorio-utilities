local String = require("Utils/String")
local Table = require("Utils/Table")
local GuiUtils = require("Utils/Gui")
local GuiEvent = require("stdlib/event/gui")
local Event = require("stdlib/event/event")

-- Table Viewer UI
------------------------------------------------------------------------------


local TableUI = {}
global.TableUI = global.TableUI or { uis = {} }

local NUM_LINES = 200

Event.register(defines.events.on_tick, function()
    for _, ui in pairs(global.TableUI.uis) do
        for _, player in pairs(game.players) do
            TableUI.update(ui, player)
        end
    end
end)

-- The table will be saved in the global table!
function TableUI.add_table(table_ui, name, t)
    table_ui.the_table[name] = t
end

function TableUI.remove_table(table_ui, name)
    table_ui.the_table[name] = nil
end

function TableUI.create(name)
    if not name then name = #global.TableUI.uis + 1 end
    local table_ui = {
        name = name,
        the_table = {},
        player_data = {},
    }

    global.TableUI.uis[name] = table_ui

    return table_ui
end

function TableUI.create_ui(table_ui, player)
    table_ui.player_data[player.index] = { showed_elements = {}, line_data = {}, show_ui = true, need_update = true}
    local flow = player.gui.center
    local frame = flow.add{name="tableui_frame_" .. table_ui.name, type="frame", direction="vertical"}
	local scroll_pane = frame.add{type="scroll-pane", name="scroll_pane", direction="vertical"}
	local table = scroll_pane.add{type="table", name="table", column_count=1}
	table.style.vertical_spacing = 0
	scroll_pane.style.maximal_height = 800
	scroll_pane.style.maximal_width = 800
	scroll_pane.style.minimal_height = 800
    scroll_pane.style.minimal_width = 800

    GuiUtils.make_hide_button(player, frame, true, "virtual-signal/signal-T", nil, nil, true)
    frame.style.visible = false
end

function TableUI.get_line(table_ui, player, line_index)
    if not line_index then game.print(debug.traceback()) end
    if line_index > 200 then return nil end
    local line_table = player.gui.center["tableui_frame_" .. table_ui.name].scroll_pane.table
    local name = "tableui_line_" .. line_index
    if line_table[name] and line_table[name].valid then
        return line_table[name]
    else
        local line = line_table.add{type="label", caption="--", name=name}
        line.style.maximal_width = 800
        line.style.single_line = false
        return line
    end
end

local function descend(table, keys, stop_before)
    local t = table
    for i = 1, #keys - (stop_before or 0) do
        local k = keys[i]
        if t[k] then
            t = t[k]
        else
            return nil
        end
    end
    return t
end


function TableUI.update(table_ui, player)
    if not table_ui.the_table then return end
    local flow = player.gui.center
    local player_ui_data = table_ui.player_data[player.index]

    if not player_ui_data then
        TableUI.create_ui(table_ui, player)
        player_ui_data = table_ui.player_data[player.index]
    elseif (not flow["tableui_frame_" .. table_ui.name]) and player_ui_data.show_ui then
        TableUI.create_ui(table_ui, player)
    end

    local ui_frame = flow["tableui_frame_" .. table_ui.name]

    if player_ui_data.show_ui == ui_frame.style.visible then
        ui_frame.style.visible = player_ui_data.show_ui
    end


	if not player_ui_data.show_ui or not player_ui_data.need_update then return end
    player_ui_data.need_update = false
    
    local line_index = 1
    local stack = {{table_ui.the_table, {}}}
    local t
    local path
    while true do
        local node = stack[#stack]
        if not node then break end
        t = node[1]
        path = node[2]
        stack[#stack] = nil

        local line = TableUI.get_line(table_ui, player, line_index)
        if not line then break end

        local output_string = ""
        for i = 1, #path do
            output_string = output_string .. "        "
        end

        if descend(player_ui_data.showed_elements, path) then
            output_string = output_string .. "▼   "
        else
            local tab = descend(table_ui.the_table, path)
            local found_table = false
            for _, v in pairs(tab) do
                if type(v) == "table" and not Table.is_position(v) then
                    found_table = true
                    break
                end
            end
            if found_table then
                output_string = output_string .. "▶   "
            else
                output_string = output_string .. "        "
            end
        end

        if not next(path) then
            output_string = output_string .. "Root: "
        else
            output_string = output_string .. path[#path] .. ": "
        end


        for k, v in pairs(t) do
            if type(v) == "table" and not Table.is_position(v) then
                local new_path = Table.copy(path)
                table.insert(new_path, k)
                if descend(player_ui_data.showed_elements, path) then
                    table.insert(stack, {v, new_path})
                end
            else
                output_string = output_string .. String.printable(k) .. "= " .. String.printable(v) .. "  "
            end
        end
        line.caption = output_string
        player_ui_data.line_data[line_index] = { Table.copy(path) }
        line_index = line_index + 1
    end

    while player_ui_data.line_data[line_index] do
        player_ui_data.line_data[line_index] = nil
        local line = TableUI.get_line(table_ui, player, line_index)
        line.caption = ""
        line_index = line_index + 1
    end
end



function TableUI.destroy_ui(ui, player)
    local flow = player.gui.center
    local ui_frame = flow["tableui_frame_" .. ui.name]
    GuiUtils.remove_hide_button(ui_frame)
    if ui_frame and ui_frame.valid then ui_frame.destroy() end
    ui.player_data[player.index] = nil
end


function TableUI.destroy(ui)
    for i, _ in pairs(ui.player_data) do
        local player = game.players[i]
        TableUI.destroy(ui, player)
    end
end



local function expandNode(event)
    -- So this is a bit dirty.
    local name = string.sub(event.element.parent.parent.parent.name, 15)
    local table_ui = global.TableUI.uis[name]
    local player = game.players[event.player_index]
    local player_ui_data = table_ui.player_data[player.index]
    local line = event.element
    local the_table = table_ui.the_table
    player_ui_data.need_update = true
    local line_num = tonumber(event.match) -- tableui_line_###
    local line_data = player_ui_data.line_data[line_num]

    if not line_data or line_num == 1 then return end

    local path = line_data[1]
    local t = descend(the_table, path)
    local show_t = descend(player_ui_data.showed_elements, path)

    local table_found = false

    for _, v in pairs(t) do
        if type(v) == "table" then
            table_found = true
            break
        end
    end

    if not table_found then return end


    if #path >= 1 then
        if show_t then
            local parent = descend(player_ui_data.showed_elements, path, 1)
            parent[path[#path]] = nil
        else
            local parent = descend(player_ui_data.showed_elements, path, 1)
            parent[path[#path]] = {}
        end
    end
end


GuiEvent.on_click("tableui_line_(.*)", expandNode)

Event.register(defines.events.on_tick, function(event)
    if (event.tick % math.floor(game.speed * 20 + 1)) ~= 0 then return end
    for _, ui in pairs(global.TableUI.uis) do
        for i, player_ui_data in pairs(ui.player_data) do
            local player = game.players[i]
            TableUI.update(ui, player)
        end
    end
end)




return TableUI