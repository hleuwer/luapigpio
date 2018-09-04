local gpio = require "core"

_ENV = setmetatable(gpio, {__index = _G})

tsleep = 0.001
sec = 1e6
msec = 1000
us = 1

-- Initialize the pigpio library.
initialise()

---
-- Info for Raspberry Pi GPIO functionality.
---
function info()
   return [[
Raspberry Pi 3 GPIO information:
===================================================================================================
    PWM (pulse-width modulation)
        Software PWM available on all pins
        Hardware PWM available on GPIO12, GPIO13, GPIO18, GPIO19
    SPI
        SPI0: MOSI (GPIO10); MISO (GPIO9); SCLK (GPIO11); CE0 (GPIO8), CE1 (GPIO7)
        SPI1: MOSI (GPIO20); MISO (GPIO19); SCLK (GPIO21); CE0 (GPIO18); CE1 (GPIO17); CE2 (GPIO16)
    I2C
        Data: (GPIO2); Clock (GPIO3)
        EEPROM Data: (GPIO0); EEPROM Clock (GPIO1)
    Serial
        TX (GPIO14); RX (GPIO15)
===================================================================================================
]]
end

---
-- Wait for a while.
-- @param t time to sleep in milliseconds.
-- @return none.
---
function wait(t, ts)
   local ts = (ts or tsleep) * 1e6
   local n = t / ts * 1e6
   for i = 1, n do
      gpio.delay(ts)
   end
end

---
-- Busy wait for a while.
---
function busyWait(t)
   local n = t * 3 * 1e7
   for i = 1, n do
   end
end

return _ENV
