-- Voting UI
------------------------------------------------------------------------------

-- Vote and Selection System
-- Sparsely tested!




local GuiEvent = require("stdlib/event/gui")
local Event = require("stdlib/event/event")
local mod_gui = require("mod-gui")

local Table = require("Utils/Table")
local Maths = require("Utils/Maths")
local GuiUtils = require("Utils/Gui")


local VoteUI = {}

if not global.VoteUI then global.VoteUI = { } end
global.VoteUI.votes = global.VoteUI.votes or {}


VoteUI.on_vote_finished = script.generate_event_name()
-- {vote_name=, option_name=}




-- cfg = {
-- 	title,
-- 	description,
-- 	frame_style,
-- 	force,
-- 	duration, 
-- 	mode,
--  sprite,
-- }

-- options = {
--     name1 = { title =, tooltip=},
-- }

function VoteUI.get_vote(name)
	return global.VoteUI.votes[name]
end

function VoteUI.init_vote(name, cfg, options)
	local vote_data = global.VoteUI.votes[name]
	if vote_data then 
		error("Duplicate Vote.")
	end
	vote_data = {
		name = name,
		options = options,

		cfg = Table.copy(cfg),
		-- duration = nil
		-- ended = true

		players = {},
		choices = {}
    }

    vote_data.cfg.mode = vote_data.cfg.mode or "majority"

	if vote_data.cfg.duration then vote_data.duration = vote_data.cfg.duration end

	for n, _ in pairs(options) do
		vote_data.choices[n] = 0
	end

	if type(vote_data.cfg.force) == "string" or type(vote_data.cfg.force) == "number" then 
		vote_data.cfg.force = game.forces[vote_data.cfg.force] 
	end

	
	global.VoteUI.votes[vote_data.name] = vote_data

	if vote_data.cfg.force then
		for _, player in pairs(vote_data.cfg.force.players) do
			VoteUI.add_player(vote_data, player)
		end
    end
    	
	return vote_data
end


function VoteUI.add_player(vote, player, ui_parent)
    if vote.players[player.index] then return end

	if not ui_parent then ui_parent = mod_gui.get_frame_flow(player) end
	local frame = ui_parent.add{type="frame", name="vote_ui_" .. vote.name, style=vote.cfg.frame_style, caption=vote.cfg.title, direction="vertical"}

	if vote.cfg.description then 
		frame.add{type="label", name="description", caption=vote.cfg.description}
	end

    for option_name, option in pairs(vote.options) do
		local option_flow = frame.add{type="flow", direction="horizontal", name = "option_flow_" .. option_name}
		local button = option_flow.add{type="button", name="vote_option_button_" .. option_name, caption=option.title, tooltip=option.tooltip}
		button.style.minimal_width = 200
    end

    local is_sprite = vote.cfg.sprite ~= nil
    GuiUtils.make_hide_button(player, frame, is_sprite, vote.cfg.sprite or vote.cfg.title)

	vote.players[player.index] = {
		frame = frame
		-- choice = nil
	}
end


function VoteUI.remove_player(vote, player)
    if not player or not player.valid then return end
	local player_data = vote.players[player.index]
	if player_data.frame and player_data.frame.valid then 
		GuiUtils.remove_hide_button(player, player_data.frame)
		player_data.frame.destroy() 
	end


	if vote.ended then 
		vote.players[player.index] = nil
		return
	end


	if player_data.choice then 
        vote.choices[player_data.choice] = vote.choices[player_data.choice] - 1
        local finished = VoteUI.check_finished(vote)      
        if not finished then 
            VoteUI.update_guis(vote, player) 
        end
	end
	vote.players[player.index] = nil
end

function VoteUI.stop_vote(vote, cause, option_name)
    if not (cause == "finished" and option_name) then
        -- need to determine option
        if vote.cfg.mode == "single" then
            for name, vote_count in pairs(vote.choices) do
                if vote_count > 0 then 
                    option_name = name
                    break
                end
            end
        elseif vote.cfg.mode == "majority" or vote.cfg.mode == "timeout" then
            local weights = {}
            local most_votes = -1
            for name, vote_count in pairs(vote.choices) do 
                if vote_count > most_votes then
                    weights = {}
                    most_votes = vote_count
				end
				if vote_count == most_votes then 
					weights[name] = 1
				end
			end
            option_name = Maths.roulette_choice(weights)
        end
	end
	
	vote.ended = true

    -- for player_name, _ in pairs(vote.players) do
    --     local player = game.players[player_name]
    --     player.print("Vote Ended! Selected " .. option_name)
    -- end
    local event = {
        vote_name = vote.name,
		option_name = option_name,
		option = vote.options[option_name],
        cause = cause,
    }
	script.raise_event(VoteUI.on_vote_finished, event)
	
    VoteUI.destroy(vote)
end

