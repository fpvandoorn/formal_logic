/-
Copyright (c) 2018 Jeremy Avigad. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jeremy Avigad

We isolate the first-order fragment of hol over some basic sorts. Assume sorts are numbered
0, 1, ..., n-1 for some n. (We should change that later.)
-/

/-
This will be convenient: a hol "arity" is of the form
  a1 ⇒ a2 ⇒ ... ⇒ an ⇒ r 
where the `a`'s are sorts and the `r` is either a sort or `prop`. If `r` is a sort, the arity
is a function arity, and if `r` is `prop`, it is a relation arity  
-/
import ..syntax

namespace hol

namespace arity
  @[derive has_reflect, derive decidable_eq]
  inductive kind 
  | fn | rel | none

  namespace kind
    def repr : kind → string
    | fn := "fn"
    | rel := "rel"
    | none := "none"

    instance : has_repr kind := ⟨repr⟩ 

  end kind
end arity

namespace type

def is_sort (num_sorts : nat) : type → bool
| (type.Basic (type.basic.user n)) := if n < num_sorts then tt else ff
| _                                := ff

def is_prop : type → bool 
| (type.Basic type.basic.prop) := tt
| _                            := ff

lemma is_not_arrow_of_is_sort {ty : type} {n : nat} : ty.is_sort n = tt → ty.is_arrow = ff :=
by cases ty; simp [type.is_sort]

section
  open arity

  def infer_arity_kind (num_sorts : nat) : type → arity.kind
  | (type.Var n)             := kind.none
  | t@(type.Basic _)         := if is_sort num_sorts t = tt then kind.fn
                                else if is_prop t = tt then kind.rel
                                else kind.none
  | (type.Arr t₁ t₂)         := if is_sort num_sorts t₁ = tt then infer_arity_kind t₂ else kind.none
  | (type.Constructor _)     := kind.none
  | (type.App _ _)           := kind.none 
end

def is_arity (num_sorts : nat) (t : type) : bool := 
if t.infer_arity_kind num_sorts = arity.kind.none then ff else tt 

/--
If `t` is an arity, `infer_arity num_sorts t` returns `some (alist, r)` where `alist` is the list of argument types, and `r` is the return type.

Otherwise, it return `none`.
-/
def infer_arity (num_sorts : nat) : type → option (list type × type)
| (type.Var n)             := none
| t@(type.Basic _)         := if is_sort num_sorts t || is_prop t = tt then some ([], t)
                              else none
| (type.Arr t₁ t₂)         := if is_sort num_sorts t₁ = tt then 
                              match infer_arity t₂ with
                              | some (alist, r) := some (t₁ :: alist, r)
                              | none            := none
                              end
                              else none
| (type.Constructor _)     := none
| (type.App _ _)           := none 

end type

end hol

namespace fol

-- TODO: probably better to use boolean bounded quantifiers
structure language :=
(num_sorts : nat)
(num_symbols : nat) 
(arity : fin num_symbols → hol.type)
(arities_ok : ∀ i, (arity i).is_arity num_sorts = tt)

end fol

namespace hol 

namespace type

@[reducible]
def is_fo_sort (L : fol.language) (t : type) : bool :=
t.is_sort L.num_sorts

def in_fo_language (L : fol.language) : type → bool
| (type.Var n)         := ff
| t@(type.Basic b)     := t.is_fo_sort L || t.is_prop
| (type.Arr t₁ t₂)     := in_fo_language t₁ && in_fo_language t₂
| (type.Constructor _) := ff
| (type.App _ _)       := ff

theorem is_in_language_of_is_sort (L : fol.language) :
    Π t : type, t.is_fo_sort L = tt → t.in_fo_language L = tt :=
by { intro t, cases t; simp [is_fo_sort, is_sort, in_fo_language], intro h, simp [h] }

theorem is_in_language_of_is_arity (L : fol.language) : 
    Π t : type, t.is_arity L.num_sorts = tt → t.in_fo_language L = tt
| (type.Var n)         := by simp [is_arity, infer_arity_kind]
| (type.Basic b)       := 
    begin 
      simp [is_arity, infer_arity_kind, in_fo_language, is_fo_sort],
      cases is_sort L.num_sorts (Basic b); simp,
      cases is_prop (Basic b); simp
    end
| (type.Arr t₁ t₂)     := 
    begin
      simp [in_fo_language, is_arity, infer_arity_kind],
      cases h: is_sort L.num_sorts t₁; simp,
      intro h₁, split,
      { apply is_in_language_of_is_sort _ _ h },
      apply is_in_language_of_is_arity, revert h₁,  
      simp [is_arity]
    end
| (type.Constructor _) := by simp [is_arity, infer_arity_kind]
| (type.App _ _)       := by simp [is_arity, infer_arity_kind]

/- TODO: if we replace every `= tt` with a coercion to Prop, something fails in the
   previous lemma, and the terms are huge. -/

end type

namespace term

namespace const

