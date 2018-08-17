local gpio = require "lgpio"
local util = require "test.test_util"
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
intro_1()
assert(N <= 10, "max. 10 timers supported!")
assert(dT >= 10, "min. interval of 10 ms violated!")
gpio.initialise()

local function timoutEx(index, udata)
   tcount[index] = (tcount[index] or 0) + 1
   local dT = gpio.tick() - last_timeouts[index]
   last_timeouts[index] = gpio.tick()
   if show == 1 then
      -- show timer expiration info - long
      printf("Timer %2d expired: count=%3d dT=%3.3f ms udata.t=%s udata[1]=%d",
             index, tcount[index], dT/1000, udata.someText, udata[1])
   elseif show == 2 then
      -- show timer expirattin as index in a row
      io.stdout:write(index.." ") io.stdout:flush()
   end
   counter = counter + 1
end

local userparam = {}
for i = 1, N do
   local dTime = i * dT
   userparam[i] = {someText="timeout "..i.." was:", dTime}
   local succ = gpio.setTimerFuncEx(i, dTime, timoutEx, userparam[i])
   printf("Timer %d started: dT=%d succ=%s", i, dTime, tostring(succ))
   last_timeouts[i] = gpio.tick()
end

if show == 3 then
   for i = 1, 500 do
      io.stdout:write("\r")
      for i = 1, N do
         -- show timer expirations as running counter values
         io.stdout:write(string.format("%3d ", tcount[i]))
      end
      gpio.delay(10000)
   end
else
   gpio.delay(5*sec)
end

print()
print("Cancel timers ...")
for i = 1, N do
   local succ = gpio.setTimerFunc(i, i*dT, nil)
   printf("Timer %d stopped: %s", i, tostring(succ))
end

print("Wait a second ...")
gpio.delay(1*sec)

print("Timeout counts:")
for i = 1, N do print("count "..i..":", tcount[i]) end

--collectgarbage("restart")
print("cleanup ...")
gpio.terminate()
