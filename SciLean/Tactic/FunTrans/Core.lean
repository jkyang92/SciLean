/-
Copyright (c) 2024 Tomas Skrivan. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Tomas Skrivan
-/
import Lean
import Qq
import Batteries.Tactic.Exact

import SciLean.Tactic.FunTrans.Theorems
import SciLean.Tactic.FunTrans.Types
import Mathlib.Tactic.FunProp.Core
import Mathlib.Tactic.FunProp.Types

/-!
## `funTrans` core tactic algorithm
-/

namespace Mathlib
open Lean Meta Qq

namespace Meta.FunTrans

def runFunProp (e : Expr) : SimpM (Option Expr) := do
  let cache := (← get).cache
  modify (fun s => { s with cache := {}}) -- hopefully this prevent duplicating the cache
  let ctx   := (← funTransContext.get).funPropContext
  let state := { cache := cache : FunProp.State }
  -- We run fun_prop at default transparency
  -- As fun_prop unfolds `id`, `Function.comp`, ... it tries to apply `Continuous id` to
  -- `Continuous (fun x => x)` and this fails when running at 'reducible and instances' transparency
  -- and that is the default transparency simp is running in
  let (result?, state) ← withDefault <| FunProp.funProp e |>.run ctx state
  modify (fun simpState => { simpState with cache := state.cache })

  match result? with
  | .some r => return r.proof
  | .none => return .none


private def ppOrigin' (origin : FunProp.Origin) : MetaM String := do
  match origin with
  | .fvar id => return s!"{← ppExpr (.fvar id)} : {← ppExpr (← inferType (.fvar id))}"
  | _ => pure (toString origin.name)


-- TODO: remove this once updated to newer version of mathlib
/-- Is `e` a `fun_prop` goal? For example `∀ y z, Continuous fun x => f x y z` -/
private def FunProp.isFunPropGoal (e : Expr) : MetaM Bool := do
  forallTelescope e fun _ b =>
  return (← FunProp.getFunProp? b).isSome


