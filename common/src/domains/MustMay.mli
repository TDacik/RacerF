(* Domain representing mapping to {must, may}.
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2026 *)

open MustMay_sig

module Make (I : INPUT) : sig

  type t [@@deriving equal, compare]

  type elem = I.t

  val show : t -> string

  val empty : t

  val join : t -> t -> t

  val singleton : elem -> t

  val set_must : t -> elem -> t

  val set_may : t -> elem -> t

  val set_must_not : t -> elem -> t

  val set_must_list : t -> elem list -> t

  val set_may_list : t -> elem list -> t

  val set_all_may : t -> t

  (** Queries *)

  val is_must : elem -> t -> bool

  val is_may : elem -> t -> bool

  val must_set : t -> elem list

  val may_set : t -> elem list

end
