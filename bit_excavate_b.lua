local tArgs = { ... }

local position
local direction

-- to access a chest behind the start position,
--   go to (0, 0, 0) facing south
--   N.B. if you go behind the chest you could hit it

function refuel()
  local fuelLevel = turtle.getFuelLevel()
  if fuelLevel == "unlimited" then
    return true
  end

  needed = position[1] + position[2] + position[3] + 2
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
    print("Running low on fuel.")
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
  updatePositionForward()
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

local function turnTo(newDirection)
  while direction ~= newDirection do
    turtle.turnRight()
  end
  direction = newDirection
end

local function left()
  turtle.turnLeft()
  direction = (direction - 1) % 4
end

local function right()
  turtle.turnRight()
  direction = (direction + 1) % 4
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

local function moveTo(destination)
  local originalDirection = direction
  moveToY(destination[2])
  moveToX(destination[1])
  moveToZ(destination[3])
  turnTo(originalDirection)
end

-- Actual turtle code
if #tArgs ~= 2 then
  print( "Usage: bit_excavate <width (multiple of 2)> <depth (multiple of 3)>" )
  return
end

local width = tonumber(tArgs[1])
local depth = tonumber(tArgs[2])
if width < 1 then
  print("Width of pit must be a positive number.")
  return
end
if depth < 1 or depth % 3 ~= 0 then
  print("Depth of pit must be a positive multiple of 3.")
  return
end

position = {0, 0, 0}
direction = east

-- Place in top-left block to be excavated.
-- width is the block cross-section of the pit.
-- depth is the block depth of the pit.

local runs = depth / 3
-- N.B. nextTurnDirection needs preserving between runs.
local nextTurnDirection = "r"
for r = 1,runs do
  print("run" .. tostring(r))
  print("start position " .. tostring(position[1]) .. "," .. tostring(position[2]) .. "," .. tostring(position[3]))

  -- Go into middle of 3-block high run.
  down()

  -- Excavate the run.
  for i = 1,width do
    -- Go (width-1) forward.
    for j = 2,width do
      forwardDigAll()
    end

    -- Handle end of this row appropriately.
    if i == width then
      break
    end

    -- Only this row is complete.
    -- Move to the next row and do an about face.
    -- Alternate between two right turns and two left turns. Four right turns would bring it back on itself.
    if nextTurnDirection == "r" then
      right()
      forwardDigAll()
      right()
      nextTurnDirection = "l"
    else
      left()
      forwardDigAll()
      left()
      nextTurnDirection = "r"
    end
  end

  -- Avoid further downward excavation once at the bottom.
  if r == runs then
    break
  end

  -- This run is complete. Turn in the direction we most recently turned in.
  -- Between the last two turns and this we need a 270-degree turn to stay in the cuboid.
  -- Furthermore the following two turns also need to be the same in order to achieve a 450-degree turn.
  if nextTurnDirection == "r" then
    left()
    nextTurnDirection = "l"
  else
    right()
    nextTurnDirection = "r"
  end

  -- Go to top layer of next run.
  down()
  down()
end

moveTo({0, 0, 0})
turnTo(east)
