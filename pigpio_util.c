#include "lua.h"
#include "lauxlib.h"

#include "pigpio_util.h"
#include <stdio.h>
#include <stdint.h>
#define DEBUG
#ifdef DEBUG
#define dprintf(...) fprintf(stderr, __VA_ARGS__)
#else
#define dprintf(...)
#endif
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
#ifdef USE_LUAHOOK
   { timerFuncEx0},
   { timerFuncEx1},
   { timerFuncEx2},
   { timerFuncEx3},
   { timerFuncEx4},
   { timerFuncEx5},
   { timerFuncEx6},
   { timerFuncEx7},
   { timerFuncEx8},
   { timerFuncEx9}
#else
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
#endif
  };

#ifdef USE_LUAHOOK
static lua_State *LL = NULL;
static lua_Hook oldhook = NULL;
static int oldmask = 0;
static int oldcount = 0;
static slot_t slots[MAX_SLOTS];
static int nslots = 0;
#endif

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

#ifdef USE_LUAHOOK
/*
 * Occupy a slot in event hook slot table at relative position index.
 */
static void set_slot(unsigned index, slot_t *slot)
{
  unsigned slotindex;
  switch(slot->type){
  case ALERT:
    slotindex = index;
    break;
  case TIMER:
    slotindex = MAX_ALERTS + index;
    break;
  case ISR:
    slotindex = MAX_ALERTS + MAX_TIMERS + index;
    break;
  default:
    luaL_error(LL, "Invalid slot type %d", slot->type);
    break;
  };
  slot->any.valid = SLOT_VALID;
  slots[slotindex] = *slot;
  /* make sure that we never count more than 1 for each slot */
  nslots++;
  dprintf("#3# set_slot: s.t=%d slotindex=%d s.v=0x%08X n=%d\n",
         slot->type, slotindex, slot->any.valid, nslots);
}

/*
 * Get an occupied slot from event hook slot table.
 * Returns pointer to slot descriptor and index of returned event.
 */
static slot_t* get_slot(int *index)
{
  int slotindex;
  slot_t*  slot;
  for (slotindex = 0; slotindex < MAX_SLOTS; slotindex++){
    slot = &slots[slotindex];
    if (slot->any.valid == SLOT_VALID){
      switch(slot->type){
      case ALERT: *index = slotindex; break;
      case TIMER: *index = slotindex - MAX_ALERTS; break;
      case ISR: *index = slotindex - MAX_ALERTS - MAX_TIMERS; break;
      }
      nslots--;
      slot->any.valid = SLOT_INVALID;
      dprintf("#4# get_slot: s.t=%d slotindex=%d n=%d\n", slot->type, slotindex, nslots);
      return slot;
    }
  }
  return NULL;
}

/*
 * Check whether hook slots are empty.
 * Returns 1 if slots are empty, 0 otherwise.
 */
static int check_slot(void)
{
  dprintf("check_slot: %d\n", nslots);
  return nslots == 0;
}

static void init_slot(slottype_t type, unsigned index)
{
  switch(type){
  case ALERT: slots[index].any.valid = SLOT_INVALID; break;
  case TIMER: slots[index + MAX_ALERTS].any.valid = SLOT_INVALID; break;
  case ISR: slots[index + MAX_TIMERS + MAX_ALERTS].any.valid = SLOT_INVALID; break;
  }
}

/*
 * Remind Lua hooks.
 * Must only be called when all lgpio event hook slots are empty. 
 */
static void remind_hooks(lua_State *L)
{
  if (check_slot()){
    /* empty slot table: remind old hook */
    dprintf("remind_hooks\n");
    oldhook = lua_gethook(L);
    oldmask = lua_gethookmask(L);
    oldcount = lua_gethookcount(L);
  }
}

/* 
 * Hook handler:
 * Process all slots with a valid entry and call the corresponding Lua callback.
 * - alert_cb(pin, level, tick)
 * - timer_cb(index)
 * - isr_cb(pin, level, tick)
 * When all callbacks are processed the Lua hook is restored.
 */
