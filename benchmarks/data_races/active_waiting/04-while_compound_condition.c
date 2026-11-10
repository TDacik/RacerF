//# expected: unknown

#include <stdlib.h>
#include <pthread.h>
#include <stdatomic.h>

int g;

void *thread(void *arg)
{
    g--;

    // Active waiting
    int i = 0;
    int j = 0;
    while (atomic_load(&i) == 0 && atomic_load(&j) == 0) {};

    return NULL;
}

int main(void)
{
    pthread_t t1;
    pthread_t t2;

    pthread_create(&t1, NULL, thread, NULL);
    pthread_create(&t2, NULL, thread, NULL);
    
    pthread_join(t1, NULL);
    pthread_join(t2, NULL);

    return 0;
}
