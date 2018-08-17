local gpio = require "lgpio"
local util = require "test.test_util"

intro_1()

local pinp, pout = 20, 21

gpio.initialise()

gpio.setMode(pinp, gpio.INPUT)
gpio.setMode(pout, gpio.OUTPUT)

local last_tick = 0
local x = 1
local function alertEx(pin, level, tick, userparam)
   local _tick = gpio.tick()
   local delta = tick - last_tick
   last_tick = tick
   print(string.format("alert ex cb %3d at %d (%4d): pin=%d (ok=%s), level=%d, tick=%d us, delta=%.3f us, udata.t=%q udata[1]=%q (type=%s)",
                       x, _tick, _tick-tick, pin, tostring(pin==pinp), level, tick, delta/1000, userparam.someText, userparam[1], type(userparam))) 
   last_tick = tick
   x = x + 1
end

local userparam = {someText="output pin was:", pout}
gpio.setAlertFuncEx(pinp, alertEx, userparam)

local freq = getNumber("PWM frequency: ", 100)
gpio.setPWMfrequency(pout, freq)
print("PWM frequency:", gpio.getPWMfrequency(pout))
collectgarbage("stop")
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
