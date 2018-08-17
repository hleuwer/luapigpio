#include "lua.h"
#include "lauxlib.h"

#include "pigpio_util.h"
#include <stdio.h>
#include <stdint.h>

/*
 * Forward declaration.
 */
static void timerFuncEx(unsigned index, void *uparam);

/* 
 * Array of alert and ISR callback function entries. We use the address of these entries 
 * as keys into LUAREGISTRYTABLE 
*/
alertfuncEx_t alertfuncsEx[MAX_ALERTS];
isrfuncEx_t isrfuncsEx[MAX_ISRGPIO];

static void timerFuncEx0(void *uparam) { return timerFuncEx(0, uparam); }
static void timerFuncEx1(void *uparam) { return timerFuncEx(1, uparam); }
static void timerFuncEx2(void *uparam) { return timerFuncEx(2, uparam); }
static void timerFuncEx3(void *uparam) { return timerFuncEx(3, uparam); }
static void timerFuncEx4(void *uparam) { return timerFuncEx(4, uparam); }
static void timerFuncEx5(void *uparam) { return timerFuncEx(5, uparam); }
static void timerFuncEx6(void *uparam) { return timerFuncEx(6, uparam); }
static void timerFuncEx7(void *uparam) { return timerFuncEx(7, uparam); }
static void timerFuncEx8(void *uparam) { return timerFuncEx(8, uparam); }
static void timerFuncEx9(void *uparam) { return timerFuncEx(9, uparam); }

timfuncEx_t timfuncsEx[MAX_TIMERS] =
  {
   { NULL, timerFuncEx0},
   { NULL, timerFuncEx1},
   { NULL, timerFuncEx2},
   { NULL, timerFuncEx3},
   { NULL, timerFuncEx4},
   { NULL, timerFuncEx5},
   { NULL, timerFuncEx6},
   { NULL, timerFuncEx7},
   { NULL, timerFuncEx8},
   { NULL, timerFuncEx9}
  };

/*
 * Temporary usage for showing non-implemented bindings.
 * Should vanish once everything is done.
 */
static int  notImplemented(lua_State *L)
{
  luaL_error(L, "Function not yet implemented!");
  return 1;
}

/*
 * Process gpio argument.
 */
static int get_gpio(lua_State *L, int stackindex, unsigned min, unsigned max)
{
  unsigned gpio;
  if (lua_isnumber(L, stackindex) == 0)
    luaL_error(L, "Number expected as arg %d 'GPIO pin', received %s.",
               stackindex, lua_typename(L, lua_type(L, stackindex)));

  gpio = lua_tonumber(L, stackindex);

  if (gpio < min || gpio > max)
    luaL_error(L, "GPIO pin range of 0 to %d exceeded.", MAX_ALERTS - 1);

  return gpio;
}

/*
 * Process timer index parameter.
 */
static unsigned get_timer_index(lua_State *L, unsigned min, unsigned max)
{
  unsigned index;
  
  if (lua_isnumber(L, 1) == 0)  /* func, time, index */
    luaL_error(L, "Number expected as arg 1, received %s.", lua_typename(L, lua_type(L, 1)));
  index = lua_tonumber(L, 1) - 1;

  if ((index < min) || (index > max))
    luaL_error(L, "Invalid timer index %d (allowed = %d .. %d).", index + 1, 1, MAX_TIMERS);

  return index;
}

/*
 * Callback function for alerts.
 * Calls Lua callback luacbEx(gpio, level, tick, userparam).
 */
static void alertFuncEx(int gpio, int level, uint32_t tick, void *userparam)
{
  alertfuncEx_t *cbfunc = &alertfuncsEx[gpio];
  lua_State *L = userparam;
  if (L == NULL)
    return;
  lua_pushlightuserdata(L, &cbfunc->f);  /* key */
  lua_gettable(L, LUA_REGISTRYINDEX);    /* func */
  lua_pushinteger(L, gpio);              /* gpio, func */
  lua_pushinteger(L, level);             /* level gpio, func */
  lua_pushnumber(L, (lua_Number)tick);   /* tick, level, gpio, func */
  lua_call(L, 3, 0);                     /* */
}

/*
 * Callback function for timers: timcb(index)
 */
static void timerFuncEx(unsigned index, void *userparam)
{
  timfuncEx_t *cbfunc = &timfuncsEx[index];
  lua_State *L = userparam;
  lua_pushlightuserdata(L, &cbfunc->f); /* ns: key */
  lua_gettable(L, LUA_REGISTRYINDEX);   /* ns: func */
  lua_pushnumber(L, index + 1);         /* ns: index, func */
  lua_call(L, 1, 0);
}

