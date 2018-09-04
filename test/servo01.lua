local gpio = require "pigpio"
local util = require "test.test_util"

local wait = gpio.wait
local last_tick = gpio.tick()

local step = tonumber(os.getenv("p")) or 1500
local freq = tonumber(os.getenv("f")) or 20

print(gpio.info())

local pinp, pout = 20, 21

gpio.initialise()

gpio.setMode(pinp, gpio.INPUT)
gpio.setMode(pout, gpio.OUTPUT)

local count = 1
local function alert(pin, level, tick)
   local _tick = gpio.tick()
   local delta = tick - last_tick
   last_tick = tick
   print(string.format("alert cb %3d at %d (%4d us): pin=%d (ok=%s), level=%d, tick=%d us, delta=%.3f ms",
                       count, _tick, _tick-tick, pin, tostring(pin==pinp), level, tick, delta/1000))
   count = count + 1
end

local freq = util.getNumber("Frequency [Hz]:", freq)
local step = util.getNumber("PulseWidth [500..2500]:", step)
gpio.setPWMfrequency(pout, freq)
assert(gpio.servo(pout, step)==0, "invalid pulsewidth")
printf("PWM frequency: %d", gpio.getPWMfrequency(pout))
printf("Pulse width: %d", gpio.getServoPulsewidth(pout))


last_tick = gpio.tick()
gpio.setAlertFunc(pinp, alert)
wait(0.2)

print("cleanup ...")
gpio.setMode(pout, gpio.INPUT)
gpio.terminate()
