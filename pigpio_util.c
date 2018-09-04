#include "lua.h"
#include "lauxlib.h"

#include "pigpio_util.h"
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

//#define DEBUG
#if DEBUG == 1
#define dprintf(...) fprintf(stderr, __VA_ARGS__)
#else
#define dprintf(...)
#endif

#if DEBUG2 == 1
#define dprintf2(...) fprintf(stderr, __VA_ARGS__)
#else
#define dprintf2(...)
#endif
/*
 * Forward declaration.
 */
static void timerFuncEx(unsigned index, void *uparam);
static int enqueue(anchor_t* anchor, event_t *event);
static event_t* dequeue(anchor_t* anchor);

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
  };

static lua_State *LL = NULL;
static lua_Hook oldhook = NULL;
static int oldmask = 0;
static int oldcount = 0;
//static slot_t slots[MAX_SLOTS];
//static int nslots = 0;
static anchor_t anchor = {NULL, NULL, 0, LIMIT_EVENT_QUEUE};
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
 * Remind Lua hooks.
 * Must only be called when all lgpio event hook slots are empty. 
 */
static void remind_hooks(lua_State *L)
{
  if (anchor.count == 0){
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
  event_t *event;
  event = dequeue(&anchor);
  dprintf("HANDLER 1: %p qlen=%d qfirst=%p qlast=%p\n",
          event, anchor.count, anchor.first, anchor.last);
  while (event != NULL) {
    switch (event->type){
    case ALERT:
      {
        alertfuncEx_t *cbfunc = &alertfuncsEx[event->slot.alert.index];
        lua_pushlightuserdata(L, &cbfunc->f);
        lua_gettable(L, LUA_REGISTRYINDEX);
        lua_pushnumber(L, event->slot.alert.index);
        lua_pushnumber(L, event->slot.alert.level);
        lua_pushnumber(L, event->slot.alert.tick);
        lua_call(L, 3, 0);
      }
      break;
    case TIMER:
      {
        timfuncEx_t *cbfunc = &timfuncsEx[event->slot.timer.index];
        dprintf("HANDLER 2: ev.index=%d ev.tick=%d\n",
               event->slot.timer.index, event->slot.timer.tick);
        lua_pushlightuserdata(L, &cbfunc->f);
        lua_gettable(L, LUA_REGISTRYINDEX);
        lua_pushnumber(L, event->slot.timer.index+1);
        lua_pushnumber(L, event->slot.timer.tick);
        lua_call(L, 2, 0);
      }
      break;
    case ISR:
      {
        isrfuncEx_t *cbfunc = &isrfuncsEx[event->slot.isr.index];
        lua_pushlightuserdata(L, &cbfunc->f);
        lua_gettable(L, LUA_REGISTRYINDEX);
        lua_pushnumber(L, event->slot.isr.index);
        lua_pushnumber(L, event->slot.isr.level);
        lua_pushnumber(L, event->slot.isr.tick);
        lua_call(L, 3, 0);
      }
      break;
    }
    dprintf("HANDLER 3: almost done. qlen=%d qfirst=%p qlast=%p\n",
            anchor.count, anchor.first, anchor.last);
    free(event);
    event = dequeue(&anchor);
    dprintf("HANDLER 3: %p qlen=%d qfirst=%p qlast=%p\n",
            event, anchor.count, anchor.first, anchor.last);
  }
  /* All slots processed: restore old hooks */
  lua_sethook(L, oldhook, oldmask, oldcount);
}

/*
 * Append event to tail of event queue.
 */
static int enqueue(anchor_t* anchor, event_t* event)
{
  if (anchor->count < anchor->limit){
    if (anchor->count++ == 0)
      /* list empty: event becomes first in queue */
      anchor->first = anchor->last = event;
    else {
      /* append event at tail */
      anchor->last->next = event;
      anchor->last = event;
    }
    dprintf2("eq: %d\n", anchor->count);
    return 0;
  } else {
    anchor->drop++;
    dprintf2("eq: %d drop\n", anchor->count);
    return -1;
  }
  
}

/*
 * Pop an event from head of event queue.
 */
static event_t* dequeue(anchor_t* anchor)
{
  event_t* current;
  if (anchor->count-- == 0){
    anchor->count = 0;
    return NULL;
  }
  current = anchor->first;
  anchor->first = current->next;
  dprintf2("dq: %d\n", anchor->count);
  return current;
}
    

/* 
 * Alert event:
 * Put event in the correct Lua hook slot and schedule the hook handler.
 */
static void alertFuncEx(int gpio, int level, uint32_t tick, void *userparam)
{
  lua_State *L = userparam;
  event_t *event;
  dprintf("alert: gpio=%d level=%d tick=%d qlen=%d\n", gpio, level, tick, anchor.count);
  remind_hooks(L);
  event = malloc(sizeof(event_t));
  event->type = ALERT;
  event->slot.alert.index = gpio;
  event->slot.alert.level = level;
  event->slot.alert.tick = tick;
  enqueue(&anchor, event);
  lua_sethook(L, handler, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

/* 
 * Timer event:
 * Put event in the correct Lua hook slot and schedule the hook handler.
 */
static void timerFuncEx(unsigned index, void *userparam)
{
  lua_State *L = userparam;
  event_t *event;
  uint32_t tick = gpioTick();
  dprintf("timer: index=%d qlen:%d\n", index, anchor.count);
  remind_hooks(L);
  event = malloc(sizeof(event_t));
  event->type = TIMER;
  event->slot.timer.index = index;
  event->slot.timer.tick = tick;
  enqueue(&anchor, event);
  lua_sethook(L, handler, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

/*
 * Interrupt event:
 * Put event in the correct Lua hook slot and schedule the hook handler.
 */
static void isrFuncEx(int gpio, int level, uint32_t tick, void *userparam)
{
  lua_State *L = userparam;
  event_t *event;
  dprintf("isr: gpio=%d level=%d tick=%d qlen=%d\n", gpio, level, tick, anchor.count);
  remind_hooks(L);
  event = malloc(sizeof(event_t));
  event->type = ISR;
  event->slot.isr.index = gpio;
  event->slot.isr.level = level;
  event->slot.isr.tick = tick;
  enqueue(&anchor, event);
  lua_sethook(L, handler, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
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
  cbfunc->f = alertFuncEx;
  /* memorize lua function in registry */
  lua_pushlightuserdata(L, &cbfunc->f); /* key, func, index */
  lua_pushvalue(L, 2);                  /* func, key, func, index */
  lua_settable(L, LUA_REGISTRYINDEX);   /* func, index */
  LL = L;
  //init_slot(ALERT, gpio);
  retval = gpioSetAlertFuncEx(gpio, cbfunc->f, L);
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
    lua_pushlightuserdata(L, &cbfunc->f);  /* s: key, func, time, index */
    lua_pushvalue(L, 3);                   /* s: func, key, func, time, index */
    lua_settable(L, LUA_REGISTRYINDEX);    /* s: func, time, index */
    LL = L;
    remind_hooks(L);
    retval = gpioSetTimerFuncEx(index, time, cbfunc->f, L);
    lua_pushnumber(L, retval);             /* s: res, func, time, index */
    return 1;
  } else {
    /* cancel timer */
    retval = gpioSetTimerFuncEx(index, time, NULL, L);
    lua_pushnumber(L, retval);              /* res, func, time, index */
    lua_pushlightuserdata(L, &cbfunc->f);
    lua_pushnil(L);
    lua_settable(L, LUA_REGISTRYINDEX);
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
    /* memorize lua function in registry using isrfunc struct as index */
    lua_pushlightuserdata(L, &cbfunc->f);      /* key, func, tout, edge, pin */
    lua_pushvalue(L, 4);                   /* func, key, func, tout, edge, pin */
    lua_settable(L, LUA_REGISTRYINDEX);    /* func, tout, edge, pin */
    LL = L;
    retval = gpioSetISRFuncEx(gpio, edge, timeout, isrFuncEx, L);
    lua_pushnumber(L, retval);             /* res, thr, func, tout, edge, pin */
    return 1;
  } else {
    /* cancel isr */
    retval = gpioSetISRFuncEx(gpio, edge, timeout, NULL, L);
    lua_pushnumber(L, retval);
    /* delete func ref in registry */
    lua_pushlightuserdata(L, &cbfunc->f);      /* key, func, ... */
    lua_pushnil(L);                        /* func, key, func, tout, ... */
    lua_settable(L, LUA_REGISTRYINDEX);    /* func, tout, edge, pin */
    return 1;
  }
}

