local tArgs = { ... }

-- Excavates holes with a mining turtle.
--   pastebin get V2pQK64w github
--   github get 46bit turtles master bit_excavate.lua bit_excavate
--   bit_excavate 6 15 10
-- Digs a 6-wide, 15-deep hole in a line 10 times, forming a 6-wide 60-long 15-deep chamber.

-- x,z are on the horizontal plane
-- y is vertical
-- south=0 and increases z
-- west=1 and decreases x
-- north=2 and decreases z
-- east=3 and increases x
local south = 0
local west = 1
local north = 2
local east = 3

local position = {0, 0, 0}
local direction = east

-- Fueling
function refuelTo(needed)
  for n = 1,16 do
    turtle.select(n)
    while turtle.getItemCount(n) > 0 and turtle.getFuelLevel() < needed and turtle.refuel(0) do
      turtle.refuel(1)
    end
    turtle.select(1)

    if turtle.getFuelLevel() >= needed then
      return true
    end
  end
  return false
end

function refuel(needed)
  local fuelLevel = turtle.getFuelLevel()
  if fuelLevel == "unlimited" then
    return true
  end

  needed = math.max(needed, math.abs(position[1]) + math.abs(position[2]) + math.abs(position[3]) + 2)
  if fuelLevel < needed then
    if not refuelTo(needed) then
      print("Running low on fuel.")
    end

    -- If we have no fuel, all to do is to loop and hope some gets loaded.
    if turtle.getFuelLevel() == 0 then
      sleep(1)
      return refuelTo(needed)
    end
    return true
  end

  return true
end

-- Resilient movement routines.
local function left(n)
  n = n or 1
  for i = 1,n do
    turtle.turnLeft()
    direction = (direction - 1) % 4
  end
end

local function right(n)
  n = n or 1
  for i = 1,n do
    turtle.turnRight()
    direction = (direction + 1) % 4
  end
end

local function forward(n, tryDigUp, tryDigDown)
  n = n or 1
  refuel(2 * n)
  for i = 1,n do
    while not turtle.forward() do
      if turtle.detect() then
        if not turtle.dig() then
          return false
        end
      else
        turtle.attack()
      end
    end

    if direction == south then
      position[3] = position[3] + 1
    elseif direction == west then
      position[1] = position[1] - 1
    elseif direction == north then
      position[3] = position[3] - 1
    elseif direction == east then
      position[1] = position[1] + 1
    end

    -- Fails silently for digging up and down. The aim is for the turtle to move forward;
    -- digging up and down is a convenient side-effect. Many programs will want to work
    -- this way.
    -- Looping digging up will eliminate newly falling gravel. But the limiter prevents
    -- colliding lava and water from stalling the turtle forever.
    local upDigLimit = 4
    while tryDigUp and upDigLimit > 0 and turtle.detectUp() do
      turtle.digUp()
      upDigLimit = upDigLimit + 1
    end
    if tryDigDown and turtle.detectDown() then
      turtle.digDown()
    end
  end
  return true
end

local function back(n)
  n = n or 1
  refuel(2 * n)
  for i = 1,n do
    while not turtle.back() do
      turtle.turnLeft()
      turtle.turnLeft()
      if turtle.detect() then
        if not turtle.dig() then
          return false
        end
      else
        turtle.attack()
      end
      turtle.turnRight()
      turtle.turnRight()
    end

    if direction == south then
      position[3] = position[3] - 1
    elseif direction == west then
      position[1] = position[1] + 1
    elseif direction == north then
      position[3] = position[3] + 1
    elseif direction == east then
      position[1] = position[1] - 1
    end
  end
  return true
end

local function up(n)
  n = n or 1
  refuel(2 * n)
  for i = 1,n do
    while not turtle.up() do
      if turtle.detectUp() then
        if not turtle.digUp() then
          return false
        end
      else
        turtle.attackUp()
      end
    end
    position[2] = position[2] + 1
  end
  return true
end

local function down(n)
  n = n or 1
  refuel(2 * n)
  for i = 1,n do
    while not turtle.down() do
      if turtle.detectDown() then
        if not turtle.digDown() then
          return false
        end
      else
        turtle.attackDown()
      end
    end
    position[2] = position[2] - 1
  end
  return true
end

-- Coordinate-system movement routines.
local function turnTo(newDirection)
  if newDirection == (direction + 1) % 4 then
    right()
  else
    while direction ~= newDirection do
      left()
    end
  end
end

local function moveToX(x)
  -- Align with X axis pointing towards x=0.
  dx = x - position[1]

  -- Turn in direction of destX.
  if dx > 0 then
    turnTo(east)
  else
    turnTo(west)
  end

  -- Advance until reached.
  rem = math.abs(dx)
  while rem > 0 do
    forward()
    rem = rem - 1
  end
end

local function moveToZ(z)
  -- Align with X axis pointing towards x=0.
  dz = z - position[3]

  -- Turn in direction of destX.
  if dz > 0 then
    turnTo(south)
  else
    turnTo(north)
  end

  -- Advance until reached.
  rem = math.abs(dz)
  while rem > 0 do
    forward()
    rem = rem - 1
  end
end

local function moveToY(y)
  -- Move until x=0.
  dy = y - position[2]
  rem = math.abs(dy)

  while rem > 0 do
    if dy > 0 then
      up()
    else
      down()
    end
    rem = rem - 1
  end
end

