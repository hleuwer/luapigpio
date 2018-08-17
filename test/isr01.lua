local gpio = require "lgpio"
local util = require "test.test_util"
local sec = 1e6
local msec = sec/1000
intro_1()

local pinp, pout = 20, 21

gpio.initialise()

gpio.setMode(pinp, gpio.INPUT)
gpio.setMode(pout, gpio.OUTPUT)
local x = 1
local last_tick

function isr(pin, level, tick)
   local _tick = gpio.tick()
   local delta = tick - last_tick
   last_tick = tick
   local inbits = gpio.read_Bits_0_31()
   local a,b = collectgarbage("count")
   if level == gpio.TIMEOUT then
      print(string.format("TIMEOUT %3d at %d (%4d): gpio=%d (ok=%s), level=%d (%08x), tick=%d us, delta=%.3f ms garbage=%.1f,%d",
                          x, _tick, _tick-tick, pin, tostring(pin==pinp), level, inbits, tick, delta/1000, a,b))
   else
      print(string.format("ISR cb %3d at %d (%4d): gpio=%d (ok=%s), level=%d (%08x), tick=%d us, delta=%.3f ms garbage=%.1f,%d",
                          x, _tick, _tick-tick, pin, tostring(pin==pinp), level, inbits, tick, delta/1000, a,b))
   end
   x = x + 1
end

local N = getNumber("Number of transitions: ", 50)
local ton = getNumber("T_on [ms]: ", 10)
local toff = getNumber("T_off [ms] ", 10)
local c1, c2, c3 = 5, 10, 15

print("T_on:", ton)
print("T_off:", toff)
print("Setup ISR callbacks ...")
gpio.setISRFunc(pinp, gpio.RISING_EDGE, 500, isr)

print("  rising edge")
last_tick = gpio.tick()

for i = 1, N/2 do
   
   if i == c1 then
--      collectgarbage("collect")
      print(" falling edge ...")
      gpio.setISRFunc(pinp, gpio.FALLING_EDGE, 500, isr)
   elseif i == c2 then
--      collectgarbage("collect")
      print(" either edge ...")
      gpio.setISRFunc(pinp, gpio.EITHER_EDGE, 500, isr)
   elseif i == c3 then
--      collectgarbage("collect")
      print(" rising edge ...")
      gpio.setISRFunc(pinp, gpio.RISING_EDGE, 500, isr)
      c1 = i + 10
      c2 = c1 + 10
      c3 = c2 + 5
   end
   print("  set 1 now")
   gpio.write(pout, 1)
   gpio.delay(ton * math.random(800,1200))

   print("  set 0 now")
   gpio.write(pout, 0)
   gpio.delay(toff * math.random(800,1200))
end

print("Checking timeout (waiting 1.2 sec) ...")
gpio.delay(0.9*sec)

collectgarbage("collect")
print(string.format("garbage: %.1f, %d", collectgarbage("count")))

print("Cancel timeouts ...")
gpio.setISRFunc(pinp, gpio.RISING_EDGE, 0, isr)

print("Cancel ISR callbacks ...")
gpio.setISRFunc(pinp, gpio.RISING_EDGE, 0, nil)

print("Wait a second ...")
gpio.delay(1*sec)

print("cleanup ...")
gpio.setMode(pout, gpio.INPUT)
gpio.terminate()
