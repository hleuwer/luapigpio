#ifndef PIGPIO_UTIL_INCL
#define PIGPIO_UTIL_INCL

#include "lua.h"
#include "pigpio.h"

#define USE_LUAHOOK

#define MAX_ALERTS (32)
#define MAX_TIMERS (10)
#define MAX_ISRGPIO (54)

#ifdef USE_LUAHOOK

#define OFFS_TIMERS (MAX_ALERTS)
#define OFFS_ALERTS (0)
#define OFFS_ISRGPIO (MAX_ALERTS + MAX_TIMERS)

#define MAX_SLOTS (MAX_ALERTS + MAX_TIMERS + MAX_ISRGPIO)
#define SLOT_VALID (0xFFC0FFEE)
#define SLOT_INVALID (0x00000000)

struct alertfuncEx {
#ifndef USE_LUAHOOK
  lua_State *L;
#endif
  gpioAlertFuncEx_t f;
};
typedef struct alertfuncEx alertfuncEx_t;

struct isrfuncEx {
#ifndef USE_LUAHOOK
  lua_State *L;
#endif
  gpioISRFuncEx_t f;
};
typedef struct isrfuncEx isrfuncEx_t;

struct timfuncEx {
#ifndef USE_LUAHOOK
  lua_State *L;
#endif
  gpioTimerFuncEx_t f;
};
typedef struct timfuncEx timfuncEx_t;

enum slottype {
               ALERT = 0,
               TIMER = 1,
               ISR = 2,
};
typedef enum slottype slottype_t;

struct anyslot {
  slottype_t type;
  unsigned valid;
  unsigned index;
};
typedef struct anyslot anyslot_t;

struct timerslot {
  slottype_t type;
  unsigned valid;
};
typedef struct timerslot timerslot_t;

struct alertslot {
  slottype_t type;
  unsigned valid;
  int level;
  uint32_t tick;
};
typedef struct alertslot alertslot_t;

struct isrslot {
  slottype_t type;
  unsigned valid;
  int level;
  uint32_t tick;
};
typedef struct isrslot isrslot_t;

union slot {
  slottype_t type;
  anyslot_t any; 
  alertslot_t alert;
  timerslot_t timer;
  isrslot_t isr;
};
typedef union slot slot_t;

#endif

int utlSetAlertFunc(lua_State *L);
int utlSetISRFunc(lua_State *L);
int utlSetTimerFunc(lua_State *L);
#endif
