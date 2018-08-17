local gpio = require "lgpio"
local util = require "test.test_util"
local socket = require "socket"
local function printf(fmt, ...) print(string.format(fmt, ...)) end
local min = 60*1e6
local sec = 1e6
local msec = 1e6/1000
local usec = 1
local counter = 0
local tcount = {0,0,0,0,0,0,0,0,0,0}
local show = tonumber(os.getenv("show")) or 1
local last_timeouts = {}
local dT = tonumber(os.getenv("dT")) or 100
local N = tonumber(os.getenv("N")) or 2
local gcpause = tonumber(os.getenv("gcpause")) or 200
local gcstep = tonumber(os.getenv("gcstep")) or 200
local gcstop = os.getenv("gcstop") or "no"
local gcdo = os.getenv("gcdo") or "no"
local sockuse = os.getenv("sockuse") or "no"
local T = tonumber(os.getenv("T")) or 5

local function sleep(t)
   if sockuse == "yes" then
      socket.sleep(t)
   else
      gpio.delay(t*sec)
   end
end

intro_1()
assert(N <= 10, "max. 10 timers supported!")
assert(dT >= 10, "min. interval of 10 ms violated!")
gpio.initialise()

local function timeout(index)
   tcount[index] = (tcount[index] or 0) + 1
   local dT = gpio.tick() - last_timeouts[index]
   last_timeouts[index] = gpio.tick()
   if show == 1 then
      -- show timer expiration info - long
      printf("Timer %2d expired: count=%3d dT=%3.3f ms garbage:%.1f kB (%d)",
             index, tcount[index], dT/1000, collectgarbage("count"))
   elseif show == 2 then
      -- show timer expirattin as index in a row
      io.stdout:write(index.." ") io.stdout:flush()
   end
   counter = counter + 1
end

print("Config garbage collector: "..gcstop.." ...")
if gcstop == "yes" then
   collectgarbage("stop")
elseif gcstop == "gen" then
   collectgarbage("generational")
elseif gcstop == "set" then
   print(string.format("Set gc pause   ... was: %d", collectgarbage("setpause", gcpause)))
   print(string.format("Set gc stepmul ... was: %d", collectgarbage("setstepmul", gcstep)))
end
print(string.format("Registry: %s ...", tostring(debug.getregistry())))
for i = 1, N do
   local dTime = i * dT
   print("#1#", timeout)
   local succ= gpio.setTimerFunc(i, dTime, timeout)
   printf("Timer %d started: dT=%d succ=%s tout=%s", i, dTime, tostring(succ), tostring(timeout))
   last_timeouts[i] = gpio.tick()
end

sleep(1)
local M = T*1000*0.1
if show == 3 then
   for i = 1, M do
      io.stdout:write("\r")
      for i = 1, N do
         -- show timer expirations as running counter values
         io.stdout:write(string.format("%4d ", tcount[i]))
      end
      io.stdout:write(string.format(" mem in use: %4.1f kB (%4d)", collectgarbage("count")))
      sleep(0.01)
      if gcdo == "yes" then
         collectgarbage("collect")
      end
   end
else
   sleep(T)
end

if gcstop == "yes" then
   collectgarbage("restart")
end


print()
print("Cancel timers ...")
for i = 1, N do
   local succ = gpio.setTimerFunc(i, i*dT, nil)
   printf("Timer %d stopped: %s", i, tostring(succ))
end

print("Wait a second ...")
sleep(1)

print("Timeout counts:")
for i = 1, N do print("count "..i..":", tcount[i]) end

print("cleanup ...")
gpio.terminate()
