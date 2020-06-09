Require bbv.WordScope Crypto.Util.WordUtil.
Require Import Coq.ZArith.BinIntDef.
Require Crypto.Algebra.Hierarchy Algebra.ScalarMult.
Require Coq.ZArith.Znumtheory Coq.ZArith.BinInt.
Require Coq.Numbers.Natural.Peano.NPeano.

Require Import Crypto.Spec.ModularArithmetic.

Local Infix "-" := BinInt.Z.sub.
Local Infix "^" := BinInt.Z.pow.
Local Infix "mod" := BinInt.Z.modulo.
Local Infix "++" := Word.combine.
Local Notation setbit := BinInt.Z.setbit.

Section EdDSA.
  Class EdDSA (* <https://eprint.iacr.org/2015/677.pdf> *)
        {E Eeq Eadd Ezero Eopp} {ZEmul} (* the underllying elliptic curve operations *)

        {b : nat} (* public keys are k bits, signatures are 2*k bits *)
        {H : forall {n}, Word.word n -> Word.word (b + b)} (* main hash function *)
        {c : nat} (* cofactor E = 2^c *)
        {n : nat} (* secret keys are (n+1) bits *)
        {l : BinPos.positive} (* order of the subgroup of E generated by B *)

        {B : E} (* base point *)

        {Eenc : E   -> Word.word b} (* normative encoding of elliptic cuve points *)
        {Senc : F l -> Word.word b} (* normative encoding of scalars *)
    :=
      {
        EdDSA_group:@Algebra.Hierarchy.group E Eeq Eadd Ezero Eopp;
        EdDSA_scalarmult:@Algebra.ScalarMult.is_scalarmult E Eeq Eadd Ezero Eopp ZEmul;

        EdDSA_c_valid : c = 2 \/ c = 3;

        EdDSA_n_ge_c : n >= c;
        EdDSA_n_le_b : n <= b;

        EdDSA_B_not_identity : not (Eeq B Ezero);

        EdDSA_l_prime : Znumtheory.prime l;
        EdDSA_l_odd : BinInt.Z.lt 2 l;
        EdDSA_l_order_B : Eeq (ZEmul l B) Ezero
      }.
  Global Existing Instance EdDSA_group.
  Global Existing Instance EdDSA_scalarmult.

  Context `{prm:EdDSA}.

  Local Coercion Word.wordToNat : Word.word >-> nat.
  Local Coercion BinInt.Z.of_nat : nat >-> BinInt.Z.
  Local Notation secretkey := (Word.word b) (only parsing).
  Local Notation publickey := (Word.word b) (only parsing).
  Local Notation signature := (Word.word (b + b)) (only parsing).

  Local Arguments H {n} _.
  Local Notation wfirstn n w := (@WordUtil.wfirstn n _ w _) (only parsing).

  Local Obligation Tactic := destruct prm; simpl; intros; Omega.omega.

  Program Definition curveKey (sk:secretkey) : BinInt.Z :=
    let x := wfirstn n (H sk) in (* hash the key, use first "half" for secret scalar *)
    let x := x - (x mod (2^c)) in (* it is implicitly 0 mod (2^c) *)
             setbit x n. (* and the high bit is always set *)

  Local Infix "+" := Eadd.
  Local Infix "*" := ZEmul.

  Definition prngKey (sk:secretkey) : Word.word b := Word.split2 b b (H sk).
  Definition public (sk:secretkey) : publickey := Eenc (curveKey sk*B).

  Program Definition sign (A_:publickey) sk {n} (M : Word.word n) :=
    let r := H (prngKey sk ++ M) in (* secret nonce *)
    let R := r * B in (* commitment to nonce *)
    let s := curveKey sk in (* secret scalar *)
    let S := F.of_Z l (r + H (Eenc R ++ A_ ++ M) * s) in
        Eenc R ++ Senc S.

  Definition valid {n} (message : Word.word n) pubkey signature :=
    exists A S R, Eenc A = pubkey /\ Eenc R ++ Senc S = signature /\
                  Eeq (F.to_Z S * B) (R + (H (Eenc R ++ Eenc A ++ message) mod l) * A).
End EdDSA.