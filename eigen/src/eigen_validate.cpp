// eigen_validate.cpp
// Eigen 5.0.1 numerical validation for RISC-V64
// Tanmay Gulhane — LFX Mentorship Summer 2026
// Tests core linear algebra operations against known references.
// Designed to run under qemu-riscv64 on a cross-compiled RV64GC binary.

#include <Eigen/Dense>
#include <iostream>
#include <iomanip>
#include <cmath>
#include <cstdio>

using namespace Eigen;

static int passed = 0;
static int failed = 0;

void report(const char* name, const char* detail, double error, double tol) {
    bool ok = error <= tol;
    printf("  %-40s  error = %.2e   %s\n", name, error, ok ? "PASS" : "FAIL");
    if (!ok) printf("    !! expected error <= %.2e, got %.2e  [%s]\n", tol, error, detail);
    ok ? passed++ : failed++;
}

// ── Test 1: Double-precision matrix multiply ─────────────────────────────────
// Compute C = A * B two ways and compare: once with Eigen's operator*,
// once manually row-by-row. Any discrepancy points to a codegen bug.
void test_dgemm() {
    printf("\n[1] DGEMM — 4x4 double-precision matrix multiply\n");

    Matrix4d A, B;
    A << 1.5, 2.3, 0.7, 4.1,
         3.2, 1.1, 2.8, 0.4,
         0.9, 4.4, 1.6, 3.7,
         2.1, 0.6, 3.9, 1.2;

    B << 2.2, 1.4, 3.1, 0.8,
         0.5, 3.3, 1.9, 2.6,
         4.0, 0.2, 1.7, 3.4,
         1.3, 2.7, 0.6, 1.5;

    Matrix4d C_eigen = A * B;

    // Manual reference
    Matrix4d C_ref = Matrix4d::Zero();
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            for (int k = 0; k < 4; k++)
                C_ref(i, j) += A(i, k) * B(k, j);

    double err = (C_eigen - C_ref).norm();
    report("operator* vs manual loop", "Frobenius norm of difference", err, 1e-12);

    printf("    C[0][0]=%.6f  C[1][1]=%.6f  C[2][2]=%.6f  C[3][3]=%.6f\n",
           C_eigen(0,0), C_eigen(1,1), C_eigen(2,2), C_eigen(3,3));
}

// ── Test 2: LU decomposition — solve Ax = b ──────────────────────────────────
// Use a 6x6 matrix with a known solution. Check residual ||Ax - b||.
void test_lu_solve() {
    printf("\n[2] LU solve — Ax = b, 6x6 double-precision\n");

    Matrix<double, 6, 6> A;
    A <<  4, -1,  0,  0,  0,  0,
         -1,  4, -1,  0,  0,  0,
          0, -1,  4, -1,  0,  0,
          0,  0, -1,  4, -1,  0,
          0,  0,  0, -1,  4, -1,
          0,  0,  0,  0, -1,  4;

    Matrix<double, 6, 1> b;
    b << 1, 2, 3, 4, 5, 6;

    Matrix<double, 6, 1> x = A.lu().solve(b);
    double residual = (A * x - b).norm();

    report("LU residual ||Ax - b||", "should be near machine epsilon", residual, 1e-12);
    printf("    x = [%.6f, %.6f, %.6f, %.6f, %.6f, %.6f]\n",
           x(0), x(1), x(2), x(3), x(4), x(5));
}

