(* Representation of locks, locksets and sets of locksets.
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2024 *)

open ConcurrencyModel_types
open ConcurrencyModel_types.LockKind

type kind =
  | Mutex
  | Global        (* Used for atomic sequences *)
  | Once_running  (* Hold inside callee of *_once function *)
  | Once_finished (* Hold by caller of *_once functions representing
                     that corresponding actions was already performed. *)
[@@deriving compare]

type t = {
  base: Base.t;
  properties: LockKind.t;
  kind : kind;
  offset: Z.t;
  status: Cil_types.lval Option.t;
  callstack: Callstack.t Option.t;
}

let global_lock =
  let cache = ref None in
  fun () -> match !cache with
    | Some lock -> lock
    | None ->
      let base = Base.of_varinfo @@ Cil.makeGlobalVar "__racerf_global_lock" Cil_const.voidType in
      let lock = {
        base = base;
        properties = {blocking = true; read_lock = false; reentrant = true};
        kind = Global;
        offset = Z.zero;
        callstack = None;
        status = None;
      }
      in
      cache := Some lock;
      lock

let is_read lock = lock.properties.read_lock
let is_write lock = not @@ is_read lock
let is_blocking lock = lock.properties.blocking
let is_reentrant lock = lock.properties.reentrant

let is_local lock = Base.is_any_local lock.base

let is_builtin lock = match lock.kind with
  | Mutex -> true | _ -> false

let get_callstack lock = Option.get lock.callstack

let compare lock1 lock2 =
  let aux1 = compare_kind lock1.kind lock2.kind in
  if aux1 <> 0 then aux1
  else
    let aux2 = Base.compare lock1.base lock2.base in
    if aux2 <> 0 then aux2
    else Z.compare lock1.offset lock2.offset

let equal lhs rhs = (compare lhs rhs) == 0

let relaxed_equal lhs rhs =
  Base.equal lhs.base rhs.base
  && Z.equal lhs.offset rhs.offset

let show_addr lock =
  if Z.is_zero lock.offset then Format.asprintf "%a" Base.pretty lock.base
  else Format.asprintf "%a[%a]" Base.pretty lock.base Z.pretty lock.offset

let show lock = match lock.kind with
  | Global -> "global_lock"
  | Mutex -> show_addr lock
  | Once_running  -> Format.asprintf "once_runing:%s" (show_addr lock)
  | Once_finished -> Format.asprintf "once_finished:%s" (show_addr lock)

let mk ?callstack ?(kind=Mutex)
    ?(properties={blocking=true; read_lock=true; reentrant=true}) ?status base offset = {
  base = base;
  properties = properties;
  kind = kind;
  offset = offset;
  callstack = callstack;
  status = status;
}

let mk_once_running ?callstack base offset =
  let base = mk ?callstack ~kind:Once_running base offset in
  {base with properties = {base.properties with read_lock = false}}

let mk_once_finished ?callstack base offset =
  let base = mk ?callstack ~kind:Once_finished base offset in
  {base with properties = {base.properties with read_lock = false}}

let hash = Hashtbl.hash

module Lock = struct
  type nonrec t = t
  let show = show
  let compare = compare
  let equal = equal
end

include Datatype.Printable(Lock)

module Set = struct
  include BatSet.Make(Lock)

  let show xs =
    elements xs
    |> List.map show
    |> String.concat ", "
    |> (fun s -> "{" ^ s ^ "}")

  include Datatype.Printable(struct
    type nonrec t = t
    let show = show
  end)

  let is_empty ~ignore_builtin set =
    let set =
      if ignore_builtin then filter is_builtin set
      else set
    in
    is_empty set

  let rw_disjoint ls1 ls2 =
    not @@ exists (fun l1 ->
      exists (fun l2 ->
        relaxed_equal l1 l2
        && (is_write l1 || is_write l2)
        && (not @@ is_local l1)
      ) ls2
    ) ls1

end

module PowerSet = struct
  include BatSet.Make(Set)

  let union_list = List.fold_left union empty

  let add_each ls update =
    if List.is_empty update then singleton ls
    else List.fold_left (fun acc lock -> add (Set.add lock ls) acc) empty update

  let remove_each ls update =
    if List.is_empty update then singleton ls
    else List.fold_left (fun acc lock -> add (Set.remove lock ls) acc) empty update

  let flatten_union lss = fold Set.union lss Set.empty

  let flatten_inter lss =
    if is_empty lss then Set.empty (* Unreachable statement *)
    else fold Set.inter lss (choose lss)

  let show xs =
    elements xs
    |> List.map Set.show
    |> String.concat ", "
    |> (fun s -> "{" ^ s ^ "}")

  include Datatype.Printable(struct
    type nonrec t = t
    let show = show
  end)

end