def synthesizeArgs (thmId : FunProp.Origin) (xs : Array Expr) : SimpM Bool := do
  let mut postponed : Array Expr := #[]
  for x in xs do
    let type ← inferType x
    if (← instantiateMVars x).isMVar then
      -- A hypothesis can be both a type class instance as well as a proposition,
      -- in that case we try both TC synthesis and the discharger
      -- (because we don't know whether the argument was originally explicit or instance-implicit).
      if (← isClass? type).isSome then
        if (← synthesizeInstance x type) then
          continue

      if (← isProp type) then
        if ← FunProp.isFunPropGoal type then
          if let .some r ← runFunProp type then
            try
              -- we assign the result at default transparency as we run `fun_prop` at default
              -- transparency, see comment at the function `runFunProp`
              withDefault <| x.mvarId!.assignIfDefEq r
            catch _ =>
              trace[Meta.Tactic.fun_trans.discharge]
                "{← ppOrigin' thmId}, failed to assign {r} to ({x} : {type})"
              return false
            continue
        else
          let disch := (← funTransContext.get).funPropContext.disch
          if let .some r ← disch type then
            try
              -- we run this at default transparency just in case too
              withDefault <| x.mvarId!.assignIfDefEq r
            catch _ =>
              trace[Meta.Tactic.fun_trans.discharge]
                "{← ppOrigin' thmId}, failed to assign {r} to ({x} : {type})"
              return false
            continue

      if ¬(← isProp type) then
        postponed := postponed.push x
        continue
      else
        trace[Meta.Tactic.fun_trans]
          "{← ppOrigin' thmId}, failed to discharge hypotheses{indentExpr type}"
        return false

  for x in postponed do
    if (← instantiateMVars x).isMVar then
      trace[Meta.Tactic.fun_trans]
        "{← ppOrigin' thmId}, failed to infer `({← ppExpr x} : {← ppExpr (← inferType x)})`"
      return false

  return true
where
  synthesizeInstance (x type : Expr) : SimpM Bool := do
    match (← trySynthInstance type) with
    | LOption.some val =>
      if (← withReducibleAndInstances <| isDefEq x val) then
        return true
      else
        trace[Meta.Tactic.fun_trans.discharge] "{← ppOrigin' thmId}, failed to assign instance{indentExpr type}\nsythesized value{indentExpr val}\nis not definitionally equal to{indentExpr x}"
        return false
    | _ =>
      trace[Meta.Tactic.fun_trans.discharge] "{← ppOrigin' thmId}, failed to synthesize instance{indentExpr type}"
      return false



def tryTheoremCore (lhs : Expr) (xs : Array Expr) (val : Expr) (type : Expr) (e : Expr) (thmId : FunProp.Origin) : SimpM (Option Simp.Result) := do
  withTraceNode `Meta.Tactic.fun_trans
    (fun r => return s!"[{ExceptToEmoji.toEmoji r}] applying: {← ppOrigin' thmId}") do

  unless (← isDefEq lhs (← instantiateMVars e)) do
    trace[Meta.Tactic.fun_trans.unify] "failed to unify {← ppOrigin' thmId}\n{lhs}\nwith\n{e}"
    return none

  if ¬(← synthesizeArgs thmId xs) then
    return none

  let proof ← instantiateMVars (mkAppN val xs)
  let rhs := (← instantiateMVars type).appArg!
  if e == rhs then
    return none
  trace[Meta.Tactic.fun_trans] "{← ppOrigin' thmId}, \n{e}\n==>\n{rhs}"
  return .some { expr := rhs, proof? := proof }


def tryTheoremWithHint (e : Expr) (thmOrigin : FunProp.Origin) (hint : Array (Nat × Expr)) : SimpM (Option Simp.Result) := do

  let proof ← thmOrigin.getValue
  let type ← instantiateMVars (← inferType proof)
  let (xs, _, type) ← forallMetaTelescope type
  let .some (_,lhs,_) := type.eq?
    | throwError "fun_trans bug: applying theorem {← ppExpr type} that is not an equality"

  try
    for (id,v) in hint do
      xs[id]!.mvarId!.assignIfDefEq v
  catch _ =>
    trace[Meta.Tactic.fun_trans.discharge]  "failed to use `{← FunProp.ppOrigin thmOrigin}` on `{e}`"
    return .none

  let extraArgsNum := e.getAppNumArgs - lhs.getAppNumArgs
  let e' := e.stripArgsN extraArgsNum
  let extraArgs := e.getAppArgsN extraArgsNum
  let .some r ← tryTheoremCore lhs xs proof type e' thmOrigin | return .none
  return (← r.addExtraArgs extraArgs)


def tryTheorem? (e : Expr) (thmOrigin : FunProp.Origin) : SimpM (Option Simp.Result) :=
  tryTheoremWithHint e thmOrigin #[]


def applyIdRule (funTransDecl : FunTransDecl) (e : Expr) : SimpM (Option Simp.Result) := do
  trace[Meta.Tactic.fun_trans.step] "id case"

  let thms ← getLambdaTheorems funTransDecl.funTransName .id e.getAppNumArgs

  if thms.size = 0 then
    trace[Meta.Tactic.fun_trans] "missing identity rule to transform `{← ppExpr e}`"
    return none

  for thm in thms do
    if let .some r ← tryTheorem? e (.decl thm.thmName) then
      return r

  return none

def applyConstRule (funTransDecl : FunTransDecl) (e : Expr) : SimpM (Option Simp.Result) := do
  let thms ← getLambdaTheorems funTransDecl.funTransName .const e.getAppNumArgs

  if thms.size = 0 then
    trace[Meta.Tactic.fun_trans] "missing const rule to transform `{← ppExpr e}`"
    return none

  for thm in thms do
    if let .some r ← tryTheorem? e (.decl thm.thmName) then
      return r

  return none

def applyCompRule (funTransDecl : FunTransDecl) (e f g : Expr) : SimpM (Option Simp.Result) := do
  let thms ← getLambdaTheorems funTransDecl.funTransName .comp e.getAppNumArgs

  if thms.size = 0 then
    trace[Meta.Tactic.fun_trans] "missing comp rule to transform `{← ppExpr e}`"
    return none

  for thm in thms do
    let .comp id_f id_g := thm.thmArgs | continue
    trace[Meta.Tactic.fun_trans] "trying comp theorem {thm.thmName}"
    if let .some r ← tryTheoremWithHint e (.decl thm.thmName) #[(id_f,f),(id_g,g)] then
      return r

  return none

def applyLetRule (funTransDecl : FunTransDecl) (e f g : Expr) : SimpM (Option Simp.Result) := do
  let thms ← getLambdaTheorems funTransDecl.funTransName .letE e.getAppNumArgs

  if thms.size = 0 then
    trace[Meta.Tactic.fun_trans] "missing let rule to transform `{← ppExpr e}`"
    return none

  for thm in thms do
    let .letE id_f id_g := thm.thmArgs | continue

    if let .some r ← tryTheoremWithHint e (.decl thm.thmName) #[(id_f,f),(id_g,g)] then
      return r

  return none

def applyApplyRule (funTransDecl : FunTransDecl) (e : Expr) : SimpM (Option Simp.Result) := do
  let thms ← getLambdaTheorems funTransDecl.funTransName .apply e.getAppNumArgs

  if thms.size = 0 then
    trace[Meta.Tactic.fun_trans]
      "missing projection rule to transform `{← ppExpr e}`"
    return none

  for thm in thms do
    if let .some r ← tryTheorem? e (.decl thm.thmName) then
      return r

  return none

def applyPiRule (funTransDecl : FunTransDecl) (e f : Expr) : SimpM (Option Simp.Result) := do
  let thms ← getLambdaTheorems funTransDecl.funTransName .pi e.getAppNumArgs

  if thms.size = 0 then
    trace[Meta.Tactic.fun_trans] "missing pi rule to transform `{← ppExpr e}`"
    return none

  for thm in thms do
    let .pi id_f := thm.thmArgs | continue
    if let .some r ← tryTheoremWithHint e (.decl thm.thmName) #[(id_f, f)] then
      return r

  return none


def applyMorTheorems (funTransDecl : FunTransDecl) (e : Expr) (fData : FunProp.FunctionData) : SimpM (Option Simp.Result) := do

  match ← fData.isMorApplication with
  | .none => return none
  | .underApplied =>
    applyPiRule funTransDecl e (← fData.toExpr)
  | .overApplied =>
    let .some (f,g) ← fData.peeloffArgDecomposition | return none
    applyCompRule funTransDecl e f g
  | .exact =>
    let ext := (morTheoremsExt.getState (← getEnv))

    let candidates ← withConfig (fun cfg => {cfg with iota :=false, zeta := false}) <|
      ext.theorems.getMatchWithScoreWithExtra e false
    let candidates := candidates.map (·.1) |>.flatten

    trace[Meta.Tactic.fun_trans]
      "candidate morphism theorems: {← candidates.mapM fun c => ppOrigin (.decl c.thmName)}"

    for c in candidates do
      if let .some r ← tryTheoremWithHint e (.decl c.thmName) #[] then
        return r

    return none

def applyFVarTheorems (e : Expr) : SimpM (Option Simp.Result) := do

  let ext := (fvarTheoremsExt.getState (← getEnv))

  let candidates ← withConfig (fun cfg => {cfg with iota :=false, zeta := false}) <|
    ext.theorems.getMatchWithScoreWithExtra e false
  let candidates := candidates.map (·.1) |>.flatten

  trace[Meta.Tactic.fun_trans]
    "candidate fvar theorems: {← candidates.mapM fun c => ppOrigin (.decl c.thmName)}"

  for c in candidates do
    if let .some r ← tryTheoremWithHint e (.decl c.thmName) #[] then
      return .some r

  return none

def getLocalTheorems (funTransDecl : FunTransDecl) (funOrigin : FunProp.Origin)
    (mainArgs : Array Nat) (appliedArgs : Nat) : MetaM (Array FunctionTheorem) := do

  let mut thms : Array FunctionTheorem := #[]
  let lctx ← getLCtx
  for var in lctx do
    if (var.kind = Lean.LocalDeclKind.auxDecl) then
      continue
    let type ← instantiateMVars var.type
    let thm? : Option FunctionTheorem ←
      forallTelescope type fun _ b => do
      let b ← whnfR b
      let .some (_,lhs,_) := b.eq? | return none
      let .some (decl,f) ← getFunTrans? lhs | return none
      unless decl.funTransName = funTransDecl.funTransName do return none

      let .data fData ← FunProp.getFunctionData? f FunProp.defaultUnfoldPred | return none
      unless (fData.getFnOrigin == funOrigin) do return none

      unless FunProp.isOrderedSubsetOf mainArgs fData.mainArgs do return none

      let dec? ← fData.nontrivialDecomposition

      let thm : FunctionTheorem := {
        funTransName := funTransDecl.funTransName
        transAppliedArgs := lhs.getAppNumArgs
        thmOrigin := .fvar var.fvarId
        funOrigin := funOrigin
        mainArgs := fData.mainArgs
        appliedArgs := fData.args.size
        priority := eval_prio default
        form := if dec?.isSome then .comp else .uncurried
      }

      return .some thm

    if let .some thm := thm? then
      thms := thms.push thm

  thms := thms
    |>.qsort (fun t s =>
      let dt := (Int.ofNat t.appliedArgs - Int.ofNat appliedArgs).natAbs
      let ds := (Int.ofNat s.appliedArgs - Int.ofNat appliedArgs).natAbs
      match compare dt ds with
      | .lt => true
      | .gt => false
      | .eq => t.mainArgs.size < s.mainArgs.size)

  return thms


def tryTheorems (funTransDecl : FunTransDecl) (e : Expr) (fData : FunProp.FunctionData)
    (thms : Array FunctionTheorem) : SimpM (Option Simp.Result) := do
  -- none - decomposition not tried
  -- some none - decomposition failed
  -- some some (f, g) - succesfull decomposition
  let mut dec? : Option (Option (Expr × Expr)) := none

  for thm in thms do

    trace[Meta.Tactic.fun_trans.step] s!"trying theorem {← ppOrigin' thm.thmOrigin}"

    match compare thm.appliedArgs fData.args.size with
    | .lt =>
      trace[Meta.Tactic.fun_trans] s!"removing argument to later use {← ppOrigin' thm.thmOrigin}"
      trace[Meta.Tactic.fun_trans] s!"NOT IMPLEMENTED"
      -- if let .some r ← removeArgRule funTransDecl e fData funTrans then
      --   return r
      return none
    | .gt =>
      trace[Meta.Tactic.fun_trans] s!"adding argument to later use {← ppOrigin' thm.thmOrigin}"
      if let .some r ← applyPiRule funTransDecl e (← fData.toExpr) then
        return r
      continue
    | .eq =>
      if thm.form == .comp then
        if let .some r ← tryTheorem? e thm.thmOrigin then
          return r
      else

        if thm.mainArgs.size == fData.mainArgs.size then
          if dec?.isNone then
            dec? := .some (← fData.nontrivialDecomposition)
          match dec? with
          | .some .none =>
            if let .some r ← tryTheorem? e thm.thmOrigin then
              return r
          | .some (.some (f,g)) =>
            trace[Meta.Tactic.fun_trans.step]
              s!"decomposing to later use {←ppOrigin' thm.thmOrigin}, {← ppExpr (←fData.toExpr)} = {← ppExpr f}∘{← ppExpr g}"
            if let .some r ← applyCompRule funTransDecl e f g then
              return r
          | _ => continue
        else
          trace[Meta.Tactic.fun_trans.step]
            s!"decomposing in args {thm.mainArgs} to later use {←ppOrigin' thm.thmOrigin}"
          let .some (f,g) ← fData.decompositionOverArgs thm.mainArgs
            | continue
          trace[Meta.Tactic.fun_trans.step]
            s!"decomposition: {← ppExpr f} ∘ {← ppExpr g}"
          if let .some r ← applyCompRule funTransDecl e f g then
            return r
  return none


def letCase (funTransDecl : FunTransDecl) (e f : Expr) : SimpM (Option Simp.Result) := do
  trace[Meta.Tactic.fun_trans.step] "let case"

  let .lam xName xType (.letE yName yType yVal yBody _) xBi := f | return none

  match (yVal.hasLooseBVar 0), (yBody.hasLooseBVar 0), (yBody.hasLooseBVar 1) with
  | false, _, _ =>
    -- this probably breaks with dependent functions
    let f := Expr.lam xName xType (yBody.swapBVars 0 1) xBi
    let e' := Expr.letE yName yType yVal (e.setArg (funTransDecl.funArgId) f) false

    trace[Meta.Tactic.fun_trans.step] "{e} ==> {e'}"

    return .some ({expr := e'})

  | _, true, true =>

    let f := Expr.lam xName xType (.lam yName yType yBody .default) xBi
    let g := Expr.lam xName xType yVal .default

    applyLetRule funTransDecl e f g
  | _, true, false =>
    let f := Expr.lam yName yType yBody default
    let g := Expr.lam xName xType yVal default

    applyCompRule funTransDecl e f g

  | true, false, _ =>
    let f := Expr.lam xName xType (yBody.lowerLooseBVars 1 1) xBi
    let e' := e.setArg (funTransDecl.funArgId) f

    trace[Meta.Tactic.fun_trans.step] "{e} ==> {e'}"

    return .some ({expr := e'})




def bvarAppCase (funTransDecl : FunTransDecl) (e : Expr) (fData : FunProp.FunctionData) : SimpM (Option Simp.Result) := do
  trace[Meta.Tactic.fun_trans.step] "bvar app case"

  if (← fData.isMorApplication) != .none then
    applyMorTheorems funTransDecl e fData
  else
    if let .some (f, g) ← fData.nontrivialDecomposition then
      applyCompRule funTransDecl e f g
    else
      applyApplyRule funTransDecl e

  -- if let .some (f,g) ← fData.nontrivialDecomposition then
  --   return ← applyCompRule funTransDecl e f g
  -- else
  --   if fData.args.size = 1 then
  --     let x := fData.args[0]!
  --     if x.coe.isSome then
  --       trace[Meta.Tactic.fun_trans.step] "morphism apply case"
  --       if let .some r ← applyMorTheorems funTransDecl e fData then
  --         return r
  --       return none
  --     else
  --       let x := x.expr
  --       let .forallE xName X Y bi ← withLCtx fData.lctx fData.insts do inferType fData.fn
  --         | return none

  --       if Y.hasLooseBVars then
  --         let Y := Expr.lam xName X Y bi
  --         return ← applyApplyDepRule funTransDecl e x Y
  --       else
  --         return ← applyApplyRule funTransDecl e x Y
  --   else
  --     -- can we get here?
  --     throwError "fun_trans bug: bvar app unhandled case"


def fvarAppCase (funTransDecl : FunTransDecl) (e : Expr) (fData : FunProp.FunctionData) : SimpM (Option Simp.Result) := do
  trace[Meta.Tactic.fun_trans.step] "fvar app case"
  if let .some (f,g) ← fData.nontrivialDecomposition then
    if let .some r ← applyMorTheorems funTransDecl e fData then
      return r

    return ← applyCompRule funTransDecl e f g
  else

    let .fvar fvarId := fData.fn | throwError "fun_trans bug: incorrectly calling fvarAppCase!"

    let thms ← getLocalTheorems funTransDecl (.fvar fvarId) fData.mainArgs e.getAppNumArgs
    trace[Meta.Tactic.fun_trans] "candidate local theorems for {← ppExpr (.fvar fvarId)}: {thms.map fun thm => thm.thmOrigin.name}"
    if let .some r ← tryTheorems funTransDecl e fData thms then
      return r

    -- unfold let fvar and add new let fvar with its transformation
    if let .some f ← fData.unfoldHeadFVar? then
      trace[Meta.Tactic.fun_trans] "unfolding local function {Expr.fvar fvarId} ==> {f}"
      let r' := e.setArg funTransDecl.funArgId f
      let fname' := (← fvarId.getUserName).appendAfter "'"
      let e' := Expr.letE fname' (← inferType r') r' (.bvar 0) false
      trace[Meta.Tactic.fun_trans] "{e} ==> {e'}"
      return .some { expr := e' }

      -- let r' ← Simp.simp (e.setArg funTransDecl.funArgId f)
      -- let fname' := (← fvarId.getUserName).appendAfter "'"
      -- let e' := Expr.letE fname' (← inferType r'.expr) r'.expr (.bvar 0) false
      -- return .some { expr := e', proof? := r'.proof? }

    if let .some r ← applyMorTheorems funTransDecl e fData then
      return r

    if let .some r ← applyFVarTheorems e then
      return r

    return none

/-- Prevend applying morphism theorems to `fun fx => ⇑(Prod.fst fx) (Prod.snd fx)` -/
def morphismGuard (fData : FunProp.FunctionData) : MetaM Bool := do

  trace[Meta.Tactic.fun_trans] "running guard on {← ppExpr (←fData.toExpr)}"
  trace[Meta.Tactic.fun_trans] "morphism guard 0 {fData.args.size}"
  unless fData.args.size == 4 do return true
  trace[Meta.Tactic.fun_trans] "morphism guard 1 {fData.args[3]!.coe.isSome}"
  unless fData.args[3]!.coe.isSome do return true
  trace[Meta.Tactic.fun_trans] "morphism guard 2 {(← fData.getFnConstName?)}"
  unless (← fData.getFnConstName?) == .some ``Prod.fst do return true
  trace[Meta.Tactic.fun_trans] "morphism guard 3 {← ppExpr fData.args[2]!.expr}"
  unless fData.args[2]!.expr == fData.mainVar do return true
  trace[Meta.Tactic.fun_trans] "morphism guard 4"
  unless fData.args[3]!.expr.isAppOfArity ``Prod.snd 3 do return true
  trace[Meta.Tactic.fun_trans] "morphism guard 5 {← ppExpr fData.args[3]!.expr.appArg!}"
  unless fData.args[3]!.expr.appArg! == fData.mainVar do return true
  trace[Meta.Tactic.fun_trans] "morphism guard 6"

  return false


def constAppCase (funTransDecl : FunTransDecl) (e : Expr) (fData : FunProp.FunctionData) : SimpM (Option Simp.Result) := do
  trace[Meta.Tactic.fun_trans.step] "const app case on {← ppExpr e}"

  let .some funName ← fData.getFnConstName?
    | throwError "fun_trans bug: incorrectly calling constAppCase!"

  let thms ←
    getTheoremsForFunction funName funTransDecl.funTransName e.getAppNumArgs fData.mainArgs
  trace[Meta.Tactic.fun_trans]
    "candidate theorems for {funName}: {thms.map fun thm => thm.thmOrigin.name}"
  if let .some r ← tryTheorems funTransDecl e fData thms then
    return r

  let thms ← getLocalTheorems funTransDecl (.decl funName) fData.mainArgs e.getAppNumArgs
  trace[Meta.Tactic.fun_trans]
    "candidate local theorems for {funName}: {thms.map fun thm => thm.thmOrigin.name}"
  if let .some r ← tryTheorems funTransDecl e fData thms then
    return r

  -- if ← morphismGuard fData then
  if let .some r ← applyMorTheorems funTransDecl e fData then
    return r

  if let .some (f,g) ← fData.nontrivialDecomposition then
    -- if ← morphismGuard fData then
      if let .some r ← applyCompRule funTransDecl e f g then
        return r
  else
    if let .some r ← applyFVarTheorems e then
      return r

  return none

local instance {ε} : ExceptToEmoji ε (Simp.Step) :=
  ⟨fun s =>
    match s with
    | .ok (.continue .none) => crossEmoji
    | .ok _ => checkEmoji
    | .error _ => bombEmoji⟩

/-- Main `funProp` function. Returns proof of `e`. -/
partial def funTrans (e : Expr) : SimpM Simp.Step := do

  let e ← instantiateMVars e

  let .some (funTransDecl, f) ← getFunTrans? e | return .continue

  if e.approxDepth > 200 then
    throwError "fun_trans, expression is too deep({e.approxDepth})\n{← ppExpr e}"

  withTraceNode `Meta.Tactic.fun_trans
    (fun r => return s!"[{ExceptToEmoji.toEmoji r}] {← ppExpr e}") do

  -- bubble leading lets infront of function transformationx
  if f.isLet then
    return ← FunProp.letTelescope f fun xs b => do
      trace[Meta.Tactic.fun_trans.step] "moving let bindings out"
      let e' := e.setArg funTransDecl.funArgId b
      return .visit { expr := ← mkLambdaFVars xs e' }

  let toStep (e : SimpM (Option Simp.Result)) : SimpM Simp.Step := do
    if let .some r ← e then
      return .visit r
    else
      return .continue

  match ← withConfig (fun cfg => {cfg with zeta := false, zetaDelta := false}) <|
    FunProp.getFunctionData? f FunProp.defaultUnfoldPred with
  | .letE f =>
    trace[Meta.Tactic.fun_trans.step] "let case on {← ppExpr f}"
    let e := e.setArg funTransDecl.funArgId f -- update e with reduced f
    toStep <| letCase funTransDecl e f
  | .lam f =>
    trace[Meta.Tactic.fun_trans.step] "lam case on {← ppExpr f}"
    let e := e.setArg funTransDecl.funArgId f -- update e with reduced f
    toStep <| applyPiRule funTransDecl e f
  | .data fData =>
    let e := e.setArg funTransDecl.funArgId (← fData.toExpr) -- update e with reduced f

    if fData.isIdentityFun then
      toStep <| applyIdRule funTransDecl e
    else if fData.isConstantFun then
      toStep <| applyConstRule funTransDecl e
    else
      match fData.fn with
      | .fvar id =>
        if id == fData.mainVar.fvarId!
        then toStep <| bvarAppCase funTransDecl e fData
        else toStep <| fvarAppCase funTransDecl e fData
      | .mvar .. => funTrans (← instantiateMVars e)
      | .const ..
      | .proj .. => toStep <| constAppCase funTransDecl e fData
      | _ =>
        trace[Meta.Tactic.fun_trans.step] "unknown case, ctor: {fData.fn.ctorName}\n{e}"
        return .continue
