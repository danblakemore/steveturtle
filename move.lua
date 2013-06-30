--------------------------------------------------------------
-- Movement commands that keep track of distance 
--------------------------------------------------------------
-- Enumeration to store names for the 6 directions
direction = { FORWARD=0, RIGHT=1, BACK=2, LEFT=3, UP=4, DOWN=5, NONE=6 }
cardinals = { SOUTH=0, WEST=1, NORTH=2, EAST=3 }
-- where the heart is
local homeX = 0
local homeY = 0
local homeZ = 0
local homeOr = cardinals.EAST
-- note we start at home
local currX = homeX
local currY = homeY
local currZ = homeZ
local currOr = homeOr
-- a place to save where we were when our inventory filled up or we ran out of fuel
local savedX = homeX
local savedY = homeY
local savedZ = homeZ
local savedOr = homeOr
local destX
local destY
local destZ

-- offsets to change coordinates when moving relative directions (set by rotate functions)
local zForwardOffset = 0 
local zBackOffset = 0
local xForwardOffset = 1
local xBackOffset = -1


-- equalizes current y coord with saved y coord.
function moveToSavedY()
	-- equalize Y coords
	while currY ~= savedY do
		down()
	end
end

-- moves to the position on this level of the home column
function moveToHomeColumn()
	moveToDestination(homeX, currY, homeZ, homeOr)
end

-- moves to the saved position
function moveToSavedPos()
	moveToDestination(savedX, savedY, savedZ, savedOr)
end

-- takes the turtle back to base, or as close as we can get on our fuel level
function returnToBase()
	-- move to the home coordinates
	moveToDestination(homeX, homeY, homeZ, homeOr)
end

-- moves to the specified coordinates (assumes a clear path)
function moveToDestination(x, y, z, Or)
	local areWeThereYet = false
	while not areWeThereYet do
		local moveDir = helpMoveToPoint(x, y, z)
		if moveDir == direction.NONE then
			areWeThereYet = true
		elseif moveDir == direction.RIGHT then
			-- don't waste time preserving orientation when we restore it anyway
			turnRight()
		elseif moveDir == direction.LEFT then
			-- ditto
			turnLeft()
		else
			move(moveDir) -- should check error, not going to
		end
	end
	turnToCardinal(Or)
end

-- move and keep track of motion
function move(moveDir)
	if moveDir == direction.LEFT then
		-- psuedo move
		turnLeft()
		while not turtle.forward() do
			turtle.dig()
			sleep(0.3)
		end
		currX = currX + xForwardOffset
		currZ = currZ + zForwardOffset
		turnRight()
	elseif moveDir == direction.RIGHT then
		-- psuedo move
		turnRight()
		while not turtle.forward() do
			turtle.dig()
			sleep(0.3)
		end
		currX = currX + xForwardOffset
		currZ = currZ + zForwardOffset
		turnLeft()
	elseif moveDir == direction.FORWARD then
		while not turtle.forward() do
			turtle.dig()
			sleep(0.3)
		end
		currX = currX + xForwardOffset
		currZ = currZ + zForwardOffset
	elseif moveDir == direction.BACK then
		if turtle.back() then
			currX = currX + xBackOffset
			currZ = currZ + zBackOffset
		else
			turnRight()
			turnRight()
			while not turtle.forward() do
				turtle.dig()
				sleep(0.3)
			end
			currX = currX + xForwardOffset
			currZ = currZ + zForwardOffset
			turnRight()
			turnRight()
		end
	elseif moveDir == direction.UP then
		while not turtle.up() do
			turtle.digUp()
			sleep(0.3)
		end
		currY = currY + 1
	else
		while not turtle.down() do
			turtle.digDown()
			sleep(0.3)
		end
		currY = currY - 1
	end
end

