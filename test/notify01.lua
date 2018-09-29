local gpio = require "pigpio"
local util = require "test.test_util"
local posix = require "posix"
local wait = gpio.wait

print(gpio.info())

local pinp, pout = 20, 21

gpio.initialise()

local x = 1
local last_tick

local handle = gpio.notifyOpen()
local fname = "/dev/pigpio"..handle
--local fh = io.open(fname, "r")
local fd = posix.open(fname, posix.O_RDONLY)
---
--Alert callback.
---
local function alert(pin, level, tick)
   local _tick = gpio.tick()
   local delta = tick - last_tick
   last_tick = tick
   local inbits = gpio.read_Bits_0_31()
   print(string.format("alert cb %3d at %d (%4d us): gpio=%d (ok=%s), level=%d (%08x), tick=%d us, delta=%.3f ms gc=%.1f (%d)",
                       x, _tick, _tick-tick, pin, tostring(pin==pinp), level, inbits, tick, delta/1000,
                       collectgarbage("count")))
   x = x + 1
end

print("set pin pullup ...")
gpio.setPullUpDown(pinp, gpio.PUD_UP)
print("set pin to input ...")
gpio.setMode(pinp, gpio.INPUT)
print("set pout to output ...")
gpio.setMode(pout, gpio.OUTPUT)
--print("preset 1 ...")
--gpio.write(pout, 1)

local N = util.getNumber("Number of transitions: ", 20)
local ton = util.getNumber("T_on [ms]: ", 10)
local toff = util.getNumber("T_off [ms] ", 10)
local bitmode = util.getString("Bit mode (yes/no): ", "yes")
print("T_on:", ton)
print("T_off:", toff)
print("Bitmode:", bitmode)

print("set alert func ...")

gpio.setAlertFunc(pinp, alert)
gpio.notifyBegin(handle, bit32.lshift(1, pinp))

last_tick = gpio.tick()
local last_tick2 = last_tick
for i = 1, N do
--   print("set 1")
   if bitmode == "yes" then
      gpio.write(pout, 1)
   else
      gpio.write_Bits_0_31_Set(bit32.lshift(1,pout))
   end
   wait(ton/1000)
   --   gpio.delay(ton*1000)
--   print("set 0")
   if bitmode == "yes" then
      gpio.write_Bits_0_31_Clear(bit32.lshift(1, pout))
   else
      gpio.write(pout, 0)
   end
   wait(toff/1000)
--   gpio.delay(toff*1000)
   --   collectgarbage("collect")
   if i == 5 then gpio.notifyPause(handle) end
   if i == N-5 then gpio.notifyBegin(handle, bit32.lshift(1,pinp)) end
end

print("Reading notification buffer ...")
while posix.rpoll(fd, 100) == 1 do
   local s = posix.read(fd, 12)
   local t = gpio.decodeNotificationSample(s)
   print(string.format("sample %d: flags=%04X tick=%d level=%08X dt=%d",
                       t.seqno, t.flags, t.tick, t.level, t.tick - last_tick2))
   last_tick2 = t.tick
end

print("close notification ...")
gpio.notifyClose(handle)

print("wait a second ...")
gpio.wait(1)

print("cleanup ...")
gpio.setMode(pout, gpio.INPUT)
gpio.terminate()
