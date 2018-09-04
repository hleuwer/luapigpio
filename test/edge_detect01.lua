local gpio = require "pigpio"
local util = require "test.test_util"
local wait = gpio.wait

print(gpio.info())

local pinp, pout = 20, 21

gpio.initialise()

local x = 1
local last_tick

---
--Alert callback.
---
local function alert(pin, level, tick)
   local _tick = gpio.tick()
   local delta = tick - last_tick
   last_tick = tick
   local inbits = gpio.read_Bits_0_31()
   print(string.format("alert cb %3d at %d (%4d us): gpio=%d (ok=%s), level=%d (%08x), tick=%d us, delta=%.3f ms gc=%.1f (%d)",
                       x, _tick, _tick-tick, pin, tostring(pin==pinp), level, inbits, tick, delta/1000,
                       collectgarbage("count")))
   x = x + 1
end

print("set pin pullup ...")
gpio.setPullUpDown(pinp, gpio.PUD_UP)
print("set pin to input ...")
gpio.setMode(pinp, gpio.INPUT)
print("set pout to output ...")
gpio.setMode(pout, gpio.OUTPUT)
--print("preset 1 ...")
--gpio.write(pout, 1)

local N = util.getNumber("Number of transitions: ", 10)
local ton = util.getNumber("T_on [ms]: ", 10)
local toff = util.getNumber("T_off [ms] ", 10)
local bitmode = util.getString("Bit mode (yes/no): ", "yes")
print("T_on:", ton)
print("T_off:", toff)
print("Bitmode:", bitmode)

print("set alert func ...")

gpio.setAlertFunc(pinp, alert)

last_tick = gpio.tick()
for i = 1, N/2 do
--   print("set 1")
   if bitmode == "yes" then
      gpio.write(pout, 1)
   else
      gpio.write_Bits_0_31_Set(bit32.lshift(1,pout))
   end
   wait(ton/1000)
   --   gpio.delay(ton*1000)
--   print("set 0")
   if bitmode == "yes" then
      gpio.write_Bits_0_31_Clear(bit32.lshift(1, pout))
   else
      gpio.write(pout, 0)
   end
   wait(toff/1000)
--   gpio.delay(toff*1000)
--   collectgarbage("collect")
end

print("cleanup ...")
gpio.setMode(pout, gpio.INPUT)
gpio.terminate()
