-- script to excavate a room of a specified size
os.loadAPI("move")
local args = {...}

for i = 1, tonumber(args[1]) do
	move.turnRight()
end