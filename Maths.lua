local Maths = {}
local Table = require("Table")
local Str = require("Str")


-- Maths and Geometry
----------------------

-- Bound a value between two thresholds
function Maths.clamp(value, min, max)
	if value < min then return min elseif value > max then return max else return value end
end

function Maths.roulette_choice(weights, random_number)
	local sum = 0
	for _, w in pairs(weights) do
		sum = sum + w
	end

	if sum == 0 then error("Roulette Choice called with only zero weights!") end

	random_number = random_number * sum
	local current = 0
	for k, w in pairs(weights) do
		current = current + w
		if random_number <= current then return k end
	end
end

function Maths.roundn(x, prec)
	if not x then game.print(debug.traceback()); error("roundn called without valid parameter.") end
	if not prec then
		return math.floor(x + 0.5)
	else
		return math.floor(x*10^prec + 0.5) / 10^prec
	end
end

-- don't use this function, use in_range instead
-- TODO: remove this function
function Maths.inrange(position, myplayer)
  return ((position[1] - myplayer.position.x)^2 + (position[2] - myplayer.position.y)^2) < 36
end

function Maths.expand_rect(rect, r)
	local left_top = rect[1] or rect.left_top
	local right_bottom = rect[2] or rect.right_bottom
	local x1, y1 = Maths.get_coordinates(left_top)
	local x2, y2 = Maths.get_coordinates(right_bottom)
	return { {x1 - r, y1 - r}, {x2 + r, y2 + r} }
end

function Maths.inside_rect(point, rect)
	local x, y = Maths.get_coordinates(point)
	local lower_x, lower_y = Maths.get_coordinates(rect[1] or rect.left_top)
	local upper_x, upper_y = Maths.get_coordinates(rect[2] or rect.right_bottom)

	if not x or not y or not lower_x or not lower_y or not upper_x or not upper_y then
		game.print(debug.traceback());
		error("inside_rect called with invalid parameters.")
	end

	return lower_x < x and x < upper_x and lower_y < y and y < upper_y
end

-- rotation for angles multiple of 90°, encoded as 2 for 90°, 4 for 180°, 6 for 270°
function Maths.rotate_orthogonal(position, rotation)
	local x, y = Maths.get_coordinates(position)
	if not rotation or rotation == 0 then return {x, y}
	elseif rotation == 2 then return {-y, x}
	elseif rotation == 4 then return {-x, -y}
	elseif rotation == 6 then return {y, -x}
	else game.print(debug.traceback()) error("Bad rotation parameter! rotation = " .. serpent.block(rotation)) end
end

function Maths.rotate_rect(rect, rotation)
	if not rect then game.print(debug.traceback()) error("Called rotate_rect without rect param!") end
	if not rotation or rotation == 0 then return {rect[1] or rect.left_top, rect[2] or rect.right_bottom} end
	local x1, y1 = Maths.get_coordinates(Maths.rotate_orthogonal(rect[1] or rect.left_top, rotation))
	local x2, y2 = Maths.get_coordinates(Maths.rotate_orthogonal(rect[2] or rect.right_bottom, rotation))

	if x1 <= x2 then
		if y1 <= y2 then
			return {{x1, y1}, {x2, y2}}
		else
			return {{x1, y2}, {x2, y1}}
		end
	else
		if y1 <= y2 then
			return {{x2, y1}, {x1, y2}}
		else
			return {{x2, y2}, {x1, y1}}
		end
	end
end

function Maths.prettytime(tick)
	local hours = string.format("%02.f", math.floor(tick / 216000))
	local minutes = string.format("%02.f", math.floor(tick / 3600) - hours * 60)
	local seconds = string.format("%02.f", math.floor(tick / 60) - hours * 3600 - minutes * 60)
	local ticks = string.format("%02.f", tick - hours * 216000 - minutes * 3600 - seconds * 60)
	if hours == "00" then
		return "[" .. minutes .. ":" .. seconds .. ":" .. ticks .. "] "
	else
		return "[" .. hours .. ":" .. minutes .. ":" .. seconds .. ":" .. ticks .. "] "
	end
end



-- Geometry
------------

function Maths.translate(position, offset)
	if not offset then return position end
	local x, y = Maths.get_coordinates(position)
	local dx, dy = Maths.get_coordinates(offset)
	return {x+dx, y+dy}
end

function Maths.sqdistance(pos1, pos2)
	if not pos1[1] and not pos1.x then game.print(serpent.block(pos1)) game.print(debug.traceback()) error("Called distance with invalid parameter!") end
	local x1, y1 = Maths.get_coordinates(pos1)
	local x2, y2 = Maths.get_coordinates(pos2)

	return (x1 - x2)^2 + (y1 - y2)^2
end


function Maths.square(center, radius)
	local x, y = Maths.get_coordinates(center)
	return {{x - radius, y - radius}, {x + radius, y + radius}}
end

function Maths.center(rect)
	local l_u = rect[1] or rect.left_top
	local r_l = rect[2] or rect.right_bottom
	local x1, y1 = Maths.get_coordinates(l_u)
	local x2, y2 = Maths.get_coordinates(r_l)
	return {(x1 + x2) / 2, (y1 + y2) / 2}
end


function Maths.in_range(command, myplayer)
	return Maths.distance_from_rect(myplayer.position, command.rect) <= command.distance
end


