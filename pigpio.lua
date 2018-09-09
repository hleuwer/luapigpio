local gpio = require "core"

_ENV = setmetatable(gpio, {__index = _G})

tsleep = 0.001
sec = 1e6
msec = 1000
us = 1

-- signals
local sig = {
   SIGHUP  =  1,
   SIGINT  =  2,
   SIGQUIT =  3,
   SIGILL  =  4,
   SIGTRAP =  5,
   SIGABRT =  6,
   SIGBUS  =  7,
   SIGFPE  =  8,
   SIGKILL =  9,
   SIGUSR1 = 10,
   SIGSEGV = 11,
   SIGUSR2 = 12,
   SIGPIPE = 13,
   SIGALRM = 14,
   SIGTERM = 15,
   SIGCHLD = 17,
   SIGCONT = 18,
   SIGSTOP = 19,
   SIGTSTP = 20,
   SIGTTOU = 22,
   SIGTTIN = 21,
   SIGURG  = 23,
   SIGXCPU = 24,
   SIGXFSZ = 25,
   SIGVTALRM = 26,
   SIGSYS  = 31,
}

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

---
-- Install signal handler for
-- - SIGINT (CTRL-C)
---
local function _sighandler(signum, tick)
   if signum == sig.SIGINT then
      io.stderr:write("SIGINT detected: terminate pigpio ...\n")
      terminate()
      os.exit(1)
   end
end

setSignalFunc(sig.SIGINT, _sighandler)

return _ENV
