(**
CoLoR, a Coq library on rewriting and termination.
See the COPYRIGHTS and LICENSE files.

- Frederic Blanqui, 2005-02-17
- Adam Koprowski and Hans Zantema, 2007-03-20

rewriting
*)

Set Implicit Arguments.

Require Export AContext ASubstitution.

Require Import ARelation ListUtil ListRepeatFree LogicUtil VecUtil RelUtil
  ListForall SN BoolUtil EqUtil NatUtil Basics Syntax.

Section basic_definitions.

Variable Sig : Signature.

Notation term := (term Sig). Notation terms := (vector term).

(***********************************************************************)
(** rules *)

Record rule : Type := mkRule { lhs : term; rhs : term }.

Lemma rule_eq : forall a b : rule, (lhs a = lhs b /\ rhs a = rhs b) <-> a = b.

Proof.
intros. destruct a. destruct b. split; intros.
destruct H. simpl in *. subst. refl. rewrite H. simpl. auto.
Qed.

Definition beq_rule (a b : rule) : bool :=
  beq_term (lhs a) (lhs b) && beq_term (rhs a) (rhs b).

Lemma beq_rule_ok : forall a b, beq_rule a b = true <-> a = b.

Proof.
destruct a as [a1 a2]. destruct b as [b1 b2]. unfold beq_rule. simpl.
rewrite andb_eq. repeat rewrite beq_term_ok. split.
intuition. subst. refl. intro. inversion H. auto.
Qed.

Definition eq_rule_dec := dec_beq beq_rule_ok.

Definition rules := list rule.

Definition brule (f : term -> term -> bool) a := f (lhs a) (rhs a).

(***********************************************************************)
(** basic definitions and properties on rules *)

Definition is_notvar_lhs a :=
  match lhs a with
    | Var _ => false
    | _ => true
  end.

Lemma is_notvar_lhs_elim : forall R, forallb is_notvar_lhs R = true ->
  forall l r, In (mkRule l r) R -> exists f, exists ts, l = Fun f ts.

Proof.
intros. rewrite forallb_forall in H. ded (H _ H0). destruct l. discr.
exists f. exists v. refl.
Qed.

Lemma is_notvar_lhs_false : forall R, forallb is_notvar_lhs R = true ->
  forall x r, In (mkRule (Var x) r) R -> False.

Proof.
intros. rewrite forallb_forall in H. ded (H _ H0). discr.
Qed.

Definition is_notvar_rhs a :=
  match rhs a with
    | Var _ => false
    | _ => true
  end.

Lemma is_notvar_rhs_elim : forall R, forallb is_notvar_rhs R = true ->
  forall l r, In (mkRule l r) R -> exists f, exists ts, r = Fun f ts.

Proof.
intros. rewrite forallb_forall in H. ded (H _ H0). destruct r. discr.
exists f. exists v. refl.
Qed.

Lemma is_notvar_rhs_false : forall R, forallb is_notvar_rhs R = true ->
  forall x l, In (mkRule l (Var x)) R -> False.

Proof.
intros. rewrite forallb_forall in H. ded (H _ H0). discr.
Qed.

(***********************************************************************)
(** standard rewriting *)

Section rewriting.

  Variable R : rules.

  (* standard rewrite step *)
  Definition red u v := exists l r c s,
    In (mkRule l r) R /\ u = fill c (sub s l) /\ v = fill c (sub s r).

  (* head rewrite step *)
  Definition hd_red u v := exists l r s,
    In (mkRule l r) R /\ u = sub s l /\ v = sub s r.

  (* internal rewrite step *)
  Definition int_red u v := exists l r c s, c <> Hole /\
    In (mkRule l r) R /\ u = fill c (sub s l) /\ v = fill c (sub s r).

  Definition NF u := forall v, ~red u v.

(***********************************************************************)
(** innermost rewriting *)

  Definition innermost u := forall f us, u = Fun f us -> Vforall NF us.

  Definition in_red u v := exists l, exists r, exists c, exists s,
    In (mkRule l r) R /\ u = fill c (sub s l) /\ v = fill c (sub s r)
    /\ innermost (sub s l).

  Definition in_hd_red u v := exists l, exists r, exists s,
    In (mkRule l r) R /\ u = sub s l /\ v = sub s r /\ innermost u.

  Definition in_int_red u v := exists l, exists r, exists c, exists s,
    c <> Hole
    /\ In (mkRule l r) R /\ u = fill c (sub s l) /\ v = fill c (sub s r)
    /\ innermost (sub s l).

End rewriting.

(***********************************************************************)
(** rewrite modulo steps *)

Section rewriting_modulo.

  Variables (S : relation term) (E R : rules).

  (* relative rewrite step *)
  Definition red_mod := red E # @ red R.

  (* head rewrite step modulo some relation *)
  Definition hd_red_Mod := S @ hd_red R.

  (* relative head rewrite step *)
  Definition hd_red_mod := red E # @ hd_red R.

  (* relative minimal head rewrite step *)
  Definition hd_red_mod_min s t := hd_red_mod s t 
    /\ lforall (SN (red E)) (direct_subterms s)
    /\ lforall (SN (red E)) (direct_subterms t).

End rewriting_modulo.

