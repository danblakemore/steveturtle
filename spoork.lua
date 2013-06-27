-- Diamond-level mining script

-- now time to steal some things from other scripts
-- Enumeration to store names for the 6 directions
direction = { FORWARD=0, RIGHT=1, BACK=2, LEFT=3, UP=4, DOWN=5, NONE=6 }
state = { MINING=0, RETURNING=1, STUCK=2, DROPOFF=3, STOPPED=4, RESUMING=6 }
minestate = { DIGGING=0, BACKTRACKING=1, LEVELING=2 }
cardinals = { SOUTH=0, WEST=1, NORTH=2, EAST=3 }

local fuelLevelToRefuelAt = 5
local refuelItemsToUseWhenRefuelling = 63
local emergencyFuelToRetain = 0
local maximumGravelStackSupported = 25 -- The number of stacked gravel or sand blocks supported
local noiseBlocksCount
local bottomLayer = 5 -- The y co-ords of the layer immediately above bedrock

-- where the heart is
local homeX = 112
local homeY = 15
local homeZ = 160
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
local shouldResume = false

-- offsets to change coordinates when moving relative directions (set by rotate functions)
local zForwardOffset = 0 
local zBackOffset = 0
local xForwardOffset = 1
local xBackOffset = -1

-- start state
local currState = state.MINING

-- state about mine progress
local currentMineLevel = 0
local destX
local destY
local destZ
local mineAreaSize = 32
local mineLevelCap = 4
local mineLevelSpacing = 3
local mineRow = 0
local mineCol = 0
local mineLevel = 0
local miningState = minestate.DIGGING 
local filterBlockCount = 4
local rowCountModifier = 1

-- main function.  This contains the run loop
function main()
	-- initialize variables to start mining

	while true do
		sleep(0)
		print(currState)
		-- check if we need to go back (starving)
		if not checkFuel() and currState == state.MINING then
			returnToBase()
			currState = state.STOPPED
			return
		end
		
		-- check if we need to go back (full)
		if currState == state.MINING and isInventoryFull() then
			savedX = currX
			savedY = currY
			savedZ = currZ
			savedOr = currOr
			shouldResume = true
			currState = state.RETURNING
			-- back out of this column (if we are on a column besides 1)
			if mineCol > 0 then
				turnToCardinal(cardinals.NORTH)
				forward()
			else
			-- turn so we can back out
			turnToCardinal(cardinals.EAST)
		end
		
		-- switch on state and see what we should do
		if currState == state.STOPPED then
			-- DO NOTHING
		elseif currState == state.RETURNING then
			returnToBase()
		elseif currState == state.DROPOFF then
			dropoff()
			turnToCardinal(homeOr)
			if shouldResume then
				currState = state.RESUMING
			else
				currState = state.STOPPED
			end
		elseif currState == state.RESUMING then
			resumeMining()
			currState = state.MINING
		elseif currState == state.MINING then
			-- for now, mine south-east from home 
			if miningState == minestate.DIGGING then
				mineForwardOneBlockAndLookAround()
				mineRow = mineRow + rowCountModifier
				if mineRow == mineAreaSize - 1  or mineRow == 0 then
					-- check if we should keep mining
					if mineCol == mineAreaSize - 1 then
						miningState = minestate.LEVELING
						mineCol = 0
					else
						-- move into new column
						turnToNewCol()
						mineForwardOneBlockAndLookAround()
						turnToNewCol() -- call again to make finish u-turn
						mineCol = mineCol + 1
						-- switch direction
						rowCountModifier = rowCountModifier * -1
					end
				end
			else
				-- go back to the start column and move down three blocks
				if mineLevel == mineLevelCap - 1 then
					currState = state.RETURNING
				else
					moveToDestination(homeX, currY, homeZ)
					decreaseLevel()
					miningState = minestate.DIGGING
					mineLevel = mineLevel + 1
					rowCountModifier = 1
					turnToCardinal(homeOr)
				end
			end
		else
			-- wat do here?
		end
		
	end
end

-- helper to turn the correct direction depending on what row you are on
function turnToNewCol()
	if rowCountModifier == 1 then
		turnRight()
	else
		turnLeft()
	end
end

-- go down one mine level, look around for blocks, and get ready to mine again
function decreaseLevel()
	-- dig down three
	for i = 1, mineLevelSpacing do
		while turtle.detectDown() do
			-- check if the space is free (gravel or sand could have fallen)
			-- only mine if there is a block
			turtle.digDown()
		end
		down()
	end
	
	-- look down
	if lookForTreasure(turtle.compareDown) then
		turtle.digDown()
	end
end

