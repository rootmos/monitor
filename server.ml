open Lwt
open Lwt_unix

let sf = Utils.socket_path ()
let lf = sf ^ ".lock"

let init =
  Logs.set_level (Some Logs.Debug);
  Logs.set_reporter (Logs_fmt.reporter ());
  let s = socket PF_UNIX SOCK_STREAM 0 in
  let%lwt () = Logs_lwt.info (fun m -> m "server socket: %s" sf) in
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
  tick_rate: int;
  ping: Ping.state;
  location: Location.state;
  fs: Fs.state;
}

let run o st = function
  [] -> return st
| "STOP" :: [] -> return @@ { st with running = false }
| "PING" :: [] ->
    let s = Ping.stats st.ping in
    let%lwt () = Lwt_io.fprintf o "%d/%d %.0fms/%.0fms/%.0fms\n"
      s.responses s.sent (1000.*.s.min) (1000.*.s.avg) (1000.*.s.max) in
    return st
| "PING" :: "AVG_MS" :: [] ->
    let s = Ping.stats st.ping in
    let%lwt () = Lwt_io.fprintf o "%.0f\n" (Float.round (1000.*.s.avg)) in
    return st
| "PING" :: "SUCCESS_PERCENT" :: [] ->
    let s = Ping.stats st.ping in
    let sr = (Float.of_int s.responses) /. (Float.of_int s.sent) in
    let%lwt () = Lwt_io.fprintf o "%.0f\n" (Float.round (100.*.sr)) in
    return st
| "PING" :: "LOSS_PERCENT" :: [] ->
    let s = Ping.stats st.ping in
    let sr = (Float.of_int (s.sent - s.responses)) /. (Float.of_int s.sent) in
    let%lwt () = Lwt_io.fprintf o "%.0f\n" (Float.round (100.*.sr)) in
    return st
| "IP" :: [] -> begin match Location.info st.location with
      Some i ->
        let%lwt () = Lwt_io.fprintf o "%s\n" i.ip in return st
    | None -> let%lwt () = Lwt_io.fprintf o "\n" in return st
    end
| "COUNTRY" :: [] -> begin match Location.info st.location with
      Some { country = Some c } ->
        let%lwt () = Lwt_io.fprintf o "%s\n" c in return st
    | _ -> let%lwt () = Lwt_io.fprintf o "\n" in return st
    end
| "CITY" :: [] -> begin match Location.info st.location with
      Some { city = Some c } ->
        let%lwt () = Lwt_io.fprintf o "%s\n" c in return st
    | _ -> let%lwt () = Lwt_io.fprintf o "\n" in return st
    end
| "LOCATION" :: [] -> begin match Location.info st.location with
      Some { city = Some c } ->
        let%lwt () = Lwt_io.fprintf o "%s\n" c in return st
    | Some { country = Some c }  ->
        let%lwt () = Lwt_io.fprintf o "%s\n" c in return st
    | _ -> let%lwt () = Lwt_io.fprintf o "\n" in return st
    end
| "FS" :: "USAGE_PERCENT" :: p ::[] -> begin match Fs.get st.fs p with
      Some s ->
        let%lwt () = Lwt_io.fprintf o "%.0f\n" (Statfs.usage_percent s) in
        return st
    | None -> let%lwt () = Lwt_io.fprintf o "\n" in return st
    end
| "FS" :: "FREE_PERCENT" :: p ::[] -> begin match Fs.get st.fs p with
      Some s ->
        let%lwt () = Lwt_io.fprintf o "%.0f\n" (Statfs.free_percent s) in
        return st
    | None -> let%lwt () = Lwt_io.fprintf o "\n" in return st
    end
| "FS" :: "AVAILABLE_BYTES" :: p ::[] -> begin match Fs.get st.fs p with
      Some s ->
        let%lwt () = Lwt_io.fprintf o "%Ld\n" (Statfs.available_bytes s) in
        return st
    | None -> let%lwt () = Lwt_io.fprintf o "\n" in return st
    end
| "FS" :: "AVAILABLE_HUMAN" :: p ::[] -> begin match Fs.get st.fs p with
      Some s ->
        let%lwt () = Lwt_io.fprintf o "%s\n"
          (Statfs.available_bytes s |> Utils.human_size_of_bytes) in
        return st
    | None -> let%lwt () = Lwt_io.fprintf o "\n" in return st
    end
| cmd ->
    let l = String.concat " " cmd in
    let%lwt () = Lwt_io.fprintf o "ERR unexpected command: %s\n" l in
    let%lwt () = Logs_lwt.err (fun m -> m "unexpected command: %s" l) in
    return st

let handle_req st s =
  let i = Lwt_io.of_fd ~mode:Lwt_io.input s in
  let o = Lwt_io.of_fd ~mode:Lwt_io.output s in
  let f l st = let ws = Str.split (Str.regexp "[ \t]+") l in
    if st.running then run o st ws else return st in
  finalize (fun () -> Lwt_stream.fold_s f (Lwt_io.read_lines i) st)
    (fun () -> Lwt_io.flush o)

let handle_tick st =
  let time = Unix.gettimeofday () in
  let t: Monitor.tick = { seq = st.seq; tick_rate = st.tick_rate; time } in
  let%lwt ping = Ping.tick st.ping t in
  let%lwt location = Location.tick st.location t in
  let%lwt fs = Fs.tick st.fs t in
  return { st with seq = st.seq + 1; ping; location; fs }

let handle_ok_event st = function
  `Tick -> handle_tick st
| `Req s ->
    finalize (fun () -> handle_req st s) (fun () -> close s)
| `Ping e ->
    let%lwt pst = Ping.event st.ping e in
    return { st with ping = pst }
| `Location e ->
    let%lwt lst = Location.event st.location e in
    return { st with location = lst }

let handle_event st = function
  Ok e -> handle_ok_event st e
| Error e ->
    let%lwt () = Logs_lwt.err (fun m ->
      m "error event: %s" (Printexc.to_string e)) in
    return st

let _ = Lwt_main.run @@ begin
  let%lwt s = init in

  let%lwt pe, ps = Ping.start () in
  let%lwt le, ls = Location.start () in
  let%lwt fs = Fs.start () in

  let st = {
    running = true;
    seq = 0;
    tick_rate = 100;
    ping = ps;
    location = ls;
    fs;
  } in
  let d = 1.0 /. (Float.of_int st.tick_rate) in

  let ticks, tick = Lwt_stream.create () in
  let _ = Lwt_engine.on_timer d true (fun _ -> tick (Some `Tick)) in

  let clients = Lwt_stream.from @@ fun () ->
    let%lwt s, _ = accept s in return (Some (`Req s)) in

  let events = [
    ticks; clients;
    pe |> Lwt_stream.map (fun e -> `Ping e);
    le |> Lwt_stream.map (fun e -> `Location e)
  ] |> List.map Lwt_stream.wrap_exn |> Lwt_stream.choose in

  let rec loop st = if not st.running then return () else
    Lwt_stream.next events >>= handle_event st >>= loop in
  finalize (fun () -> loop st) (fun () -> deinit s)
end
