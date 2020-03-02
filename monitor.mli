type tick = {
  seq : int;
  time: float;
}

module type S = sig
  type e
  type s

  val start : unit -> (e Lwt_stream.t * s) Lwt.t
  val event : s -> e -> s Lwt.t
  val tick : s -> tick -> s Lwt.t
end
