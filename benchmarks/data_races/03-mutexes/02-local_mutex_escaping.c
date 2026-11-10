//# expected: unknown

#include <stdlib.h>
#include <pthread.h>

int g;

void *thread(void *mutex)
{
    pthread_mutex_t *m = (pthread_mutex_t *) mutex;

    pthread_mutex_lock(m);
    g++;
    pthread_mutex_unlock(m);
    return NULL;
}

int main(void)
{
    pthread_t t1;
    pthread_t t2;
   
    pthread_mutex_t m;
    pthread_mutex_init(&m, NULL);

    pthread_create(&t1, NULL, thread, (void *) &m);
    pthread_create(&t2, NULL, thread, (void *) &m);

    pthread_join(t1, NULL);
    pthread_join(t2, NULL);
    
    return 0;
}
