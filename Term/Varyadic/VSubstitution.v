(**
CoLoR, a Coq library on rewriting and termination.
See the COPYRIGHTS and LICENSE files.

- Frederic Blanqui, 2005-12-05

substitutions
*)

(* $Id: VSubstitution.v,v 1.3 2007-06-03 12:59:31 koper Exp $ *)

Set Implicit Arguments.

Section S.

Require Export VSignature.

Variable Sig : Signature.

Require Export VTerm.

Notation term := (term Sig).
Notation terms := (list term).

(***********************************************************************)
(* definition of substitutions as functions from variables to terms *)

Definition substitution := variable -> term.

(* application of a substitution *)

Fixpoint app (s : substitution) (t : term) {struct t} : term :=
  match t with
    | Var x => s x
    | Fun f ts =>
      let fix apps (ts : terms) : terms :=
	match ts with
	  | nil => nil
	  | cons t ts' => app s t :: apps ts'
	end
	in Fun f (apps ts)
  end.

Lemma app_fun : forall s f v, app s (Fun f v) = Fun f (map (app s) v).

Proof.
intros f s. induction v; simpl; refl.
Qed.

Section properties.

Variable succ : relation term.

Definition substitution_closed :=
  forall t1 t2 s, succ t1 t2 -> succ (app s t1) (app s t2).

End properties.

End S.
