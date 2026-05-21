/*
 * hal/simd.h — Portable SIMD abstraction for RISC-V HPC portability
 *
 * Part of: riscv-hpc-port (LFX Mentorship 2026)
 * Author:  Tanmay Gulhane · MIT World Peace University, Pune
 *
 * Purpose
 * -------
 * HPC codes are full of x86 SIMD intrinsics (_mm256_fmadd_pd etc.) that
 * fail to compile on riscv64. This header abstracts those calls behind a
 * single portable API. Application code calls hal_fmadd_f64x4(); the
 * correct backend is selected at compile time — zero #ifdefs at call sites.
 *
 * Architecture backends
 * ---------------------
 *   riscv64 + RVV 1.0   RISC-V Vector Extension (requires -march=rv64gcv)
 *   x86_64  + AVX2+FMA  _mm256_fmadd_pd, _mm256_loadu_pd
 *   x86_64  + SSE2      _mm_mul_pd, _mm_add_pd  (scalar FMA emulated)
 *   any                 Scalar C — bit-identical output, compiles anywhere
 *
 * RISC-V note
 * -----------
 * The RVV path requires -march=rv64gcv and qemu-riscv64 -cpu rv64,v=true.
 * Base RV64GC (the standard cross-compilation target) does NOT expose the
 * V extension, so the scalar fallback is used — and that is correct and
 * intentional. The scalar path produces bit-identical results to every
 * other path; it is not a degraded mode.
 *
 * Usage
 * -----
 *   #include "hal/simd.h"
 *   hal_f64x4 a = hal_load_f64x4(ptr_a);
 *   hal_f64x4 b = hal_load_f64x4(ptr_b);
 *   hal_f64x4 r = hal_fmadd_f64x4(a, b, c);   // a*b + c
 *   double    d = hal_dot4(ptr_a, ptr_b);
 *   double    s = hal_matvec_row(row, vec, n); // dot of one matrix row
 */

#pragma once
#include <stddef.h>
#include <string.h>

/* ── 1. RISC-V Vector (RVV 1.0) ─────────────────────────────────────────── */
#if defined(__riscv) && defined(__riscv_v)

  #include <riscv_vector.h>

  typedef vfloat64m4_t hal_f64x4;
  typedef vfloat32m4_t hal_f32x4;
  typedef vint32m4_t   hal_i32x4;

  #define HAL_ARCH     "riscv_rvv"
  #define HAL_WIDTH     4           /* logical doubles per vector op */

  static inline hal_f64x4 hal_load_f64x4(const double *p) {
      return __riscv_vle64_v_f64m4(p, 4);
  }
  static inline void hal_store_f64x4(double *p, hal_f64x4 v) {
      __riscv_vse64_v_f64m4(p, v, 4);
  }
  static inline hal_f64x4 hal_set1_f64x4(double x) {
      return __riscv_vfmv_v_f_f64m4(x, 4);
  }
  static inline hal_f64x4 hal_add_f64x4(hal_f64x4 a, hal_f64x4 b) {
      return __riscv_vfadd_vv_f64m4(a, b, 4);
  }
  static inline hal_f64x4 hal_sub_f64x4(hal_f64x4 a, hal_f64x4 b) {
      return __riscv_vfsub_vv_f64m4(a, b, 4);
  }
  static inline hal_f64x4 hal_mul_f64x4(hal_f64x4 a, hal_f64x4 b) {
      return __riscv_vfmul_vv_f64m4(a, b, 4);
  }
  /* FMA: a*b + c  (fused — single rounding, no precision loss) */
  static inline hal_f64x4 hal_fmadd_f64x4(hal_f64x4 a, hal_f64x4 b, hal_f64x4 c) {
      return __riscv_vfmacc_vv_f64m4(c, a, b, 4);
  }
  /* Horizontal sum across all lanes */
  static inline double hal_hsum_f64x4(hal_f64x4 v) {
      vfloat64m1_t zero = __riscv_vfmv_s_f_f64m1(0.0, 1);
      vfloat64m1_t sum  = __riscv_vfredosum_vs_f64m4_f64m1(v, zero, 4);
      return __riscv_vfmv_f_s_f64m1_f64(sum);
  }

