local gpio = require "lgpio"
local util = require "test.test_util"

intro_1()

local pinp, pout = 20, 21

gpio.initialise()

gpio.setMode(pinp, gpio.INPUT)
gpio.setMode(pout, gpio.OUTPUT)
local last_tick = 0
local x = 1

local function alert(pin, level, tick)
   printf(string.format("Alert callback: %d, gpio=%d, ok=%s, level=%d, tick=%d us, delta=%.3f us",
                        x, pin, tostring(pin==pinp), level, tick, tick - last_tick))
   last_tick = tick
   x = x + 1
   if x == 10 then
      print("  Cancel Watchdog")
      gpio.setWatchdog(pinp, 0)
   end
end



gpio.setAlertFunc(pinp, alert)

local tout = getNumber("Timeout [ms]: ", 500)

print("Config Watchdog ...")
local rc = gpio.setWatchdog(pinp, tout)

print("Write level 1 ...")
gpio.write(pout, 1)
last_tick = gpio.tick()
print("Capture Watchdog timeouts for 5 seconds ...")
gpio.delay(5*1e6)

print("cleanup ...")
gpio.setMode(pout, gpio.INPUT)
gpio.terminate()
