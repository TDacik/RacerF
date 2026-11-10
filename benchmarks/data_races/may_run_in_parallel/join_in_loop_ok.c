// We cannot precisely analyse joins in loop but we should
// still report the race before the join.

#include <stdlib.h>
#include <pthread.h>

int N = 10;

int g;

void *thread(void *arg)
{
    g++; // race
    return NULL;
}

int main(void)
{
    pthread_t threads[N];

    for (int i = 0; i < N; i++) {
        pthread_create(&threads[i], NULL, thread, NULL);
    }

    for (int i = 0; i < N; i++) {
        pthread_join(threads[i], NULL);
    }

    return 0;
}
