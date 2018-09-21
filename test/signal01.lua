local gpio = require "pigpio"
local util = require "test.test_util"
local sig = require "posix.signal"

local wait = gpio.wait
local signalnumber = sig.SIGUSR1

print(gpio.info())

local pinp, pout = 20, 21
local twait = tonumber(os.getenv("w")) or 0.1
local N = tonumber(os.getenv("N") or 10)

gpio.initialise()

local x = 1
local last_tick

---
--Alert callback.
---
local function sighandler(signum, tick)
   local _tick = gpio.tick()
   local delta = tick - last_tick
   last_tick = tick
   print(string.format("signal cb %3d at %d (%4d us): signum=%d, tick=%d us, delta=%.3f ms gc=%.1f (%d)",
                       x, _tick, _tick-tick, signum, tick, delta/1000,
                       collectgarbage("count")))
   x = x + 1
end
local function sighandler2(signum, tick)
   print(string.format("SIGINT %d at %d - terminating ...", signum, tick))
   gpio.terminate()
   os.exit(1)
end

N = util.getNumber("Number of signal events: ", N)

print("set signal handler func ...")

gpio.setSignalFunc(signalnumber, sighandler)
gpio.setSignalFunc(sig.SIGINT, sighandler2)

last_tick = gpio.tick()
for i = 1, N do
   print("raise signal "..signalnumber .." ...")
   sig.raise(signalnumber)
   wait(twait)
end

print("Cancel signal handlers ...")
gpio.setSignalFunc(signalnumber, nil)

print("cleanup ...")
gpio.terminate()
