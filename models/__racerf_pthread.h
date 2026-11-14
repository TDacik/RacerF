#ifndef PTHREAD_MODELS_H
#define PTHREAD_MODELS_H

// Ensures that the macro is not expanded inside pthread.h
#include <pthread.h>

#define pthread_once(ctl, f) \
    __racerf_init_once_start(ctl); \
    static atomic_int __racerf_control_int = 0; \
    if (__racerf_control_int == 0) {__racerf_control_int = 1; (f)();} \
    __racerf_init_once_end(ctl);

#endif
