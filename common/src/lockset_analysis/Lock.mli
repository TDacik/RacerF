(* Representation of locks, locksets and sets of locksets.
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2024 *)

open ConcurrencyModel_types

type kind =
  | Mutex
  | Global        (* Used for atomic sequences *)
  | Once_running  (* Hold inside callee of *_once function *)
  | Once_finished (* Hold by caller of *_once functions representing
                     that corresponding actions was already performed. *)
type t = {
  base: Base.t;
  properties : LockKind.t;
  kind: kind;
  offset: Z.t;
  status: Cil_types.lval Option.t;
  callstack: Callstack.t Option.t;
}

include Datatype_sig.PRINTABLE with type t := t
include Datatype_sig.COMPARABLE with type t := t

val global_lock : unit -> t

val is_blocking : t -> bool

val hash : t -> int

val mk :
  ?callstack:Callstack.t ->
  ?kind:kind ->
  ?properties:LockKind.t ->
  ?status:Cil_types.lval ->
  Base.t ->
  Z.t ->
    t

val mk_once_running : ?callstack:Callstack.t -> Base.t -> Z.t -> t

val mk_once_finished : ?callstack:Callstack.t -> Base.t -> Z.t -> t

val get_callstack : t -> Callstack.t

module Set : sig
  include BatSet.S with type elt = t
  include Datatype_sig.PRINTABLE with type t := t

  val is_empty : ignore_builtin:bool -> t -> bool

  val rw_disjoint : t -> t -> bool

end


module PowerSet : sig
  include BatSet.S with type elt = Set.t
  include Datatype_sig.PRINTABLE with type t := t

  val union_list : t list -> t

  val add_each : Set.t -> Set.elt list -> t

  val remove_each : Set.t -> Set.elt list -> t

  val flatten_union : t -> Set.t

  val flatten_inter : t -> Set.t

end
