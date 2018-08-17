local gpio = require "lgpio"
local util = require "test.test_util"

intro_1()

local pinp, pout = 20, 21

gpio.initialise()

gpio.setMode(pinp, gpio.INPUT)
gpio.setMode(pout, gpio.OUTPUT)
local x = 1
local last_tick

local function alert(pin, level, tick)
   local _tick = gpio.tick()
   local delta = tick - last_tick
   last_tick = tick
   local inbits = gpio.read_Bits_0_31()
   print(string.format("alert cb %3d at %d (%4d): gpio=%d (ok=%s), level=%d (%08x), tick=%d us, delta=%.3f us gc=%.1f (%d)",
                       x, _tick, _tick-tick, pin, tostring(pin==pinp), level, inbits, tick, delta/1000,
                       collectgarbage("count")))
   x = x + 1
end

gpio.setAlertFunc(pinp, alert)

local N = getNumber("Number of transitions: ", 10)
local ton = getNumber("T_on [ms]: ", 10)
local toff = getNumber("T_off [ms] ", 10)
local bitmode = getString("Bit mode (yes/no): ", "yes")
print("T_on:", ton)
print("T_off:", toff)
print("Bitmode:", bitmode)

last_tick = gpio.tick()
for i = 1, N/2 do
   if bitmode == "yes" then
      gpio.write(pout, 1)
   else
      gpio.write_Bits_0_31_Set(bit32.lshift(1,pout))
   end
   gpio.delay(ton*1000)
   if bitmode == "yes" then
      gpio.write_Bits_0_31_Clear(bit32.lshift(1, pout))
   else
      gpio.write(pout, 0)
   end
   gpio.delay(toff*1000)
   collectgarbage("collect")
end

print("cleanup ...")
gpio.setMode(pout, gpio.INPUT)
gpio.terminate()