// ── Test 3: Symmetric eigenvalue decomposition ───────────────────────────────
// 4x4 symmetric tridiagonal matrix with eigenvalues known analytically:
// λ_k = 2 - 2*cos(k*π/5) for k=1..4
void test_eigen_decomp() {
    printf("\n[3] Symmetric eigenvalue decomposition — 4x4\n");

    Matrix4d A;
    A <<  2, -1,  0,  0,
         -1,  2, -1,  0,
          0, -1,  2, -1,
          0,  0, -1,  2;

    SelfAdjointEigenSolver<Matrix4d> solver(A);
    Vector4d computed = solver.eigenvalues();

    // Analytical eigenvalues: 2 - 2*cos(k*pi/5), k=1..4, sorted ascending
    Vector4d reference;
    for (int k = 1; k <= 4; k++)
        reference(k-1) = 2.0 - 2.0 * std::cos(k * M_PI / 5.0);
    // sort reference ascending
    std::sort(reference.data(), reference.data() + 4);

    double err = (computed - reference).norm();
    report("eigenvalues vs analytical", "L2 norm of difference", err, 1e-12);

    printf("    computed:   [%.8f, %.8f, %.8f, %.8f]\n",
           computed(0), computed(1), computed(2), computed(3));
    printf("    analytical: [%.8f, %.8f, %.8f, %.8f]\n",
           reference(0), reference(1), reference(2), reference(3));

    // Also verify A = V * D * V^T
    Matrix4d V = solver.eigenvectors();
    Matrix4d reconstructed = V * computed.asDiagonal() * V.transpose();
    double recon_err = (reconstructed - A).norm();
    report("reconstruction A = V*D*V^T", "Frobenius norm", recon_err, 1e-12);
}

// ── Test 4: Cholesky decomposition ───────────────────────────────────────────
// Build a symmetric positive definite matrix A = B^T * B, factor it,
// solve a system, and verify the residual.
void test_cholesky() {
    printf("\n[4] Cholesky decomposition — 5x5 SPD\n");

    Matrix<double, 5, 5> B;
    B << 2, 1, 0, 0, 0,
         1, 3, 1, 0, 0,
         0, 1, 4, 1, 0,
         0, 0, 1, 3, 1,
         0, 0, 0, 1, 2;

    Matrix<double, 5, 5> A = B.transpose() * B;
    Matrix<double, 5, 1> b;
    b << 1, 0, 1, 0, 1;

    LLT<Matrix<double, 5, 5>> llt(A);
    Matrix<double, 5, 1> x = llt.solve(b);
    double residual = (A * x - b).norm();

    report("Cholesky residual ||Ax - b||", "should be near machine epsilon", residual, 1e-12);
    printf("    x = [%.8f, %.8f, %.8f, %.8f, %.8f]\n",
           x(0), x(1), x(2), x(3), x(4));
}

// ── Test 5: SVD — singular value decomposition ───────────────────────────────
// Decompose a 4x3 matrix, reconstruct it, check reconstruction error.
void test_svd() {
    printf("\n[5] SVD — 4x3 double-precision, full reconstruction\n");

    Matrix<double, 4, 3> A;
    A << 1, 2, 3,
         4, 5, 6,
         7, 8, 9,
         1, 0, 1;

    JacobiSVD<Matrix<double, 4, 3>> svd(A, ComputeFullU | ComputeFullV);
    Matrix<double, 4, 3> reconstructed =
        svd.matrixU().leftCols(3) *
        svd.singularValues().asDiagonal() *
        svd.matrixV().transpose();

    double err = (reconstructed - A).norm();
    report("SVD reconstruction ||U*S*V^T - A||", "Frobenius norm", err, 1e-12);
    printf("    singular values: [%.6f, %.6f, %.6f]\n",
           svd.singularValues()(0),
           svd.singularValues()(1),
           svd.singularValues()(2));
}

// ─────────────────────────────────────────────────────────────────────────────

int main() {
    printf("============================================================\n");
    printf("  Eigen 5.0.1 — RISC-V64 Numerical Validation\n");
    printf("  Target: RV64GC | Emulator: qemu-riscv64\n");
    printf("  Toolchain: riscv64-linux-gnu-g++ 15.2.0\n");
    printf("============================================================\n");

    test_dgemm();
    test_lu_solve();
    test_eigen_decomp();
    test_cholesky();
    test_svd();

    printf("\n============================================================\n");
    printf("  Results: %d passed, %d failed\n", passed, failed);
    printf("============================================================\n");

    return failed == 0 ? 0 : 1;
}
