-- script to excavate a room of a specified size
os.loadAPI("move")


state = { MINING=0, RETURNING=1, STUCK=2, DROPOFF=3, STOPPED=4, RESUMING=6 }
minestate = { DIGGING=0, BACKTRACKING=1, LEVELING=2 }

local args = {...}
local length = 0
local width = 0
local height = 0

-- start state
local currState = state.MINING

-- state about mine progress
local currentMineLevel = 0
local mineLevelSpacing = 1
local mineRow = 0
local mineCol = 0
local mineLevel = 0
local miningState = minestate.DIGGING 
local rowCountModifier = 1
local shouldResume = false

function main()
	-- parse args (will crash if invalid args)
	length = tonumber(args[1])
	width = tonumber(args[2])
	height = tonumber(args[3])
	
	-- clear the room
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
				move.forward() -- just dig forward
				mineRow = mineRow + rowCountModifier
				if mineRow == length - 1  or mineRow == 0 then
					-- check if we should keep mining
					if mineCol == width - 1 then
						miningState = minestate.LEVELING
						mineCol = 0
					else
						-- move into new column
						turnToNewCol()
						move.forward() -- just dig forward
						turnToNewCol() -- call again to make finish u-turn
						mineCol = mineCol + 1
						-- switch direction
						rowCountModifier = rowCountModifier * -1
					end
				end
			else
				-- go back to the start column and move down
				if mineLevel == height - 1 then
					currState = state.RETURNING
					shouldResume = false
				else
					move.moveToHomeColumn()
					increaseLevel()
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
function increaseLevel()
	-- dig down three
	for i = 1, mineLevelSpacing do
		move.up()
	end
end

-- check if we have enough fuel to continue and refuel if possible
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
	for i = 1, 15 do
		if turtle.getItemCount(i) == 0 then -- if a stack is empty, there's room, otherwise, we should go back so we don't waste any ore.
			return false
		end
	end
	return true
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
	for i = 1, 15 do -- ignore filter blocks and fuel level
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


main()