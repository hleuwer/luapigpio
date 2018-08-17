function printf(fmt, ...) print(string.format(fmt, ...)) end

function getNumber(prompt, default)
   local n
   repeat
      io.write(string.format("%s [%.2f]: ", prompt, default))
      io.flush()
      local s = io.read("*l")
      if #s == 0 then
         return default
      end
      n = tonumber(s)
   until type(n) == "number"
--   print(n, type(n))
   return n
end

function getString(prompt, default)
   local n
   io.write(string.format("%s [%s]: ", prompt, default))
   io.flush()
   local s = io.read("*l")
   if #s == 0 then
      return default
   end
   return s   
end

function intro_1()
   printf("%s",[[
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
]])
end
