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
  city: string option;
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
  let uri = Uri.of_string "https://ip.rootmos.io/json" in
  let%lwt (rsp, body) = Client.get uri in
  let rspat = Unix.gettimeofday () in
  let%lwt body = Cohttp_lwt.Body.to_string body in
  let rsp = Ip_resp_j.ip_resp_of_string body in
  let i = { reqat; rspat; ip = rsp.ip;
    country = rsp.country;
    city = rsp.city;
  } in
  st.new_info i;
  return i

let event st (i: info) =
  match st.info with
    Some j when j.reqat < i.reqat -> return { st with info = Some i }
  | Some _ -> return st
  | None -> return { st with info = Some i }

let tick st (t: Monitor.tick) =
  if not (Monitor.divide_tick_seconds ~salt 2 t) then return st else begin
    let%lwt () = match Array.get st.reqs st.i with
      Some r when Lwt.is_sleeping r ->
        let%lwt () = Logs_lwt.warn (fun m ->
          m "cancelling location request: %d" st.i) in
        return (Lwt.cancel r)
    | _ -> return () in
    let f = fetch t.time st in
    let () = Lwt.on_failure f (fun ex -> Logs.err (fun m ->
        m "location error: %s" (Printexc.to_string ex))) in
    Array.set st.reqs st.i (Some f);
    let%lwt () = Logs_lwt.debug (fun m -> m "location request sent: %d" st.i) in
    return { st with i = (st.i + 1) mod Array.length st.reqs }
  end

let info st = st.info
