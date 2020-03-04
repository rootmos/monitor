open Lwt
open Lwt_unix
open Cohttp
open Cohttp_lwt_unix

let salt = Utils.fresh_salt ()

type info = {
  reqat: float;
  rspat: float;
  ip: string;
  country: string option;
}

type state = {
  info: info option;
  new_info: info -> unit;
  reqs : info Lwt.t option Array.t;
  i: int;
}

let start () =
  let es, f = Lwt_stream.create () in
  let reqs = Array.make 100 None in
  let s = { info = None; reqs; i = 0;
    new_info = fun i -> f (Some i)
  } in
  return (es, s)

let fetch reqat st =
  let uri = Uri.of_string "http://ip.rootmos.io/json" in
  let%lwt (rsp, body) = Client.get uri in
  let rspat = Unix.gettimeofday () in
  let%lwt body = Cohttp_lwt.Body.to_string body in
  let rsp = Ip_resp_j.ip_resp_of_string body in
  let i = { reqat; rspat; ip = rsp.ip; country = rsp.country } in
  st.new_info i;
  return i

let event st (i: info) =
  match st.info with
    Some j when j.reqat < i.reqat -> return { st with info = Some i }
  | Some _ -> return st
  | None -> return { st with info = Some i }

let tick st (t: Monitor.tick) =
  if not (Monitor.divide_tick_seconds ~salt 2 t) then return st else begin
    let () = match Array.get st.reqs st.i with
      Some r -> Lwt.cancel r
    | None -> () in
    let f = fetch t.time st in
    Array.set st.reqs st.i (Some f);
    return { st with i = (st.i + 1) mod Array.length st.reqs }
  end

let info st = st.info
