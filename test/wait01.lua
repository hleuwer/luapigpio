local gpio = require "pigpio"

local N = tonumber(os.getenv("n")) or 100
local W = tonumber(os.getenv("w")) or 0.001
local S = tonumber(os.getenv("s")) or 0.001

assert(W >= S, "step time too small (must be >= wait time)")
print(N, W, S)
local t1 = gpio.tick()

for i = 1,N do
  gpio.wait(W, S)
end

local t2 = gpio.tick()
local dT = ((t2-t1)/1e3)/N
print(string.format("n=%d, twait=%.3f ms, dT=%.3f ms, err=%.1f%%",
                    N, W*1000, dT, (1-(W*1000)/dT)*100))
gpio.terminate()
