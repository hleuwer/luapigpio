# LuaPIGPIO
Use Lua to control a Raspberry PI's GPIO pins.

LuaPGPIO is a binding to the [pigpio](https://github.com/joan2937/pigpio) library. 

It provides direct access to the GPIO pins without using the pigpio socket or pipe interface. Hence, Lua scripts must be run as root.

If the daemon `pigpiod` is running after booting your Raspberry PI, you have to stop it before running a LuaPGPIO script:

`$ sudo killall pigpiod`

## General

LuaPIGPIO uses [SWIG](http://www.swig.org/) to automatically generate the binding from pgpio header file pugpio.h. Since all declaration will reside in a dedicated namespace the 'gpio' prefix is removed from the definitions. The pigpio functions gpioWrite() and gpioSetMode() map to gpio.write() and gpio.setMode(), respectively.

Upon loading `pigpio`the pigpio library is implicitely initialized as required. However, termination via `gpio.terminate()' must be called within the user's Lua code.

## Event Handling
LuaPIGPIO provides means to write event handlers functions as Lua functions. This occurs via Lua's debug hook interface in order to avoid pre-emptive call of Lua defined event handlers.
Event issued by pigpio are queued in a linear list for subsequent processing by Lua debug hooks. During execution of such a hook additional events may occur, which are simply stored in the linear list and the processed as debug hooks one after the other.
Each event is tagged with an additional time (tick) parameter in order to keep track of it's occurence. This gives Lua knowledge when the event occured independently on how many events are waiting in the qeueue for further processing.

Events may receive an arbitrary Lua value as an opaque parameter defined by the user.

## Thread Handling
The pigpio library provides a simple interface for starting and stopping threads. LuaPIGPIO associates a separate Lua state with each thread. The new state receives an arbitrary number of arguments which must be of type number, string or boolean. Tables and function must first be externally serialized into a string.