/*
 * Callback function of IsrEx.
 * Calls Lua callback: luacbEx(gpio, level, tick, userparam)
 */
static void isrFuncEx(int gpio, int level, unsigned int tick, void *userparam)
{
  isrfuncEx_t *cbfunc = &isrfuncsEx[gpio];
  lua_State *L = userparam;
  lua_pushlightuserdata(L, &cbfunc->f);
  lua_gettable(L, LUA_REGISTRYINDEX);  /* ns: func */
  lua_pushinteger(L, gpio);            /* ns: gpio, func */
  lua_pushinteger(L, level);           /* level, gpio, func */
  lua_pushnumber(L, (lua_Number)tick); /* tick, level, gpio, func */
  lua_call(L, 3, 0);
}

/*
 * Lua binding: retval, thread = setTimerFunc(index, time, func)
 * Returns: see documentation of gpioSetCbfunc.
 * If func is not nil, then the Lua thread is also returned in addition to 
 * success code.
 */
int utlSetTimerFunc(lua_State *L)
{
  unsigned index, time;
  timfuncEx_t *cbfunc;
  int retval;

  index = get_timer_index(L, 0, MAX_TIMERS - 1);
  if (lua_isnumber(L, 2) == 0) 
    luaL_error(L, "Number expected as arg 2 'time', received %s.",
               lua_typename(L, lua_type(L, 2)));
  time = lua_tonumber(L, 2);
  if (!lua_isnil(L, 3) && !lua_isfunction(L, 3))
    luaL_error(L, "Function or nil expected as arg 3 'func', received %s.",
               lua_typename(L, lua_type(L, 3)));
  /* func not nil => set timer, func is nil => cancel timter */
  cbfunc = &timfuncsEx[index];
  if (!lua_isnil(L, 3)){
    if (cbfunc->L != NULL)
      luaL_error(L, "Timer already running - double start not allowed.");
    lua_pushlightuserdata(L, &cbfunc->L);  /* s: key, func, time, index */
    cbfunc->L = lua_newthread(L);          /* s: thr, key, func, time, index */
    lua_settable(L, LUA_REGISTRYINDEX);    /* s: func, time, index */
    lua_pushlightuserdata(L, &cbfunc->f);  /* s: key, func, time, index */
    lua_pushvalue(L, 3);                   /* s: func, key, func, time, index */
    lua_settable(L, LUA_REGISTRYINDEX);    /* s: func, time, index */
    retval = gpioSetTimerFuncEx(index, time, cbfunc->f, cbfunc->L);
    lua_pushnumber(L, retval);             /* s: res, func, time, index */
    return 1;
  } else {
    /* cancel timer */
    retval = gpioSetTimerFuncEx(index, time, NULL, cbfunc->L);
    lua_pushnumber(L, retval);              /* res, func, time, index */
    lua_pushlightuserdata(L, &cbfunc->L);
    lua_pushnil(L);
    lua_settable(L, LUA_REGISTRYINDEX);
    lua_pushlightuserdata(L, &cbfunc->f);
    lua_pushnil(L);
    lua_settable(L, LUA_REGISTRYINDEX);
    cbfunc->L = NULL;
    return 1;
  }
}


/*
 * Lua binding: retval = setAlertFunc(gpio, func)
 * Returns: see documentation of gpioSetAlertFunc.
 */
int utlSetAlertFunc(lua_State *L)
{
  unsigned gpio;
  alertfuncEx_t *cbfunc;
  int retval;

  gpio = get_gpio(L, 1, 0, MAX_ALERTS - 1);
  if (lua_isfunction(L, 2) == 0)       /* func, index */ 
    luaL_error(L, "Function expected as arg 2, received %s.", lua_typename(L, lua_type(L, 2)));
  cbfunc = &alertfuncsEx[gpio];
  cbfunc->L = L;
  cbfunc->f = alertFuncEx;
  /* memorize lua function in registry */
  lua_pushlightuserdata(L, &cbfunc->f); /* key, func, index */
  lua_pushvalue(L, 2);                  /* func, key, func, index */
  lua_settable(L, LUA_REGISTRYINDEX);   /* func, index */
  retval = gpioSetAlertFuncEx(gpio, cbfunc->f, cbfunc->L);
  lua_pushnumber(L, retval);            /* retval, func, index */
  return 1;
}
#if 0
/*
 * Lua binding: succ = setAlertFunc(gpio, func, userparam)
 */
