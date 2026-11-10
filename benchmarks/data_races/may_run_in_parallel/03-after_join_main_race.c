//# expected: unknown

#include <stdlib.h>
#include <pthread.h>

int g;

void *thread(void *arg)
{
    g++;
    return NULL;
}

int main(void)
{
    pthread_t t;
    pthread_create(&t, NULL, thread, NULL);

    if (__VERIFIER_nondet_bool())
        pthread_join(t, NULL); //race

    g++;

    return 0;
}
