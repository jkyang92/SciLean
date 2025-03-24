import SciLean.Analysis.Convenient.ContCDiff
import SciLean.Analysis.Convenient.IsSmoothLinearMap
import SciLean.Analysis.Calculus.CDeriv

set_option linter.unusedVariables false

namespace SciLean

variable
  (K : Type _) [RCLike K]
  {X : Type _} [Vec K X]
  {Y : Type _} [Vec K Y]
  {Z : Type _} [Vec K Z]
  {W : Type _} [Vec K W]
  {ι : Type _} [IdxType ι nι] [DecidableEq ι]
  {E : ι → Type _} [∀ i, Vec K (E i)]

local notation "∞" => (⊤ : ℕ∞)


-- Function space --------------------------------------------------------------
--------------------------------------------------------------------------------

structure ContCDiffMap (n : ℕ∞) (X Y : Type _)  [Vec K X] [Vec K Y] where
  toFun : X → Y
  is_cont_cdiff_map : ContCDiff K n toFun

variable (n : ℕ∞)

instance : FunLike (ContCDiffMap K n X Y) X Y where
  coe f := f.toFun
  coe_injective' := sorry_proof

macro X:term:25 " ⟿[" K:term "," n:term "] " Y:term:26 : term =>
  `(ContCDiffMap $K $n $X $Y)

macro X:term:25 " ⟿[" n:term "] " Y:term:26 : term =>
  `(ContCDiffMap defaultScalar% $n $X $Y)

