//# expected: unknown

#include <stdlib.h>
#include <pthread.h>

struct s {
  _Atomic int data1;
  int data2;
} g;

void *thread(void *arg)
{
    g.data2++; // race
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
