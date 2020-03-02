open Lwt
open Lwt_unix

let sf, lf =
  let gid = Unix.getuid () in
  let t = Sys.getenv_opt "MONITOR_RUN_DIR"
    |> Option.value ~default:"/var/run/user/%u"
    |> Str.global_replace (Str.regexp "%u") (Int.to_string gid) in
  t ^ "/monitor.sock", t ^ "/monitor.lock"

let init =
  let s = socket PF_UNIX SOCK_STREAM 0 in
  let%lwt _ = Lwt_io.printf "server socket: %s\n" sf in
  let%lwt l = openfile lf Unix.(O_WRONLY :: O_CREAT :: []) 0o600 in
  let%lwt _ = lockf l F_TLOCK 0 in
  let%lwt _ = try%lwt unlink sf with
    Unix.Unix_error (ENOENT, _, _) -> return () in
  let%lwt _ = bind s (ADDR_UNIX sf) in
  let%lwt _ = chmod sf 0o666 in
  let _ = listen s 10 in
  return s

let deinit s =
  let%lwt _ = close s in
  let%lwt _ = unlink sf in
  let%lwt _ = unlink lf in
  return ()

type state = {
  running: bool;
  seq: int;
  ping: Ping.Monitor.s;
}

let run o st = function
  "STOP" -> return @@ { st with running = false }
| "PING" ->
    let%lwt () = Lwt_io.write o "PONG\n" in
    return st
| cmd ->
    let%lwt () = Lwt_io.fprintf o "ERR unexpected command: %s\n" cmd in
    let%lwt () = Lwt_io.printf "unexpected command: %s\n" cmd in
    return st

let handle_req st s =
  let i = Lwt_io.of_fd ~mode:Lwt_io.input s in
  let o = Lwt_io.of_fd ~mode:Lwt_io.output s in
  let f l st = if st.running then run o st l else return st in
  Lwt_stream.fold_s f (Lwt_io.read_lines i) st

let handle_tick st =
  let t: Monitor.tick = { seq = st.seq } in
  let%lwt _ = Ping.Monitor.tick st.ping t in
  return { st with seq = st.seq + 1 }

let handle_event st = function
  `Tick -> handle_tick st
| `Req s -> handle_req st s
| `Ping e ->
    let%lwt pst = Ping.Monitor.event st.ping e in
    return { st with ping = pst }

let _ = Lwt_main.run @@
  let%lwt s = init in

  let%lwt pe, ps = Ping.Monitor.start () in

  let st = {
    running = true;
    seq = 0;
    ping = ps;
  } in

  let ticks, tick = Lwt_stream.create () in
  let _ = Lwt_engine.on_timer 1.0 true (fun _ -> tick (Some `Tick)) in

  let clients = Lwt_stream.from @@ fun () ->
    let%lwt s, _ = accept s in return (Some (`Req s)) in

  let events = Lwt_stream.choose [
    ticks; clients;
    pe |> Lwt_stream.map (fun e -> `Ping e)
  ] in

  let rec loop st = if not st.running then return () else
    Lwt_stream.next events >>= handle_event st >>= loop in
  finalize (fun () -> loop st) (fun () -> deinit s)
