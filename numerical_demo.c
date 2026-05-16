#include <stdio.h>
#include <math.h>
#include <stdlib.h>

#define EPSILON 1e-10
#define MAX_ITER 1000

double f(double x) { return x*x*x - x - 2.0; }

double bisection(double a, double b) {
    double mid;
    int iter = 0;
    printf("\n-- Bisection Method --\n");
    printf("  %-6s %-14s %-14s %-14s\n", "Iter", "a", "b", "mid");
    while ((b - a) > EPSILON && iter < MAX_ITER) {
        mid = (a + b) / 2.0;
        if (iter < 6)
            printf("  %-6d %-14.8f %-14.8f %-14.8f\n", iter+1, a, b, mid);
        if (f(mid) == 0.0) break;
        else if (f(a) * f(mid) < 0) b = mid;
        else a = mid;
        iter++;
    }
    mid = (a + b) / 2.0;
    printf("  Root found: %.10f (after %d iterations)\n", mid, iter);
    printf("  Residual f(x) = %.2e\n", f(mid));
    return mid;
}

double rk4_step(double x, double y, double h) {
    double k1 = -y;
    double k2 = -(y + 0.5*h*k1);
    double k3 = -(y + 0.5*h*k2);
    double k4 = -(y + h*k3);
    return y + (h/6.0)*(k1 + 2*k2 + 2*k3 + k4);
}

void runge_kutta(double x0, double y0, double xend, int steps) {
    double h = (xend - x0) / steps;
    double x = x0, y = y0;
    printf("\n-- Runge-Kutta 4th Order ODE Solver --\n");
    printf("  %-8s %-14s %-14s %-14s\n", "x", "RK4", "Exact", "Error");
    for (int i = 0; i <= steps; i++) {
        double exact = exp(-x);
        double error = fabs(y - exact);
        if (i % (steps/5) == 0)
            printf("  %-8.4f %-14.8f %-14.8f %-14.2e\n", x, y, exact, error);
        y = rk4_step(x, y, h);
        x += h;
    }
}

#define N 4
void lu_decompose(double A[N][N], double L[N][N], double U[N][N]) {
    for (int i = 0; i < N; i++) {
        for (int k = i; k < N; k++) {
            double sum = 0.0;
            for (int j = 0; j < i; j++) sum += L[i][j] * U[j][k];
            U[i][k] = A[i][k] - sum;
        }
        L[i][i] = 1.0;
        for (int k = i+1; k < N; k++) {
            double sum = 0.0;
            for (int j = 0; j < i; j++) sum += L[k][j] * U[j][i];
            L[k][i] = (A[k][i] - sum) / U[i][i];
        }
    }
}

void print_matrix(const char *name, double M[N][N]) {
    printf("  %s:\n", name);
    for (int i = 0; i < N; i++) {
        printf("    [");
        for (int j = 0; j < N; j++) printf(" %8.4f", M[i][j]);
        printf(" ]\n");
    }
}

void lu_demo() {
    double A[N][N] = {{2,-1,-2,3},{4,1,-3,2},{-2,5,2,-1},{6,-3,4,5}};
    double L[N][N] = {0}, U[N][N] = {0};
    printf("\n-- LU Decomposition --\n");
    print_matrix("A", A);
    lu_decompose(A, L, U);
    print_matrix("L (lower triangular)", L);
    print_matrix("U (upper triangular)", U);
    double residual = 0.0;
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            double val = 0.0;
            for (int k = 0; k < N; k++) val += L[i][k] * U[k][j];
            residual += fabs(val - A[i][j]);
        }
    printf("  Residual ||L*U - A||_1 = %.2e\n", residual);
}

int main() {
    printf("=============================================\n");
    printf("  Numerical Methods Demo - RISC-V Port\n");
    printf("  LFX 2026: Broadening RISC-V High Precision\n");
    printf("  Author: Tanmay Gulhane, MIT-WPU Pune\n");
    printf("=============================================\n");
    bisection(1.0, 2.0);
    runge_kutta(0.0, 1.0, 2.0, 100);
    lu_demo();
    printf("\n=============================================\n");
    printf("  All algorithms completed successfully.\n");
    printf("  Running on emulated RISC-V (qemu-riscv64)\n");
    printf("=============================================\n");
    return 0;
}
