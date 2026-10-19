#include <stdlib.h>
#include <pthread.h>

int g;
pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;

void *thread1(void *arg)
{
    pthread_mutex_lock(&m);
    g++;
    pthread_mutex_unlock(&m);
    return NULL;
}

void *thread2(void *arg)
{
    pthread_mutex_lock(&m);
    g--;
    pthread_mutex_unlock(&m);
    return NULL;
}

int main(void)
{
    pthread_t t1;
    pthread_t t2;

    pthread_create(&t1, NULL, thread1, NULL);
    pthread_create(&t2, NULL, thread1, NULL);
    
    return 0;
}
