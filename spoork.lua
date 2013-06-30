-- Diamond-level mining script
os.loadAPI("move") -- load movement functions

state = { MINING=0, RETURNING=1, STUCK=2, DROPOFF=3, STOPPED=4, RESUMING=6 }
minestate = { DIGGING=0, BACKTRACKING=1, LEVELING=2 }

-- start state
local currState = state.MINING

-- state about mine progress
local currentMineLevel = 0
local mineAreaSize = 32
local mineLevelCap = 4
local mineLevelSpacing = 3
local mineRow = 0
local mineCol = 0
local mineLevel = 0
local miningState = minestate.DIGGING 
local filterBlockCount = 4
local rowCountModifier = 1
local shouldResume = false

-- main function.  This contains the run loop
function main()
	-- initialize variables to start mining

	while true do
		sleep(0)
		-- check if we need to go back (starving)
		if not checkFuel() and currState == state.MINING then
			shouldReturn = false
			currState = state.RETURNING
		end
		
		-- check if we need to go back (full)
		if currState == state.MINING and isInventoryFull() then
			move.savePos()
			shouldResume = true
			currState = state.RETURNING
		end
		
		-- switch on state and see what we should do
		if currState == state.STOPPED then
			-- DO NOTHING
			return
		elseif currState == state.RETURNING then
			-- back out of this column (if we are on a column besides 0)
			if mineCol > 0 then
				move.faceNorth()
				move.forward()
			end
			-- turn so we can back out
			move.faceEast()
			move.returnToBase()
			currState = state.DROPOFF
		elseif currState == state.DROPOFF then
			dropoff()
			if shouldResume then
				currState = state.RESUMING
			else
				currState = state.STOPPED
			end
		elseif currState == state.RESUMING then
			resumeMining()
			currState = state.MINING
		elseif currState == state.MINING then
			-- mine south-east from home 
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
					shouldResume = false
				else
					move.moveToHomeColumn()
					decreaseLevel()
					miningState = minestate.DIGGING
					mineLevel = mineLevel + 1
					rowCountModifier = 1
					mineRow = 0
					move.faceHome()
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
		move.turnRight()
	else
		move.turnLeft()
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
		move.down()
	end
	
	-- look down
	if lookForTreasure(turtle.compareDown) then
		turtle.digDown()
	end
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
	move.forward()
	
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

-- empty inventory into chest behind
function dropoff()
	move.faceWest()
	for i = (filterBlockCount + 1), 15 do -- ignore filter blocks and fuel level
		turtle.select(i)
		turtle.drop()
	end
	move.faceEast()
end

-- go back to the saved location and start mining again
function resumeMining()
	-- only enters this state when resuming from home, so go back
	move.moveToSavedY()
	-- now go back to where we were mining
	move.moveToSavedPos()
end

main() -- start