def in_fo_language (L : fol.language) : const → bool
| ⟨symb, t, l⟩ := 
  match symb with
  | (term.const.kind.user n)  := if h : n < L.num_symbols then
                                   if L.arity ⟨n, h⟩ = t ∧ t.in_fo_language L = bool.tt 
                                   then l.empty else bool.ff
                                 else bool.ff
  | (term.const.kind.true)    := if t = mk_prop then l.empty else bool.ff
  | (term.const.kind.false)   := if t = mk_prop then l.empty else bool.ff
  | (term.const.kind.not)     := if t = (mk_prop ⇒ mk_prop) then l.empty else bool.ff
  | (term.const.kind.and)     := if t = (mk_prop ⇒ mk_prop ⇒ mk_prop) then l.empty else bool.ff
  | (term.const.kind.or)      := if t = (mk_prop ⇒ mk_prop ⇒ mk_prop) then l.empty else bool.ff
  | (term.const.kind.implies) := if t = (mk_prop ⇒ mk_prop ⇒ mk_prop) then l.empty else bool.ff
  | (term.const.kind.iff)     := if t = (mk_prop ⇒ mk_prop ⇒ mk_prop) then l.empty else bool.ff
  | (term.const.kind.all)     := match l with 
                                 | [t'] := if t = (t' ⇒ t' ⇒ t') then bool.tt else bool.ff
                                 | _     := bool.ff
                                 end
  | (term.const.kind.ex)      := match l with 
                                 | [t'] := if t = (t' ⇒ t' ⇒ t') then bool.tt else bool.ff
                                 | _     := bool.ff
                                 end
  | _                         := bool.ff
  end

end const 

@[simp]
def in_fo_language (L : fol.language) (σ : list type): term → bool 
| (term.Var n)      := if h : n < σ.length then (σ.nth_le n h).is_fo_sort L else bool.ff  
| (term.Const c)    := c.in_fo_language L = tt
| (term.App t₁ t₂)  := in_fo_language t₁ && in_fo_language t₂ = tt
| (term.Abs s ty t) := in_fo_language t = ff

def is_fo_term (L : fol.language) (t : term) (σ : list type) : Prop :=
t.is_well_typed σ ∧ in_fo_language L σ t = tt ∧ (t.typeof σ).is_fo_sort L = tt

theorem in_fo_language_mk_app (L : fol.language) (t : term) (l : list term) (σ : list type) :
  (mk_app t l).in_fo_language L σ = tt ↔ 
    (t.in_fo_language L σ = tt ∧ (∀ t' ∈ l, in_fo_language L σ t' = tt)) :=
begin
  revert t, induction l with t' l ih; simp,
  intro t, rw ih, simp, rw [← and.assoc, @and.comm (_ = tt)],
end

private theorem hoist_precondition {A B C : Prop} (h₀ : A → C) (h₁ : B → C) (h : C → (A ↔ B)) :
  A ↔ B :=
iff.intro (λ hA, (h (h₀ hA)).mp hA) (λ hB, (h (h₁ hB)).mpr hB)

/-
both sides imply: is not an arrow, is well_typed, ...
-/

theorem is_fo_term_iff_aux (L : fol.language) (t : term) (σ : list type) (h : t.is_app = tt):
  is_fo_term L t σ ↔ 
    let fn := t.get_app_fn,
          args := t.get_app_args,
          fn_type := fn.typeof σ in
        fn.is_const = tt ∧ fn.in_fo_language L σ = tt ∧ fn_type.get_return_type.is_fo_sort L = tt ∧ 
        (∀ t' ∈ args, is_fo_term L t σ) ∧
        fn_type.get_arg_types = t.get_app_args.map (λ t', t'.typeof σ) :=
sorry  

theorem is_fo_term_iff (L : fol.language) (t : term) (σ : list type) :
  is_fo_term L t σ ↔ 
    (t.is_var = tt ∧ t.in_fo_language L σ = tt) ∨ 
    (t.is_const = tt ∧ t.in_fo_language L σ = tt ∧ (t.typeof σ).is_fo_sort L ) ∨ 
    (t.is_app = tt ∧ 
      let fn := t.get_app_fn,
          args := t.get_app_args,
          fn_type := fn.typeof σ in
        fn.is_const = tt ∧ fn.in_fo_language L σ = tt ∧ fn_type.get_return_type.is_fo_sort L = tt ∧ 
        (∀ t' ∈ args, is_fo_term L t σ) ∧
        fn_type.get_arg_types = t.get_app_args.map (λ t', t'.typeof σ)) :=
begin
  induction t,
  { simp [is_fo_term, in_fo_language, is_well_typed_iff, typeof],
    cases (decidable.em (t < list.length σ)) with h h; simp [h] },
  { simp [is_fo_term, in_fo_language, is_well_typed_iff] },
  { simp, apply is_fo_term_iff_aux, reflexivity  },
  simp [is_fo_term, type.is_fo_sort, type.is_sort, typeof]
end 

end term

end hol

namespace fol

namespace language

theorem arity_in_fo_language (L : language) (i : fin L.num_symbols) : 
  (L.arity i).in_fo_language L = tt :=
begin
  apply (L.arity i).is_in_language_of_is_arity L,
  apply L.arities_ok
end

end language

end fol