-- Outputs the closest point we need to if we want to build e.g. an assembler
-- Closest here is not quite according to euclidean distance since we can only walk axis-aligned or diagonally.
function Maths.closest_point(square, circle_radius, position)
	local ax, ay = Maths.get_coordinates(square[1] or square.left_top)
	local bx, by = Maths.get_coordinates(square[2] or square.right_bottom)

	local cx, cy = (ax + bx) / 2, (ay + by) / 2
	local square_radius = cx - ax

	-- Translate to origin
	local px, py = Maths.get_coordinates(Maths.translate(position, {-cx, -cy}))

	-- Rotate until coordinates are positive
	local rotation = 0
	while not ((px >= 0) and (py >= 0)) do
		rotation = rotation + 2
		px, py = Maths.get_coordinates(Maths.rotate_orthogonal({px, py}, 2))
	end

	-- Mirror until x > y
	local mirrored = false
	if py > px then
		mirrored = true
		px, py = py, px
	end


	-- Actual calculation of target point.
	local rx, ry -- result.
	if py <= square_radius then
		rx, ry = square_radius + circle_radius, py
		--  then
	elseif py <= square_radius + circle_radius * math.sin(3.14159 / 8) then
		px, py = px - square_radius, py - square_radius --luacheck: ignore
		rx, ry = math.sqrt(circle_radius^2 - py^2), py
		rx, ry = rx + square_radius, ry + square_radius
	elseif px - (square_radius + circle_radius * math.cos(3.14159 / 8)) >= py - (square_radius + circle_radius * math.sin(3.14159 / 8))  then
		rx, ry = square_radius + circle_radius * math.cos(3.14159 / 8), square_radius + circle_radius * math.sin(3.14159 / 8)
	else
		px, py = px - square_radius, py - square_radius
		local D = math.sqrt(2*circle_radius^2 - (px-py)^2)
		rx, ry = (px - py + D) / 2, (py - px + D) / 2
		rx, ry = rx + square_radius, ry + square_radius
	end

	-- Revert mirroring
	if mirrored then
		rx, ry = ry, rx
	end
	-- Revert rotation
	rx, ry = Maths.get_coordinates(Maths.rotate_orthogonal({rx, ry}, (-rotation % 8)))

	local ret = Maths.translate({cx, cy}, {rx*0.99, ry*0.99})
	return ret
end

-- Works only for axis-aligned rectangles.
function Maths.distance_from_rect(pos, rect)
	if not rect then game.print(debug.traceback()) error("Called distance_from_rect with invalid rect param.") end
	local posx, posy = Maths.get_coordinates(pos)
	local rect1x, rect1y = Maths.get_coordinates(rect[1])
	local rect2x, rect2y = Maths.get_coordinates(rect[2])

	-- find the two closest corners to pos and the center
	local corners = {{x=rect1x, y=rect1y}, {x=rect1x, y=rect2y}, {x=rect2x, y=rect1y}, {x=rect2x, y=rect2y}}

	local function lt(a, b)
		return Maths.sqdistance(a, pos) < Maths.sqdistance(b, pos)
	end
	local index, corner1 = Table.find_minimum(corners, lt)
	table.remove(corners, index)
	local _, corner2 = Table.find_minimum(corners, lt)

	local closest = {}

	-- Set closest point on rectangle
	if corner1.x == corner2.x then
		closest[1] = corner1.x
		if corner1.y > corner2.y then corner1, corner2 = corner2, corner1 end
		if posy < corner1.y then closest[2] = corner1.y
		elseif posy > corner2.y then closest[2] = corner2.y
		else closest[2] = posy end
	else
		closest[2] = corner1.y
		if corner1.x > corner2.x then corner1, corner2 = corner2, corner1 end
		if posx < corner1.x then closest[1] = corner1.x
		elseif posx > corner2.x then closest[1] = corner2.x
		else closest[1] = posx end
	end

	return math.sqrt(Maths.sqdistance(closest, pos)), closest
end

function Maths.distance_rect_to_rect(rect1, rect2)
	local corners1 = {{rect1[1][1], rect1[1][2]}, {rect1[2][1], rect1[1][2]}, {rect1[2][1], rect1[2][2]}, {rect1[1][1], rect1[2][2]}} -- corners1[1] is the top left corner, continue clockwise
	local corners2 = {{rect2[1][1], rect2[1][2]}, {rect2[2][1], rect2[1][2]}, {rect2[2][1], rect2[2][2]}, {rect2[1][1], rect2[2][2]}}

	local in_cross_x = false
	local in_cross_y = false

	for _,corner in pairs(corners1) do
		if corners2[1][1] <= corner[1] and corner[1] <= corners2[2][1] then
			in_cross_x = true
		end

		if corners2[2][2] <= corner[2] and corner[2] <= corners2[3][2] then
			in_cross_y = true
		end
	end

	if in_cross_x then
		return math.min(math.abs(corners1[1][2] - corners2[1][2]), math.abs(corners1[3][2] - corners2[1][2]), math.abs(corners1[1][2] - corners2[3][2]), math.abs(corners1[3][2] - corners2[3][2]))
	end

	if in_cross_y then
		return math.min(math.abs(corners1[2][1] - corners2[2][1]), math.abs(corners1[4][1] - corners2[2][1]), math.abs(corners1[2][1] - corners2[4][1]), math.abs(corners1[4][1] - corners2[4][1]))
	end

	local min_distance = Maths.sqdistance(corners1[1], corners2[1])

	for _,corner1 in pairs(corners1) do
		for _,corner2 in pairs(corners2) do
			local distance = Maths.sqdistance(corner1, corner2)

			if distance < min_distance then
				min_distance = distance
			end
		end
	end

	return min_distance
end

function Maths.get_coordinates(pos)
	if not pos then game.print(debug.traceback()); error("Trying to access coordinates of invalid point!") end
	if pos.x then
		return pos.x, pos.y
	else
		return pos[1], pos[2]
	end
end


return Maths