(* May-run-in-parallel analysis.
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2024 *)

open Cil_types

module Logger = Core0.Logger(struct let dkey = "may-run-in-parallel" end)
module Callstack = RelaxedCallstack


module Domain = struct
  include MustMay.Make(Thread)
  let may_run t dom = is_may dom t
  let must_run t dom = is_must dom t
end

module VisitedCache = Set.Make(struct
  type t = Callstack.t * Domain.t [@@deriving equal, compare]
end)

module Context = struct
  module M = Map.Make(Callstack)

  type t = {
    (* Read-only input data *)
    input : ThreadAnalysis.Result.t;

    (* Analysis state *)
    callstack : Callstack.t;
    visited : VisitedCache.t;

    (* Computed results *)
    results: Domain.t M.t;
  }

  let equal ctx1 ctx2 =
    M.equal Domain.equal ctx1.results ctx2.results

  let init threads =
    let main = ThreadAnalysis.Result.get_main threads in
    {
      input = threads;
      callstack = Callstack.empty main;
      visited = VisitedCache.empty;
      results = M.empty;
    }

  let set_thread ctx thread = {ctx with callstack = Callstack.empty thread}

  let push_call ctx stmt fn = {ctx with callstack = Callstack.push stmt fn ctx.callstack}

  let pop_call ctx = {ctx with callstack = Callstack.pop_call ctx.callstack}

  let was_visited ctx stmt state =
    let cs = Callstack.push_event stmt ctx.callstack in
    VisitedCache.mem (cs, state) ctx.visited

  let add_visited ctx stmt state =
    let cs = Callstack.push_event stmt ctx.callstack in
    {ctx with visited = VisitedCache.add (cs, state) ctx.visited}

  let add_stmt_summary ctx stmt state =
    let cs = Callstack.push_event stmt ctx.callstack in
    {ctx with results = M.update cs (function None -> Some state | Some old -> Option.some @@ Domain.join old state) ctx.results}

  let reset_thread_res ctx thread =
    {ctx with results = M.filter (fun cs _ -> not @@ Thread.equal thread @@ Callstack.get_thread cs) ctx.results;
              visited = VisitedCache.filter (fun (cs, _) -> not @@ Thread.equal thread @@ Callstack.get_thread cs) ctx.visited}

  (** True if in some callstack: t1 must run && t2 must run. *)
  let must_run_with ctx t1 t2 =
    M.exists (fun cs res -> Domain.must_run res t1 && Domain.must_run res t2) ctx.results

  (** True if in some callstack: t1 may run && t2 may run. *)
  let may_run_with ctx t1 t2 =
    M.exists (fun cs res -> Domain.may_run res t1 && Domain.may_run res t2) ctx.results

  (** Compute initial state for a thread different from main based on the current results. *)
  let compute_initial_t ctx self =
    let thread_graph = ThreadAnalysis.Result.get_threads ctx.input in
    ThreadGraph.fold_vertex (fun t acc ->
      if Thread.is_main t || Thread.equal t self then Domain.set_must acc t
      else if must_run_with ctx self t then Domain.set_must acc t
      else if may_run_with ctx self t then Domain.set_may acc t
      else acc
    ) thread_graph Domain.empty

  let compute_initial ctx self =
    if Thread.is_main self then Domain.singleton self
    else compute_initial_t ctx self

  let show self =
    M.bindings self.results
    |> List.map (fun (cs, res) -> Format.asprintf "%s: %s" (Callstack.show_short cs) (Domain.show res))
    |> String.concat "\n"

  let pp fmt self = Format.fprintf fmt "%s" (show self)

end

open Context

