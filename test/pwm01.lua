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
   local _tick = gpio.tick()
   local delta = tick - last_tick
   last_tick = tick
   print(string.format("alert cb %3d at %d (%4d): pin=%d (ok=%s), level=%d, tick=%d us, delta=%.3f us",
                       x, _tick, _tick-tick, pin, tostring(pin==pinp), level, tick, delta/1000))
   
   x = x + 1
end

gpio.setAlertFunc(pinp, alert)

local freq = getNumber("PWM frequency:", 100)
collectgarbage("stop")
gpio.setPWMfrequency(pout, freq)
print("PWM frequency:", gpio.getPWMfrequency(pout))

printf("Start PWM: duty cyle 128 (%.1f %%) ...", 128/256 * 100)
io.write("Hit <return> ...") io.flush() io.read()
gpio.PWM(pout, 128)
gpio.delay(1e6/5)
gpio.PWM(pout, 0)

gpio.delay(1e6/5)
printf("Start PWM: duty cyle 255 (%.1f %%) ...", 255/256 * 100)
io.write("Hit <return> ...") io.flush() io.read()
gpio.PWM(pout, 255)
gpio.delay(1e6/5)
gpio.PWM(pout, 0)

gpio.delay(1e6/5)
printf("Start PWM: duty cyle 1 (%.1f %%) ...", 1/256 * 100)
io.write("Hit <return> ...") io.flush() io.read()
gpio.PWM(pout, 1)
gpio.delay(1e6/5)
gpio.PWM(pout, 0)
collectgarbage("restart")
print("cleanup ...")
gpio.setMode(pout, gpio.INPUT)
gpio.terminate()
