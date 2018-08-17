local gpio = require "lgpio"
local util = require "test.test_util"

intro_1()

local pinp, pout = 25, 18

gpio.initialise()

local rc1 = gpio.setMode(pinp, gpio.INPUT) 
local rc2 = gpio.setMode(pout, gpio.OUTPUT)

local last_tick = 0
local x = 1
local function alert(gpio, level, tick)
   print("Alert callback:", x)
   print("gpio     :", gpio, "correct pin:", gpio==pinp)
   print("level    :", level)
   print("tick [us]:", tick, "delta [us]:", tick - last_tick)
   last_tick = tick
   x = x + 1
end

gpio.setAlertFunc(pinp, alert)

local freq = getNumber("PWM frequency [Hz]:", 100)
local wait = getNumber("burst size [ms]:", 200)
local dutymax = 1000000
printf("Start PWM: duty cyle %d (%.1f %%) ...", dutymax * 0.5, (dutymax * 0.5) / dutymax * 100)
io.write("Hit <return> ...") io.flush() io.read()

local rc = gpio.hardwarePWM(pout, freq, dutymax * 0.5)
gpio.delay(wait*1000)
gpio.setMode(pout, gpio.INPUT)

gpio.setMode(pout, gpio.OUTPUT)
gpio.delay(wait*1000)
printf("Start PWM: duty cyle %d (%.1f %%) ...", dutymax * 0.95, (dutymax * 0.95) / dutymax * 100)
io.write("Hit <return> ...") io.flush() io.read()
gpio.hardwarePWM(pout, freq, dutymax * 0.99)
gpio.delay(wait*1000)
gpio.setMode(pout, gpio.INPUT)

gpio.setMode(pout, gpio.OUTPUT)
gpio.delay(wait*1000)
printf("Start PWM: duty cyle %d (%.1f %%) ...", dutymax * 0.05, (dutymax * 0.05) / dutymax * 100)
io.write("Hit <return> ...") io.flush() io.read()
gpio.hardwarePWM(pout, freq, dutymax * 0.01)
gpio.delay(wait*1000)
gpio.setMode(pout, gpio.INPUT)

print("cleanup ...")
gpio.setMode(pout, gpio.INPUT)
gpio.terminate()
