local gpio = require "core"

local strbyte = string.byte
local band, bor, lshift, rshift = bit32.band, bit32.bor, bit32.lshift, bit32.rshift
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
-- @param t time to sleep in seconds.
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
-- @param t time to sleep in seconds.
-- @return none.
---
function busyWait(t)
   local n = t * 3 * 1e7
   for i = 1, n do
   end
end

---
-- Convert a notification sample into a table.
---
function decodeNotificationSample(s)
   local t = {}
   t.seqno = strbyte(s,2) * 256 + strbyte(s,1)
   t.flags = strbyte(s,4) * 256 + strbyte(s,3)
   t.tick = strbyte(s,8) * 0x1000000 + strbyte(s,7) * 0x10000 + strbyte(s,6) * 0x100 + strbyte(s,5)
   t.level = strbyte(s,12) * 0x1000000 + strbyte(s,11) * 0x10000 + strbyte(s,10) * 0x100 + strbyte(s,9)
   return t
end

local _waveChain = waveChain
---
-- Construct a binary buffer with chained waveforms and commands
-- from a table definition.
-- @param list Command list for chain.
--
---
function waveChain(list)
   local s = ""
   if type(list) ~= "table" then
      error(strinf.format("Table expected as arg %d, received %s.", type(list)))
   end
   for k, v in ipairs(list) do
      if type(v) == "number" then
         -- this is a wave id
         s = s..string.char(v)
      elseif type(v) == "string" then
         if v == "start" then
            -- 'start' command
            s = s .. string.char(255, 0)
         elseif v == "forever" then
            -- 'forever" command
            s = s .. string.char(255, 3)
         else
            -- 'CMD' param command
            string.gsub(v, "(%w+)%s+(%d+)",
                        function(cmd, param)
                           local p = tonumber(param)
                           local hi, lo = bit32.extract(p, 8, 8), bit32.extract(p, 0, 8)
                           if cmd == "repeat" then
                              -- command 'repeat n"
                              s = s .. string.char(255, 1, lo, hi)
                           elseif cmd == "delay" then
                              -- command 'delay n'
                              s = s .. string.char(255, 2, lo, hi)
                           end
                        end
            )
         end
      else
         error(string.format("Invalid chain command '%s' at position %d.", v, k)) 
      end
   end
   print("#s: ", #s)
   return _waveChain(s, #s)
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
