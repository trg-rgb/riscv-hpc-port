/*
 * hal/test_hal.c — Validation harness for hal/simd.h
 *
 * Verifies all HAL primitives against known analytical results.
 * Designed to run under qemu-riscv64 (statically linked).
 *
 * Build (riscv64):
 *   riscv64-linux-gnu-gcc -O2 -march=rv64gc -static \
 *       -I. hal/test_hal.c -o hal/test_hal_riscv64 -lm
 *
 * Run:
 *   qemu-riscv64 hal/test_hal_riscv64
 *
 * Build (x86 AVX2+FMA, for cross-reference):
 *   gcc -O2 -mavx2 -mfma -I. hal/test_hal.c -o hal/test_hal_x86 -lm
 */

#include <stdio.h>
#include <math.h>
#include "hal/simd.h"

/* ── helpers ────────────────────────────────────────────────────────────── */
static int pass_count = 0;
static int fail_count = 0;

static void check(const char *name, double got, double expected, double tol) {
    double err = fabs(got - expected);
    if (err <= tol) {
        printf("  PASS  %-30s  got=%.10f  expected=%.10f  err=%.2e\n",
               name, got, expected, err);
        pass_count++;
    } else {
        printf("  FAIL  %-30s  got=%.10f  expected=%.10f  err=%.2e  tol=%.2e\n",
               name, got, expected, err, tol);
        fail_count++;
    }
}

/* ── test cases ─────────────────────────────────────────────────────────── */

static void test_dot4(void) {
    printf("\n[hal_dot4]\n");

    /* Case 1: unit vectors — dot should be 1.0 */
    double a1[4] = {1.0, 0.0, 0.0, 0.0};
    double b1[4] = {1.0, 0.0, 0.0, 0.0};
    check("unit_vector", hal_dot4(a1, b1), 1.0, 1e-15);

    /* Case 2: [1,2,3,4]·[1,2,3,4] = 1+4+9+16 = 30 */
    double a2[4] = {1.0, 2.0, 3.0, 4.0};
    double b2[4] = {1.0, 2.0, 3.0, 4.0};
    check("squares_sum_30", hal_dot4(a2, b2), 30.0, 1e-12);

    /* Case 3: orthogonal vectors — dot should be 0.0 */
    double a3[4] = {1.0, -1.0,  1.0, -1.0};
    double b3[4] = {1.0,  1.0,  1.0,  1.0};
    check("orthogonal_zero", hal_dot4(a3, b3), 0.0, 1e-15);

    /* Case 4: [1,1,1,1]·[1,1,1,1] = 4 */
    double a4[4] = {1.0, 1.0, 1.0, 1.0};
    double b4[4] = {1.0, 1.0, 1.0, 1.0};
    check("all_ones_4", hal_dot4(a4, b4), 4.0, 1e-15);
}

static void test_fmadd(void) {
    printf("\n[hal_fmadd_f64x4]  — a*b + c\n");

    /* [2,2,2,2] * [3,3,3,3] + [1,1,1,1] = [7,7,7,7] → hsum = 28 */
    double pa[4] = {2.0, 2.0, 2.0, 2.0};
    double pb[4] = {3.0, 3.0, 3.0, 3.0};
    double pc[4] = {1.0, 1.0, 1.0, 1.0};

    hal_f64x4 va = hal_load_f64x4(pa);
    hal_f64x4 vb = hal_load_f64x4(pb);
    hal_f64x4 vc = hal_load_f64x4(pc);
    hal_f64x4 vr = hal_fmadd_f64x4(va, vb, vc);

    double out[4];
    hal_store_f64x4(out, vr);

    check("fmadd_lane0", out[0], 7.0, 1e-15);
    check("fmadd_lane1", out[1], 7.0, 1e-15);
    check("fmadd_lane2", out[2], 7.0, 1e-15);
    check("fmadd_lane3", out[3], 7.0, 1e-15);
    check("fmadd_hsum",  hal_hsum_f64x4(vr), 28.0, 1e-12);
}

static void test_matvec_row(void) {
    printf("\n[hal_matvec_row]  — matrix row × vector\n");

    /* 1×8 row × 8-element vector
     * row = [1,2,3,4,5,6,7,8]
     * vec = [1,1,1,1,1,1,1,1]
     * result = 1+2+3+4+5+6+7+8 = 36                             */
    double row[8] = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
    double vec[8] = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0};
    check("matvec_n8_sum36", hal_matvec_row(row, vec, 8), 36.0, 1e-12);

    /* odd-length tail test: n=5
     * [1,2,3,4,5]·[2,2,2,2,2] = 2+4+6+8+10 = 30                */
    double row5[5] = {1.0, 2.0, 3.0, 4.0, 5.0};
    double vec5[5] = {2.0, 2.0, 2.0, 2.0, 2.0};
    check("matvec_n5_tail", hal_matvec_row(row5, vec5, 5), 30.0, 1e-12);

    /* n=4 (exact SIMD width) */
    double row4[4] = {1.0, 0.0, 0.0, 1.0};
    double vec4[4] = {5.0, 9.0, 9.0, 5.0};
    check("matvec_n4_exact", hal_matvec_row(row4, vec4, 4), 10.0, 1e-12);
}

static void test_axpy4(void) {
    printf("\n[hal_axpy4]  — y = alpha*x + y\n");

    /* alpha=2.0, x=[1,1,1,1], y=[3,3,3,3] → y=[5,5,5,5] */
    double x[4] = {1.0, 1.0, 1.0, 1.0};
    double y[4] = {3.0, 3.0, 3.0, 3.0};
    hal_axpy4(2.0, x, y);
    check("axpy_lane0", y[0], 5.0, 1e-15);
    check("axpy_lane1", y[1], 5.0, 1e-15);
    check("axpy_lane2", y[2], 5.0, 1e-15);
    check("axpy_lane3", y[3], 5.0, 1e-15);
}

static void test_sub(void) {
    printf("\n[hal_sub_f64x4]\n");

    double pa[4] = {5.0, 4.0, 3.0, 2.0};
    double pb[4] = {1.0, 1.0, 1.0, 1.0};
    hal_f64x4 vr = hal_sub_f64x4(hal_load_f64x4(pa), hal_load_f64x4(pb));
    double out[4];
    hal_store_f64x4(out, vr);
    check("sub_lane0", out[0], 4.0, 1e-15);
    check("sub_lane1", out[1], 3.0, 1e-15);
    check("sub_lane2", out[2], 2.0, 1e-15);
    check("sub_lane3", out[3], 1.0, 1e-15);
}

/* ── main ───────────────────────────────────────────────────────────────── */
int main(void) {
    printf("=== HAL SIMD Shim Validation ===\n");
    printf("Architecture : %s\n", HAL_ARCH);
    printf("Vector width : %d doubles per op\n", HAL_WIDTH);

    test_dot4();
    test_fmadd();
    test_matvec_row();
    test_axpy4();
    test_sub();

    printf("\n================================\n");
    printf("Results: %d PASS, %d FAIL\n", pass_count, fail_count);
    printf("================================\n");

    return fail_count == 0 ? 0 : 1;
}
