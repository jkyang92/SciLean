import SciLean.Algebra.TensorProduct.Basic
import SciLean.Algebra.TensorProduct.Self

namespace SciLean

class MatrixType (R : outParam Type*) (Y X : outParam Type*) (M : Type*) [RCLike R]
  [NormedAddCommGroup X] [AdjointSpace R X] [NormedAddCommGroup Y] [AdjointSpace R Y]
  [AddCommGroup M] [Module R M]
  extends
    TensorProductType R Y X M
  where

/-- Class that allows matrix-vector multiplication -/
class MatrixMulNotation (M : Type*) where

variable
  {R : Type*} [RCLike R]
  {X : Type*} [NormedAddCommGroup X] [AdjointSpace R X]
  {Y : Type*} [NormedAddCommGroup Y] [AdjointSpace R Y]
  {M : Type*} [AddCommGroup M] [Module R M] [MatrixType R Y X M]

instance
  {M : Type*} [MatrixMulNotation M]
  {R : Type*} {_ : RCLike R}
  {X : Type*} {_ : NormedAddCommGroup X} {_ : AdjointSpace R X}
  {Y : Type*} {_ : NormedAddCommGroup Y} {_ : AdjointSpace R Y}
  [AddCommGroup M] {_ : Module R M} [MatrixType R Y X M] :
  HMul M X Y := ⟨fun A x => TensorProductType.matVecMulAdd (1:R) A x 0 (0:Y)⟩

instance
  {M : Type*} [MatrixMulNotation M]
  {R : Type*} {_ : RCLike R}
  {X : Type*} {_ : NormedAddCommGroup X} {_ : AdjointSpace R X}
  {Y : Type*} {_ : NormedAddCommGroup Y} {_ : AdjointSpace R Y}
  [AddCommGroup M] {_ : Module R M} [MatrixType R Y X M] :
  HMul Y M X := ⟨fun y A => TensorProductType.vecMatMulAdd (1:R) y A 0 (0:X)⟩

variable [MatrixMulNotation M]

@[simp, simp_core] theorem zero_matVecMul (x : X) : (0 : M) * x = 0 := sorry_proof
@[simp, simp_core] theorem matVecMul_zero (A : M) : A * (0 : X) = 0 := sorry_proof
@[simp, simp_core] theorem vecMatMul_zero (y : Y) : y * (0 : M) = 0 := sorry_proof
@[simp, simp_core] theorem zero_vecMatMul (A : M) : (0 : Y) * A = 0 := sorry_proof

theorem add_matVecMul (A B : M) (x : X) : (A+B)*x = A*x + B*x := sorry_proof
theorem matVecMul_add (A : M) (x y : X) : A*(x+y) = A*x + A*y := sorry_proof
theorem vecMatMul_add (A B : M) (y : Y) : y*(A+B) = y*A + y*B := sorry_proof
theorem add_vecMatMul (A : M) (x y : Y) : (x+y)*A = x*A + y*A := sorry_proof
theorem matVecMul_smul_assoc (a : R) (A : M) (x : X) : (a•A)*x = a•(A*x) := sorry_proof
theorem vecMatMul_smul_assoc (a : R) (y : Y) (A : M) : y*(a•A) = a•(y*A) := sorry_proof

section MatVecNotation

variable
  {XX : Type*} [AddCommGroup XX] [Module R XX] [MatrixType R X X XX] [TensorProductSelf R X XX]
  [MatrixMulNotation XX]

set_default_scalar R

@[simp, simp_core] theorem identityMatrix_matVecMul (x : X) : 𝐈[X] * x = x := sorry_proof
@[simp, simp_core] theorem vecMatMul_identityMatrix (x : X) : x * 𝐈[X] = x := sorry_proof

@[simp, simp_core]
theorem smul_identityMatrix_matVecMul (a : R) (x : X) : (a • 𝐈[X]) * x = a•x := by
  simp[matVecMul_smul_assoc]

@[simp, simp_core]
theorem vecMatMul_smul_identityMatrix (a : R) (x : X) : x * (a • 𝐈[X]) = a•x := by
  simp[vecMatMul_smul_assoc]
