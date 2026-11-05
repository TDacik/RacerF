#include <stdlib.h>
#include <pthread.h>

int g;

void *thread1(void *arg)
{
    g++; // race
    return NULL;
}

void *thread2(void *arg)
{
    g--; // race
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
