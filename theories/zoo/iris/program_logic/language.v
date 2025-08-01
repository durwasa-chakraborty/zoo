From iris.algebra Require Import
  ofe.

From zoo Require Import
  prelude.
From zoo.common Require Import
  list.
From zoo Require Import
  options.

Definition thread_id :=
  nat.
Implicit Types tid : thread_id.

Section language_mixin.
  Context {expr val state observation : Type}.
  Context (of_val : val → expr).
  Context (to_val : expr → option val).
  Context (prim_step : thread_id → expr → state → list observation → expr → state → list expr → Prop).

  Record LanguageMixin := {
    mixin_to_of_val v :
      to_val (of_val v) = Some v ;
    mixin_of_to_val e v :
      to_val e = Some v →
      of_val v = e ;
    mixin_val_stuck tid e σ κ e' σ' es :
      prim_step tid e σ κ e' σ' es →
      to_val e = None ;
  }.
End language_mixin.

Structure language := {
  expr : Type ;
  val : Type ;
  state : Type ;
  observation : Type ;
  of_val : val → expr ;
  to_val : expr → option val ;
  prim_step : thread_id → expr → state → list observation → expr → state → list expr → Prop ;
  language_mixin : LanguageMixin of_val to_val prim_step ;
}.
#[global] Arguments Build_language {_ _ _ _ _ _ _} _ : assert.
#[global] Arguments of_val {_}.
#[global] Arguments to_val {_}.
#[global] Arguments prim_step {_}.

Implicit Types Λ : language.

Declare Scope expr_scope.
Delimit Scope expr_scope with E.

Declare Scope val_scope.
Delimit Scope val_scope with V.

Bind Scope expr_scope with expr.
Bind Scope val_scope with val.

Canonical state_O {SI : sidx} Λ :=
  leibnizO (state Λ).
Canonical val_O {SI : sidx} Λ :=
  leibnizO (val Λ).
Canonical expr_O {SI : sidx} Λ :=
  leibnizO (expr Λ).

Definition config Λ : Type :=
  list (expr Λ) * state Λ.