static void handler(lua_State *L, lua_Debug *ar)
{
  (void) ar;
  int index = -1;
  slot_t *slot;
  /* process all slots with valid entry */
  dprintf("1 HANDLER\n");
  slot = get_slot(&index);
  dprintf("2 HANDLER: %p\n", slot);
  while (slot != NULL) {
    switch (slot->type){
    case ALERT:
      {
        alertfuncEx_t *cbfunc = &alertfuncsEx[index];
        lua_pushlightuserdata(L, &cbfunc->f);
        lua_gettable(L, LUA_REGISTRYINDEX);
        lua_pushnumber(L, index);
        lua_pushnumber(L, slot->alert.level);
        lua_pushnumber(L, slot->alert.tick);
        lua_call(L, 3, 0);
      }
      break;
    case TIMER:
      {
        timfuncEx_t *cbfunc = &timfuncsEx[index];
        lua_pushlightuserdata(L, &cbfunc->f);
        lua_gettable(L, LUA_REGISTRYINDEX);
        lua_pushnumber(L, index+1);
        lua_call(L, 1, 0);
      }
      break;
    case ISR:
      {
        isrfuncEx_t *cbfunc = &isrfuncsEx[index];
        lua_pushlightuserdata(L, &cbfunc->f);
        lua_gettable(L, LUA_REGISTRYINDEX);
        lua_pushnumber(L, slot->isr.level);
        lua_pushnumber(L, slot->isr.tick);
        lua_call(L, 3, 0);
      }
      break;
    }
    slot = get_slot(&index);
  }
  /* All slots processed: restore old hooks */
  lua_sethook(L, oldhook, oldmask, oldcount);
}
  
/* 
 * Alert event:
 * Put event in the correct Lua hook slot and schedule the hook handler.
 */