(***********************************************************************)
(** minimal infinite sequences: two functions [f] and [g] describing
an infinite sequence of head D-steps modulo arbitrary internal M-steps
is minimal if:
- every rule of D is applied infinitely often
- the strict subterms of this rewrite sequence terminate wrt M *)

Section inf_seq.

  (* strict subterms terminate wrt M *)
  Definition MinNT M (f : nat -> term) :=
    forall i x, subterm x (f i) -> forall g, g 0 = x -> ~IS (red M) g.

  (* every rule of [D] is applied infinitely often *)
  Definition ISModInfRuleApp (D : rules) f g :=
    forall d, In d D -> exists h : nat -> nat,
      forall j, h j < h (S j) /\ hd_red (d :: nil) (g (h j)) (f (S (h j))).

  Definition ISModMin (M D : rules) f g :=
    ISMod (int_red M #) (hd_red D) f g
    /\ ISModInfRuleApp D f g /\ MinNT M g /\ MinNT M f.

End inf_seq.

End basic_definitions.

Implicit Arguments is_notvar_lhs_elim [Sig R l r].
Implicit Arguments is_notvar_rhs_elim [Sig R l r].

(***********************************************************************)
(** tactics *)

Ltac redtac := repeat
  match goal with
    | H : red _ _ _ |- _ =>
      let l := fresh "l" in let r := fresh "r" in 
      let c := fresh "c" in let s := fresh "s" in 
      let lr := fresh "lr" in let xl := fresh "xl" in
      let yr := fresh "yr" in
        destruct H as [l [r [c [s [lr [xl yr]]]]]]
    | H : transp (red _) _ _ |- _ => unfold transp in H; redtac
    | H : hd_red _ _ _ |- _ =>
      let l := fresh "l" in let r := fresh "r" in
      let s := fresh "s" in let lr := fresh "lr" in 
      let xl := fresh "xl" in let yr := fresh "yr" in
        destruct H as [l [r [s [lr [xl yr]]]]]
    | H : transp (hd_red _) _ _ |- _ => unfold transp in H; redtac
    | H : int_red _ _ _ |- _ =>
      let l := fresh "l" in let r := fresh "r" in 
      let c := fresh "c" in let cne := fresh "cne" in
      let s := fresh "s" in  let lr := fresh "lr" in 
      let xl := fresh "xl" in let yr := fresh "yr" in
        destruct H as [l [r [c [s [cne [lr [xl yr]]]]]]]
    | H : transp (int_red _) _ _ |- _ => unfold transp in H; redtac
    | H : red_mod _ _ _ _ |- _ =>
      let t := fresh "t" in let h := fresh in
        destruct H as [t h]; destruct h; redtac
    | H : hd_red_mod _ _ _ _ |- _ =>
      let t := fresh "t" in let h := fresh in
        destruct H as [t h]; destruct h; redtac
    | H : hd_red_Mod _ _ _ _ |- _ =>
      let t := fresh "t" in let h := fresh in
        destruct H as [t h]; destruct h; redtac
  end.

Ltac is_var_lhs := cut False;
  [tauto | eapply is_notvar_lhs_false; eassumption].

Ltac is_var_rhs := cut False;
  [tauto | eapply is_notvar_rhs_false; eassumption].

Require ListDec.

Ltac incl_rule Sig := ListDec.incl (@beq_rule_ok Sig).

(***********************************************************************)
(** monotony properties *)

Require Import Setoid.

Add Parametric Morphism (Sig : Signature) : (@red Sig)
  with signature (@incl (@rule Sig)) ==> (@inclusion (term Sig))
    as red_incl.

Proof.
intros R R' RR' u v Rst. redtac.
exists l. exists r. exists c. exists s. repeat split; try hyp.
apply RR'. hyp.
Qed.

(*COQ: can be removed?*)
Add Parametric Morphism (Sig : Signature) : (@red Sig)
  with signature (@incl (@rule Sig)) ==>
    (@eq (term Sig)) ==> (@eq (term Sig)) ==> impl
    as red_incl_ext.

Proof.
unfold impl. intros. apply (red_incl H). hyp.
Qed.

Add Parametric Morphism (Sig : Signature) : (@red Sig)
  with signature (@lequiv (@rule Sig)) ==> (same_relation (term Sig))
    as red_equiv.

Proof.
intros R S [h1 h2]. split; apply red_incl; hyp.
Qed.

(*COQ: can be removed?*)
Add Parametric Morphism (Sig : Signature) : (@red Sig)
  with signature (@lequiv (@rule Sig)) ==>
    (@eq (term Sig)) ==> (@eq (term Sig)) ==> iff
    as red_equiv_ext.

Proof.
intros A B [h1 h2]. split; apply red_incl; hyp.
Qed.

Add Parametric Morphism (Sig : Signature) : (@hd_red Sig)
  with signature (@incl (@rule Sig)) ==> (@inclusion (term Sig))
    as hd_red_incl.

Proof.
intros R R' RR' u v Rst. redtac.
exists l. exists r. exists s. repeat split; try hyp.
apply RR'. hyp.
Qed.

(*COQ: can be removed?*)
Add Parametric Morphism (Sig : Signature) : (@hd_red Sig)
  with signature (@incl (@rule Sig)) ==>
    (@eq (term Sig)) ==> (@eq (term Sig)) ==> impl
    as hd_red_incl_ext.

Proof.
unfold impl. intros. apply (hd_red_incl H). hyp.
Qed.

Add Parametric Morphism (Sig : Signature) : (@hd_red Sig)
  with signature (@lequiv (@rule Sig)) ==> (same_relation (term Sig))
    as hd_red_equiv.

Proof.
intros R S [h1 h2]. split; apply hd_red_incl; hyp.
Qed.

(*COQ: can be removed?*)
Add Parametric Morphism (Sig : Signature) : (@hd_red Sig)
  with signature (@lequiv (@rule Sig)) ==>
    (@eq (term Sig)) ==> (@eq (term Sig)) ==> iff
    as hd_red_equiv_ext.

Proof.
intros R S [h1 h2]. split; apply hd_red_incl; hyp.
Qed.

Add Parametric Morphism (Sig : Signature) : (@red_mod Sig)
  with signature (@incl (@rule Sig)) ==>
    (@incl (@rule Sig)) ==> (@inclusion (term Sig))
    as red_mod_incl.

Proof.
intros. unfold red_mod. comp. apply clos_refl_trans_m'.
apply red_incl. hyp. apply red_incl. hyp.
Qed.

(*COQ: can be removed?*)
Add Parametric Morphism (Sig : Signature) : (@red_mod Sig)
  with signature (@incl (@rule Sig)) ==>
    (@incl (@rule Sig)) ==>
    (@eq (term Sig)) ==> (@eq (term Sig)) ==> impl
    as red_mod_incl_ext.

Proof.
unfold impl. intros. apply (red_mod_incl H H0). hyp.
Qed.

Add Parametric Morphism (Sig : Signature) : (@red_mod Sig)
  with signature (@lequiv (@rule Sig)) ==>
    (@lequiv (@rule Sig)) ==> (same_relation (term Sig))
    as red_mod_equiv.

Proof.
intros R R' [h1 h2] S S' [h3 h4]. split; apply red_mod_incl; hyp.
Qed.

(*COQ: can be removed?*)
Add Parametric Morphism (Sig : Signature) : (@red_mod Sig)
  with signature (@lequiv (@rule Sig)) ==>
    (@lequiv (@rule Sig)) ==>
    (@eq (term Sig)) ==> (@eq (term Sig)) ==> iff
    as red_mod_equiv_ext.

Proof.
intros R R' [h1 h2] S S' [h3 h4]. split; apply red_mod_incl; hyp.
Qed.

Add Parametric Morphism (Sig : Signature) : (@hd_red_mod Sig)
  with signature (@incl (@rule Sig)) ==>
    (@incl (@rule Sig)) ==> (@inclusion (term Sig))
    as hd_red_mod_incl.

Proof.
intros. unfold hd_red_mod. comp. apply clos_refl_trans_m'. apply red_incl. hyp.
apply hd_red_incl. hyp.
Qed.

(*COQ: can be removed?*)
Add Parametric Morphism (Sig : Signature) : (@hd_red_mod Sig)
  with signature (@incl (@rule Sig)) ==>
    (@incl (@rule Sig)) ==>
    (@eq (term Sig)) ==> (@eq (term Sig)) ==> impl
    as hd_red_mod_incl_ext.

Proof.
unfold impl. intros. apply (hd_red_mod_incl H H0). hyp.
Qed.

Add Parametric Morphism (Sig : Signature) : (@hd_red_mod Sig)
  with signature (@lequiv (@rule Sig)) ==>
    (@lequiv (@rule Sig)) ==> (same_relation (term Sig))
    as hd_red_mod_equiv.

Proof.
intros R R' [h1 h2] S S' [h3 h4]. split; apply hd_red_mod_incl; hyp.
Qed.

(*COQ: can be removed?*)
Add Parametric Morphism (Sig : Signature) : (@hd_red_mod Sig)
  with signature (@lequiv (@rule Sig)) ==>
    (@lequiv (@rule Sig)) ==>
    (@eq (term Sig)) ==> (@eq (term Sig)) ==> iff
    as hd_red_mod_equiv_ext.

Proof.
intros R R' [h1 h2] S S' [h3 h4]. split; apply hd_red_mod_incl; hyp.
Qed.

Add Parametric Morphism (Sig : Signature) : (@hd_red_Mod Sig)
  with signature (@inclusion (term Sig)) ==>
    (@incl (@rule Sig)) ==> (@inclusion (term Sig))
    as hd_red_Mod_incl.

Proof.
intros. unfold hd_red_Mod. comp. hyp. rewrite H0. refl.
Qed.

(*COQ: can be removed?*)
Add Parametric Morphism (Sig : Signature) : (@hd_red_Mod Sig)
  with signature (@inclusion (term Sig)) ==>
    (@incl (@rule Sig)) ==>
    (@eq (term Sig)) ==> (@eq (term Sig)) ==> impl
    as hd_red_Mod_incl_ext.

Proof.
unfold impl. intros. apply (hd_red_Mod_incl H H0). hyp.
Qed.

Add Parametric Morphism (Sig : Signature) : (@hd_red_Mod Sig)
  with signature (same_relation (term Sig)) ==>
    (@lequiv (@rule Sig)) ==> (same_relation (term Sig))
    as hd_red_Mod_equiv.

Proof.
intros R R' [h1 h2] S S' [h3 h4]. split; apply hd_red_Mod_incl; hyp.
Qed.

(*COQ: can be removed?*)
Add Parametric Morphism (Sig : Signature) : (@hd_red_Mod Sig)
  with signature (same_relation (term Sig)) ==>
    (@lequiv (@rule Sig)) ==>
    (@eq (term Sig)) ==> (@eq (term Sig)) ==> iff
    as hd_red_Mod_equiv_ext.

Proof.
intros R R' [h1 h2] S S' [h3 h4]. split; apply hd_red_Mod_incl; hyp.
Qed.

(***********************************************************************)
(** basic properties *)

Section S.

Variable Sig : Signature.

Notation term := (term Sig). Notation terms := (vector term).
Notation rule := (rule Sig). Notation rules := (list rule).

Notation empty_trs := (@nil rule).

Section rewriting.

Variable R R' : rules.

Lemma red_rule : forall l r c s, In (mkRule l r) R ->
  red R (fill c (sub s l)) (fill c (sub s r)).

Proof.
intros. unfold red. exists l. exists r. exists c. exists s. auto.
Qed.

Lemma red_empty : forall t u : term, red empty_trs # t u -> t = u.

Proof.
intros. induction H. redtac. contradiction. refl. congruence.
Qed.

Lemma red_rule_top : forall l r s, In (mkRule l r) R ->
  red R (sub s l) (sub s r).

Proof.
intros. unfold red. exists l. exists r. exists (@Hole Sig). exists s. auto.
Qed.

Lemma hd_red_rule : forall l r s, In (mkRule l r) R ->
  hd_red R (sub s l) (sub s r).

Proof.
intros. unfold hd_red. exists l. exists r. exists s. auto.
Qed.

Lemma red_fill : forall t u c, red R t u -> red R (fill c t) (fill c u).

Proof.
intros. redtac. unfold red.
exists l. exists r. exists (AContext.comp c c0). exists s. split. hyp.
subst t. subst u. do 2 rewrite fill_fill. auto.
Qed.

Lemma context_closed_red : context_closed (red R).

Proof.
intros t u c h. apply red_fill. hyp.
Qed.

Lemma red_sub : forall t u s, red R t u -> red R (sub s t) (sub s u).

Proof.
intros. redtac. subst. repeat rewrite sub_fill. repeat rewrite sub_sub.
apply red_rule. hyp.
Qed.

Lemma red_subterm : forall u u' t, red R u u' -> subterm_eq u t
  -> exists t', red R t t' /\ subterm_eq u' t'.

Proof.
unfold subterm_eq. intros. destruct H0 as [d]. subst t. redtac. subst u.
subst u'. exists (fill (AContext.comp d c) (sub s r)). split.
exists l. exists r. exists (AContext.comp d c). exists s. split. hyp.
rewrite fill_fill. auto. exists d. rewrite fill_fill. refl.
Qed.

Lemma int_red_fun : forall f ts v, int_red R (Fun f ts) v
  -> exists i, exists vi : terms i, exists t, exists j, exists vj : terms j,
    exists h, exists t', ts = Vcast (Vapp vi (Vcons t vj)) h
    /\ v = Fun f (Vcast (Vapp vi (Vcons t' vj)) h) /\ red R t t'.

Proof.
intros. redtac. destruct c. absurd (@Hole Sig = Hole); auto. simpl in xl.
Funeqtac. exists i. exists v0. exists (fill c (sub s l)). exists j. exists v1.
exists e. exists (fill c (sub s r)). split. hyp. split. hyp.
unfold red. exists l. exists r. exists c. exists s. auto.
Qed.

Lemma red_swap : red (R ++ R') << red (R' ++ R).

Proof.
intros x y RR'xy. redtac.
exists l. exists r. exists c. exists s. repeat split; auto.
destruct (in_app_or lr); apply in_or_app; auto.
Qed.

Lemma hd_red_swap : hd_red (R ++ R') << hd_red (R' ++ R).

Proof.
intros x y RR'xy. redtac.
exists l. exists r. exists s. repeat split; auto.
destruct (in_app_or lr); auto with datatypes.
Qed.

Lemma int_red_incl_red : int_red R << red R.

Proof.
unfold inclusion, int_red. intros. decomp H. subst x. subst y. apply red_rule.
hyp.
Qed.

Lemma hd_red_incl_red : hd_red R << red R.

Proof.
unfold inclusion. intros. redtac. subst x. subst y. apply red_rule_top. hyp.
Qed.

Lemma WF_red_empty : WF (red empty_trs).

Proof.
intro x. apply SN_intro. intros y Exy. redtac. contradiction.
Qed.

Lemma hd_red_mod_incl_red_mod : forall E, hd_red_mod E R << red_mod E R.

Proof.
intro. unfold hd_red_mod, red_mod. comp. apply hd_red_incl_red.
Qed.

Lemma int_red_preserve_hd : forall u v, int_red R u v ->
  exists f, exists us,exists vs, u = Fun f us /\ v = Fun f vs.

Proof.
intros. do 5 destruct H. intuition. destruct x1. congruence.
simpl in *. exists f.
exists (Vcast (Vapp v0 (Vcons (fill x1 (sub x2 x)) v1)) e).
exists (Vcast (Vapp v0 (Vcons (fill x1 (sub x2 x0)) v1)) e).
tauto.
Qed.

Lemma int_red_rtc_preserve_hd : forall u v, int_red R # u v ->
  u=v \/ exists f, exists us, exists vs, u = Fun f us /\ v = Fun f vs.

Proof.
intros. induction H; auto.
right. apply int_red_preserve_hd. auto.
destruct IHclos_refl_trans1; destruct IHclos_refl_trans2; subst; auto.
right. do 3 destruct H1. do 3 destruct H2. intuition; subst; auto.
inversion H1. subst. exists x3; exists x1; exists x5. auto.
Qed.

Lemma red_case : forall t u, red R t u -> hd_red R t u
  \/ exists f, exists ts, exists i, exists p : i < arity f, exists u',
    t = Fun f ts /\ red R (Vnth ts p) u' /\ u = Fun f (Vreplace ts p u').

Proof.
intros. redtac. destruct c.
(* Hole *)
left. subst. simpl. apply hd_red_rule. hyp.
(* Cont *)
right. exists f. exists (Vcast (Vapp v (Vcons (fill c (sub s l)) v0)) e).
exists i. assert (p : i<arity f). omega. exists p. exists (fill c (sub s r)).
subst. simpl. intuition. rewrite Vnth_cast. rewrite Vnth_app.
destruct (le_gt_dec i i). 2: absurd_arith. rewrite Vnth_cons_head.
apply red_rule. hyp. omega.
apply args_eq. apply Veq_nth; intros. rewrite Vnth_cast. rewrite Vnth_app.
destruct (le_gt_dec i i0).
(* 1) i <= i0 *)
destruct (eq_nat_dec i i0).
(* a) i = i0 *)
subst i0. rewrite Vnth_cons_head. rewrite Vnth_replace. refl. omega.
(* b) i <> i0 *)
rewrite Vnth_replace_neq. 2: hyp. rewrite Vnth_cast. rewrite Vnth_app.
destruct (le_gt_dec i i0). 2: absurd_arith. assert (l0=l1). apply le_unique.
subst l1. repeat rewrite Vnth_cons. destruct (lt_ge_dec 0 (i0-i)).
apply Vnth_eq. refl. absurd_arith.
(* 2) i > i0 *)
rewrite Vnth_replace_neq. 2: omega. rewrite Vnth_cast.
rewrite Vnth_app. destruct (le_gt_dec i i0). absurd_arith.
apply Vnth_eq. refl.
Qed.

