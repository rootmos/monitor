open Lwt

let salt = Utils.fresh_salt ()

module FsMap = Map.Make(String)

type state = {
  fs: (Statfs.t option) FsMap.t
}

let start () =
  let fs = FsMap.empty in
  let fs = FsMap.add "/" None fs in
  let fs = FsMap.add "/tmp" None fs in
  let fs = FsMap.add "/stash" None fs in
  return { fs }

let refresh st =
  let f k _ = FsMap.add k (Some (Statfs.statfs k)) in
  let fs = FsMap.fold f st.fs st.fs in
  { fs }

let tick st (t: Monitor.tick) =
  if not (Monitor.divide_tick_seconds ~salt 5 t) then return st else begin
    return (refresh st)
  end

let get st p = Option.join (FsMap.find_opt p st.fs)
