import SciLean.Numerics.Optimization.Optimjl.Multivariate.Optimize.Optimize
import SciLean.Numerics.Optimization.Optimjl.Multivariate.Solvers.FirstOrder.BFGS
import SciLean.Numerics.Optimization.Optimjl.Multivariate.Solvers.FirstOrder.LBFGS
import SciLean.Numerics.Optimization.ArgMin

import SciLean.Analysis.Scalar.FloatAsReal
import SciLean.Util.Approx.Basic
import SciLean.Util.Approx.ApproxLimit

namespace SciLean

open Optimjl



/-- We just assume that there is some limiting process (expressed mathematically as a filter)
 on optimizer options under which all the optimizers converge.

An example of such limiting process would be sending `g_abstol` to zero and `iterations` to infinity.

Most definitelly there is not such universal limiting process as the convergence will surelly depend
on the particular optimizer and the function we optimize. As for now we just keep it as `opaque`
preventing us from proving anything about it. -/
opaque Options.filter {R : Type} [RealScalar R] : Filter (Options R) := default


/-- Finding minimum of a function an be approximated by running `optimize` with optimization
algorithm `method` with initial guess `x₀`.

This is most definitelly missing crucial assumptions on `f`, `method`, `x₀` to be actually true.
When used it should mainly just document user intent. -/
theorem argmin_eq_limit_optimize
    {R : Type} [RealScalar R] [ToString R]
    {X : Type} [NormedAddCommGroup X] [AdjointSpace R X] [CompleteSpace X] [ToString X]
    {Method : Type*} {State : outParam Type} [AbstractOptimizer Method State R X]
    (method : Method) (x₀ : X)
    {f : X → R} :
    (argmin x, f x)
    =
    limit opts ∈ Options.filter (R:=R),
      let f' := holdLet <| revFDeriv R f
      let r := optimize {f:=f,f':=f',hf:=sorry_proof} (AbstractOptimizer.setOptions X method opts) x₀
      r.minimizer := sorry_proof


#check LBFGS Float 1

set_default_scalar Float

open Scalar

approx mySqrt_v1 (y : Float) := argmin (x : Float), ‖x^2-y‖₂²
by
  rw[argmin_eq_limit_optimize (method := (default : LBFGS Float 1)) (x₀:=1)]

  approx_limit options sorry_proof

  conv in (revFDeriv _ _) => autodiff


def mySqrt_v2  (y : Float) :=
  let r := optimize (d:={f := fun (x : Float) => ‖x^2-y‖₂²,
                         f' := _,
                         hf := by data_synth => enter[3]; lsimp})
                    (method := (default : LBFGS Float 1))
                    (x₀ := 1)
  r.minimizer



/-- info: 1.414212 -/
#guard_msgs in
#eval mySqrt_v1 2 ({},())

/-- info: 1.414214 -/
#guard_msgs in
#eval mySqrt_v1 2 ({x_abstol := 1e-16, g_abstol := 0},())
