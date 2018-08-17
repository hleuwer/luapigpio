#ifndef PIGPIO_UTIL_INCL
#define PIGPIO_UTIL_INCL

#include "lua.h"
#include "pigpio.h"

#define MAX_ALERTS (32)
#define MAX_TIMERS (10)
#define MAX_ISRGPIO (54)


struct alertfuncEx {
  lua_State *L;
  gpioAlertFuncEx_t f;
};
typedef struct alertfuncEx alertfuncEx_t;

struct isrfuncEx {
  lua_State *L;
  gpioISRFuncEx_t f;
};
typedef struct isrfuncEx isrfuncEx_t;

struct timfuncEx {
  lua_State *L;
  gpioTimerFuncEx_t f;
};
typedef struct timfuncEx timfuncEx_t;

int utlSetAlertFunc(lua_State *L);
int utlSetISRFunc(lua_State *L);
int utlSetTimerFunc(lua_State *L);
#endif
