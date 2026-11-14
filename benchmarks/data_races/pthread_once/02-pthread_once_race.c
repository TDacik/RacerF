#include <stdlib.h>
#include <pthread.h>

int g;

pthread_once_t c = PTHREAD_ONCE_INIT;

void init_global(void)
{
    g = 0; // race
}

void *thread1(void *arg)
{
    pthread_once(&c, init_global);
    return NULL;
}

void *thread2(void *arg)
{
    int x = g; // race
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
