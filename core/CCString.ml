
(*
copyright (c) 2013-2014, simon cruanes
all rights reserved.

redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.  redistributions in binary
form must reproduce the above copyright notice, this list of conditions and the
following disclaimer in the documentation and/or other materials provided with
the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*)

(** {1 Basic String Utils} *)

type 'a gen = unit -> 'a option
type 'a sequence = ('a -> unit) -> unit
type 'a klist = unit -> [`Nil | `Cons of 'a * 'a klist]

module type S = sig
  type t

  val length : t -> int

  val blit : t -> int -> t -> int -> int -> unit
  (** See {!String.blit} *)

  (** {2 Conversions} *)

  val to_gen : t -> char gen
  val to_seq : t -> char sequence
  val to_klist : t -> char klist
  val to_list : t -> char list

  val pp : Buffer.t -> t -> unit
end

let equal (a:string) b = a=b

let compare = String.compare

let hash s = Hashtbl.hash s

let init n f =
  let s = String.make n ' ' in
  for i = 0 to n-1 do s.[i] <- f i done;
  s

let length = String.length

let rec _to_list s acc i len =
  if len=0 then List.rev acc
  else _to_list s (s.[i]::acc) (i+1) (len-1)

let _is_sub ~sub i s j ~len =
  let rec check k =
    if k = len
      then true
      else sub.[i + k] = s.[j+k] && check (k+1)
  in
  j+len <= String.length s && check 0

let is_sub ~sub i s j ~len =
  if i+len > String.length sub then invalid_arg "String.is_sub";
  _is_sub ~sub i s j ~len


module Split = struct
  type split_state =
    | SplitStop
    | SplitAt of int (* previous *)

  (* [by_j... prefix of s_i...] ? *)
  let rec _is_prefix ~by s i j =
    j = String.length by
    ||
    ( i < String.length s &&
      s.[i] = by.[j] &&
      _is_prefix ~by s (i+1) (j+1)
    )

  let rec _split ~by s state = match state with
    | SplitStop -> None
    | SplitAt prev -> _split_search ~by s prev prev
  and _split_search ~by s prev i =
    if i >= String.length s
      then Some (SplitStop, prev, String.length s - prev)
      else if _is_prefix ~by s i 0
        then Some (SplitAt (i+String.length by), prev, i-prev)
      else _split_search ~by s prev (i+1)

  let _tuple3 x y z = x,y,z

  let _mkgen ~by s k =
    let state = ref (SplitAt 0) in
    fun () ->
      match _split ~by s !state with
        | None -> None
        | Some (state', i, len) ->
            state := state';
            Some (k s i len)

  let gen ~by s = _mkgen ~by s _tuple3

  let gen_cpy ~by s = _mkgen ~by s String.sub

  let _mklist ~by s k =
    let rec build acc state = match _split ~by s state with
      | None -> List.rev acc
      | Some (state', i, len) ->
          build (k s i len ::acc) state'
    in
    build [] (SplitAt 0)

  let list_ ~by s = _mklist ~by s _tuple3

  let list_cpy ~by s = _mklist ~by s String.sub

  let _mkklist ~by s k =
    let rec make state () = match _split ~by s state with
      | None -> `Nil
      | Some (state', i, len) ->
          `Cons (k s i len , make state')
    in make (SplitAt 0)

  let klist ~by s = _mkklist ~by s _tuple3

  let klist_cpy ~by s = _mkklist ~by s String.sub

  let _mkseq ~by s f k =
    let rec aux state = match _split ~by s state with
      | None -> ()
      | Some (state', i, len) -> k (f s i len); aux state'
    in aux (SplitAt 0)

  let seq ~by s = _mkseq ~by s _tuple3
  let seq_cpy ~by s = _mkseq ~by s String.sub
end

(* note: inefficient *)
let find ?(start=0) ~sub s =
  let n = String.length sub in
  let i = ref start in
  try
    while !i + n < String.length s do
      if _is_sub ~sub 0 s !i ~len:n then raise Exit;
      incr i
    done;
    -1
  with Exit ->
    !i

let repeat s n =
  assert (n>=0);
  let len = String.length s in
  assert(len > 0);
  let buf = String.create (len * n) in
  for i = 0 to n-1 do
    String.blit s 0 buf (i * len) len;
  done;
  buf

let prefix ~pre s =
  String.length pre <= String.length s &&
  (let i = ref 0 in
    while !i < String.length pre && s.[!i] = pre.[!i] do incr i done;
    !i = String.length pre)

let blit = String.blit

let _to_gen s i0 len =
  let i = ref i0 in
  fun () ->
    if !i = i0+len then None
    else (
      let c = String.unsafe_get s !i in
      incr i;
      Some c
    )

let to_gen s = _to_gen s 0 (String.length s)

let of_gen g =
  let b = Buffer.create 32 in
  let rec aux () = match g () with
    | None -> Buffer.contents b
    | Some c -> Buffer.add_char b c; aux ()
  in aux ()

let to_seq s k = String.iter k s

let of_seq seq =
  let b= Buffer.create 32 in
  seq (Buffer.add_char b);
  Buffer.contents b

let rec _to_klist s i len () =
  if len=0 then `Nil
  else `Cons (s.[i], _to_klist s (i+1)(len-1))

let of_klist l =
  let rec aux acc n l = match l() with
    | `Nil ->
        let s = String.create n in
        let acc = ref acc in
        for i=n-1 downto 0 do
          s.[i] <- List.hd !acc;
          acc := List.tl !acc
        done;
        s
    | `Cons (x,l') -> aux (x::acc) (n+1) l'
  in aux [] 0 l

let to_klist s = _to_klist s 0 (String.length s)

let to_list s = _to_list s [] 0 (String.length s)

let of_list l =
  let s = String.make (List.length l) ' ' in
  List.iteri (fun i c -> s.[i] <- c) l;
  s

(*$T
  of_list ['a'; 'b'; 'c'] = "abc"
  of_list [] = ""
*)

let of_array a =
  let s = String.make (Array.length a) ' ' in
  Array.iteri (fun i c -> s.[i] <- c) a;
  s

let to_array s =
  Array.init (String.length s) (fun i -> s.[i])

let pp buf s =
  Buffer.add_char buf '"';
  Buffer.add_string buf s;
  Buffer.add_char buf '"'

module Sub = struct
  type t = string * int * int

  let make s i ~len =
    if i<0||len<0||i+len > String.length s then invalid_arg "CCString.Sub.make";
    s,i,len

  let full s = s, 0, String.length s

  let copy (s,i,len) = String.sub s i len

  let underlying (s,_,_) = s

  let sub (s,i,len) i' len' =
    if i+i' + len' > i+len then invalid_arg "CCString.Sub.sub";
    (s, i+i',len')

  let length (_,_,l) = l

  let blit (a1,i1,len1) o1 (a2,i2,len2) o2 len =
    if o1+len>len1 || o2+len>len2 then invalid_arg "CCString.Sub.blit";
    String.blit a1 (i1+o1) a2 (i2+o2) len

  let to_gen (s,i,len) = _to_gen s i len
  let to_seq (s,i,len) k =
    for i=i to i+len-1 do k s.[i] done
  let to_klist (s,i,len) = _to_klist s i len
  let to_list (s,i,len) = _to_list s [] i len

  let pp buf (s,i,len) =
    Buffer.add_char buf '"';
    Buffer.add_substring buf s i len;
    Buffer.add_char buf '"'
end
