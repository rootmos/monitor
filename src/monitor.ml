type tick = {
  seq: int;
  tick_rate: int;
  time: float;
}

let divide_tick_hz ?(salt=0) freq t =
  (t.seq + salt) mod (t.tick_rate / freq) = 0

let divide_tick_seconds ?(salt=0) seconds t =
  (t.seq + salt) mod (t.tick_rate * seconds) = 0
