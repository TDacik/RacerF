//# expected: unknown

// Threads are created as:
//
//   main -- thread1     -- thread3 (A)
//        -- thread2 (A)
//
// May-run-in-parallel analysis must determine that thread3
// may run in parallel with its "uncle" thread1

#include <stdlib.h>
#include <pthread.h>

int g;

void *thread3(void *arg)
{
    g++; // race
    return NULL;
}

void *thread1(void *arg)
{
    pthread_t t;
    pthread_create(&t, NULL, thread3, NULL);
    pthread_join(t, NULL);

    return NULL;
}

void *thread2(void *arg)
{
    g++; // race
    return NULL;
}

int main(void)
{
    pthread_t t1;
    pthread_t t2;

    pthread_create(&t1, NULL, thread1, NULL);
    pthread_create(&t2, NULL, thread2, NULL);

    pthread_join(t1, NULL);
    pthread_join(t2, NULL);

    return 0;
}
