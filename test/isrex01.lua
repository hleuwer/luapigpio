local gpio = require "lgpio"
local util = require "test.test_util"
local sec = 1e6
local msec = sec/1000
intro_1()

local pinp, pout = 20, 21

gpio.initialise()

gpio.setMode(pinp, gpio.INPUT)
gpio.setMode(pout, gpio.OUTPUT)
local x = 1
local last_tick

local function isrEx(pin, level, tick, userparam)
   local _tick = gpio.tick()
   local delta = tick - last_tick
   last_tick = tick
   local inbits = gpio.read_Bits_0_31()
   if level == gpio.TIMEOUT then
      print(string.format("TIMEOUT %3d at %d (%4d): gpio=%d (ok=%s), level=%d (%08x), tick=%d us, delta=%.3f us udata.t=%q, udata[1]=%q udata.s=%q",
                          x, _tick, _tick-tick, pin, tostring(pin==pinp), level, inbits, tick, delta/1000,
                          userparam.someText, userparam[1], userparam.specText))
   else
      print(string.format("ISR cb %3d at %d (%4d): gpio=%d (ok=%s), level=%d (%08x), tick=%d us, delta=%.3f us udata.t=%q, udata[1]=%q udata.s=%q",
                          x, _tick, _tick-tick, pin, tostring(pin==pinp), level, inbits, tick, delta/1000,
                          userparam.someText, userparam[1], userparam.specText))
   end
   x = x + 1
end

local N = getNumber("Number of transitions: ", 30)
local ton = getNumber("T_on [ms]: ", 10)
local toff = getNumber("T_off [ms] ", 10)

print("T_on:", ton)
print("T_off:", toff)

print("Setup ISR callbacks ...")

local userparam = {someText="ISR pin was:", pout, specText="-"}
userparam.specText = "rising edge"
gpio.setISRFuncEx(pinp, gpio.RISING_EDGE, 500, isrEx, userparam)

print("  rising edge")
last_tick = gpio.tick()

for i = 1, N/2 do
   if i == 5 then
      print("  falling edge ...")
      userparam.specText = "falling edge"
      gpio.setISRFuncEx(pinp, gpio.FALLING_EDGE, 500, isrEx, userparam)
   elseif i == 10 then
      print("  either edge ...")
      userparam.specText = "either edge"
      gpio.setISRFuncEx(pinp, gpio.EITHER_EDGE, 500, isrEx, userparam)
   end
   print("  set 1 now")
   gpio.write(pout, 1)
   gpio.delay(ton * math.random(800,1200))

   print("  set 0 now")
   gpio.write(pout, 0)
   gpio.delay(toff * math.random(800,1200))
end

print("Checking timeout (waiting 1.2 sec) ...")
gpio.delay(0.9*sec)

print("Cancel timeouts ...")
gpio.setISRFuncEx(pinp, gpio.RISING_EDGE, 0, isrEx, userparam)

print("Cancel ISR callbacks ...")
gpio.setISRFuncEx(pinp, gpio.RISING_EDGE, 0, nil, userparam)

print("Wait a second ...")
gpio.delay(1*sec)

print("cleanup ...")
gpio.setMode(pout, gpio.INPUT)
gpio.terminate()
