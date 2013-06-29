#!/bin/bash
scp "spoork.lua" trevor:
scp "move.lua" trevor:
ssh trevor "cp ~/spoork.lua /home/trevor/Minecraft/FTB-Beta-A/computer/0/minediamond"
ssh trevor "cp ~/move.lua /home/trevor/Minecraft/FTB-Beta-A/computer/0/move"