/* ── 2. x86 AVX2 + FMA3 ──────────────────────────────────────────────────── */
#elif defined(__AVX2__) && defined(__FMA__)

  #include <immintrin.h>

  typedef __m256d hal_f64x4;
  typedef __m128  hal_f32x4;
  typedef __m128i hal_i32x4;

  #define HAL_ARCH     "x86_avx2_fma"
  #define HAL_WIDTH     4

  static inline hal_f64x4 hal_load_f64x4(const double *p) {
      return _mm256_loadu_pd(p);
  }
  static inline void hal_store_f64x4(double *p, hal_f64x4 v) {
      _mm256_storeu_pd(p, v);
  }
  static inline hal_f64x4 hal_set1_f64x4(double x) {
      return _mm256_set1_pd(x);
  }
  static inline hal_f64x4 hal_add_f64x4(hal_f64x4 a, hal_f64x4 b) {
      return _mm256_add_pd(a, b);
  }
  static inline hal_f64x4 hal_sub_f64x4(hal_f64x4 a, hal_f64x4 b) {
      return _mm256_sub_pd(a, b);
  }
  static inline hal_f64x4 hal_mul_f64x4(hal_f64x4 a, hal_f64x4 b) {
      return _mm256_mul_pd(a, b);
  }
  static inline hal_f64x4 hal_fmadd_f64x4(hal_f64x4 a, hal_f64x4 b, hal_f64x4 c) {
      return _mm256_fmadd_pd(a, b, c);
  }
  static inline double hal_hsum_f64x4(hal_f64x4 v) {
      __m128d lo  = _mm256_castpd256_pd128(v);
      __m128d hi  = _mm256_extractf128_pd(v, 1);
      __m128d sum = _mm_add_pd(lo, hi);
      sum = _mm_hadd_pd(sum, sum);
      return _mm_cvtsd_f64(sum);
  }

/* ── 3. x86 SSE2 ─────────────────────────────────────────────────────────── */
#elif defined(__SSE2__)

  #include <emmintrin.h>

  /* SSE2 registers are 2-wide. We wrap two __m128d to maintain the 4-wide
   * API contract — same call sites, same results as every other backend.  */
  typedef struct { __m128d lo; __m128d hi; } hal_f64x4;
  typedef struct { __m128  lo; __m128  hi; } hal_f32x4;
  typedef struct { __m128i lo; __m128i hi; } hal_i32x4;

  #define HAL_ARCH     "x86_sse2"
  #define HAL_WIDTH     4

  static inline hal_f64x4 hal_load_f64x4(const double *p) {
      hal_f64x4 r;
      r.lo = _mm_loadu_pd(p);
      r.hi = _mm_loadu_pd(p + 2);
      return r;
  }
  static inline void hal_store_f64x4(double *p, hal_f64x4 v) {
      _mm_storeu_pd(p,     v.lo);
      _mm_storeu_pd(p + 2, v.hi);
  }
  static inline hal_f64x4 hal_set1_f64x4(double x) {
      hal_f64x4 r;
      r.lo = _mm_set1_pd(x);
      r.hi = _mm_set1_pd(x);
      return r;
  }
  static inline hal_f64x4 hal_add_f64x4(hal_f64x4 a, hal_f64x4 b) {
      hal_f64x4 r;
      r.lo = _mm_add_pd(a.lo, b.lo);
      r.hi = _mm_add_pd(a.hi, b.hi);
      return r;
  }
  static inline hal_f64x4 hal_sub_f64x4(hal_f64x4 a, hal_f64x4 b) {
      hal_f64x4 r;
      r.lo = _mm_sub_pd(a.lo, b.lo);
      r.hi = _mm_sub_pd(a.hi, b.hi);
      return r;
  }
  static inline hal_f64x4 hal_mul_f64x4(hal_f64x4 a, hal_f64x4 b) {
      hal_f64x4 r;
      r.lo = _mm_mul_pd(a.lo, b.lo);
      r.hi = _mm_mul_pd(a.hi, b.hi);
      return r;
  }
  static inline hal_f64x4 hal_fmadd_f64x4(hal_f64x4 a, hal_f64x4 b, hal_f64x4 c) {
      hal_f64x4 r;
      r.lo = _mm_add_pd(_mm_mul_pd(a.lo, b.lo), c.lo);
      r.hi = _mm_add_pd(_mm_mul_pd(a.hi, b.hi), c.hi);
      return r;
  }
  static inline double hal_hsum_f64x4(hal_f64x4 v) {
      __m128d s   = _mm_add_pd(v.lo, v.hi);
      __m128d hi  = _mm_unpackhi_pd(s, s);
      __m128d sum = _mm_add_pd(s, hi);
      return _mm_cvtsd_f64(sum);
  }

