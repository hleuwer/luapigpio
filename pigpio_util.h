#ifndef PIGPIO_UTIL_INCL
#define PIGPIO_UTIL_INCL

#include <pthread.h>
#include "lua.h"
#include "pigpio.h"

#define DEBUG (0)
#define DEBUG2 (0)

#define UPVALUE_IGNORE_UNSUPPORTED (1)

#define TRUE (1)
#define FALSE (0)
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
  void *u;
};
typedef struct alertfuncEx alertfuncEx_t;

struct isrfuncEx {
  gpioISRFuncEx_t f;
  void *u;
};
typedef struct isrfuncEx isrfuncEx_t;

struct timfuncEx {
  gpioTimerFuncEx_t f;
  void *u;
};
typedef struct timfuncEx timfuncEx_t;

struct sigfuncEx {
  gpioSignalFuncEx_t f;
  void *u;
};
typedef struct sigfuncEx sigfuncEx_t;

struct samplefuncEx {
  gpioGetSamplesFuncEx_t f;
  void *u;
};
typedef struct samplefuncEx samplefuncEx_t;

struct threadfunc {
  gpioThreadFunc_t *f;
  lua_State *L;
  int a;
  pthread_t *t;
  char *n;
};
typedef struct threadfunc threadfunc_t;

enum slottype {
               ALERT = 0,
               TIMER = 1,
               ISR = 2,
               SIGNAL = 3,
               SAMPLE = 4
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

struct sampleslot {
  int numsamples;
  gpioSample_t *samples;
  uint32_t tick;
};
typedef struct sampleslot sampleslot_t;

union slot {
  alertslot_t alert;
  timerslot_t timer;
  isrslot_t isr;
  sigslot_t sig;
  sampleslot_t sample;
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
int utlSetGetSamplesFunc(lua_State *L);
int utlStartThread(lua_State *L);
int utlStopThread(lua_State *L);
int utlWaveAddGeneric(lua_State *L);
#endif
