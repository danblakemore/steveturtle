#!/bin/bash
scp "room.lua" trevor:
scp "move.lua" trevor:
ssh trevor "cp ~/room.lua /home/trevor/Minecraft/FTB-Beta-A/computer/7/room"
ssh trevor "cp ~/move.lua /home/trevor/Minecraft/FTB-Beta-A/computer/7/move"