-- get direction to move to get to a specified point
function helpMoveToPoint(x, y, z)
	-- move from curr* pos toward x,y,z specified
	-- move in the direction with the highest delta of x or z
	-- move in y only if already at x and z
	-- south is +z, east is +x
	if currZ == z and currY == y and currX == x then
		return direction.NONE
	end
	
	local zDiff = currZ - z
	local xDiff = currX - x
	local yDiff = currY - y
	
	-- move in x first, then z, then y
	if xDiff ~= 0 then
		-- move in X
		-- if xdiff is positive, subtract x (go west), else add x (go east)
		if xDiff > 0 then
			return resolveRelative(cardinals.WEST)
		else
			return resolveRelative(cardinals.EAST)
		end
	elseif zDiff ~= 0 then
		-- move in Z
		-- if zdiff is positive, subtract z (go north), else add z (go south)
		if zDiff > 0 then
			return resolveRelative(cardinals.NORTH)
		else
			return resolveRelative(cardinals.SOUTH)
		end
	else
		-- if zdiff and xdiff are 0, then we should move vertically
		-- ydiff is positive, we are above it, so move down, else move up
		if yDiff > 0 then
			return direction.DOWN
		else
			return direction.UP
		end
	end
end

-- save currect position
function savePos()
	savedX = currX
	savedY = currY
	savedZ = currZ
	savedOr = currOr
end

-- move north and keep track of motion
function north()
	move(resolveRelative(cardinals.NORTH))
end

-- move south and keep track of motion
function south()
	move(resolveRelative(cardinals.SOUTH))
end

-- move east and keep track of motion
function east()
	move(resolveRelative(cardinals.EAST))
end

-- move west and keep track of motion
function west()
	move(resolveRelative(cardinals.WEST))
end

-- move left and keep track of motion
function left()
	move(direction.LEFT)
end

-- move right and keep track of motion
function right()
	move(direction.RIGHT)
end

-- move forward and keep track of motion
function forward()
	move(direction.FORWARD)
end

-- move back and keep track of motion
function back()
	move(direction.BACK)
end

-- move up and keep track of motion
function up()
	move(direction.UP)
end

-- move down and keep track of motion
function down()
	move(direction.DOWN)
end

-- turn right and keep track of motion
function turnRight()
	-- turn and bookkeep
	if turtle.turnRight() then
		currOr = (currOr + 1) % 4
		fixOffsets()
		return true
	end
	return false
end

-- turn left and keep track of motion
function turnLeft()
	-- turn and bookkeep
	if turtle.turnLeft() then
		currOr = (currOr - 1) % 4
		fixOffsets()
		return true
	end
	return false
end

-- face north
function faceNorth()
	turnToCardinal(cardinals.NORTH)
end

-- face east
function faceEast()
	turnToCardinal(cardinals.EAST)
end

-- face south
function faceSouth()
	turnToCardinal(cardinals.SOUTH)
end

-- face west
function faceWest()
	turnToCardinal(cardinals.WEST)
end

-- face the way we faced at home
function faceHome()
	turnToCardinal(homeOr)
end

-- turn until you are at this cardinal
function turnToCardinal(cardinal)
	while currOr ~= cardinal do
		turnRight()
	end
end

-- resolve cardinal direction to relative direction
function resolveRelative(cardinal)
	-- math, math, baby
	local relativeOffset = currOr - cardinal
	
	if relativeOffset == 0 then
		-- go forward
		return direction.FORWARD
	elseif relativeOffset == -1 or relativeOffset == 3 then
		-- go right
		return direction.RIGHT
	elseif relativeOffset == 1 or relativeOffset == -3 then
		-- go left
		return direction.LEFT
	else
		-- go back
		return direction.BACK
	end
end

-- change the offsets to match the new direction
function fixOffsets()
	-- please note this is a lookup table because i'm too lazy to calculate them.
	-- matricies make my head hurt
	if currOr == cardinals.EAST then
		xForwardOffset = 1
		xBackOffset = -1
		zForwardOffset = 0 
		zBackOffset = 0
	elseif currOr == cardinals.NORTH then
		xForwardOffset = 0
		xBackOffset = 0
		zForwardOffset = -1 
		zBackOffset = 1
	elseif currOr == cardinals.WEST then
		xForwardOffset = -1
		xBackOffset = 1
		zForwardOffset = 0 
		zBackOffset = 0
	else
		xForwardOffset = 0
		xBackOffset = 0
		zForwardOffset = 1 
		zBackOffset = -1
	end
end
