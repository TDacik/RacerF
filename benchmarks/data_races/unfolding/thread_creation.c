#include <stdlib.h>
#include <pthread.h>

#define N 10

int g;

pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

void *thread(void *arg)
{
    pthread_mutex_lock(&mutex);
    g++; // race
    pthread_mutex_unlock(&mutex);
    return NULL;
}

int main(void)
{
    pthread_t threads[N];

    for (int i = 0; i < N; i++) {
        pthread_create(&threads[i], NULL, thread, NULL);
    }

    // To report a must-race here, we must unfold the above
    // loop at least one
    g++; // race

    for (int i = 0; i < N; i++) {
        pthread_join(threads[i], NULL);
    }

    return 0;
}
