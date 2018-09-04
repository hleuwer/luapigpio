%module core
%{
#include <stdio.h>
#include "pigpio.h"
#include "pigpio_util.h"
%}
%include <stdint.i>
// Global renaming - remove 'gpio' prefix because we have a namespace
//%rename("%(strip:[PI_])s") "";
//%rename("%(strip:[gpio])s") "";
%rename(PWM) gpioPWM; 
%rename("%(regex:/^(gpio)(.*)/\\l\\2/)s") "";
%rename("%(regex:/^(PI_)(.*)/\\2/)s") "";
//%rename("%(regex:/^(gpio|PI_)(.*)/\\2/)s") "";
// Replacements of native calls
%native (gpioSetAlertFunc) int utlSetAlertFunc(lua_State *L);
//%native (gpioSetAlertFuncEx) int utlSetAlertFuncEx(lua_State *L);
%native (gpioSetISRFunc) int utlSetISRFunc(lua_State *L);
//%native (gpioSetISRFuncEx) int utlSetISRFuncEx(lua_State *L);
%native (gpioSetTimerFunc) int utlSetTimerFunc(lua_State *L);
//%native (gpioSetTimerFuncEx) int utlSetTimerFuncEx(lua_State *L);

// type mapping
%typemap(in) uint_32_t {
}

// Headers to parse
%include /usr/local/include/pigpio.h 