function VoteUI.destroy(vote)
	for player_index, _ in pairs(vote.players) do
		local player = game.players[player_index]
		VoteUI.remove_player(vote, player)
	end

    global.VoteUI.votes[vote.name] = nil
end

function VoteUI.update_guis(vote)
    for player_name, player_data in pairs(vote.players) do
        local player = game.players[player_name]
        if player and player.connected then
            local frame = player_data.frame
            for option_name, option in pairs(vote.options) do
                local flow = frame["option_flow_" .. option_name]
                local button = flow["vote_option_button_" .. option_name]
                local caption = option.title
                if vote.cfg.mode ~= "single" then
                    caption = caption .. " (" .. vote.choices[option_name] .. ")"
                end
                if player_data.choice == option_name then
                    caption = "▶ " .. caption
                end
                button.caption = caption
            end
        else 
            VoteUI.remove_player(vote, player)
        end
    end
end
    

function VoteUI.check_finished(vote)
    if vote.cfg.mode == "single" then
        for option_name, vote_count in pairs(vote.choices) do
            if vote_count > 0 then 
                VoteUI.stop_vote(vote, "finished", option_name)
                return true
            end
        end
	elseif vote.cfg.mode == "majority" then
		local undecided = 0
		for _, player_data in pairs(vote.players) do
			if not player_data.choice then
				undecided = undecided + 1
			end
		end
		local max = -1
		local max_option
		local second = -1
		for option_name, vote_count in pairs(vote.choices) do
			if vote_count > max then 
				max_option = option_name
				max = vote_count
			elseif vote_count > second then
				second = vote_count
			end
		end
		if undecided + second < max then 
			VoteUI.stop_vote(vote, "decided", max_option)
			return true
		end
    end
    return false
end


-- Handle Duration

Event.register(-60, function(event)
	for k, vote in pairs(global.VoteUI.votes) do
		if vote.duration then
			vote.duration = vote.duration - 1
			if vote.duration < 0 then
				VoteUI.stop_vote(vote, "timeout")
			else
				for i, player_data in pairs(vote.players) do
					local caption = vote.cfg.title .. "       Time Left: " .. Maths.prettytime(vote.duration * 60, true)
					player_data.frame.caption = caption
				end
			end
		end
	end
end)


-- Handle Force and Player Changes

Event.register(defines.events.on_player_joined_game, function(event) 
	local player = game.players[event.player_index]
	for _, vote in pairs(global.VoteUI.votes) do
		if vote.cfg.force and player.force.name == vote.cfg.force.name then 
			VoteUI.add_player(vote, player)
		end
	end
end)

Event.register(defines.events.on_player_left_game, function(event)
	local player = game.players[event.player_index]
	for _, vote in pairs(global.VoteUI.votes) do
		if vote.players[event.player_index] then 
            VoteUI.remove_player(vote, player)
		end
	end
end)

Event.register(defines.events.on_forces_merging, function(event)
	local source = event.source
	local destination = event.destination

	for _, vote in pairs(global.VoteUI.votes) do
		if vote.cfg.force.name == destination.name then
			for _, player in pairs(source.players) do
				VoteUI.add_player(vote, player)
			end
		elseif vote.cfg.force.name == source.name then
			for _, player in pairs(destination.players) do
				VoteUI.add_player(vote, player)
			end
		end
	end
end)

Event.register(defines.events.on_player_changed_force, function(event)
	local player = game.players[event.player_index]
	for _, vote in pairs(global.VoteUI.votes) do
		if vote.cfg.force and player.force.name == vote.cfg.force.name then 
			VoteUI.add_player(vote, player)
		elseif vote.cfg.force and vote.cfg.force.name == event.force.name and vote.players[player.index] then
            VoteUI.remove_player(vote, player)
		end
	end
end)


GuiEvent.on_click("vote_option_button_(.*)", function (event)
	local player = game.players[event.player_index]
	local element = event.element
	local option_name = event.match

	local vote_name = string.sub(element.parent.parent.name, #"vote_ui_" + 1)

	local vote_data = global.VoteUI.votes[vote_name]
	if not vote_data then return end
	if not vote_data.players[player.index] then return end

	--local option = vote_data.options[option_name]
	local player_data = vote_data.players[event.player_index]

	-- Actual vote		
	if player_data.choice == option_name then 
		vote_data.choices[player_data.choice] = vote_data.choices[player_data.choice] - 1 
		player_data.choice = nil
		VoteUI.update_guis(vote_data)
	else
		if player_data.choice then
			vote_data.choices[player_data.choice] = vote_data.choices[player_data.choice] - 1
		end
		vote_data.choices[option_name] = vote_data.choices[option_name] + 1
		player_data.choice = option_name
		local finished = VoteUI.check_finished(vote_data)
        if not finished then
            VoteUI.update_guis(vote_data)
		end
	end
	
end)

return VoteUI