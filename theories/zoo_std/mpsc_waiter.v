From zoo Require Import
  prelude.
From zoo.common Require Import
  countable.
From zoo.iris.base_logic Require Import
  lib.oneshot
  lib.excl.
From zoo.language Require Import
  notations.
From zoo.diaframe Require Import
  diaframe.
From zoo_std Require Export
  base
  mpsc_waiter__code.
From zoo_std Require Import
  condition
  mpsc_waiter__types.
From zoo Require Import
  options.

Implicit Types b : bool.
Implicit Types l : location.

Class MpscWaiterG Σ `{zoo_G : !ZooG Σ} := {
  #[local] mpsc_waiter_G_mutex_G :: MutexG Σ ;
  #[local] mpsc_waiter_G_lstate_G :: OneshotG Σ unit unit ;
  #[local] mpsc_waiter_G_consumer_G :: ExclG Σ unitO ;
}.

Definition mpsc_waiter_Σ := #[
  mutex_Σ ;
  oneshot_Σ unit unit ;
  excl_Σ unitO
].
#[global] Instance subG_mpsc_waiter_Σ Σ `{zoo_G : !ZooG Σ} :
  subG mpsc_waiter_Σ Σ →
  MpscWaiterG Σ .
Proof.
  solve_inG.
Qed.

