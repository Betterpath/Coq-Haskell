Require Import Hask.Prelude.
Require Import Hask.Control.Lens.
Require Import Hask.Control.Monad.
Require Import Hask.Control.Monad.Trans.Free.

(* Set Universe Polymorphism. *)

Generalizable All Variables.

Inductive Proxy (a' a b' b : Type) (m : Type -> Type) (r : Type) : Type :=
    | Request of a' & (a  -> Proxy a' a b' b m r)
    | Respond of b  & (b' -> Proxy a' a b' b m r)
    | M : forall x, (x -> Proxy a' a b' b m r) -> m x
                       -> Proxy a' a b' b m r
    | Pure    of r.

Arguments Request {a' a b' b m r} _ _.
Arguments Respond {a' a b' b m r} _ _.
Arguments M {a' a b' b m r x} _ _.
Arguments Pure {a' a b' b m r} _.

Program Instance Proxy_Functor {a' a b' b} `{Monad m} :
  Functor (Proxy a' a b' b m) := {
  fmap := fun _ _ f p0 =>
    let fix go p := match p with
      | Request a' fa  => Request a' (fun a  => go (fa  a))
      | Respond b  fb' => Respond b  (fun b' => go (fb' b'))
      | M _     f  t   => M (go \o f) t
      | Pure    r      => Pure (f r)
      end in
    go p0
}.

Program Instance Proxy_Applicative {a' a b' b} `{Monad m} :
  Applicative (Proxy a' a b' b m) := {
  pure := fun _ => Pure;
  ap := fun _ _ pf px =>
    let fix go p := match p with
      | Request a' fa  => Request a' (fun a  => go (fa  a))
      | Respond b  fb' => Respond b  (fun b' => go (fb' b'))
      | M _     f  t   => M (go \o f) t
      | Pure    f      => fmap f px
      end in
    go pf
}.

