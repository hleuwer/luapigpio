local gpio = require "pigpio"
local util = require "test.test_util"

local wait = gpio.wait
local last_tick = gpio.tick()

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

local freq = util.getNumber("PWM frequency:", 100)

gpio.setPWMfrequency(pout, freq)
printf("PWM frequency: %d", gpio.getPWMfrequency(pout))
printf("Duty cycle range: %d", gpio.getPWMrange(pout))
printf("Duty cycle real range: %d", gpio.getPWMrealRange(pout))

printf("Start PWM: duty cyle 128 (%.1f %%) ...", 128/256 * 100)
io.write("Hit <return> ...") io.flush() io.read()
gpio.setAlertFunc(pinp, alert)
last_tick = gpio.tick()
gpio.PWM(pout, 128)
printf("duty cycle: %d", gpio.getPWMdutycycle(pout))
wait(0.4)
gpio.PWM(pout, 0)
printf("duty cycle: %d", gpio.getPWMdutycycle(pout))

wait(0.2)
printf("Start PWM: duty cyle 255 (%.1f %%) ...", 255/256 * 100)
io.write("Hit <return> ...") io.flush() io.read()
last_tick = gpio.tick()
gpio.PWM(pout, 255)
printf("duty cycle: %d", gpio.getPWMdutycycle(pout))
wait(0.2)
gpio.PWM(pout, 0)
printf("duty cycle: %d", gpio.getPWMdutycycle(pout))

wait(0.2)
printf("Start PWM: duty cyle 1 (%.1f %%) ...", 1/256 * 100)
io.write("Hit <return> ...") io.flush() io.read()
last_tick = gpio.tick()
gpio.PWM(pout, 1)
printf("duty cycle: %d", gpio.getPWMdutycycle(pout))
wait(0.2)
gpio.PWM(pout, 0)
printf("duty cycle: %d", gpio.getPWMdutycycle(pout))

print("cleanup ...")
gpio.setMode(pout, gpio.INPUT)
gpio.terminate()
