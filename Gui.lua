-- GUI related.
---------------

local GuiEvent = require("stdlib/event/gui")
local mod_gui = require("mod-gui")

local Table = require("Utils/Table")
local Maths = require("Utils/Maths")
local String = require("Utils/String")

local GuiUtils = {}

if not global.GuiUtils then global.GuiUtils = { hide_buttons = {} } end
if not global.GuiUtils.hide_buttons then global.GuiUtils.hide_buttons = {} end




-- Hide Buttons for UI elements
--------------------------------


local function hide_button_handler(event)
	local player_buttons = global.GuiUtils.hide_buttons[event.player_index]
	-- Check if this lua instance created any hide buttons
	if not player_buttons then return end
	local element = event.element
	local button_data = player_buttons[element.name]

	-- Check if this lua instance created this button
	if not button_data then return end
	local target_element = button_data.element

	if target_element.style.visible == nil then 
		target_element.style.visible = false
	else
		target_element.style.visible = not target_element.style.visible
	end
end

GuiEvent.on_click("hide_button_(.*)", hide_button_handler)

-- set_as_opened doesnt seem to work.
function GuiUtils.make_hide_button(player, gui_element, is_sprite, text, parent, style)
	global.GuiUtils.hide_buttons[player.index] = global.GuiUtils.hide_buttons[player.index] or {}

	if not parent then parent = mod_gui.get_button_flow(player) end
	local name = "hide_button_" .. gui_element.name
	local button
	if is_sprite then
		button = parent.add{name=name, type="sprite-button", style=style or mod_gui.button_style, sprite=text,}
	else
		button = parent.add{name=name, type="button", style=style, caption=text}
		if not style then button.style.font = "default-bold" end
	end
	button.style.visible = true
	global.GuiUtils.hide_buttons[player.index][name] = {
		element = gui_element,
		button = button,
	}
end

function GuiUtils.remove_hide_button(player, gui_element)
	if not gui_element then game.print(debug.traceback()) end
	local name = "hide_button_" .. gui_element.name
	local button_data = global.GuiUtils.hide_buttons[player.index][name]
	button_data.button.destroy()
	global.GuiUtils.hide_buttons[player.index][name] = nil
end

function GuiUtils.hide_button_info(player, gui_element)
	local name = "hide_button_" .. gui_element.name
	if not global.GuiUtils.hide_buttons or not global.GuiUtils.hide_buttons[player.index] then
		return false
	end
	return global.GuiUtils.hide_buttons[player.index][name]	
end




return GuiUtils