local tArgs = { ... }

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

local function printLocation()
  print("position (" .. position[1] .. "," .. position[2] .. "," .. position[3] .. ") direction " .. direction)
end

-- to access a chest behind the start position,
--   go to (0, 0, 0) facing south
--   N.B. if you go behind the chest you could hit it

function refuel(disp)
  local fuelLevel = turtle.getFuelLevel()
  if fuelLevel == "unlimited" then
    return true
  end

  needed = math.abs(position[1]) + math.abs(position[2]) + math.abs(position[3]) + 2
  if fuelLevel < needed then
    for n = 1,16 do
      if turtle.getItemCount(n) > 0 then
        turtle.select(n)
        if turtle.refuel(1) then
          while turtle.getItemCount(n) > 0 and turtle.getFuelLevel() < needed do
            turtle.refuel(1)
          end
          if turtle.getFuelLevel() >= needed then
            turtle.select(1)
            return true
          end
        end
      end
    end
    turtle.select(1)
    if not disp then
      print("Running low on fuel.")
    end
    if fuelLevel == 0 then
      sleep(1)
      return refuel(true)
    end
    return false
  end

  return true
end

-- Resilient functions for moving by one step.
local function updatePositionForward()
  if direction == south then
    position[3] = position[3] + 1
  elseif direction == west then
    position[1] = position[1] - 1
  elseif direction == north then
    position[3] = position[3] - 1
  elseif direction == east then
    position[1] = position[1] + 1
  end
end

local function updatePositionBack()
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

local function forward()
  -- @TODO: If running low on fuel, return to (0,0,0)?
  refuel()
  while not turtle.forward() do
    if turtle.detect() then
      if not turtle.dig() then
        return false
      end
    else
      turtle.attack()
    end
  end
  updatePositionForward()
  return true
end

local function forwardDigAll()
  refuel()
  if turtle.detectUp() then
    if not turtle.digUp() then
      return false
    end
  end
  if turtle.detectDown() then
    if not turtle.digDown() then
      return false
    end
  end
  while not turtle.forward() do
    if turtle.detect() then
      if not turtle.dig() then
        return false
      end
    else
      turtle.attack()
    end
  end
  updatePositionForward()
  if turtle.detectUp() then
    if not turtle.digUp() then
      return false
    end
  end
  if turtle.detectDown() then
    if not turtle.digDown() then
      return false
    end
  end
  return true
end

local function back()
  refuel()
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
  updatePositionBack()
  return true
end

local function up()
  refuel()
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
  return true
end

local function down()
  refuel()
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
  return true
end

-- Turning!
local function left()
  turtle.turnLeft()
  direction = (direction - 1) % 4
end

local function right()
  turtle.turnRight()
  direction = (direction + 1) % 4
end

local function turnTo(newDirection)
  if newDirection == (direction + 1) % 4 then
    right()
  else
    while direction ~= newDirection do
      left()
    end
  end
  direction = newDirection
end

-- Movement
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

  position[1] = x
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

  position[3] = z
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

  position[2] = y
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

local function goHome()
  printLocation()
  moveTo({0, 0, 0}, east)
end

-- Inventory
local function listInventoryNames()
  for i = 1,16 do
    local detail = turtle.getItemDetail(i)
    local count = turtle.getItemCount(i)
    if detail then
      print("Inventory slot " .. i .. " contains " .. count .. " of item name '" .. detail.name .. "'.")
    end
  end
end

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

-- Conditions for depositing:
-- * No empty inventory slots.
-- * An inventory slot is full, except for the first fuel one.
local function shouldUnloadInventory(missNothing)
  local haveHadAFuelSlot = false
  for i = 1,16 do
    local count = turtle.getItemCount(i)
    if count == 0 then
      return false
    end
  end
  if missNothing then
    return true
  end
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

local function unloadInventoryAndResume()
  local originalPosition = {position[1], position[2], position[3]}
  local originalDirection = direction
  moveTo({0, 0, 0}, west)
  unload(true)
  moveTo(originalPosition, originalDirection)
end

-- Actual turtle code
if #tArgs ~= 3 then
  print("Usage: bit_excavate <width (multiple of 2)> <depth (multiple of 3)> <pits>")
  return
end

local width = tonumber(tArgs[1])
local depth = tonumber(tArgs[2])
local pits = tonumber(tArgs[3])
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

-- Place in top-left block to be excavated.
-- width is the block cross-section of the pit.
-- depth is the block depth of the pit.

local function forwardDigAllBy(n)
  for t = 1,n do
    u = forwardDigAll()
    if not u then
      return u
    end
  end
  return true
end

local runs = depth / 3
local inner = width - 1
local runWind = "in"

for p = 1,pits do
  if p > 1 then
    moveTo({width*(p-1), 0, 0}, east)
  end

  for r = 1,runs do
    print("pit=" .. p .. " run=" .. r .. " winding=" .. runWind)
    listInventoryNames()

    -- Go to middle layer of 3-block high run.
    down()

    if runWind == "in" then
      -- Wind into center of run.
      if r > 1 then
        right()
      end
      forwardDigAllBy(inner)
      for d = inner,1,-1 do
        --dropAllExcept(???)
        if shouldUnloadInventory(true) then
          unloadInventoryAndResume()
        end
        right()
        forwardDigAllBy(d)
        right()
        forwardDigAllBy(d)
      end
      runWind = "out"
    else
      -- Wind to outside of run.
      if width % 2 == 0 then
        right()
      end
      for d=1,inner do
        if shouldUnloadInventory(true) then
          unloadInventoryAndResume()
        end
        forwardDigAllBy(d)
        right()
        forwardDigAllBy(d)
        right()
      end
      forwardDigAllBy(inner)
      runWind = "in"
    end

    if r ~= runs then
      -- Go to top layer of next run.
      down()
      down()
    end
  end
  moveTo({0, 0, 0}, west)
  unload(true)
  turnTo(east)
end
