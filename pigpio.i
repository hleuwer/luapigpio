%module core
%{
#include <stdio.h>
#include "pigpio.h"
#include "pigpio_util.h"
%}
%include <stdint.i>

 // Global renaming - remove 'gpio' prefix because we have a namespace
%rename(PWM) gpioPWM; 
%rename("%(regex:/^(gpio)(.*)/\\l\\2/)s") "";
%rename("%(regex:/^(PI_)(.*)/\\2/)s") "";

// Replacements of native calls
%native (gpioSetAlertFunc) int utlSetAlertFunc(lua_State *L);
%native (gpioSetTimerFunc) int utlSetTimerFunc(lua_State *L);
%native (gpioSetISRFunc) int utlSetISRFunc(lua_State *L);
%native (gpioSetSignalFunc) int utlSetSignalFunc(lua_State *L);
%native (gpioSetGetSamplesFunc) int utlSetGetSamplesFunc(lua_State *L);
%native (gpioStartThread) int utlStartThread(lua_State *L);
%native (gpioStopThread) int utlStopThread(lua_State *L);
%native (gpioWaveAddGeneric) int utlWaveAddGeneric(lua_State *L);
// type mapping
%typemap(in) uint_32_t {
}

// Headers to parse
%include /usr/local/include/pigpio.h 
