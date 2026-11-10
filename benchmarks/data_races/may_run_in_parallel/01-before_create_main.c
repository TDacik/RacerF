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
    g++;
    pthread_create(&t, NULL, thread, NULL);
    pthread_join(t, NULL);
    return 0;
}
