local gpio = require "pigpio"
local util = require "test.test_util"

print(gpio.info())
local pinp, pout = 20, 21

gpio.initialise()

gpio.setPullUpDown(pinp, gpio.PUD_UP)
gpio.setMode(pinp, gpio.INPUT)
gpio.setMode(pout, gpio.OUTPUT)

local last_tick = 0
local count = 1

---
-- Alert function.
---
local function alert(gpio, level, tick)
   print(string.format("Alert callback: count=%d, gpio=%d, ok=%s, level=%d, tick=%d us delta]=%.3f ms",
                       count, gpio, tostring(gpio==pinp), level, tick, (tick - last_tick)/1000))
   last_tick = tick
   count = count + 1
end

gpio.setAlertFunc(pinp, alert)

local N = util.getNumber("Number of triggers: ", 10)
local ton = util.getNumber("Pulse length [us]: ", 100)

last_tick = gpio.tick()
for i = 1, N do
   print("Trigger ...")
   gpio.trigger(pout, ton, 1)
   gpio.busyWait(1)
end

print("cleanup ...")
gpio.setMode(pout, gpio.INPUT)
gpio.terminate()
