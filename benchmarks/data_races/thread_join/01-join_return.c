//# expected: unknown

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

int g;

pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;

void *thread(void *arg)
{
    pthread_mutex_lock(&m);
    g++; // race
    pthread_mutex_unlock(&m);
    return &g;
}

int main(void)
{
    int *ptr;

    pthread_t t1;
    pthread_t t2;

    pthread_create(&t1, NULL, thread, NULL);
    pthread_create(&t2, NULL, thread, NULL);
    pthread_join(t1, (void **) &ptr);
    (*ptr)++; // race
    pthread_join(t2, NULL);

    return 0;
}