Program Instance Proxy_Monad {a' a b' b} `{Monad m} :
  Monad (Proxy a' a b' b m) := {
  join := fun _ x =>
    let fix go p := match p with
      | Request a' fa  => Request a' (fun a  => go (fa  a))
      | Respond b  fb' => Respond b  (fun b' => go (fb' b'))
      | M _     f  t   => M (go \o f) t
      | Pure    f      => f
      end in
    go x
}.

Fixpoint runEffect `{Monad m} `(p : Proxy False unit unit False m r) : m r :=
  match p with
  | Request v f => False_rect _ v
  | Respond v f => False_rect _ v
  | M _     f t => t >>= (runEffect \o f)
  | Pure    r   => pure r
  end.

Definition respond {x' x a' a m} (z : a) : Proxy x' x a' a m a' :=
  Respond z Pure.

Definition Producer := Proxy False unit unit.
Definition Producer' b m r := forall x' x, Proxy x' x unit b m r.

Definition yieldxx {a m} (z : a) : Producer' a m unit :=
  fun _ _ => respond z.
Definition yield {a x' x m} (z : a) : Proxy x' x unit a m unit :=
  @yieldxx a m z x' x.

Definition forP {x' x a' b' b c' c} `{Monad m} (p0 : Proxy x' x b' b m a')
  (fb : b -> Proxy x' x c' c m b') : Proxy x' x c' c m a' :=
  let fix go p := match p with
    | Request x' fx  => Request x' (fun x => go (fx x))
    | Respond b  fb' => fb b >>= fun b' => go (fb' b')
    | M _     f  t   => M (go \o f) t
    | Pure       a   => Pure a
    end in
  go p0.

Notation "x //> y" := (forP x y) (at level 60).

Notation "f />/ g" := (fun a => f a //> g) (at level 60).

Definition each `{Monad m} {a} : seq a -> Producer a m unit :=
  mapM_ yield.

Fixpoint toListM `{Monad m} `(p : Producer a m unit) : m (seq a) :=
  match p with
  | Request v _  => False_rect _ v
  | Respond x fu =>
        xs <-- toListM (fu tt) ;;
        pure (x::xs)
  | M _     f t  => t >>= (toListM \o f)
  | Pure    _    => pure [::]
  end.

(* jww (2015-05-30): Make \o bind tighter than >>= *)

Module PipesLaws.

Include MonadLaws.

Require Import FunctionalExtensionality.

Program Instance Proxy_FunctorLaws {a' a b' b} `{Monad m} :
  FunctorLaws (Proxy a' a b' b m).
Obligation 1.
  move=> x.
  elim: x => [A' fa IHx|B fb' IHx|f t IHx| x].
  - f_equal.
    extensionality a1.
    exact: IHx.
  - f_equal.
    extensionality b'1.
    exact: IHx.
  - move=> m0.
    f_equal.
    extensionality x.
    exact: IHx.
  - by [].
Qed.
Obligation 2.
  move=> x.
  rewrite /funcomp.
  elim: x => [A' fa IHx|B fb' IHx|mf t IHx| x].
  - f_equal.
    extensionality a1.
    exact: IHx.
  - f_equal.
    extensionality b'1.
    exact: IHx.
  - move=> m0.
    f_equal.
    extensionality x.
    exact: IHx.
  - by [].
Qed.

Program Instance Proxy_Applicative {a' a b' b} `{Monad m} :
  ApplicativeLaws (Proxy a' a b' b m).
Obligation 1.
  move=> x.
  elim: x => [A' fa IHx|B fb' IHx|mf t IHx| x].
  - f_equal.
    extensionality a1.
    exact: IHx.
  - f_equal.
    extensionality b'1.
    exact: IHx.
  - move=> m0.
    f_equal.
    extensionality x.
    exact: IHx.
  - by [].
Qed.
Obligation 2.
Admitted.

Program Instance Proxy_Monad {a' a b' b} `{Monad m} :
  MonadLaws (Proxy a' a b' b m).
Obligation 1.
  move=> x.
  rewrite /funcomp.
  elim: x => [A' fa IHx|B fb' IHx|mf t IHx| x].
  - f_equal.
    extensionality a1.
    exact: IHx.
  - f_equal.
    extensionality b'1.
    exact: IHx.
  - move=> m0.
    f_equal.
    extensionality x.
    exact: IHx.
  - by [].
Qed.
Obligation 2.
  move=> x.
  rewrite /funcomp.
  elim: x => [A' fa IHx|B fb' IHx|mf t IHx| x].
  - f_equal.
    extensionality a1.
    exact: IHx.
  - f_equal.
    extensionality b'1.
    exact: IHx.
  - move=> m0.
    f_equal.
    extensionality x.
    exact: IHx.
  - by [].
Qed.
Obligation 4.
  move=> x.
  rewrite /funcomp.
  elim: x => [A' fa IHx|B fb' IHx|mf t IHx| x].
  - f_equal.
    extensionality a1.
    exact: IHx.
  - f_equal.
    extensionality b'1.
    exact: IHx.
  - move=> m0.
    f_equal.
    extensionality x.
    exact: IHx.
  - by [].
Qed.

Theorem respond_left_id `{MonadLaws m} :
  forall (a' a b' b : Type) (r : Type) (f : a -> Proxy a' a b' b m r),
  (respond />/ f) =1 f.
Proof.
  move=> a' a b' b r f x.
  exact: join_fmap_pure_x.
Qed.

Theorem respond_right_id `{MonadLaws m} :
  forall (a' a b' b : Type) (r : Type) (f : a -> Proxy a' a b' b m r),
  (f />/ respond) =1 f.
Proof.
  move=> a' a b' b r f x.
  rewrite /respond.
  elim: (f x) => //= [A' fa IHx|B fb' IHx|mf t IHx].
  - f_equal.
    extensionality a1.
    exact: IHx.
  - rewrite /bind /=.
    f_equal.
    extensionality b'1.
    exact: IHx.
  - move=> m0.
    f_equal.
    rewrite /funcomp.
    extensionality y.
    exact: IHx.
Qed.

Theorem respond_assoc `{MonadLaws m} :
  forall (x' x a' a b' b c' c d' d : Type)
         (f : a -> Proxy x' x b' b m a')
         (g : b -> Proxy x' x c' c m b')
         (h : c -> Proxy x' x d' d m c'),
  (f />/ g) />/ h =1 f />/ (g />/ h).
Proof.
  move=> x' x a' a b' b c' c d' d f g h z.
  elim: (f z) => //= [A' fa IHx|B fb' IHx|mf t IHx].
  - f_equal.
    extensionality a1.
    exact: IHx.
  - rewrite /bind /=.
    f_equal.
    extensionality b'1.
    exact: IHx.
  - move=> m0.
    f_equal.
    rewrite /funcomp.
    extensionality y.
    exact: IHx.
Qed.

Theorem toListM_each_id : forall a, toListM \o each =1 pure (a:=seq a).
Proof.
  move=> a xs.
  elim: xs => //= [x xs IHxs].
  by rewrite IHxs.
Qed.

End PipesLaws.