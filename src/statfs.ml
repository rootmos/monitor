type t = {
  block_size : int;
  blocks : int64;
  blocks_free : int64;
}

external statfs : string -> t = "statfs_prim"

let free_percent s =
  100. *. Int64.to_float s.blocks_free /. Int64.to_float s.blocks

let usage_percent s = 100. -. free_percent s

let available_bytes s = Int64.(mul (of_int s.block_size) s.blocks_free)