End rewriting.

(***********************************************************************)
(** preservation of variables under reduction *)

Definition rules_preserve_vars := fun R : rules =>
  forall l r, In (mkRule l r) R -> vars r [= vars l.

Definition brules_preserve_vars := let P := eq_nat_dec in
 fun R : rules => forallb (fun x => Inclb P (vars (rhs x)) (vars (lhs x))) R.

Lemma brules_preserve_vars_ok :
 forall R, rules_preserve_vars R <-> brules_preserve_vars R = true.

Proof.
intro; unfold brules_preserve_vars. rewrite forallb_forall; split; intros.
destruct x as [l r]; simpl. rewrite Inclb_ok. apply H; auto.
intros l r Rlr. rewrite <- (Inclb_ok eq_nat_dec). apply (H _ Rlr).
Qed. 

Lemma rules_preserve_vars_cons : forall a R, rules_preserve_vars (a :: R)
  <-> vars (rhs a) [= vars (lhs a) /\ rules_preserve_vars R.

Proof.
unfold rules_preserve_vars. intuition. apply H. left. destruct a. refl.
simpl in H. destruct H. subst. hyp. apply H1. hyp.
Qed.

Section vars.

Variable R : rules.
Variable hyp : rules_preserve_vars R.

Lemma red_preserve_vars : preserve_vars (red R).

Proof.
unfold preserve_vars. intros. redtac. subst t. subst u.
apply incl_tran with (cvars c ++ vars (sub s r)). apply vars_fill_elim.
apply incl_tran with (cvars c ++ vars (sub s l)). apply appl_incl.
apply incl_vars_sub. apply hyp. hyp.
apply vars_fill_intro.
Qed.

Lemma tred_preserve_vars : preserve_vars (red R !).

Proof.
unfold preserve_vars. induction 1. apply red_preserve_vars. hyp.
apply incl_tran with (vars y); hyp.
Qed.

Lemma rtred_preserve_vars : preserve_vars (red R #).

Proof.
unfold preserve_vars. induction 1. apply red_preserve_vars. hyp.
apply List.incl_refl. apply incl_tran with (vars y); hyp.
Qed.

Require Import ListMax.

Lemma red_maxvar : forall t u, red R t u -> maxvar u <= maxvar t.

Proof.
intros. repeat rewrite maxvar_lmax. apply incl_lmax. apply red_preserve_vars.
hyp.
Qed.

Lemma red_maxvar0 : forall t u, maxvar t = 0 -> red R t u -> maxvar u = 0.

Proof.
intros. cut (maxvar u <= maxvar t). intro. omega. apply red_maxvar. hyp.
Qed.

Lemma rtc_red_maxvar : forall t u, red R # t u -> maxvar u <= maxvar t.

Proof.
induction 1. apply red_maxvar. hyp. omega. omega.
Qed.

Lemma rtc_red_maxvar0 : forall t u,
  maxvar t = 0 -> red R # t u -> maxvar u = 0.

Proof.
intros. cut (maxvar u <= maxvar t). intro. omega. apply rtc_red_maxvar. hyp.
Qed.

End vars.

Section red_mod.

Variables (E R : rules)
  (hE : rules_preserve_vars E) (hR : rules_preserve_vars R).

Lemma red_mod_maxvar : forall t u, red_mod E R t u -> maxvar u <= maxvar t.

Proof.
intros. do 2 destruct H. transitivity (maxvar x). apply (red_maxvar hR H0).
apply (rtc_red_maxvar hE H).
Qed.

Lemma red_mod_maxvar0 : forall t u,
  maxvar t = 0 -> red_mod E R t u -> maxvar u = 0.

Proof.
intros. cut (maxvar u <= maxvar t). intro. omega. apply red_mod_maxvar. hyp.
Qed.

End red_mod.

Lemma rules_preserve_vars_incl : forall R S : rules,
  R [= S -> rules_preserve_vars S -> rules_preserve_vars R.

Proof.
unfold rules_preserve_vars, incl. intuition. eapply H0. apply H. apply H1. hyp.
Qed.

(***********************************************************************)
(** biggest variable in a list of rules *)

Require Import Max.

Definition maxvar_rule (a : rule) :=
  let (l,r) := a in max (maxvar l) (maxvar r).

Definition fold_max m a := max m (maxvar_rule a).

Definition maxvar_rules R := fold_left fold_max R 0.

Lemma maxvar_rules_init : forall R x, fold_left fold_max R x >= x.

Proof.
induction R; simpl; intros. refl. rewrite IHR. apply le_max_l.
Qed.

Lemma maxvar_rules_init_mon : forall R x y,
  x >= y -> fold_left fold_max R x >= fold_left fold_max R y.

Proof.
induction R; simpl; intros. hyp. apply IHR. unfold fold_max.
apply max_ge_compat. hyp. refl.
Qed.

Notation rule_dec := (dec_beq (@beq_rule_ok Sig)).
Notation remove := (remove rule_dec).

Lemma maxvar_rules_remove : forall a R x y,
  x >= y -> fold_left fold_max R x >= fold_left fold_max (remove a R) y.

Proof.
induction R; simpl; intros. hyp. case (rule_dec a0 a); intro. subst a0.
apply IHR. transitivity x. apply le_max_l. hyp.
simpl. apply IHR. apply max_ge_compat. hyp. refl.
Qed.

Lemma maxvar_rules_elim : forall a R n,
  In a R -> n > maxvar_rules R -> n > maxvar_rule a.

Proof.
unfold maxvar_rules. induction R; simpl; intuition. subst.
unfold fold_max in H0. simpl in H0. fold fold_max in H0.
apply le_lt_trans with (fold_left fold_max R (fold_max 0 a)).
apply maxvar_rules_init. hyp.
apply IHR. hyp. apply le_lt_trans with (fold_left fold_max R (fold_max 0 a0)).
apply maxvar_rules_init_mon. apply le_max_l. hyp.
Qed.

(***********************************************************************)
(** rewriting vectors of terms *)

Section vector.

Require Import VecOrd.

Variable R : rules.

Definition terms_gt := Vgt_prod (red R).

Lemma Vgt_prod_fun : forall f ts ts',
  Vgt_prod (red R) ts ts' -> int_red R (Fun f ts) (Fun f ts').

Proof.
intros. ded (Vgt_prod_gt H). do 8 destruct H0. destruct H1. redtac.
subst x1. subst x5. unfold transp, int_red. rewrite H0. rewrite H1.
exists l. exists r. exists (Cont f x4 x0 c x3). exists s. split. discriminate.
auto.
Qed.

End vector.

(***********************************************************************)
(** union of rewrite rules *)

Section union.

Variables R R' : rules.

Lemma red_union : red (R ++ R') << red R U red R'.

Proof.
unfold inclusion. intros. redtac. subst x. subst y.
destruct (in_app_or lr).
left. apply red_rule. hyp. 
right. apply red_rule. hyp.
Qed.

Lemma red_union_inv : red R U red R' << red (R ++ R').

Proof.
intros x y RR'xy.
destruct RR'xy as [Rxy | Rxy]; destruct Rxy as [rl [rr [c [s [Rr [dx dy]]]]]]; 
  subst x; subst y; exists rl; exists rr; exists c; exists s; intuition.
Qed.

Lemma hd_red_union : hd_red (R ++ R') << hd_red R U hd_red R'.

Proof.
unfold inclusion. intros. redtac. subst x. subst y.
destruct (in_app_or lr).
left. apply hd_red_rule. hyp. 
right. apply hd_red_rule. hyp.
Qed.

Lemma hd_red_union_inv : hd_red R U hd_red R' << hd_red (R ++ R').

Proof.
intros x y RR'xy.
destruct RR'xy as [Rxy | Rxy]; destruct Rxy as [rl [rr [s [Rr [dx dy]]]]]; 
  subst x; subst y; exists rl; exists rr; exists s; intuition.
Qed.

End union.

(***********************************************************************)
(** properties of rewriting modulo *)

Section rewriting_modulo_results.

Variables (S S' : relation term) (E E' R R' : rules).

Lemma hd_red_mod_of_hd_red_Mod_int :
  hd_red_Mod (int_red E #) R << hd_red_mod E R.

Proof.
unfold hd_red_Mod, hd_red_mod.
apply compose_m'. assert (int_red E # << red E #).
apply clos_refl_trans_m'. apply int_red_incl_red. eauto.
inclusion_refl.
Qed.

Lemma hd_red_mod_of_hd_red_Mod : hd_red_Mod (red E #) R << hd_red_mod E R.

Proof.
unfold hd_red_Mod, hd_red_mod. inclusion_refl.
Qed.

Lemma hd_red_Mod_make_repeat_free :
  hd_red_Mod S R << hd_red_Mod S (make_repeat_free (@eq_rule_dec Sig) R).

Proof.
intros. unfold hd_red_Mod. comp. unfold inclusion. intros. redtac.
exists l; exists r; exists s. intuition. apply incl_make_repeat_free. auto.
Qed.

Lemma hd_red_mod_make_repeat_free :
  hd_red_mod E R << hd_red_mod E (make_repeat_free (@eq_rule_dec Sig) R).

Proof.
intros. unfold hd_red_mod. comp. unfold inclusion. intros. redtac.
exists l; exists r; exists s. intuition. apply incl_make_repeat_free. auto.
Qed.

Lemma red_mod_empty_incl_red : red_mod empty_trs R << red R.

Proof.
intros u v Ruv. destruct Ruv as [s' [ss' Ruv]].
rewrite (red_empty ss'). hyp.
Qed.

Lemma red_mod_empty : red_mod nil R == red R.

Proof.
split. apply red_mod_empty_incl_red. intros t u h. exists t. split.
apply rtc_refl. hyp.
Qed.

Lemma hd_red_mod_empty_incl_hd_red : hd_red_mod empty_trs R << hd_red R.

Proof.
unfold inclusion. intros. do 2 destruct H. ded (red_empty H). subst x0.
exact H0.
Qed.

Lemma WF_red_mod_empty : WF (red_mod E empty_trs).

Proof.
intro x. apply SN_intro. intros y Exy. destruct Exy as [z [xz zy]]. redtac.
contradiction.
Qed.

Lemma WF_hd_red_mod_empty : WF (hd_red_mod E empty_trs).

Proof.
apply WF_incl with (red_mod E empty_trs).
apply hd_red_mod_incl_red_mod. apply WF_red_mod_empty.
Qed.

Lemma WF_hd_red_Mod_empty : WF (hd_red_Mod S empty_trs).

Proof.
apply WF_incl with (@empty_rel term). intros x y h. redtac. contradiction.
apply WF_empty_rel.
Qed.

Lemma hd_red_mod_min_incl : hd_red_mod_min E R << hd_red_mod E R.

Proof.
unfold hd_red_mod_min. intros s t [hrm _]. trivial. 
Qed.

Lemma red_mod_fill : forall t u c,
  red_mod E R t u -> red_mod E R (fill c t) (fill c u).

Proof.
intros. do 2 destruct H. exists (fill c x); split.
apply context_closed_rtc. unfold context_closed. apply red_fill. hyp.
apply red_fill. hyp.
Qed.

Lemma context_closed_red_mod : context_closed (red_mod E R).

Proof.
intros t u c h. apply red_mod_fill. hyp.
Qed.

Lemma red_mod_sub : forall t u s,
  red_mod E R t u -> red_mod E R (sub s t) (sub s u).

Proof.
intros. do 2 destruct H. exists (sub s x); split.
apply substitution_closed_rtc. unfold substitution_closed. apply red_sub. hyp.
apply red_sub. hyp.
Qed.

End rewriting_modulo_results.

(***********************************************************************)
(** termination as special case of relative termination *)

Section termination_as_relative_term.

Variable R R' : rules.

Lemma red_incl_red_mod : red R << red_mod empty_trs R.

Proof.
intros u v Ruv. exists u. split. constructor 2. hyp.
Qed.

Lemma hd_red_incl_hd_red_mod : hd_red R << hd_red_mod empty_trs R.

Proof.
intros u v Ruv. exists u. split. constructor 2. hyp.
Qed.

End termination_as_relative_term.

(***********************************************************************)
(** union of rewrite rules modulo *)

Section union_modulo.

Variable S : relation term.
Variables E R R' : rules.

Lemma red_mod_union : red_mod E (R ++ R') << red_mod E R U red_mod E R'.

Proof.
unfold inclusion. intros. do 2 destruct H. redtac. subst x0. subst y.
destruct (in_app_or lr).
left. exists (fill c (sub s l)); split. hyp. apply red_rule. hyp.
right. exists (fill c (sub s l)); split. hyp. apply red_rule. hyp.
Qed.

Lemma hd_red_Mod_union :
  hd_red_Mod S (R ++ R') << hd_red_Mod S R U hd_red_Mod S R'.

Proof.
unfold inclusion. intros. do 2 destruct H. redtac. subst x0. subst y.
destruct (in_app_or lr).
left. exists (sub s l); split. hyp. apply hd_red_rule. hyp.
right. exists (sub s l); split. hyp. apply hd_red_rule. hyp.
Qed.

Lemma hd_red_mod_union :
  hd_red_mod E (R ++ R') << hd_red_mod E R U hd_red_mod E R'.

Proof.
unfold inclusion. intros. do 2 destruct H. redtac. subst x0. subst y.
destruct (in_app_or lr).
left. exists (sub s l); split. hyp. apply hd_red_rule. hyp.
right. exists (sub s l); split. hyp. apply hd_red_rule. hyp.
Qed.

Lemma hd_red_mod_min_union :
  hd_red_mod_min E (R ++ R') << hd_red_mod_min E R U hd_red_mod_min E R'.

Proof.
unfold inclusion. intros. destruct H. do 2 destruct H. redtac. subst x0.
subst y. destruct (in_app_or lr).
left. split. exists (sub s l); split. hyp. apply hd_red_rule. hyp. hyp.
right. split. exists (sub s l); split. hyp. apply hd_red_rule. hyp. hyp.
Qed.

End union_modulo.

(***********************************************************************)
(** rewriting is invariant under rule renamings *)

Definition sub_rule s (a : rule) := mkRule (sub s (lhs a)) (sub s (rhs a)).

Definition sub_rules s := map (sub_rule s).

Section rule_renaming.

Variable s1 s2 : @substitution Sig.
Variable hyp : forall x, sub s1 (sub s2 (Var x)) = Var x.

Lemma sub_rule_inv : forall x, sub_rule s1 (sub_rule s2 x) = x.

Proof.
intros [l r]. unfold sub_rule. simpl. repeat rewrite sub_inv. refl. hyp. hyp.
Qed.

Lemma sub_rules_inv : forall x, sub_rules s1 (sub_rules s2 x) = x.

Proof.
induction x. refl. simpl. rewrite sub_rule_inv. rewrite IHx. refl.
Qed.

Lemma red_ren : forall R, red R << red (map (sub_rule s2) R).

Proof.
intros R t u h. redtac. subst. rewrite <- (sub_inv hyp l).
rewrite <- (sub_inv hyp r). rewrite sub_sub.
rewrite sub_sub with (s1:=s) (s2:=s1). apply red_rule.
change (In (sub_rule s2 (mkRule l r)) (map (sub_rule s2) R)).
apply in_map. hyp.
Qed.

End rule_renaming.

End S.

Implicit Arguments int_red_fun [Sig R f ts v].

(***********************************************************************)
(** tactics *)

Ltac set_Sig_to x :=
  match goal with
  | |- WF (@hd_red_Mod ?S _ _) => set (x := S)
  | |- WF (@hd_red_mod ?S _ _) => set (x := S)
  end.

Ltac set_rules_to x :=
  match goal with
  | |- WF (hd_red_Mod _ ?R) => set (x := R)
  | |- WF (hd_red_mod _ ?R) => set (x := R)
  | |- WF (red_mod _ ?R) => set (x := R)
  | |- WF (red ?R) => set (x := R)
  end.

Ltac set_mod_rules_to x :=
  match goal with
  | |- WF (hd_red_mod ?E _) => set (x := E)
  end.

Ltac set_Mod_to x :=
  match goal with
  | |- WF (hd_red_Mod ?S _) => set (x := S)
  | |- WF (hd_red_mod ?E _) => set (x := red E #)
  end.

Ltac hd_red_mod :=
  match goal with
  | |- WF (hd_red_Mod _ _) =>
    eapply WF_incl;
    [(apply hd_red_mod_of_hd_red_Mod || apply hd_red_mod_of_hd_red_Mod_int)
      | idtac]
  | |- WF (hd_red_mod _ _) => idtac
  end.

Ltac termination_trivial :=
  let R := fresh in set_rules_to R; norm R;
  (apply WF_hd_red_mod_empty || apply WF_red_mod_empty || apply WF_red_empty).

Ltac remove_relative_rules E := norm E; rewrite red_mod_empty
  || fail "this certificate cannot be applied on a relative system".

Ltac no_relative_rules :=
  match goal with
    | |- WF (red_mod ?E _) => remove_relative_rules E
    | |- non_terminating (red_mod ?E _) => remove_relative_rules E
    | |- _ => idtac
  end.

(* REMOVE: non-reflexive tactic used in a previous version of Rainbow
Ltac rules_preserve_vars := solve
  [match goal with
    | |- rules_preserve_vars ?R =>
      unfold rules_preserve_vars; let H := fresh in
      assert (H :
        lforall (fun a => incl (ATerm.vars (rhs a)) (ATerm.vars (lhs a))) R);
        [ unfold incl; vm_compute; intuition
        | let H0 := fresh in do 2 intro; intro H0; apply (lforall_in H H0)]
  end] || fail 10 "some rule does not preserve variables".*)

Ltac norm_rules := match goal with |- forallb _ ?R = _ => norm R end.

Ltac get_rule :=
  match goal with |- forallb ?f ?l = _ =>
    match l with context C [ @mkRule ?S ?l ?r] =>
      let x := fresh "r" in set (x := @mkRule S l r);
        let y := fresh "b" in set (y := f x); norm_in y (f x) end end.

Ltac init := set(r:=0); set(r0:=0); set(b:=0); set(b0:=0).

Ltac get_rules := norm_rules; repeat get_rule.
