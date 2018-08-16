
local Maths = require("Utils.Maths")


local Chunked = {}

-- Relatively Structured way of storing mass data related to positions by splitting the map into chunks

function Chunked.new(chunk_size)
    return {
        chunked_data = {},
        chunk_size = chunk_size,
    }
end

function Chunked.get_entries_close(data, position, chunk_radius)
    local chunked_data = data.chunked_data
    local chunk_size = data.chunk_size
    local res = {}

    local x = math.floor((position.x or position[1]) / chunk_size)
    local y = math.floor((position.y or position[2]) / chunk_size)

    for X = x-chunk_radius, x+chunk_radius do
        for Y = y-chunk_radius, y+chunk_radius do
            for _, entity in pairs(chunked_data[X .. "_" .. Y] or {}) do
                table.insert(res, entity)
            end
        end
    end

    return res
end

function Chunked.get_chunk_entries(data, position)
    local chunked_data = data.chunked_data

    local key = Chunked.key_from_position(data, position)
    return chunked_data[key]
end

function Chunked.get_chunk_entries_at_chunk(data, chunk_position)
    return data.chunked_data[Chunked.key_from_chunk_position(chunk_position)]
end

function Chunked.get_entry_at(data, position)
    local chunked_data = data.chunked_data
    for _, entity in pairs(chunked_data[Chunked.key_from_position(data, position)] or {}) do
        if Maths.sqdistance(entity._position, position) < 0.01 then
            return entity
        end
    end
end

function Chunked.save_entry_data(data, position, t)
    local chunked_data = data.chunked_data
    for _, entity in pairs(chunked_data[Chunked.key_from_position(data, position)] or {}) do
        if Maths.sqdistance(entity._position, position) < 0.01 then
            for k, v in pairs(t) do
                entity[k] = v
            end
			return entity
        end
    end
end

function Chunked.create_entry(data, position, entry)
    local chunked_data = data.chunked_data
    local key = Chunked.key_from_position(data, position)
    if chunked_data[key] then
        table.insert(chunked_data[key], entry)
    else
        chunked_data[key] = {entry}
    end
    entry._index = #chunked_data[key]
	entry._position = position
end

-- Returns wether the chunked table has entries left
function Chunked.remove_entry(data, entry)
    local chunked_data = data.chunked_data
    local chunk_size = data.chunk_size
    if not chunked_data or not entry then
        game.print(debug.traceback())
        error("Called Utils.Chunked.remove_entry with invalid param!")
    end
    local key = Chunked.key_from_position(entry._position, chunk_size)

    if not chunked_data[key] then game.print(debug.traceback()); error("Attempted to delete entry in chunk that does not exist! Entry: " .. serpent.block(entry)) end
    if not chunked_data[key][entry._index] then game.print(debug.traceback()); error("Attempted to delete entry that does not exist! Entry: " .. serpent.block(entry)) end
    chunked_data[key][entry._index] = nil
    if next(chunked_data[key]) == nil then
        chunked_data[key] = nil
    end
    return (next(chunked_data) ~= nil)
end


function Chunked.remove_chunk(data, chunk_position)
    local chunked_data = data.chunked_data
    chunked_data[Chunked.key_from_chunk_position(chunk_position)] = nil
end

function Chunked.key_from_position(data, position)
    local chunk_size
    if type(data) == "number" then chunk_size = data else chunk_size = data.chunk_size end
	if not position or not chunk_size then game.print(debug.traceback()) end
    local x, y = Maths.get_coordinates(position)
    return math.floor(x / chunk_size) .. "_" .. math.floor(y / chunk_size)
end

function Chunked.get_chunk_position(data, position)
    local chunk_size
    if type(data) == "number" then chunk_size = data else chunk_size = data.chunk_size end
    local x, y = Maths.get_coordinates(position)
    return {math.floor(x / chunk_size), math.floor(y / chunk_size)}
end

function Chunked.key_from_chunk_position(chunk_position)
    return chunk_position[1] .. "_" .. chunk_position[2]
end


return Chunked