-- moves to the specified coordinates (assumes a clear path)
function moveToDestination(x, y, z, Or)
	local areWeThereYet = false
	while not areWeThereYet do
		local moveDir = helpMoveToPoint(x, y, z)
		if moveDir == direction.NONE then
			areWeThereYet = true
		else
			move(moveDir) -- should check error, not going to
		end
	end
	turnToCardinal(Or)
end

-- takes care of the details of digging forward and looking for ore.
function mineForwardOneBlockAndLookAround()
	-- mine a block in the direction we are moving
	while turtle.detect() do
		-- check if the space is free (gravel or sand could have fallen)
		-- only mine if there is a block
		turtle.dig()
		sleep(0.3)
	end

	-- move into space
	forward()
	
	-- look around and mine goodies
	-- look up
	if lookForTreasure(turtle.compareUp) then
		turtle.digUp()
	end
	-- look down
	if lookForTreasure(turtle.compareDown) then
		turtle.digDown()
	end
	
end

-- filters the specified block (1-ahead, 2-down, 3-up) against the blocks in the first three inventory spots
function lookForTreasure(compareFunctionPointer)
	for i = 1, filterBlockCount do
		turtle.select(i)
		if compareFunctionPointer() then
			return false
		end
	end
	return true
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

-- 
function checkFuel()
	-- just refuel with the entire first stack of coal if fuel is below 250
	local currentFuelLevel = turtle.getFuelLevel()
	local coalSlot = 16
	if currentFuelLevel < 250 then
		-- assume coal is in the last slot
		local coalCount = turtle.getItemCount(coalSlot) - 1
		if coalCount < 1 then
			-- well, we have no more fuel in this slot, check other slots
			local coalSlot = probeSlotsForItem(coalSlot, 16)
			
			if coalSlot > 0 then
				coalCount = turtle.getItemCount(coalSlot) - 1 
			else
				-- we have no coal ANYWHERE
				return false
			end	
		end
		
		-- refuel
		turtle.select(coalSlot)
		turtle.refuel(coalCount)
	end
	return true
end

function isInventoryFull()
	for i = (filterBlockCount + 1), 15 do -- ignore filter blocks and fuel level
		if turtle.getItemCount(i) == 0 then -- if a stack is empty, there's room, otherwise, we should go back so we don't waste any ore.
			return false
		end
	end
	return not cleanInventory() -- only clean if necessary
end

-- eliminate filter blocks in inventory and empty those stacks
function cleanInventory()
	local cleanedSome = false
	for i = 1,4 do
		-- select filter block and empty stack
		turtle.select(i)
		local filterCount = turtle.getItemCount(i)
		turtle.drop(filterCount - 1)
		
		-- find all other stacks of that filter block and dump them
		local cleaningFilter = true
		while cleaningFilter do
			local filterInstance = probeSlotsForItem(i, i)
			if filterInstance > 0 then
				turtle.select(filterInstance)
				turtle.drop()
				cleanedSome = true
			else
				cleaningFilter = false
			end
		end
	end
	return cleanedSome
end

function probeSlotsForItem(slotOfItem, currentlySelectedSlot)
	-- return the first slot containing the item (but not the one it started on), -1 if not found
	for i = 1, 16 do
		if i ~= slotOfItem then
			turtle.select(i) -- select item slot to probe
			if turtle.compareTo(slotOfItem) then
				turtle.select(currentlySelectedSlot) -- restore state
				return i
			end
		end
	end
	
	turtle.select(currentlySelectedSlot) -- restore state
	return -1
end

-- takes the turtle back to base, or as close as we can get on our fuel level
function returnToBase()
	-- move to the home coordinates
	-- movement strategy is to move horizontally and only move vertically when over the home point
	while currState ~= state.DROPOFF do
		local moveDir = helpMoveToPoint(homeX, homeY, homeZ)
		if moveDir == direction.NONE then
			currState = state.DROPOFF
		else
			move(moveDir) -- should check error, not going to
		end
	end
end

-- empty inventory into chest behind
function dropoff()
	turnRight()
	turnRight()
	for i = (filterBlockCount + 1), 15 do -- ignore filter blocks and fuel level
		turtle.select(i)
		turtle.drop()
	end
	turnRight()
	turnRight()
end

-- go back to the saved location and start mining again
function resumeMining()
	-- only enters this state when resuming from home, so go back
	-- equalize Y coords
	while currY ~= savedY do
		down()
	end
	
	-- now go back to where we were mining
	moveToDestination(savedX, savedY, savedZ, savedOr)
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
	print("x " .. currX .. " y " .. currY .. " z " .. currZ)
	-- couldn't move
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
	elseif relativeOffset == -1 then
		-- go right
		return direction.RIGHT
	elseif relativeOffset == 1 then
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



main() -- start

