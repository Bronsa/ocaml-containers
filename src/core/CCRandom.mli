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

(** {1 Random Generators} *)

type state = Random.State.t

type 'a t = state -> 'a
(** Random generator for values of type ['a] *)

type 'a random_gen = 'a t

val return : 'a -> 'a t
(** [return x] is the generator that always returns [x].
    Example:  [let random_int = return 4 (* fair dice roll *)] *)

val flat_map : ('a -> 'b t) -> 'a t -> 'b t

val (>>=) : 'a t -> ('a -> 'b t) -> 'b t

val map : ('a -> 'b) -> 'a t -> 'b t

val (>|=) : 'a t -> ('a -> 'b) -> 'b t

val delay : (unit -> 'a t) -> 'a t
(** Delay evaluation. Useful for side-effectful generators that
    need some code to run for every call.
    Example:
    {[
    let gensym = let r = ref 0 in fun () -> incr r; !r ;;

    delay (fun () ->
      let name = gensym() in
      small_int >>= fun i -> return (name,i)
    )
    ]}
    @since 0.4
*)

val choose : 'a t list -> 'a option t
(** Choose a generator within the list. *)

val choose_exn : 'a t list -> 'a t
(** Same as {!choose} but without option.
    @raise Invalid_argument if the list is empty *)

val choose_array : 'a t array -> 'a option t

val choose_return : 'a list -> 'a t
(** Choose among the list
    @raise Invalid_argument if the list is empty *)

val replicate : int -> 'a t -> 'a list t
(** [replicate n g] makes a list of [n] elements which are all generated
    randomly using [g] *)

val sample_without_replacement:
  ?compare:('a -> 'a -> int) -> int -> 'a t -> 'a list t
(** [sample_without_replacement n g] makes a list of [n] elements which are all
    generated randomly using [g] with the added constraint that none of the generated
    random values are equal
    @since 0.15
 *)

val list_seq : 'a t list -> 'a list t
(** Build random lists from lists of random generators
    @since 0.4 *)

val small_int : int t

val int : int -> int t

val int_range : int -> int -> int t
(** Inclusive range *)

val small_float : float t
(** A reasonably small float.
    @since 0.6.1 *)

val float : float -> float t
(** Random float within the given range
    @since 0.6.1 *)

val float_range : float -> float -> float t
(** Inclusive range. [float_range a b] assumes [a < b].
    @since 0.6.1 *)

val split : int -> (int * int) option t
(** Split a positive value [n] into [n1,n2] where [n = n1 + n2].
    @return [None] if the value is too small *)

val split_list : int -> len:int -> int list option t
(** Split a value [n] into a list of values whose sum is [n]
    and whose length is [length].
    @return [None] if the value is too small *)

val retry : ?max:int -> 'a option t -> 'a option t
(** [retry g] calls [g] until it returns some value, or until the maximum
    number of retries was reached. If [g] fails,
    then it counts for one iteration, and the generator retries.
    @param max: maximum number of retries. Default [10] *)

val try_successively : 'a option t list -> 'a option t
(** [try_successively l] tries each generator of [l], one after the other.
    If some generator succeeds its result is returned, else the
    next generator is tried *)

val (<?>) : 'a option t -> 'a option t -> 'a option t
(** [a <?> b] is a choice operator. It first tries [a], and returns its
    result if successful. If [a] fails, then [b] is returned. *)

val fix :
  ?sub1:('a t -> 'a t) list ->
  ?sub2:('a t -> 'a t -> 'a t) list ->
  ?subn:(int t * ('a list t -> 'a t)) list ->
  base:'a t -> int t -> 'a t
(** Recursion combinators, for building recursive values.
    The integer generator is used to provide fuel. The [sub_] generators
    should use their arguments only once!
    @param sub1 cases that recurse on one value
    @param sub2 cases that use the recursive gen twice
    @param subn cases that use a list of recursive cases *)

(** {6 Applicative} *)

val pure : 'a -> 'a t

val (<*>) : ('a -> 'b) t -> 'a t -> 'b t

(** {6 Run a generator} *)

val run : ?st:state -> 'a t -> 'a
(** Using a random state (possibly the one in argument) run a generator *)

(**/**)

val uniformity_test : ?size_hint:int -> int -> 'a t -> bool t
(** [uniformity_test k rng] tests the uniformity of the random generator [rng] using
    [k] samples.
    @since 0.15
*)