module Make (ValueAnalysis : ValueAnalysis_sig.VALUE_ANALYSIS) = struct

  let update_on_create ctx state stmt id children arg =
    (* TODO: Could this be done better using information computed in thread analysis? *)
    let children =
      ValueAnalysis.eval_fn_pointer stmt children
      |> List.map (Thread.mk ~stmt)
    in
    match children with
    | [t] -> Domain.set_must state t
    | ts -> Domain.set_may_list state ts

  let update_on_join ctx state stmt id =
    let kf = Kernel_function.find_englobing_kf stmt in
    let dont_know_fallback () =
      Imprecision.add (Join stmt);
      state
    in
    (** We cannot handle joining of threads in loops *)
    if Kernel_function.stmt_in_loop kf stmt
    then (Imprecision.add (JoinInLoop stmt); state)
    else match id.enode with
      | Lval lval -> (
        let id = Cil.mkAddrOf ~loc:id.eloc lval in
        match ThreadAnalysis.Result.find_by_id_opt ctx.input id with
        | Some thread -> Domain.set_must_not state thread
        | None -> dont_know_fallback ()
      )
      | _ -> dont_know_fallback ()

  let rec compute_stmt ctx state stmt =
    if Context.was_visited ctx stmt state then None
    else (
      let ctx = Context.add_visited ctx stmt state in
      let ctx', state' = match ConcurrencyModel.classify_stmt stmt with
        | Thread_create (id, children, arg) -> ctx, update_on_create ctx state stmt id children arg
        | Thread_join (id, _) -> ctx, update_on_join ctx state stmt id
        | Call (_, _, fn, _) -> compute_call ctx state stmt fn
        | _ -> ctx, state
      in
      let ctx'' = Context.add_stmt_summary ctx' stmt state' in
      List.fold_left (fun (acc_ctx, acc_state) succ ->
        match compute_stmt acc_ctx acc_state succ with
        | None -> (acc_ctx, acc_state)
        | Some (ctx_s, state_s) -> ctx_s, Domain.join state_s acc_state
      ) (ctx'', state') stmt.succs
      |> Option.some
    )

  and compute_call ctx state callsite expr =
    let callees = ValueAnalysis.eval_call callsite expr in
    List.fold_left (fun (acc_ctx, acc_state) callee ->
      let ctx' = Context.push_call ctx callsite callee in
      let ctx_s, state_s = compute_function ctx' acc_state callee in
      Context.pop_call ctx_s, Domain.join state_s acc_state
    ) (ctx, state) callees

  and compute_function ctx state fn =
    if not @@ Kernel_function.has_definition fn then ctx, state
    else
      let _ = Core0.debug "Computing fn %a" Kernel_function.pretty fn in
      let stmt = Kernel_function.find_first_stmt fn in
      match compute_stmt ctx state stmt with
      | None -> ctx, state
      | Some res -> res

  let compute_thread ctx thread_graph thread =
    let entry_point = Thread.get_entry_point thread in
    let ctx = Context.set_thread ctx thread in
    let state = Context.compute_initial ctx thread in
    let ctx = Context.reset_thread_res ctx thread in
    let stmt = Kernel_function.find_first_stmt entry_point in
    Logger.debug "Computing thread %s with %s" (Thread.show thread) (Domain.show state);
    match compute_stmt ctx state stmt with
    | None -> ctx
    | Some (ctx, _) -> ctx

  let compute_step ctx =
    let thread_graph = ThreadAnalysis.Result.get_threads ctx.input in
    ThreadGraph.fold_vertex (fun thread ctx ->
      ValueAnalysis.set_active_thread thread;
      compute_thread ctx thread_graph thread
    ) thread_graph ctx

  let rec compute_until_fixpoint =
    let iteration = ref 0 in
    fun ctx ->
      incr iteration;
      Logger.feedback "> iteration %d" !iteration;
      let ctx' = compute_step ctx in
      if Context.equal ctx ctx' then ctx
      else compute_until_fixpoint ctx'

  let compute threads =
    Logger.feedback "Starting may-run-in-parallel analysis";
    let ctx0 = Context.init threads in
    let res = compute_until_fixpoint ctx0 in
    Logger.feedback "May-run-in-parallel analysis finished";
    Logger.debug "Results:\n %a" Context.pp res;
    res

end

(** Expose context as results of the analysis. *)
module Result = struct
  include Context

  let may_active_threads res cs = Thread.Set.of_list @@ Domain.may_set @@ M.find cs res.results
  let must_active_threads res cs = Thread.Set.of_list @@ Domain.must_set @@ M.find cs res.results

  let may_active_stmt res stmt =
    let open Cil_datatype in
    let open Callstack in
    M.bindings res.results
    |> List.filter (fun (cs, _) -> Stmt.equal (Option.get cs.event) stmt)
    |> List.fold_left (fun acc (_, res) -> Domain.may_set res @ acc) []
    |> Thread.Set.of_list

  let parallel_aux get_fn res cs1 cs2 =
    let t1 = Callstack.get_thread cs1 in
    let t2 = Callstack.get_thread cs2 in
    let set1 = get_fn res cs1 in
    let set2 = get_fn res cs2 in
    Thread.Set.mem t1 set2 && Thread.Set.mem t2 set1

  let must_run_in_parallel = parallel_aux must_active_threads
  let may_run_in_parallel = parallel_aux may_active_threads

end
