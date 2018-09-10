local gpio = require "pigpio"
local util = require "test.test_util"

print(gpio.info())

local pinp, pout = 25, 18

gpio.initialise()

local rc1 = gpio.setMode(pinp, gpio.INPUT) 
local rc2 = gpio.setMode(pout, gpio.OUTPUT)

local last_tick = gpio.tick()
local count = 1
local function alert(pin, level, tick, udata)
   local _tick = gpio.tick()
   local delta = tick - last_tick
   last_tick = tick
   print(string.format("alert cb %3d at %d (%4d us): pin=%d (ok=%s), level=%d, tick=%d us, delta=%.3f ms duty=%d",
                       count, _tick, _tick-tick, pin, tostring(pin==pinp), level, tick, delta/1000, udata.duty))
   count = count + 1
end


local freq = util.getNumber("PWM frequency [Hz]:", 100)
local wait = util.getNumber("burst size [ms]:", 200)
local dutymax = 1000000
local udata = {duty = dutymax * 0.5}
printf("Duty cycle range: %d", gpio.getPWMrange(pout))

printf("Start PWM: duty cyle %d (%.1f %%) ...", dutymax * 0.5, (dutymax * 0.5) / dutymax * 100)
io.write("Hit <return> ...") io.flush() io.read()
gpio.setAlertFunc(pinp, alert, udata)
last_tick = gpio.tick()

local rc = gpio.hardwarePWM(pout, freq, dutymax * 0.5)
gpio.wait(wait/1000)
gpio.setMode(pout, gpio.INPUT)
gpio.setMode(pout, gpio.OUTPUT)
gpio.wait(wait/1000)
udata.duty = dutymax * 0.99
printf("Start PWM: duty cyle %d (%.1f %%) ...", dutymax * 0.99, (dutymax * 0.99) / dutymax * 100)
io.write("Hit <return> ...") io.flush() io.read()
last_tick = gpio.tick()
gpio.hardwarePWM(pout, freq, dutymax * 0.99)
gpio.wait(wait/1000)
gpio.setMode(pout, gpio.INPUT)

gpio.setMode(pout, gpio.OUTPUT)
gpio.wait(wait/1000)
udata.duty = dutymax * 0.01
printf("Start PWM: duty cyle %d (%.1f %%) ...", dutymax * 0.01, (dutymax * 0.01) / dutymax * 100)
io.write("Hit <return> ...") io.flush() io.read()
last_tick = gpio.tick()
gpio.hardwarePWM(pout, freq, dutymax * 0.01)
gpio.wait(wait/1000)
gpio.setMode(pout, gpio.INPUT)

print("cleanup ...")
gpio.setMode(pout, gpio.INPUT)
gpio.terminate()
