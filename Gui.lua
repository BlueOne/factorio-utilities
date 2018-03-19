-- GUI related.
---------------

local GuiEvent = require("stdlib/event/gui")
local mod_gui = require("mod-gui")

local GuiUtils = {}

if not global.GuiUtils then global.GuiUtils = { hide_buttons = {} } end




-- Hide Buttons for UI elements
--------------------------------


local function hide_button_handler(event)
	-- local player = game.players[event.player_index]
	local element = event.element
	local player = game.players[event.player_index]
	local button_data = global.GuiUtils.hide_buttons[event.player_index][element.name]
	local target_element = button_data.element
	target_element.style.visible = not target_element.style.visible
	if target_element.style.visible and button_data.set_as_opened then player.opened = target_element end
end

GuiEvent.on_click("hide_button_(.*)", hide_button_handler)

function GuiUtils.make_hide_button(player, gui_element, is_sprite, text, parent, style, set_as_opened)
	global.GuiUtils.hide_buttons[player.index] = global.GuiUtils.hide_buttons[player.index] or {}

	if not parent then parent = mod_gui.get_button_flow(player) end
	local name = "hide_button_" .. gui_element.name
	local button
	if is_sprite then
		button = parent.add{name=name, type="sprite-button", style=style or mod_gui.button_style, sprite=text,}
	else
		button = parent.add{name=name, type="button", style=style, caption=text}
	end
	button.style.visible = true
	global.GuiUtils.hide_buttons[player.index][name] = {
		element = gui_element,
		button = button,
		set_as_opened = set_as_opened
	}
end

function GuiUtils.remove_hide_button(player, gui_element)
	local name = "hide_button_" .. gui_element.name
	local button_data = global.GuiUtils.hide_buttons[player.index][name]
	button_data.button.destroy()
	global.GuiUtils.hide_buttons[player.index][name] = nil
	GuiEvent.remove(defines.events.on_gui_click, name)
end

function GuiUtils.hide_button_info(player, gui_element)
	local name = "hide_button_" .. gui_element.name
	if not global.GuiUtils.hide_buttons or not global.GuiUtils.hide_buttons[player.index] then
		return false
	end
	return global.GuiUtils.hide_buttons[player.index][name]	
end



return GuiUtils