static void alertFuncEx(int gpio, int level, uint32_t tick, void *userparam)
{
  lua_State *L = userparam;
  slot_t slot;
  dprintf("#1.1# alert: gpio=%d level=%d tick=%d\n", gpio, level, tick);
  remind_hooks(L);
  slot.type = ALERT;
  slot.alert.level = level;
  slot.alert.tick = tick;
  set_slot(gpio, &slot);
  lua_sethook(L, handler, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
  dprintf("#1.2# alert: hooks set ... \n");
}

/* 
 * Timer event:
 * Put event in the correct Lua hook slot and schedule the hook handler.
 */
static void timerFuncEx(unsigned index, void *userparam)
{
  lua_State *L = userparam;
  slot_t slot;
  unsigned _tick = gpioTick();
  dprintf("#1.1# timer: index=%d\n", index);
  remind_hooks(L);
  slot.type = TIMER;
  set_slot(index, &slot);
  lua_sethook(L, handler, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
  //  dprintf("#1.2# timer: hooks set ... \n");
}

/*
 * Interrupt event:
 * Put event in the correct Lua hook slot and schedule the hook handler.
 */
static void isrFuncEx(int gpio, int level, uint32_t tick, void *userparam)
{
  lua_State *L = userparam;
  slot_t slot;
  remind_hooks(L);
  slot.type = ISR;
  slot.isr.level = level;
  slot.isr.tick = tick;
  set_slot(gpio, &slot);
  lua_sethook(L, handler, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

#else

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
  dprintf("#1# alert: gpio=%d level=%d tick=%d\n", gpio, level, tick);
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
  dprintf("#1# timer: index=%d\n", index);
  lua_pushlightuserdata(L, &cbfunc->f); /* ns: key */
  lua_gettable(L, LUA_REGISTRYINDEX);   /* ns: func */
  lua_pushnumber(L, index + 1);         /* ns: index, func */
  lua_call(L, 1, 0);
}

/*
 * Callback function of IsrEx.
 * Calls Lua callback: luacbEx(gpio, level, tick, userparam)
 */
static void isrFuncEx(int gpio, int level, uint32_t tick, void *userparam)
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
#endif

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
#ifndef USE_LUAHOOK
  cbfunc->L = L;
#endif
  cbfunc->f = alertFuncEx;
  /* memorize lua function in registry */
  lua_pushlightuserdata(L, &cbfunc->f); /* key, func, index */
  lua_pushvalue(L, 2);                  /* func, key, func, index */
  lua_settable(L, LUA_REGISTRYINDEX);   /* func, index */
#ifdef USE_LUAHOOK
  LL = L;
  //init_slot(ALERT, gpio);
  retval = gpioSetAlertFuncEx(gpio, cbfunc->f, L);
#else
  retval = gpioSetAlertFuncEx(gpio, cbfunc->f, cbfunc->L);
#endif
  lua_pushnumber(L, retval);            /* retval, func, index */
  return 1;
}

/*
 * Lua binding: retval, thread = setTimerFunc(index, time, func)
 * Returns: see documentation of gpioSetCbfunc.
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
#ifndef USE_LUAHOOK
    if (cbfunc->L != NULL)
      luaL_error(L, "Timer already running - double start not allowed.");
    lua_pushlightuserdata(L, &cbfunc->L);  /* s: key, func, time, index */
    cbfunc->L = lua_newthread(L);          /* s: thr, key, func, time, index */
    lua_settable(L, LUA_REGISTRYINDEX);    /* s: func, time, index */
#endif
    lua_pushlightuserdata(L, &cbfunc->f);  /* s: key, func, time, index */
    lua_pushvalue(L, 3);                   /* s: func, key, func, time, index */
    lua_settable(L, LUA_REGISTRYINDEX);    /* s: func, time, index */
#ifdef USE_LUAHOOK
    LL = L;
    remind_hooks(L);
    retval = gpioSetTimerFuncEx(index, time, cbfunc->f, L);
#else
    retval = gpioSetTimerFuncEx(index, time, cbfunc->f, cbfunc->L);
#endif
    lua_pushnumber(L, retval);             /* s: res, func, time, index */
    return 1;
  } else {
    /* cancel timer */
#ifdef USE_LUAHOOK
    retval = gpioSetTimerFuncEx(index, time, NULL, L);
#else
    retval = gpioSetTimerFuncEx(index, time, NULL, cbfunc->L);
#endif
    lua_pushnumber(L, retval);              /* res, func, time, index */
#ifndef USE_LUAHOOK
    lua_pushlightuserdata(L, &cbfunc->L);
    lua_pushnil(L);
    lua_settable(L, LUA_REGISTRYINDEX);
#endif
    lua_pushlightuserdata(L, &cbfunc->f);
    lua_pushnil(L);
    lua_settable(L, LUA_REGISTRYINDEX);
#ifndef USE_LUAHOOK
    cbfunc->L = NULL;
#endif
    return 1;
  }
}

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
#ifndef USE_LUAHOOK
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
#endif
    /* memorize lua function in registry using isrfunc struct as index */
    lua_pushlightuserdata(L, &cbfunc->f);      /* key, func, tout, edge, pin */
    lua_pushvalue(L, 4);                   /* func, key, func, tout, edge, pin */
    lua_settable(L, LUA_REGISTRYINDEX);    /* func, tout, edge, ping */
#ifdef USE_LUAHOOK
    LL = L;
    retval = gpioSetISRFuncEx(gpio, edge, timeout, isrFuncEx, L);
#else
    retval = gpioSetISRFuncEx(gpio, edge, timeout, isrFuncEx, cbfunc->L);
#endif
    lua_pushnumber(L, retval);             /* res, thr, func, tout, edge, pin */
    return 1;
  } else {
    /* cancel isr */
#ifdef USE_LUAHOOK
    retval = gpioSetISRFuncEx(gpio, edge, timeout, NULL, L);
#else
    retval = gpioSetISRFuncEx(gpio, edge, timeout, NULL, cbfunc->L);
#endif
    lua_pushnumber(L, retval);
#ifndef USE_LUAHOOK
    /* delete  thread ref in registry */
    lua_pushlightuserdata(L, &cbfunc->L);  /* key, func, tout, edge, pin */
    lua_pushnil(L);                        /* nil, key, func, ... */
    lua_settable(L, LUA_REGISTRYINDEX);    /* func, tout, edge, pin */
#endif
    /* delete func ref in registry */
    lua_pushlightuserdata(L, &cbfunc->f);      /* key, func, ... */
    lua_pushnil(L);                        /* func, key, func, tout, ... */
    lua_settable(L, LUA_REGISTRYINDEX);    /* func, tout, edge, pin */
#ifndef USE_LUAHOOK
    cbfunc->L = NULL;
#endif
    return 1;
  }
}