Class LanguageCtx {Λ} (K : expr Λ → expr Λ) := {
  fill_not_val e :
    to_val e = None →
    to_val (K e) = None ;
  fill_step tid e1 σ1 κ e2 σ2 es :
    prim_step tid e1 σ1 κ e2 σ2 es →
    prim_step tid (K e1) σ1 κ (K e2) σ2 es ;
  fill_step_inv tid e1' σ1 κ e2 σ2 es :
    to_val e1' = None →
    prim_step tid (K e1') σ1 κ e2 σ2 es →
      ∃ e2',
      e2 = K e2' ∧
      prim_step tid e1' σ1 κ e2' σ2 es ;
}.

#[global] Instance language_ctx_id Λ :
  LanguageCtx (@id (expr Λ)).
Proof.
  constructor; naive_solver.
Qed.

Section language.
  Context {Λ}.

  Implicit Types e : expr Λ.
  Implicit Types v : val Λ.
  Implicit Types σ : state Λ.
  Implicit Types ρ : config Λ.
  Implicit Types κ : list (observation Λ).

  Class Atomic e :=
    atomic tid σ e' κ σ' es :
      prim_step tid e σ κ e' σ' es →
      is_Some (to_val e').

  Definition step ρ1 κ ρ2 :=
    ∃ tid e1 e2 σ2 es,
    prim_step tid e1 ρ1.2 κ e2 σ2 es ∧
    ρ1.1 !! tid = Some e1 ∧
    ρ2 = (<[tid := e2]> ρ1.1 ++ es, σ2).

  Definition silent_step ρ1 ρ2 :=
    ∃ κ,
    step ρ1 κ ρ2.

  Inductive nsteps : nat → config Λ → list (observation Λ) → config Λ → Prop :=
    | nsteps_refl ρ :
       nsteps 0 ρ [] ρ
    | nsteps_l n ρ1 ρ2 ρ3 κ κs :
       step ρ1 κ ρ2 →
       nsteps n ρ2 κs ρ3 →
       nsteps (S n) ρ1 (κ ++ κs) ρ3.
  #[local] Hint Constructors nsteps : core.

  Definition reducible tid e σ :=
    ∃ κ e' σ' es,
    prim_step tid e σ κ e' σ' es.
  Definition reducible_no_obs tid e σ :=
    ∃ e' σ' es,
    prim_step tid e σ [] e' σ' es.
  Definition irreducible tid e σ :=
    ∀ κ e' σ' es,
    ¬ prim_step tid e σ κ e' σ' es.
  Definition stuck tid e σ :=
    to_val e = None ∧
    irreducible tid e σ.
  Definition not_stuck tid e σ :=
    is_Some (to_val e) ∨
    reducible tid e σ.
  Definition safe ρ :=
    ∀ ρ',
    rtc silent_step ρ ρ' →
    Foralli (λ tid e, not_stuck tid e ρ'.2) ρ'.1.

  Record pure_step e1 e2 := {
    pure_step_safe tid σ1 :
      reducible_no_obs tid e1 σ1 ;
    pure_step_det tid σ1 κ e2' σ2 es :
      prim_step tid e1 σ1 κ e2' σ2 es →
        κ = [] ∧
        σ2 = σ1 ∧
        e2' = e2 ∧
        es = [] ;
  }.

  Class PureExec (ϕ : Prop) n e1 e2 :=
    pure_exec :
      ϕ →
      relations.nsteps pure_step n e1 e2.

  Lemma to_of_val v :
    to_val (of_val v) = Some v.
  Proof.
    apply language_mixin.
  Qed.
  Lemma of_to_val e v :
    to_val e = Some v →
    of_val v = e.
  Proof.
    apply language_mixin.
  Qed.
  Lemma val_stuck tid e σ κ e' σ' es :
    prim_step tid e σ κ e' σ' es →
    to_val e = None.
  Proof.
    apply language_mixin.
  Qed.

  Lemma silent_steps_nsteps ρ1 ρ2 :
    rtc silent_step ρ1 ρ2 ↔
      ∃ n κs,
      nsteps n ρ1 κs ρ2.
  Proof.
    rewrite /silent_step. split.
    - induction 1; naive_solver.
    - intros (n & κs & Hsteps).
      induction Hsteps; eauto using rtc.
  Qed.

  Lemma of_to_val_flip v e :
    of_val v = e →
    to_val e = Some v.
  Proof.
    intros <-. rewrite to_of_val //.
  Qed.

  Lemma not_reducible tid e σ :
    ¬ reducible tid e σ ↔
    irreducible tid e σ.
  Proof.
    rewrite /reducible /irreducible. naive_solver.
  Qed.
  Lemma reducible_not_val tid e σ :
    reducible tid e σ →
    to_val e = None.
  Proof.
    intros (? & ? & ? & ? & ?). eauto using val_stuck.
  Qed.
  Lemma reducible_no_obs_reducible tid e σ :
    reducible_no_obs tid e σ →
    reducible tid e σ.
  Proof.
    intros (? & ? & ? & ?). eexists. eauto.
  Qed.
  Lemma val_irreducible tid e σ :
    is_Some (to_val e) →
    irreducible tid e σ.
  Proof.
    intros [? ?] ? ? ? ? ?%val_stuck.
    destruct (to_val e); done.
  Qed.
  #[global] Instance of_val_inj :
    Inj (=) (=) (@of_val Λ).
  Proof.
    intros v v' Hv.
    apply (inj Some). rewrite -!to_of_val Hv //.
  Qed.
  Lemma val_not_stuck tid e σ :
    is_Some (to_val e) →
    not_stuck tid e σ.
  Proof.
    intros (v & ?). left. done.
  Qed.
  Lemma not_not_stuck tid e σ :
    ¬ not_stuck tid e σ ↔
    stuck tid e σ.
  Proof.
    rewrite /stuck /not_stuck -not_eq_None_Some -not_reducible.
    destruct_decide (to_val e = None); naive_solver.
  Qed.

  Lemma reducible_fill K `{!@LanguageCtx Λ K} tid e σ :
    reducible tid e σ →
    reducible tid (K e) σ.
  Proof.
    rewrite /reducible. naive_solver eauto using fill_step.
  Qed.
  Lemma reducible_fill_inv K `{!@LanguageCtx Λ K} tid e σ :
    to_val e = None →
    reducible tid (K e) σ →
    reducible tid e σ.
  Proof.
    intros He (e' & σ' & k & es & Hstep). rewrite /reducible.
    apply fill_step_inv in Hstep as (e2' & _ & Hstep); naive_solver.
  Qed.
  Lemma reducible_no_obs_fill K `{!@LanguageCtx Λ K} tid e σ :
    reducible_no_obs tid e σ →
    reducible_no_obs tid (K e) σ.
  Proof.
    rewrite /reducible_no_obs. naive_solver eauto using fill_step.
  Qed.
  Lemma reducible_no_obs_fill_inv K `{!@LanguageCtx Λ K} tid e σ :
    to_val e = None →
    reducible_no_obs tid (K e) σ →
    reducible_no_obs tid e σ.
  Proof.
    intros He (e' & σ' & es & Hstep); rewrite /reducible_no_obs.
    apply fill_step_inv in Hstep as (e2' & _ & Hstep); eauto.
  Qed.
  Lemma irreducible_fill K `{!@LanguageCtx Λ K} tid e σ :
    to_val e = None →
    irreducible tid e σ →
    irreducible tid (K e) σ.
  Proof.
    rewrite -!not_reducible. naive_solver eauto using reducible_fill_inv.
  Qed.
  Lemma irreducible_fill_inv K `{!@LanguageCtx Λ K} tid e σ :
    irreducible tid (K e) σ →
    irreducible tid e σ.
  Proof.
    rewrite -!not_reducible. naive_solver auto using reducible_fill.
  Qed.

  Lemma not_stuck_fill_inv K `{!@LanguageCtx Λ K} tid e σ :
    not_stuck tid (K e) σ →
    not_stuck tid e σ.
  Proof.
    rewrite /not_stuck -!not_eq_None_Some. intros [? | ?].
    - auto using fill_not_val.
    - destruct_decide (to_val e = None); eauto using reducible_fill_inv.
  Qed.

  Lemma stuck_fill K `{!@LanguageCtx Λ K} tid e σ :
    stuck tid e σ →
    stuck tid (K e) σ.
  Proof.
    rewrite -!not_not_stuck. eauto using not_stuck_fill_inv.
  Qed.

  Lemma pure_step_ctx K `{!@LanguageCtx Λ K} e1 e2 :
    pure_step e1 e2 →
    pure_step (K e1) (K e2).
  Proof.
    intros [Hred Hstep]. split.
    - rewrite /reducible_no_obs in Hred |- *. naive_solver eauto using fill_step.
    - intros tid σ1 κ e2' σ2 es Hpstep.
      destruct (fill_step_inv tid e1 σ1 κ e2' σ2 es) as (e2'' & -> & ?); [|exact Hpstep|].
      + destruct (Hred tid σ1) as (? & ? & ? & ?); eauto using val_stuck.
      + edestruct (Hstep tid σ1 κ e2'' σ2 es) as (? & -> & -> & ->); done.
  Qed.

  Lemma pure_step_nsteps_ctx K `{!@LanguageCtx Λ K} n e1 e2 :
    relations.nsteps pure_step n e1 e2 →
    relations.nsteps pure_step n (K e1) (K e2).
  Proof.
    eauto using nsteps_congruence, pure_step_ctx.
  Qed.

  Lemma rtc_pure_step_ctx K `{!@LanguageCtx Λ K} e1 e2 :
    rtc pure_step e1 e2 →
    rtc pure_step (K e1) (K e2).
  Proof.
    eauto using rtc_congruence, pure_step_ctx.
  Qed.

  Lemma pure_exec_ctx K `{!@LanguageCtx Λ K} ϕ n e1 e2 :
    PureExec ϕ n e1 e2 →
    PureExec ϕ n (K e1) (K e2).
  Proof.
    rewrite /PureExec; auto using pure_step_nsteps_ctx.
  Qed.

  Class AsVal e v :=
    as_val : of_val v = e.

  Lemma as_val_is_Some e :
    (∃ v, of_val v = e) →
    is_Some (to_val e).
  Proof.
    intros [v <-]. rewrite to_of_val. auto.
  Qed.

  Lemma reducible_not_stuck tid e σ :
    reducible tid e σ →
    not_stuck tid e σ.
  Proof.
    rewrite /not_stuck. naive_solver.
  Qed.
  Lemma prim_step_not_stuck tid e σ κ e' σ' es :
    prim_step tid e σ κ e' σ' es →
    not_stuck tid e σ.
  Proof.
    rewrite /not_stuck /reducible. eauto 10.
  Qed.
  Lemma pure_step_not_stuck tid e1 e2 σ :
    pure_step e1 e2 →
    not_stuck tid e1 σ.
  Proof.
    intros Hstep.
    eapply reducible_not_stuck, reducible_no_obs_reducible, pure_step_safe. done.
  Qed.

  Lemma rtc_pure_step_val `{!Inhabited (state Λ)} v e :
    rtc pure_step (of_val v) e →
    to_val e = Some v.
  Proof.
    intros ?; rewrite <- to_of_val.
    f_equal; symmetry; eapply rtc_nf; first done.
    intros [e' [Hstep _]].
    destruct (Hstep inhabitant inhabitant) as (? & ? & ? & Hval%val_stuck).
    rewrite to_of_val // in Hval.
  Qed.

  Lemma safe_step ρ1 ρ2 :
    safe ρ1 →
    silent_step ρ1 ρ2 →
    safe ρ2.
  Proof.
    intros Hsafe Hstep ρ3 Hsteps.
    apply Hsafe. eauto using rtc.
  Qed.
  Lemma safe_not_stuck ρ tid e :
    safe ρ →
    ρ.1 !! tid = Some e →
    not_stuck tid e ρ.2.
  Proof.
    intros Hsafe Hlookup.
    specialize (Hsafe ρ). rewrite Foralli_lookup in Hsafe.
    eauto using rtc.
  Qed.

  Lemma step_length ρ1 κ ρ2 :
    step ρ1 κ ρ2 →
    length ρ1.1 ≤ length ρ2.1.
  Proof.
    intros (tid & e1 & e2 & σ2 & es & Hstep & Hlookup & ->).
    simpl_length/=. lia.
  Qed.
  Lemma nsteps_length n ρ1 κs ρ2 :
    nsteps n ρ1 κs ρ2 →
    length ρ1.1 ≤ length ρ2.1.
  Proof.
    induction 1 as [| ? ? ? ? ? ? Hstep%step_length]; lia.
  Qed.
End language.

#[global] Hint Mode PureExec + - - ! - : typeclass_instances.
