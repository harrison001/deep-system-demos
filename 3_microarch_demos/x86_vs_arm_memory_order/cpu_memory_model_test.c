// cpu_memory_model_test.c
#include <stdio.h>
#include <pthread.h>
#include <stdatomic.h>
#include <unistd.h>

#define LOOP 10000000

atomic_int x = 0;
atomic_int y = 0;
atomic_int flag = 0;

int r1 = 0;
int r2 = 0;

void *thread1(void *arg) {
    for (int i = 0; i < LOOP; i++) {
#ifdef DO_RELAXED
        atomic_store_explicit(&x, 1, memory_order_relaxed);
        r1 = atomic_load_explicit(&y, memory_order_relaxed);
        atomic_store_explicit(&x, 0, memory_order_relaxed);
#endif

#ifdef DO_FENCE
        atomic_store_explicit(&x, 1, memory_order_relaxed);
        atomic_thread_fence(memory_order_seq_cst);
        r1 = atomic_load_explicit(&y, memory_order_relaxed);
        atomic_store_explicit(&x, 0, memory_order_relaxed);
#endif

#ifdef DO_RELEASE_ACQUIRE
        atomic_store_explicit(&x, 1, memory_order_release);
        atomic_store_explicit(&flag, 1, memory_order_release);
        r1 = atomic_load_explicit(&y, memory_order_acquire);
        atomic_store_explicit(&x, 0, memory_order_release);
#endif
    }
    return NULL;
}

void *thread2(void *arg) {
    for (int i = 0; i < LOOP; i++) {
#ifdef DO_RELAXED
        atomic_store_explicit(&y, 1, memory_order_relaxed);
        r2 = atomic_load_explicit(&x, memory_order_relaxed);
        atomic_store_explicit(&y, 0, memory_order_relaxed);
#endif

#ifdef DO_FENCE
        atomic_store_explicit(&y, 1, memory_order_relaxed);
        atomic_thread_fence(memory_order_seq_cst);
        r2 = atomic_load_explicit(&x, memory_order_relaxed);
        atomic_store_explicit(&y, 0, memory_order_relaxed);
#endif

#ifdef DO_RELEASE_ACQUIRE
        atomic_store_explicit(&y, 1, memory_order_release);
        while (atomic_load_explicit(&flag, memory_order_acquire) != 1) {
            // spin until thread1 signals
        }
        r2 = atomic_load_explicit(&x, memory_order_acquire);
        atomic_store_explicit(&y, 0, memory_order_release);
#endif
    }
    return NULL;
}

int main() {
    pthread_t t1, t2;
    int bug_count = 0;

    for (int run = 0; run < 100; run++) {
        atomic_store(&x, 0);
        atomic_store(&y, 0);
        atomic_store(&flag, 0);
        r1 = r2 = 0;

        pthread_create(&t1, NULL, thread1, NULL);
        pthread_create(&t2, NULL, thread2, NULL);

        pthread_join(t1, NULL);
        pthread_join(t2, NULL);

        if (r1 == 0 && r2 == 0) {
            bug_count++;
            printf("🔥 BUG: r1=0 && r2=0 (iteration %d)\n", run);
        } else {
            printf("OK: r1=%d, r2=%d\n", r1, r2);
        }
    }

    printf("Done. BUG count=%d/100\n", bug_count);
    return 0;
}