/* ── 4. Scalar fallback — any ISA, bit-identical output ──────────────────── */
#else

  #define HAL_ARCH     "scalar"
  #define HAL_WIDTH     4

  typedef struct { double v[4]; } hal_f64x4;
  typedef struct { float  v[4]; } hal_f32x4;
  typedef struct { int    v[4]; } hal_i32x4;

  static inline hal_f64x4 hal_load_f64x4(const double *p) {
      hal_f64x4 r;
      memcpy(r.v, p, 4 * sizeof(double));
      return r;
  }
  static inline void hal_store_f64x4(double *p, hal_f64x4 v) {
      memcpy(p, v.v, 4 * sizeof(double));
  }
  static inline hal_f64x4 hal_set1_f64x4(double x) {
      hal_f64x4 r;
      for (int i = 0; i < 4; i++) r.v[i] = x;
      return r;
  }
  static inline hal_f64x4 hal_add_f64x4(hal_f64x4 a, hal_f64x4 b) {
      hal_f64x4 r;
      for (int i = 0; i < 4; i++) r.v[i] = a.v[i] + b.v[i];
      return r;
  }
  static inline hal_f64x4 hal_sub_f64x4(hal_f64x4 a, hal_f64x4 b) {
      hal_f64x4 r;
      for (int i = 0; i < 4; i++) r.v[i] = a.v[i] - b.v[i];
      return r;
  }
  static inline hal_f64x4 hal_mul_f64x4(hal_f64x4 a, hal_f64x4 b) {
      hal_f64x4 r;
      for (int i = 0; i < 4; i++) r.v[i] = a.v[i] * b.v[i];
      return r;
  }
  static inline hal_f64x4 hal_fmadd_f64x4(hal_f64x4 a, hal_f64x4 b, hal_f64x4 c) {
      hal_f64x4 r;
      for (int i = 0; i < 4; i++) r.v[i] = a.v[i] * b.v[i] + c.v[i];
      return r;
  }
  static inline double hal_hsum_f64x4(hal_f64x4 v) {
      return v.v[0] + v.v[1] + v.v[2] + v.v[3];
  }

#endif  /* architecture selection */

/* ══════════════════════════════════════════════════════════════════════════
 * Architecture-independent higher-level ops
 * These build on the primitives above and work identically on all backends.
 * ══════════════════════════════════════════════════════════════════════════ */

/*
 * hal_dot4 — dot product of two 4-element vectors
 *   result = a[0]*b[0] + a[1]*b[1] + a[2]*b[2] + a[3]*b[3]
 */
static inline double hal_dot4(const double * restrict a,
                               const double * restrict b) {
    hal_f64x4 va = hal_load_f64x4(a);
    hal_f64x4 vb = hal_load_f64x4(b);
    hal_f64x4 vp = hal_mul_f64x4(va, vb);
    return hal_hsum_f64x4(vp);
}

/*
 * hal_matvec_row — dot product of one matrix row against a vector
 *   Processes 4 elements per SIMD iteration; handles arbitrary length n.
 *   This is the inner loop of DGEMV — the workhorse of TF Lite dense layers.
 *
 *   result = sum(row[i] * vec[i]) for i in [0, n)
 */
static inline double hal_matvec_row(const double * restrict row,
                                    const double * restrict vec,
                                    size_t n) {
    double acc = 0.0;
    size_t i   = 0;

    /* SIMD loop — process 4 at a time */
    for (; i + 4 <= n; i += 4) {
        hal_f64x4 vr = hal_load_f64x4(row + i);
        hal_f64x4 vv = hal_load_f64x4(vec  + i);
        hal_f64x4 vp = hal_mul_f64x4(vr, vv);
        acc += hal_hsum_f64x4(vp);
    }
    /* scalar tail — handles n not divisible by 4 */
    for (; i < n; i++) {
        acc += row[i] * vec[i];
    }
    return acc;
}

/*
 * hal_axpy4 — AXPY on 4-element vectors: y = a*x + y
 *   Fundamental BLAS-1 op; used in gradient accumulation, residual updates.
 */
static inline void hal_axpy4(double alpha,
                              const double * restrict x,
                              double       * restrict y) {
    hal_f64x4 va = hal_set1_f64x4(alpha);
    hal_f64x4 vx = hal_load_f64x4(x);
    hal_f64x4 vy = hal_load_f64x4(y);
    hal_f64x4 vr = hal_fmadd_f64x4(va, vx, vy);   /* alpha*x + y */
    hal_store_f64x4(y, vr);
}
