local gpio = require "lgpio"
local util = require "test.test_util"

intro_1()

local pinp, pout = 20, 21

gpio.initialise()

gpio.setMode(pinp, gpio.INPUT)
gpio.setMode(pout, gpio.OUTPUT)
local last_tick = 0
local x = 1

local function alert(gpio, level, tick)
   print(string.format("Alert callback: x=%d, gpio=%d, ok=%s, level=%d, tick=%d us delta]=%.3f us",
                       x, gpio, tostring(gpio==pinp), level, tick, tick - last_tick))
   last_tick = tick
   x = x + 1
end



gpio.setAlertFunc(pinp, alert)

local N = getNumber("Number of triggers: ", 10)
local ton = getNumber("Pulse length [us]: ", 100)
last_tick = gpio.tick()
for i = 1, N do 
   gpio.trigger(pout, ton, 1)
   gpio.delay(1e6/5)
   ton = ton - 10
end

print("cleanup ...")
gpio.setMode(pout, gpio.INPUT)
gpio.terminate()
