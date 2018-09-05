#ifndef PIGPIO_UTIL_INCL
#define PIGPIO_UTIL_INCL

#include "lua.h"
#include "pigpio.h"

#define DEBUG (0)
#define DEBUG2 (0)
#define LIMIT_EVENT_QUEUE (100)

#define MAX_ALERTS (32)
#define MAX_TIMERS (10)
#define MAX_ISRGPIO (54)
#define MAX_SIGNALS (64)


#define OFFS_TIMERS (MAX_ALERTS)
#define OFFS_ALERTS (0)
#define OFFS_ISRGPIO (MAX_ALERTS + MAX_TIMERS)

#define MAX_SLOTS (MAX_ALERTS + MAX_TIMERS + MAX_ISRGPIO)
#define SLOT_VALID (0xFFC0FFEE)
#define SLOT_INVALID (0x00000000)

struct alertfuncEx {
  gpioAlertFuncEx_t f;
};
typedef struct alertfuncEx alertfuncEx_t;

struct isrfuncEx {
  gpioISRFuncEx_t f;
};
typedef struct isrfuncEx isrfuncEx_t;

struct timfuncEx {
  gpioTimerFuncEx_t f;
};
typedef struct timfuncEx timfuncEx_t;

struct sigfuncEx {
  gpioSignalFuncEx_t f;
};
typedef struct sigfuncEx sigfuncEx_t;

enum slottype {
               ALERT = 0,
               TIMER = 1,
               ISR = 2,
               SIGNAL = 3
};
typedef enum slottype slottype_t;

struct timerslot {
  unsigned index;
  uint32_t tick;
};
typedef struct timerslot timerslot_t;

struct alertslot {
  unsigned index;
  int level;
  uint32_t tick;
};
typedef struct alertslot alertslot_t;

struct isrslot {
  unsigned index;
  int level;
  uint32_t tick;
};
typedef struct isrslot isrslot_t;

struct sigslot {
  unsigned signum;
  uint32_t tick;
};
typedef struct sigslot sigslot_t;

union slot {
  alertslot_t alert;
  timerslot_t timer;
  isrslot_t isr;
  sigslot_t sig;
};
typedef union slot slot_t;

struct event {
  slottype_t type;
  struct event *next;
  slot_t slot;
};
typedef struct event event_t;

struct anchor {
  event_t *first;
  event_t *last;
  int count;
  int limit;
  unsigned long drop;
};
typedef struct anchor anchor_t;

int utlSetAlertFunc(lua_State *L);
int utlSetISRFunc(lua_State *L);
int utlSetTimerFunc(lua_State *L);
int utlSetSignalFunc(lua_State *L);
#endif
