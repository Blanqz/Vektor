#include <windows.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define MAX_PROCS 64

typedef struct {
    int id;
    int status;
    void *fiber;
    long long mailbox[256];
    int mail_head;
    int mail_count;
    long long result;
    void (*entry)(void);
    int reduction_counter;
} Process;

static Process procs[MAX_PROCS];
static int num_procs = 0;
static int current_proc = 0;
static void *main_fiber = NULL;
extern long long vect_result;

static void main_fiber_func(void *param);
static void worker_fiber_func(void *param);

void vect_send(long long target, long long msg) {
    int tid = (int)target;
    if (tid >= 0 && tid < MAX_PROCS) {
        if (procs[tid].mail_count < 256) {
            int idx = (procs[tid].mail_head + procs[tid].mail_count) % 256;
            procs[tid].mailbox[idx] = msg;
            procs[tid].mail_count++;
            if (procs[tid].status == 1) procs[tid].status = 0;
        }
    }
}

long long vect_receive(void) {
    if (procs[current_proc].mail_count > 0) {
        int idx = procs[current_proc].mail_head;
        long long val = procs[current_proc].mailbox[idx];
        procs[current_proc].mail_head = (procs[current_proc].mail_head + 1) % 256;
        procs[current_proc].mail_count--;
        return val;
    }
    procs[current_proc].status = 1;
    SwitchToFiber(main_fiber);
    if (procs[current_proc].mail_count > 0) {
        int idx = procs[current_proc].mail_head;
        long long val = procs[current_proc].mailbox[idx];
        procs[current_proc].mail_head = (procs[current_proc].mail_head + 1) % 256;
        procs[current_proc].mail_count--;
        return val;
    }
    return 0;
}

long long vect_process_spawn(void *entry_func) {
    if (num_procs >= MAX_PROCS - 1) return 0;
    num_procs++;
    int id = num_procs;
    memset(&procs[id], 0, sizeof(Process));
    procs[id].id = id;
    procs[id].status = 0;
    procs[id].reduction_counter = 2000;
    procs[id].entry = entry_func;
    procs[id].fiber = CreateFiber(0, (LPFIBER_START_ROUTINE)worker_fiber_func, (void*)(long long)id);
    return id;
}

void vect_yield(void) {
    procs[current_proc].reduction_counter = 2000;
    SwitchToFiber(main_fiber);
}

long long vect_get_reduction_counter(void) {
    return procs[current_proc].reduction_counter;
}

void vect_set_reduction_counter(long long val) {
    procs[current_proc].reduction_counter = (int)val;
}

void vect_decrement_reduction(void) {
    long long saved_rax;
    __asm__ volatile ("mov %%rax, %0" : "=r"(saved_rax));
    if (--procs[current_proc].reduction_counter <= 0) {
        vect_yield();
    }
    __asm__ volatile ("mov %0, %%rax" : : "r"(saved_rax));
}

static void main_fiber_func(void *param) {
    (void)param;
    extern void vect_main_impl(void);
    vect_main_impl();
    fprintf(stderr, "AFTERMAIN %lld\n", vect_result);
    fflush(stderr);
    procs[0].status = 2;
    SwitchToFiber(main_fiber);
}

static void worker_fiber_func(void *param) {
    int pid = (int)(long long)param;
    current_proc = pid;
    if (procs[pid].entry) {
        procs[pid].entry();
    }
    procs[pid].status = 2;
    SwitchToFiber(main_fiber);
}

void vect_scheduler_run(void (*main_func)(void)) {
    main_fiber = ConvertThreadToFiber(NULL);
    
    memset(&procs[0], 0, sizeof(Process));
    procs[0].id = 0;
    procs[0].status = 0;
    procs[0].reduction_counter = 2000;
    procs[0].entry = main_func;
    procs[0].fiber = CreateFiber(0, (LPFIBER_START_ROUTINE)main_fiber_func, NULL);
    
    num_procs = 0;
    current_proc = 0;
    
    SwitchToFiber(procs[0].fiber);
    
    int progress = 1;
    while (progress) {
        progress = 0;
        for (int i = 1; i <= num_procs; i++) {
            if (procs[i].status == 0) {
                current_proc = i;
                progress = 1;
                SwitchToFiber(procs[i].fiber);
            }
        }
        if (procs[0].status == 0) {
            current_proc = 0;
            progress = 1;
            SwitchToFiber(procs[0].fiber);
        }
    }
    
    ConvertFiberToThread();
}

int main(void) {
    vect_scheduler_run(NULL);
    fprintf(stderr, "FINAL %lld\n", vect_result);
    fflush(stderr);
    return (int)(vect_result & 0xFF);
}
