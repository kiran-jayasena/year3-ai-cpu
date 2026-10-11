#include <stdint.h>

#define RESULT_MMIO (*(volatile uint32_t *)0x00007ffcU)
#define STATUS_MMIO (*(volatile uint32_t *)0x00007ff8U)

static inline uint32_t read_cycle(void) { uint32_t v; __asm__ volatile ("csrr %0, cycle" : "=r"(v)); return v; }
static inline uint32_t read_instret(void) { uint32_t v; __asm__ volatile ("csrr %0, instret" : "=r"(v)); return v; }

static const int8_t a16[16] = {3, -2, 5, -4, 7, -1, 2, -6, 4, -3, 1, -5, 6, -7, 0, 8};
static const int8_t b16[16] = {-3, 4, -1, -2, 2, -5, 6, 3, -4, 7, -8, 1, -2, 5, 9, -1};
static const int8_t a128[128] = {4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3};
static const int8_t b128[128] = {6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1, 6, -3, 8, -5, 2, -7, 4, -1};

static int32_t dot(const int8_t *a, const int8_t *b, uint32_t n) {
    int32_t sum = 0;
    for (uint32_t i = 0; i < n; ++i) sum += (int32_t)a[i] * (int32_t)b[i];
    return sum;
}

static void run_case(const int8_t *a, const int8_t *b, uint32_t n, uint32_t expected) {
    uint32_t c0 = read_cycle();
    uint32_t i0 = read_instret();
    int32_t result = dot(a, b, n);
    uint32_t i1 = read_instret();
    uint32_t c1 = read_cycle();
    RESULT_MMIO = (uint32_t)result;
    STATUS_MMIO = (result == (int32_t)expected) ? 0x600D0000U : 0xBAD00000U;
    STATUS_MMIO = (c1 - c0);
    STATUS_MMIO = (i1 - i0);
}

int main(void) {
    run_case(a16, b16, 16U, 0xffffff96U);
    run_case(a128, b128, 128U, 0x00000240U);
    for (;;) { __asm__ volatile ("wfi"); }
    return 0;
}