macro X:term:25 " ⟿ " Y:term:26 : term =>
  `(ContCDiffMap defaultScalar% ∞ $X $Y)

@[app_unexpander ContCDiffMap] def unexpandContCDiffMap : Lean.PrettyPrinter.Unexpander
  | `($(_) $R $n $X $Y) => `($X ⟿[$R,$n] $Y)
  | _  => throw ()


@[fun_prop]
theorem ContCDiffMap_apply_right (f : X ⟿[K,n] Y) : ContCDiff K n (fun x => f x) := f.2


-- Lambda function notation ----------------------------------------------------
--------------------------------------------------------------------------------

variable {K}

-- def ContCDiffMap.mk' (f : X → Y) (hf : ContCDiff K n f) :
--     ContCDiffMap K n X Y := ⟨f, hf⟩

@[simp, simp_core]
theorem ContCDiffMap.mk'_eval (x : X) (f : X → Y) (hf : ContCDiff K n f) :
    mk f hf x = f x := by rfl

@[simp, simp_core]
theorem ContCDiffMap.eta_reduce (f : ContCDiffMap K n X Y) :
    (mk f.1 f.2) = f := by rfl


variable (K)
def ContCDiffMap.mk' (f : X → Y) (hf : ContCDiff K n f) : X ⟿[K,n] Y := ⟨f,hf⟩


open Lean Parser Term
macro "fun " x:funBinder " ⟿[" K:term "," n:term "] " b:term : term =>
  `(ContCDiffMap.mk' $K $n (fun $x => $b) (by fun_prop (disch:=norm_num; linarith)))

open Lean Parser Term
macro "fun " x:funBinder " ⟿[" n:term "] " b:term : term =>
  `(ContCDiffMap.mk' defaultScalar% $n (fun $x => $b) (by fun_prop (disch:=norm_num; linarith)))

open Lean Parser Term
macro "fun " x:funBinder " ⟿ " b:term : term =>
  `(ContCDiffMap.mk' defaultScalar% ∞ (fun $x => $b) (by fun_prop (disch:=norm_num; linarith)))

@[app_unexpander ContCDiffMap.mk'] def unexpandContCDiffMapMk : Lean.PrettyPrinter.Unexpander

  | `($(_) $R $n $f:term $_:term) =>
    match f with
    | `(fun $x':ident => $b:term) => `(fun $x' ⟿[$R,$n] $b)
    | `(fun ($x':ident : $ty) => $b:term) => `(fun ($x' : $ty) ⟿[$R,$n] $b)
    | `(fun $x':ident : $ty => $b:term) => `(fun ($x' : $ty) ⟿[$R,$n] $b)
    | _  => throw ()
  | _  => throw ()


@[simp, simp_core]
theorem ContCDiffMap_eta (f : X ⟿[K,n] Y) : (fun x ⟿[K,n] f x) = f := by rfl


-- Algebra ---------------------------------------------------------------------
--------------------------------------------------------------------------------

instance : Add (X ⟿[K,n] Y) := ⟨fun f g => fun x ⟿[K,n] f x + g x⟩
instance : Sub (X ⟿[K,n] Y) := ⟨fun f g => fun x ⟿[K,n] f x - g x⟩
instance : Neg (X ⟿[K,n] Y) := ⟨fun f => fun x ⟿[K,n] - f x⟩
instance : SMul K (X ⟿[K,n] Y) := ⟨fun r f => fun x ⟿[K,n] r • f x⟩
instance : Zero (X ⟿[K,n] Y) := ⟨fun x ⟿[K,n] 0⟩

section AlgebraSimps

variable (f g : X ⟿[K,n] Y) (x : X) (r : K)


@[simp, simp_core]
theorem ContCDiffMap.add_apply : (f + g) x = f x + g x := by rfl

@[simp, simp_core]
theorem ContCDiffMap.sub_apply : (f - g) x = f x - g x := by rfl

@[simp, simp_core]
theorem ContCDiffMap.neg_apply : (- f) x = - f x := by rfl

@[simp, simp_core]
theorem ContCDiffMap.smul_apply : (r • f) x = r • f x := by rfl

@[simp, simp_core]
theorem ContCDiffMap.zero_apply : (0 : X ⟿[K,n] Y) x = 0 := by sorry_proof

end AlgebraSimps

instance : UniformSpace (X ⟿[K,n] Y) where
  IsOpen := default
  isOpen_univ := sorry_proof
  isOpen_inter := sorry_proof
  isOpen_sUnion := sorry_proof
  uniformity := default
  symm := sorry_proof
  comp := sorry_proof
  nhds_eq_comap_uniformity := sorry_proof

instance : Vec K (X ⟿[K,n] Y) := Vec.mkSorryProofs


-- set_option trace.Meta.Tactic.fun_prop.attr true


-- The following two theorems are somehow related to catesian closedness of convenient vectors spaces
@[fun_prop]
theorem ContCDiffMap_apply (f : W → X ⟿[K,∞] Y) (g : W → X)
    (hf : ContCDiff K ∞ f) (hg : ContCDiff K ∞ g) : ContCDiff K ∞ (fun w => f w (g w)) := sorry_proof

@[fun_prop]
theorem ContCDiffMap.mk.arg_f.ContCDiff_rule (f : X → Y → Z)
    (hf : ContCDiff K ⊤ (fun xy : X×Y => f xy.1 xy.2)) :
    ContCDiff K ∞ (fun x => (fun y ⟿[K,∞] f x y)) := sorry_proof

-- I'm not sure if this is true but it sounds plausible
@[fun_prop]
theorem ContCDiffMap_partial (n : Nat) (f : W → X ⟿[K,n] Y) (g : W → X)
    (hf : ContCDiff K n f) (hg : ContCDiff K n g) : ContCDiff K n (fun w => f w (g w)) := sorry_proof

-- I'm not sure if this is true but it sounds plausible
@[fun_prop]
theorem ContCDiffMap.mk.arg_f.ContCDiff_rule_partial (n l k : ℕ) (f : X → Y → Z)
    (hf : ContCDiff K n (fun xy : X×Y => f xy.1 xy.2)) (h : l + k ≤ n) :
    ContCDiff K k (fun x => (fun y ⟿[K,l] f x y)) := sorry_proof


----------------------------------------------------------------------------------------------------

@[fun_prop]
theorem ContCDiffMap_apply_linearSmoothMap
    (f : W → X ⟿[K,n] Y) (hf : IsSmoothLinearMap K f) (x : X) :
    IsSmoothLinearMap K (fun w => f w x) := sorry_proof

@[fun_prop]
theorem ContCDiffMap.mk.arg_f.IsSmoothLinearMap_rule
    (f : W → X → Y)
    (hf₁ : CDifferentiable K (fun (w,x) => f w x))
    (hf₂ : IsLinearMap K f)
    (hf₃ : ∀ w, ContCDiff K n (f w)) :
    IsSmoothLinearMap K (fun w => fun x ⟿[K,n] f w x) := sorry_proof

@[fun_prop]
theorem ContCDiffMap_eval_CDifferentiable (h : 0 < n) :
    CDifferentiable K (fun (fx : (X ⟿[K,n] Y)×X) => fx.1 fx.2) := by sorry_proof

@[fun_prop]
theorem ContCDiffMap_eval_CDifferentiable' :
    CDifferentiable K (fun (fx : (X ⟿[K,∞] Y)×X) => fx.1 fx.2) := by sorry_proof


@[fun_prop]
theorem ContCDiffMap_apply_CDifferentiable (f : W → X ⟿[K,∞] Y) (g : W → X)
    (hf : CDifferentiable K f) (hg : CDifferentiable K g) : CDifferentiable K (fun w => f w (g w)) := by sorry_proof

@[fun_prop]
theorem ContCDiffMap_apply_CDifferentiableAt (f : W → X ⟿[K,∞] Y) (g : W → X) (w : W)
    (hf : CDifferentiableAt K f w) (hg : CDifferentiableAt K g w) : CDifferentiableAt K (fun w => f w (g w)) w := by sorry_proof
