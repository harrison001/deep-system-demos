#include <pthread.h>
#include <stdio.h>

volatile long shared_var = 0;

void* worker(void* arg) {
    for (long i = 0; i < 100000000; i++) {
        shared_var++;  // 多个核同时写同一变量 → 争用
    }
    return NULL;
}

int main() {
    pthread_t t1, t2;
    pthread_create(&t1, NULL, worker, NULL);
    pthread_create(&t2, NULL, worker, NULL);
    pthread_join(t1, NULL);
    pthread_join(t2, NULL);
    return 0;
}
