import SciLean

open SciLean

variable {K} [RealScalar K]

set_default_scalar K

/-- info: ∂ x, x * x : K → K -/
#guard_msgs in
#check ∂ (fun x : K => x*x)

/-- info: ∂ (x:=1), x * x : K -/
#guard_msgs in
#check ∂ (fun x => x*x) (1:K)

/-- info: ∂ (x:=1), x * x : K -/
#guard_msgs in
#check ∂ (x:=(1:K)), x*x

variable (f : K → K → K)
-- /--
-- info: ∂ x,
--   match x with
--   | (x, y) => f x y : K × K → K × K → K
-- -/
-- #guard_msgs in
-- #check ((∂ (x,y), f x y) : K×K → K×K → K)

/-- info: ∂ (x:=1), x * x : K -/
#guard_msgs in
#check ∂ (x:=(1:K)), x*x

/-- info: ∂ (x:=0.1), x * x : K -/
#guard_msgs in
#check ∂ (x:=(0.1:K)), x*x
/-- info: ∂ x, x * x : K → K -/
#guard_msgs in
#check ∂ (x:K), x*x

/--
info: ∂ (x:=(1.0, 2.0)),
  match x with
  | (x, y) => x * y : K × K →L[K] K
-/
#guard_msgs in
#check ∂ ((x,y):=((1.0:K),(2.0:K))), x*y


/-- info: (∂ (x:=1), x) 2 : K -/
#guard_msgs in
#check ∂ x:=(1:K);(2:K), x

/-- info: (∂ (x:=1), x) 2 : K -/
#guard_msgs in
#check ∂ (x:=(1:K);(2:K)), x

/-- info: ∂ (x:=(1, 2)), (x + x) : K × K →L[K] K × K -/
#guard_msgs in
#check ∂ (x:=((1:K),(2:K))), (x + x)

/--
info: let df := ∂ (x:=(0, 0)), (x.1 + x.2 * x.1);
df (0, 0) : K
-/
#guard_msgs in
#check
  let df := ∂ (fun x : K×K => (x.1 + x.2*x.1)) (0,0)
  df (0,0)

/-- info: fun x => 2 * x : K → K -/
#guard_msgs in
#check ∂! (fun x : K => x^2)

/--
info: fun x =>
  fun x =>L[K]
    let dz := x + x;
    dz : K × K → K × K →L[K] K × K
-/
#guard_msgs in
#check ∂! (fun x : K×K => x + x)

/-- info: 1 + 1 : K -/
#guard_msgs in
#check ∂! (fun x => x*x) (1:K)

/-- info: fun x =>L[K] x + x : K × K →L[K] K × K -/
#guard_msgs in
#check ∂! (x:=((1:K),(2:K))), (x + x)

/-- info: 1 + 1 : K -/
#guard_msgs in
#check ∂! (x:=(1:K)), x*x

/-- info: fun x =>L[K] x + x : K × K →L[K] K × K -/
#guard_msgs in
#check ∂! (x:=((1:K),(2:K))), (x + x)

/-- info: ∂ x, x * x = fun x => x + x : Prop -/
#guard_msgs in
#check ((∂ (fun x : K => x*x)) = (fun x => x + x))

variable {X} [NormedAddCommGroup X] [NormedSpace K X] (f : X → X)

/-- info: ∂ (x:=0), f x : X →L[K] X -/
#guard_msgs in
#check ∂ (x:=(0:X)), f x

set_default_scalar Float

/-- info: 2.000000 -/
#guard_msgs in
#eval ∂! (fun x => x^2) (1:Float)
/-- info: 2.000000 -/
#guard_msgs in
#eval ∂! (fun x => x*x) (1:Float)
/-- info: 2.000000 -/
#guard_msgs in
#eval ∂! (x:=(1:Float)), x*x
/-- info: (2.000000, 0.000000) -/
#guard_msgs in
#eval ∂! (fun x => x + x) (1.0,2.0) (1.0,0.0)
/-- info: (2.000000, 0.000000) -/
#guard_msgs in
#eval ∂! (x:=(1.0,2.0);(1.0,0.0)), (x + x)



--------------------------------------------------------------------------------

set_default_scalar K

/-- info: ∇ x, x.1 : K × K → K × K -/
#guard_msgs in
#check ∇ x : (K×K), x.1
/-- info: fun x => (1, 0) : K × K → K × K -/
#guard_msgs in
#check ∇! x : (K×K), x.1
/-- info: fun x => (0, 1) : K × K → K × K -/
#guard_msgs in
#check ∇! x : (K×K), x.2

variable (y : K × K)

/-- info: ∇ (x:=y), (x + x) : K × K → K × K -/
#guard_msgs in
#check ∇ (x:=y), (x + x)
/-- info: ∇ x, x : K → K -/
#guard_msgs in
#check ∇ (x :K), x
/-- info: ∇ (x:=y), (x + x) : K × K → K × K -/
#guard_msgs in
#check ∇ (fun x => x + x) y
/-- info: ∇ (x:=(1.0, 2.0)), (x + x) : K × K → K × K -/
#guard_msgs in
#check ∇ (fun x => x + x) ((1.0,2.0) : K×K)
/-- info: fun x => (1, 0) : K × K → K × K -/
#guard_msgs in
#check (∇! x : (K×K), ⟪x,(1,0)⟫)


set_default_scalar Float

/-- info: 2.000000 -/
#guard_msgs in
#eval ∇! (fun x => x^2) 1
/-- info: 2.000000 -/
#guard_msgs in
#eval ∇! (fun x => x*x) 1
/-- info: 2.000000 -/
#guard_msgs in
#eval ∇! (x:=1), x*x
/-- info: (0.000000, 2.000000) -/
#guard_msgs in
#eval ∇! (fun x : Float×Float => (x + x).2) (1.0,2.0)
/-- info: (2.000000, 0.000000) -/
#guard_msgs in
#eval ∇! (x:=((1.0 : Float),(2.0:Float))), (x + x).1



--------------------------------------------------------------------------------

set_default_scalar K

/-- info: fun x dx => (x.1 + x.2 * x.1, dx.1 + (x.2 * dx.1 + dx.2 * x.1)) : K × K → K × K → K × K -/
#guard_msgs in
#check (∂>! x : K×K, (x.1 + x.2*x.1)) rewrite_by dsimp
/-- info: (1 + 1, 2 + (2 + 2)) : K × K -/
#guard_msgs in
#check (∂>! x:=(1:K);2, (x + x*x)) rewrite_by dsimp
/--
info: let a := ∂> x, (x.1 + x.2 * x.1);
a (0, 0) : K × K → K × K
-/
#guard_msgs in
#check
  let a := ∂> (fun x : K×K => (x.1 + x.2*x.1))
  a (0,0)


/-- info: ∂> x, (x + x * x) : K → K → K × K -/
#guard_msgs in
#check ∂> (x:K), (x + x*x)


--------------------------------------------------------------------------------

set_default_scalar K

/--
info: fun x => (x.1 + x.2 * x.1, fun dy => (dy + x.2 * dy, x.1 * dy)) : K × K → K × (K → K × K)
-/
#guard_msgs in
#check (<∂! x : K×K, (x.1 + x.2*x.1)) rewrite_by dsimp
/-- info: (1 + 1, fun dy => dy + (dy + dy)) : K × (K → K) -/
#guard_msgs in
#check (<∂! x:=(1:K), (x + x*x)) rewrite_by dsimp

/-- info: <∂ x, (x + x * x) : K → K × (K → K) -/
#guard_msgs in
#check <∂ (x:K), (x + x*x)
