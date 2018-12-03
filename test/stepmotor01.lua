local gpio = require "pigpio"
--local socket = require "socket"
--local sleep = socket.sleep
local sleep = function(t)
   gpio.delay(t*1e6)
end

local MIN_DELAY = 0.8
local coil_A_1_pin = 27  -- pink
local coil_A_2_pin = 17 -- orange
local coil_B_1_pin = 23 -- blau
local coil_B_2_pin = 24 -- gelb
-- #enable_pin   = 7 # Nur bei bestimmten Motoren benoetigt (+Zeile 24 und 30)
 
-- # anpassen, falls andere Sequenz
local StepCount = 8
local _Seq = {
   {0,1,0,0},
   {0,1,0,1},
   {0,0,0,1},
   {1,0,0,1},
   {1,0,0,0},
   {1,0,1,0},
   {0,0,1,0},
   {0,1,1,0}
} 
local Seq = {
   {0,0,0,1},
   {0,0,1,1},
   {0,0,1,0},
   {0,1,1,0},
   {0,1,0,0},
   {1,1,0,0},
   {1,0,0,0},
   {1,0,0,1}
} 

local function cleanup()
   gpio.setMode(coil_A_1_pin, gpio.INPUT)
   gpio.setMode(coil_A_2_pin, gpio.INPUT)
   gpio.setMode(coil_B_1_pin, gpio.INPUT)
   gpio.setMode(coil_B_2_pin, gpio.INPUT)
   gpio.terminate()
end

local function getNumber(prompt, default)
   local n
   repeat
      io.write(string.format("%s [%.2f]: ", prompt, default))
      io.flush()
      local s = io.read("*l")
      if #s == 0 then
         return default
      end
      n = tonumber(s)
   until type(n) == "number"
--   print(n, type(n))
   return n
end
print("Initialize pigpio ...")
gpio.initialise()

print("Setting up IO pins ...")
gpio.setMode(coil_A_1_pin, gpio.OUTPUT)
gpio.setMode(coil_A_2_pin, gpio.OUTPUT)
gpio.setMode(coil_B_1_pin, gpio.OUTPUT)
gpio.setMode(coil_B_2_pin, gpio.OUTPUT)
 
-- gpio.output(enable_pin, 1)
 
local function setStep(n, w1, w2, w3, w4)
--   print("setStep:", n, w1, w2, w3, w4)
   gpio.write(coil_A_1_pin, w1)
   gpio.write(coil_A_2_pin, w2)
   gpio.write(coil_B_1_pin, w3)
   gpio.write(coil_B_2_pin, w4)
end

local function forward(delay, steps)
   print("Stepping forward ".. steps)
   for i = 1, steps do
      for j = 1, StepCount do
         setStep(i, Seq[j][1], Seq[j][2], Seq[j][3], Seq[j][4]) 
         sleep(delay)
      end
   end
end

local function backwards(delay, steps)
   print("Stepping backwards ".. steps)
   for i = 1, steps do
      for j = StepCount, 1, -1 do
         setStep(i, Seq[j][1], Seq[j][2], Seq[j][3], Seq[j][4]) 
         sleep(delay)
      end
   end
end

local function main()
   local delay, steps = 100, 1
   while true do
      delay = getNumber("Delay in ms (-1 to leave)?", delay)
--      print("delay is ", delay)
      if delay < 0 then
         print("Cleaning up ...")
         cleanup()
         break
      end
      if delay < MIN_DELAY then
         print("   Delay must be >= " .. MIN_DELAY .." - try again")
      else
         steps = getNumber("Steps forward?", steps)
         forward(delay / 1000, steps)
         steps = getNumber("Steps backbard?", steps)
         backwards(delay / 1000, steps)
      end
   end
end

main()

