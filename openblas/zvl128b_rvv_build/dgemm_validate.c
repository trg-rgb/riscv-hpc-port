/*
 * DGEMM Correctness Validation for OpenBLAS 0.3.33 RVV
 * Target: RISCV64_ZVL128B, executed under qemu-riscv64
 *
 * Methodology follows standard HPC double-precision validation practice:
 *  - Error reported in units of machine epsilon (DBL_EPSILON ~ 2.22e-16)
 *  - Tolerance bound: n * eps * ||A||_inf * ||B||_inf (forward error bound
 *    for matrix multiplication with row-major accumulation)
 *  - Three test distributions: uniform random, geometric-magnitude,
 *    and Hilbert-like ill-conditioned
 *  - Reproducibility: deterministic seeds, hash output for bit-identical check
 *
 * Reference: Higham, "Accuracy and Stability of Numerical Algorithms" 2nd ed.,
 * SIAM 2002, Sec 3.5 on matrix multiplication error bounds.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>
#include "cblas.h"

/* Plain-C reference DGEMM: textbook ijk triple loop */
static void ref_dgemm(int M, int N, int K,
                      double alpha,
                      const double *A, int lda,
                      const double *B, int ldb,
                      double beta,
                      double *C, int ldc) {
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j++) {
            double sum = 0.0;
            for (int k = 0; k < K; k++) {
                sum += A[i*lda + k] * B[k*ldb + j];
            }
            C[i*ldc + j] = alpha * sum + beta * C[i*ldc + j];
        }
    }
}

/* Infinity norm of a matrix: max row sum of absolute values */
static double matrix_norm_inf(const double *A, int M, int N, int lda) {
    double max_row = 0.0;
    for (int i = 0; i < M; i++) {
        double row_sum = 0.0;
        for (int j = 0; j < N; j++) {
            row_sum += fabs(A[i*lda + j]);
        }
        if (row_sum > max_row) max_row = row_sum;
    }
    return max_row;
}

/* Componentwise max relative error, with proper handling of small values */
static double max_componentwise_error(const double *X, const double *Y, int n) {
    double max_err = 0.0;
    for (int i = 0; i < n; i++) {
        double diff = fabs(X[i] - Y[i]);
        double scale = fabs(Y[i]);
        double err = (scale > DBL_EPSILON) ? diff / scale : diff;
        if (err > max_err) max_err = err;
    }
    return max_err;
}

/* Simple deterministic hash for reproducibility check */
static unsigned long matrix_hash(const double *X, int n) {
    unsigned long h = 5381;
    const unsigned char *bytes = (const unsigned char *)X;
    for (size_t i = 0; i < n * sizeof(double); i++) {
        h = ((h << 5) + h) + bytes[i];
    }
    return h;
}

typedef enum {
    DIST_UNIFORM,       /* random [-0.5, 0.5] */
    DIST_GEOMETRIC,     /* magnitudes vary over wide range */
    DIST_HILBERT_LIKE   /* ill-conditioned */
} Distribution;

static void fill_matrix(double *X, int M, int N, Distribution dist, unsigned seed) {
    srand(seed);
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j++) {
            switch (dist) {
                case DIST_UNIFORM:
                    X[i*N + j] = (double)rand() / RAND_MAX - 0.5;
                    break;
                case DIST_GEOMETRIC: {
                    double r = (double)rand() / RAND_MAX;
                    double sign = (rand() % 2) ? 1.0 : -1.0;
                    X[i*N + j] = sign * pow(10.0, -6.0 + 12.0 * r);
                    break;
                }
                case DIST_HILBERT_LIKE:
                    X[i*N + j] = 1.0 / (double)(i + j + 1);
                    break;
            }
        }
    }
}

typedef struct {
    int M, N, K;
    Distribution dist;
    const char *dist_name;
} TestCase;

static int run_test(const TestCase *tc, int verbose) {
    int M = tc->M, N = tc->N, K = tc->K;
    double *A = malloc(M * K * sizeof(double));
    double *B = malloc(K * N * sizeof(double));
    double *C_ref = calloc(M * N, sizeof(double));
    double *C_blas = calloc(M * N, sizeof(double));

    fill_matrix(A, M, K, tc->dist, 42u + M + K);
    fill_matrix(B, K, N, tc->dist, 1337u + K + N);

    double alpha = 1.0, beta = 0.0;

    ref_dgemm(M, N, K, alpha, A, K, B, N, beta, C_ref, N);

    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
                M, N, K, alpha, A, K, B, N, beta, C_blas, N);

    /* HPC-standard forward error bound for matrix multiplication:
     *   ||C_computed - C_true||_inf <= K * eps * ||A||_inf * ||B||_inf
     * (Higham 2002, eq. 3.13, with K being the inner dimension)
     */
    double normA = matrix_norm_inf(A, M, K, K);
    double normB = matrix_norm_inf(B, K, N, N);
    double bound = (double)K * DBL_EPSILON * normA * normB;
    double normC = matrix_norm_inf(C_ref, M, N, N);
    double bound_rel = (normC > 0) ? bound / normC : bound;

    double err = max_componentwise_error(C_blas, C_ref, M * N);
    double err_in_eps = err / DBL_EPSILON;
    int pass = err <= 10.0 * bound_rel;  /* allow 10x bound for accumulation order */

    unsigned long hash = matrix_hash(C_blas, M * N);

    printf("DGEMM %4dx%4dx%4d  %-14s  err=%.3e (%6.1f*eps)  bound=%.3e  hash=%016lx  %s\n",
           M, N, K, tc->dist_name, err, err_in_eps, bound_rel, hash,
           pass ? "PASS" : "FAIL");

    free(A); free(B); free(C_ref); free(C_blas);
    return pass;
}

int main(void) {
    TestCase tests[] = {
        /* Uniform random — standard validation */
        {  8,   8,   8, DIST_UNIFORM, "uniform"},
        { 16,  16,  16, DIST_UNIFORM, "uniform"},
        { 32,  32,  32, DIST_UNIFORM, "uniform"},
        { 64,  64,  64, DIST_UNIFORM, "uniform"},
        {128, 128, 128, DIST_UNIFORM, "uniform"},
        {127, 127, 127, DIST_UNIFORM, "uniform"},    /* non-power-of-2 */
        { 50, 100,  75, DIST_UNIFORM, "uniform"},    /* rectangular */
        {200,  50, 100, DIST_UNIFORM, "uniform"},    /* tall */

        /* Geometric magnitude — tests FP cancellation handling */
        { 64,  64,  64, DIST_GEOMETRIC, "geometric"},
        {128, 128, 128, DIST_GEOMETRIC, "geometric"},

        /* Hilbert-like — ill-conditioned, tests accumulation stability */
        { 16,  16,  16, DIST_HILBERT_LIKE, "hilbert"},
        { 32,  32,  32, DIST_HILBERT_LIKE, "hilbert"},
    };
    int n_tests = sizeof(tests) / sizeof(tests[0]);
    int pass = 0;

    printf("=== DGEMM Correctness Validation ===\n");
    printf("OpenBLAS 0.3.33  TARGET=RISCV64_ZVL128B  GCC 15.2.0  qemu-riscv64\n");
    printf("Error bound: K * eps * ||A||_inf * ||B||_inf (Higham 2002, eq. 3.13)\n");
    printf("Machine epsilon: %.4e\n\n", DBL_EPSILON);

    for (int i = 0; i < n_tests; i++) {
        if (run_test(&tests[i], 1)) pass++;
    }

    printf("\n=== Result: %d/%d PASS ===\n", pass, n_tests);
    return (pass == n_tests) ? 0 : 1;
}