Section mpsc_waiter_G.
  Context `{mpsc_waiter_G : MpscWaiterG Σ}.

  Record metadata := {
    metadata_mutex : val ;
    metadata_condition : val ;
    metadata_lstate : gname ;
    metadata_consumer : gname ;
  }.
  Implicit Types γ : metadata.

  #[local] Instance metadata_eq_dec : EqDecision metadata :=
    ltac:(solve_decision).
  #[local] Instance metadata_countable :
    Countable metadata.
  Proof.
    solve_countable.
  Qed.

  #[local] Definition inv_inner l γ P : iProp Σ :=
    ∃ b,
    l.[flag] ↦ #b ∗
    if b then
      oneshot_shot γ.(metadata_lstate) () ∗
      (P ∨ excl γ.(metadata_consumer) ())
    else
      oneshot_pending γ.(metadata_lstate) (DfracOwn 1) ().
  Definition mpsc_waiter_inv t P : iProp Σ :=
    ∃ l γ,
    ⌜t = #l⌝ ∗
    meta l nroot γ ∗
    l.[mutex] ↦□ γ.(metadata_mutex) ∗
    mutex_inv γ.(metadata_mutex) True ∗
    l.[condition] ↦□ γ.(metadata_condition) ∗
    condition_inv γ.(metadata_condition) ∗
    inv nroot (inv_inner l γ P).

  Definition mpsc_waiter_consumer t : iProp Σ :=
    ∃ l γ,
    ⌜t = #l⌝ ∗
    meta l nroot γ ∗
    excl γ.(metadata_consumer) ().

  Definition mpsc_waiter_notified t : iProp Σ :=
    ∃ l γ,
    ⌜t = #l⌝ ∗
    meta l nroot γ ∗
    oneshot_shot γ.(metadata_lstate) ().

  #[global] Instance mpsc_waiter_inv_contractive t :
    Contractive (mpsc_waiter_inv t).
  Proof.
    rewrite /mpsc_waiter_inv /inv_inner. solve_contractive.
  Qed.
  #[global] Instance mpsc_waiter_inv_ne t :
    NonExpansive (mpsc_waiter_inv t).
  Proof.
    apply _.
  Qed.
  #[global] Instance mpsc_waiter_inv_proper t :
    Proper ((≡) ==> (≡)) (mpsc_waiter_inv t).
  Proof.
    apply _.
  Qed.

  #[global] Instance mpsc_waiter_inv_persistent t P :
    Persistent (mpsc_waiter_inv t P).
  Proof.
    apply _.
  Qed.
  #[global] Instance mpsc_waiter_notified_persistent t :
    Persistent (mpsc_waiter_notified t).
  Proof.
    apply _.
  Qed.
  #[global] Instance mpsc_waiter_consumer_timeless t :
    Timeless (mpsc_waiter_consumer t).
  Proof.
    apply _.
  Qed.
  #[global] Instance mpsc_waiter_notified_timeless t :
    Timeless (mpsc_waiter_notified t).
  Proof.
    apply _.
  Qed.

  Lemma mpsc_waiter_consumer_exclusive t :
    mpsc_waiter_consumer t -∗
    mpsc_waiter_consumer t -∗
    False.
  Proof.
    iIntros "(%l & %γ & -> & #Hmeta & Hconsumer1) (%l_ & %γ_ & %Heq & Hmeta_ & Hconsumer2)". injection Heq as <-.
    iDestruct (meta_agree with "Hmeta Hmeta_") as %<-. iClear "Hmeta_".
    iApply (excl_exclusive with "Hconsumer1 Hconsumer2").
  Qed.

  Lemma mpsc_waiter_create_spec P :
    {{{
      True
    }}}
      mpsc_waiter_create ()
    {{{ t,
      RET t;
      mpsc_waiter_inv t P ∗
      mpsc_waiter_consumer t
    }}}.
  Proof.
    iIntros "%Φ _ HΦ".

    wp_rec.
    wp_smart_apply (condition_create_spec with "[//]") as "%cond #Hcondition_inv".
    wp_smart_apply (mutex_create_spec True with "[//]") as "%mtx #Hmutex_inv".
    wp_block l as "Hmeta" "(Hflag & Hl_mutex & Hl_condition & _)".
    iMod (pointsto_persist with "Hl_mutex") as "Hl_mutex".
    iMod (pointsto_persist with "Hl_condition") as "Hl_condition".

    iMod (oneshot_alloc ()) as "(%γ_lstate & Hpending)".

    iMod (excl_alloc (excl_G := mpsc_waiter_G_consumer_G) ()) as "(%γ_consumer & Hconsumer)".

    pose γ := {|
      metadata_mutex := mtx ;
      metadata_condition := cond ;
      metadata_lstate := γ_lstate ;
      metadata_consumer := γ_consumer ;
    |}.
    iMod (meta_set γ with "Hmeta") as "#Hmeta"; first done.

    iSteps.
  Qed.

  Lemma mpsc_waiter_notify_spec t P :
    {{{
      mpsc_waiter_inv t P ∗
      P
    }}}
      mpsc_waiter_notify t
    {{{ b,
      RET #b;
      mpsc_waiter_notified t
    }}}.
  Proof.
    iIntros "%Φ ((%l & %γ & -> & #Hmeta & #Hl_mutex & #Hmutex_inv & #Hl_condition & #Hcondition_inv & #Hinv) & HP) HΦ".

    wp_rec.
    wp_pures.

    wp_bind (!_)%E.
    iInv "Hinv" as "(%b & Hflag & Hb)".
    wp_load.
    destruct b; first iSteps.
    iSplitR "HP HΦ"; first iSteps.
    iModIntro.

    wp_load.
    pose (Ψ_mtx res := (
      ∃ b,
      ⌜res = #b⌝ ∗
      oneshot_shot γ.(metadata_lstate)  ()
    )%I).
    wp_smart_apply (mutex_protect_spec Ψ_mtx with "[$Hmutex_inv HP]"); last iSteps.
    iIntros "Hmutex_locked _".
    wp_pures.

    wp_bind (!_)%E.
    iInv "Hinv" as "(%b & Hflag & Hb)".
    wp_load.
    destruct b; first iSteps.
    iSplitR "HP Hmutex_locked"; first iSteps.
    iModIntro.

    wp_pures.

    wp_bind (_ <- _)%E.
    iInv "Hinv" as "(%b & Hflag & Hb)".
    wp_store.
    destruct b; first iSteps.
    iMod (oneshot_update_shot with "Hb") as "#Hshot".
    iSteps.
  Qed.

  Lemma mpsc_waiter_try_wait_spec t P :
    {{{
      mpsc_waiter_inv t P ∗
      mpsc_waiter_consumer t
    }}}
      mpsc_waiter_try_wait t
    {{{ b,
      RET #b;
      if b then
        P
      else
        mpsc_waiter_consumer t
    }}}.
  Proof.
    iIntros "%Φ ((%l & %γ & -> & #Hmeta & #Hl_mutex & #Hmutex_inv & #Hl_condition & #Hcondition_inv & #Hinv) & (%l_ & %γ_ & %Heq & Hmeta_ & Hconsumer)) HΦ". injection Heq as <-.
    iDestruct (meta_agree with "Hmeta Hmeta_") as %<-. iClear "Hmeta_".

    wp_rec.
    wp_pures.

    iInv "Hinv" as "(%b & Hflag & Hb)".
    wp_load.
    destruct b; last iSteps.
    iDestruct "Hb" as "(Hshot & [HP | Hconsumer'])"; last first.
    { iDestruct (excl_exclusive with "Hconsumer Hconsumer'") as %[]. }
    iSmash.
  Qed.
  Lemma mpsc_waiter_try_wait_spec_notified t P :
    {{{
      mpsc_waiter_inv t P ∗
      mpsc_waiter_consumer t ∗
      mpsc_waiter_notified t
    }}}
      mpsc_waiter_try_wait t
    {{{
      RET #true;
      P
    }}}.
  Proof.
    iIntros "%Φ ((%l & %γ & -> & #Hmeta & #Hl_mutex & #Hmutex_inv & #Hl_condition & #Hcondition_inv & #Hinv) & (%l_1 & %γ_1 & %Heq1 & Hmeta_1 & Hconsumer) & (%l_2 & %γ_2 & %Heq2 & Hmeta_2 & #Hshot)) HΦ". injection Heq1 as <-. injection Heq2 as <-.
    iDestruct (meta_agree with "Hmeta Hmeta_1") as %<-. iClear "Hmeta_1".
    iDestruct (meta_agree with "Hmeta Hmeta_2") as %<-. iClear "Hmeta_2".

    wp_rec.
    wp_pures.

    iInv "Hinv" as "(%b & Hflag & Hb)".
    wp_load.
    destruct b; last first.
    { iDestruct (oneshot_pending_shot with "Hb Hshot") as %[]. }
    iDestruct "Hb" as "(_ & [HP | Hconsumer'])"; last first.
    { iDestruct (excl_exclusive with "Hconsumer Hconsumer'") as %[]. }
    iSmash.
  Qed.

  Lemma mpsc_waiter_wait_spec t P :
    {{{
      mpsc_waiter_inv t P ∗
      mpsc_waiter_consumer t
    }}}
      mpsc_waiter_wait t
    {{{
      RET ();
      P
    }}}.
  Proof.
    iIntros "%Φ (#Hinv & Hconsumer) HΦ".

    wp_rec.
    wp_apply (mpsc_waiter_try_wait_spec with "[$Hinv $Hconsumer]") as ([]) "Hconsumer"; first iSteps.

    iDestruct "Hinv" as "(%l & %γ & -> & #Hmeta & #Hl_mutex & #Hmutex_inv & #Hl_condition & #Hcondition_inv & #Hinv)".
    iDestruct "Hconsumer" as "(%l_ & %γ_ & %Heq & Hmeta_ & Hconsumer)". injection Heq as <-.
    iDestruct (meta_agree with "Hmeta Hmeta_") as %<-. iClear "Hmeta_".

    do 2 wp_load.
    pose Ψ_mtx res := (
      ⌜res = ()%V⌝ ∗
      P
    )%I.
    wp_smart_apply (mutex_protect_spec Ψ_mtx with "[$Hmutex_inv Hconsumer]"); last iSteps.
    iIntros "Hmutex_locked _".
    pose (Ψ_cond b := (
      if b then
        P
      else
        excl γ.(metadata_consumer) ()
    )%I).
    wp_smart_apply (condition_wait_until_spec Ψ_cond with "[$Hcondition_inv $Hmutex_inv $Hmutex_locked $Hconsumer]"); last iSteps.

    clear. iIntros "!> %Φ (Hmutex_locked & _ & Hconsumer) HΦ".
    wp_pures.

    iInv "Hinv" as "(%b & Hflag & Hb)".
    wp_load.
    destruct b; last iSteps.
    iDestruct "Hb" as "(Hshot & [HP | Hconsumer'])"; last first.
    { iDestruct (excl_exclusive with "Hconsumer Hconsumer'") as %[]. }
    iSmash.
  Qed.
End mpsc_waiter_G.

From zoo_std Require
  mpsc_waiter__opaque.

#[global] Opaque mpsc_waiter_inv.
#[global] Opaque mpsc_waiter_consumer.
#[global] Opaque mpsc_waiter_notified.
