local gpio = require "pigpio"
local util = require "test.test_util"

local show = tonumber(os.getenv("show")) or 1
local dT = tonumber(os.getenv("dT")) or 100
local N = tonumber(os.getenv("N")) or 1
local T = tonumber(os.getenv("T")) or 2

local min = 60*1e6
local counter = 0
local tcount = {0,0,0,0,0,0,0,0,0,0}
local terror = {0,0,0,0,0,0,0,0,0,0}
local last_timeouts = {}
local sec, msec, usec, tsleep, wait =
   gpio.sec, gpio.msec, gpio.usec, gpio.tsleep, gpio.wait
local printf = util.printf

print(gpio.info())
assert(N <= 10, "max. 10 timers supported!")
assert(dT >= 10, "min. interval of 10 ms violated!")

-- Init pigpio - mandatory
--gpio.initialise()

---
-- One common timeout function used for all timers
---
local function timeout(index, tick, udata)
   local now = gpio.tick()
   local deltaT = now - (last_timeouts[index] or 0)
   last_timeouts[index] = now
   terror[index] = terror[index] + (index * dT*1000 - deltaT)
   tcount[index] = (tcount[index] or 0) + 1
   if show == 1 then
      -- show timer expiration info - long
      printf("Timer %2d expired: count=%4d (%4d us) dT=%7.3f ms terr=%7.3f ms %12s udata[1]=%4d garbage:%.1f kB (%d)",
             index, tcount[index], now-tick, deltaT/1000,  terror[index]/1000/tcount[index],
             udata.someText, udata[1],
             collectgarbage("count"))
   elseif show == 2 then
      -- show timer expirattin as index in a row
      io.stdout:write(index.." ") io.stdout:flush()
   end
   counter = counter + 1
end

---
-- Start the timers.
---
local userparam = {}
for i = 1, N do
   local dTime = i * dT
   userparam[i] = {someText = "tout-"..i.." is: ", dTime}
   local succ= gpio.setTimerFunc(i, dTime, timeout, userparam[i])
   printf("Timer %d started: dT=%d succ=%s tout=%s", i, dTime, tostring(succ), tostring(timeout))
   last_timeouts[i] = gpio.tick()
end

local M = T/tsleep
if show == 3 then
   for i = 1, M do
      io.stdout:write("\r")
      for j = 1, N do
         -- show timer expirations as running counter values
         io.stdout:write(string.format("%4d ", tcount[j]))
      end
      io.stdout:write(string.format(" %5d mem in use: %4.1f kB (%4d)", M-i, collectgarbage("count")))
      wait(tsleep)
   end
else
   wait(T)
end


print()
print("Cancel timers ...")
for i = 1, N do
   local succ = gpio.setTimerFunc(i, i*dT, nil)
   printf("Timer %d stopped: %s", i, tostring(succ))
end

print("Wait a second ...")
wait(1)

print("Timeout counts:")
for i = 1, N do printf("Timer %d: count=%d terr=%.3f ms", i, tcount[i], terror[i]/tcount[i]/1000) end

print("cleanup ...")
gpio.terminate()
