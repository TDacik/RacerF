#include <stdlib.h>
#include <pthread.h>

int g;

pthread_once_t c = PTHREAD_ONCE_INIT;

void init_global(void)
{
    g = 0;
}

void *thread(void *arg)
{
    pthread_once(&c, init_global);
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