int utlSetAlertFuncEx(lua_State *L)
{
  unsigned gpio;
  alertfunc_t *cbfunc;
  userparam_t *cbparam;
  int retval;

  gpio = get_gpio(L, 1, 0, MAX_ALERTS - 1);
  
  cbfunc = &alertfuncs[gpio];
  cbparam = &alertparams[gpio];

  /* memorize user defined parameter in registry */
  lua_pushlightuserdata(L, cbparam);  /* key, userparam, func, gpio */
  lua_pushvalue(L, 3);                /* userparam, key, userparam, func, gpio */
  lua_settable(L, LUA_REGISTRYINDEX);  /* userparam, func, gpio */

  cbfunc->L = L;

  /* memorize lua function in registry */
  lua_pushlightuserdata(L, cbfunc);     /* key, userparam, func, gpio */
  lua_pushvalue(L, 2);                  /* func, key, userparam, func, gpio */
  lua_settable(L, LUA_REGISTRYINDEX);   /* userparam, func, gpio */

  retval = gpioSetAlertFuncEx(gpio, alertFuncEx, (void *) cbparam);

  lua_pushnumber(L, retval);           /* retval, userparam, func, gpio */
  return 1;
}
#endif
/*
 * Lua binding: succ = setISRFunc(pin, edge, timout, func)
 */
int utlSetISRFunc(lua_State *L)
{
  unsigned gpio;
  unsigned edge;
  unsigned timeout;
  isrfuncEx_t *cbfunc;
  int retval;

  gpio = get_gpio(L, 1, 0, MAX_ISRGPIO - 1);
  if (lua_isnumber(L, 2) == 0)      /* func, tout, edge, pin */
    luaL_error(L, "Number expected as arg 2 'edge', received %s.",
               lua_typename(L, lua_type(L, 2)));
  edge = lua_tonumber(L, 2);
  if (lua_isnumber(L, 3) == 0)      /* func, tout, edge, pin */
    luaL_error(L, "Number expected as arg 3 'timeout', received %s.",
               lua_typename(L, lua_type(L, 3)));
  timeout = lua_tonumber(L, 3);
  cbfunc = &isrfuncsEx[gpio];
  if (!lua_isnil(L, 4)) {           /* func, tout, edge, pin */
    lua_pushlightuserdata(L, cbfunc->L);    /* key, func, tout, edge, pin */
    lua_gettable(L, LUA_REGISTRYINDEX);      /* thr_or_nil, func, tout, edge, pin */
    if (lua_isthread(L, -1) == 0){
      /* thread not yet registered: create new one and register  */
      lua_remove(L, -1);                      /* func, tout, ... */
      lua_pushlightuserdata(L, &cbfunc->L);   /* key, func, tout, ... */
      cbfunc->L = lua_newthread(L);           /* thr, key, func, tout, edge, pin */
      /* memorize execution thread in registry - must not be collected */
      lua_settable(L, LUA_REGISTRYINDEX);    /* func, tout, edge, pin */
    } else {
      /* thread already registered: reuse */
      cbfunc->L = lua_tothread(L, -1);      
      lua_remove(L, -1);
    }
    /* memorize lua function in registry using isrfunc struct as index */
    lua_pushlightuserdata(L, &cbfunc->f);      /* key, func, tout, edge, pin */
    lua_pushvalue(L, 4);                   /* func, key, func, tout, edge, pin */
    lua_settable(L, LUA_REGISTRYINDEX);    /* func, tout, edge, ping */
    retval = gpioSetISRFuncEx(gpio, edge, timeout, isrFuncEx, cbfunc->L);
    lua_pushnumber(L, retval);             /* res, thr, func, tout, edge, pin */
    return 1;
  } else {
    /* cancel isr */
    retval = gpioSetISRFuncEx(gpio, edge, timeout, NULL, cbfunc->L);
    lua_pushnumber(L, retval);
    /* delete  thread ref in registry */
    lua_pushlightuserdata(L, &cbfunc->L);  /* key, func, tout, edge, pin */
    lua_pushnil(L);                        /* nil, key, func, ... */
    lua_settable(L, LUA_REGISTRYINDEX);    /* func, tout, edge, pin */
    /* delete func ref in registry */
    lua_pushlightuserdata(L, &cbfunc->f);      /* key, func, ... */
    lua_pushnil(L);                        /* func, key, func, tout, ... */
    lua_settable(L, LUA_REGISTRYINDEX);    /* func, tout, edge, pin */
    cbfunc->L = NULL;
    return 1;
  }
}