local function moveTo(destination, newDirection)
  if not newDirection then
    newDirection = direction
  end

  -- Ensure that moving from point A to B will follow the same path as B to A.
  -- When destination is deeper,
  -- * Initial movement is along the axis it started facing.
  -- * Then at a horizontal right angle to that axis.
  -- * Then finally vertically.
  -- When destination is less deep this is reversed,
  -- * Initial movement is vertical.
  -- * Then at a right angle to the turtle's initial axis.
  -- * Then along the turtle's initial axis.
  -- This pattern isn't perfect for avoiding things near the origin but for an my excavation style
  -- it is optimal in movement.
  dy = destination[2] - position[2]
  if dy > 0 then
    moveToY(destination[2])
    moveToZ(destination[3])
    moveToX(destination[1])
  else
    moveToX(destination[1])
    moveToZ(destination[3])
    moveToY(destination[2])
  end

  turnTo(newDirection)
end

local function resumeAfter(callback)
  local startPosition = {position[1], position[2], position[3]}
  local startDirection = direction
  callback()
  moveTo(startPosition, startDirection)
end

-- Inventory
local function unload(keepAFuelStack)
  local unloaded = 0
  for i = 1,16 do
    local count = turtle.getItemCount(i)
    if count > 0 then
      turtle.select(i)
      if not (keepAFuelStack and turtle.refuel(0)) then
        turtle.drop()
        unloaded = unloaded + count
      end
    end
  end
  turtle.select(1)
  return unloaded
end

local function dropAllExcept(block_ids)
  for i = 1,16 do
    local detail = turtle.getItemDetail(i)
    if detail then
      local listed = false
      for j, block_id in ipairs(block_ids) do
        if detail.name == block_id then
          listed = true
          break
        end
      end
      if not listed then
        turtle.drop()
      end
    end
  end
end

local function dropByIDs(block_ids)
  for i = 1,16 do
    local detail = turtle.getItemDetail(i)
    if detail then
      local listed = false
      for j, block_id in ipairs(block_ids) do
        if detail.name == block_id then
          turtle.select(i)
          turtle.drop()
        end
      end
    end
  end
  turtle.select(1)
end

local function shouldUnloadInventory(keepEmptyInventorySlot)
  -- Conditions for depositing:
  -- * No empty inventory slots.
  local haveHadAFuelSlot = false
  for i = 1,16 do
    local count = turtle.getItemCount(i)
    if count == 0 then
      return false
    end
  end
  -- * If keepEmptyInventorySlot, that is sufficient.
  if keepEmptyInventorySlot then
    return true
  end
  -- * An inventory slot is full besides for the first fuel stack.
  for i = 1,16 do
    if not haveHadAFuelSlot and turtle.select(i) and turtle.refuel(0) then
      haveHadAFuelSlot = true
    elseif count == 64 then
      return true
    end
    turtle.select(1)
  end
  return false
end

local function goDepositInventory()
  moveTo({0, 0, 0}, west)
  unload(true)
end

local function printInventoryNames()
  for i = 1,16 do
    local detail = turtle.getItemDetail(i)
    local count = turtle.getItemCount(i)
    if detail then
      print("Inventory slot " .. i .. " contains " .. count .. " of item name '" .. detail.name .. "'.")
    end
  end
end

-- Actual turtle code
if #tArgs < 2 or #tArgs > 3 then
  print("Usage: bit_excavate <width (multiple of 2)> <depth (multiple of 3)> [<pits>]")
  return
end

local width = tonumber(tArgs[1])
local depth = tonumber(tArgs[2])
local pits = 1
if #tArgs >= 3 then
  pits = tonumber(tArgs[3])
end
if width < 1 then
  print("Width of pit must be a positive number.")
  return
end
if depth < 1 or depth % 3 ~= 0 then
  print("Depth of pit must be a positive multiple of 3.")
  return
end
if pits < 1 then
  print("Number of pits must be a positive number.")
  return
end

local junkIDs = {
  "minecraft:cobblestone", "minecraft:dirt", "minecraft:sand", "minecraft:gravel", "minecraft:sandstone",
  "minecraft:netherrack", "chisel:andesite", "chisel:diorite", "chisel:granite", "chisel:andesite",
  "chisel:diorite", "bluepower:basalt", "Botania:stone", "chisel:marble"
}

-- Place in top-left block to be excavated.
-- width is the block cross-section of the pit.
-- depth is the block depth of the pit.

local runs = depth / 3
local inner = width - 1

-- Wind into center of run.
local function windIn(p, r)
  -- For all but the first wind in we must start by turning right.
  if r > 1 then
    right()
  end

  forward(inner, true, true)
  for d = inner,1,-1 do
    dropByIDs(junkIDs)
    if shouldUnloadInventory(true) then
      resumeAfter(goDepositInventory)
    end

    right()
    forward(d, true, true)
    right()
    forward(d, true, true)
  end
end

-- Wind to outside of run.
local function windOut(p, r)
  -- For even-width runs we must turn right at the start of winding out.
  if width % 2 == 0 then
    right()
  end

  for d=1,inner do
    dropByIDs(junkIDs)
    if shouldUnloadInventory(true) then
      resumeAfter(goDepositInventory)
    end

    forward(d, true, true)
    right()
    forward(d, true, true)
    right()
  end
  forward(inner, true, true)
end

for p = 1,pits do
  -- Go to start of pit.
  moveTo({width*(p-1), 0, 0}, east)

  local runWind = "in"
  for r = 1,runs do
    print("pit=" .. p .. " run=" .. r .. " winding=" .. runWind)

    -- Go to middle layer of 3-block high run and clear a 3-high passageway.
    down()
    turtle.digUp()
    turtle.digDown()

    -- Alternate winding in then back out.
    if runWind == "in" then
      windIn(p, r)
      runWind = "out"
    else
      windOut(p, r)
      runWind = "in"
    end

    if r ~= runs then
      -- Go to top layer of next run.
      down(2)
    end
  end

  -- Return to start and deposit inventory at end of each run.
  moveTo({0, 0, 0}, west)
  unload(true)
  turnTo(east)
end
