(*
Copyright (c) 2013, Simon Cruanes
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.  Redistributions in binary
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

(** {1 S-expressions Parser}

@since 0.4
@deprecated consider using {!CCSexpM} *)

type 'a or_error = [ `Ok of 'a | `Error of string ]
type 'a sequence = ('a -> unit) -> unit
type 'a gen = unit -> 'a option

type t = [
  | `Atom of string
  | `List of t list
  ]

(** {2 Serialization (encoding)} *)

val to_buf : Buffer.t -> t -> unit

val to_string : t -> string

val to_file : string -> t -> unit

val to_file_seq : string -> t sequence -> unit
(** Print the given sequence of expressions to a file *)

val to_chan : out_channel -> t -> unit

val print : Format.formatter -> t -> unit
(** Pretty-printer nice on human eyes (including indentation) *)

val print_noindent : Format.formatter -> t -> unit
(** Raw, direct printing as compact as possible *)

(** {2 Deserialization (decoding)} *)

type 'a parse_result = ['a or_error | `End ]
type 'a partial_result = [ 'a parse_result | `Await ]

(** {6 Source of characters} *)
module Source : sig
  type individual_char =
    | NC_yield of char
    | NC_end
    | NC_await
  (** An individual character returned by a source *)

  type t = unit -> individual_char
  (** A source of characters can yield them one by one, or signal the end,
      or signal that some external intervention is needed *)

  type source = t

  (** A manual source of individual characters. When it has exhausted its
      own input, it asks its caller to provide more or signal that none remains.
      This is especially useful when the source of data is monadic IO *)
  module Manual : sig
    type t

    val make : unit -> t
    (** Make a new manual source. It needs to be fed input manually,
        using {!feed} *)

    val to_src : t -> source
    (** The manual source contains a source! *)

    val feed : t -> string -> int -> int -> unit
    (** Feed a chunk of input to the manual source *)

    val reached_end : t -> unit
    (** Tell the decoder that end of input has been reached. From now
        the source will only yield [NC_end] *)
  end

  val of_string : string -> t
  (** Use a single string as the source *)

  val of_chan : ?bufsize:int -> in_channel -> t
  (** Use a channel as the source *)

  val of_gen : string gen -> t
end

(** {6 Streaming Lexer}
Splits the input into opening parenthesis, closing ones, and atoms *)

module Lexer : sig
  type t
  (** A streaming lexer, that parses atomic chunks of S-expressions (atoms
      and delimiters) *)

  val make : Source.t -> t
  (** Create a lexer that uses the given source of characters as an input *)

  val of_string : string -> t

  val of_chan : in_channel -> t

  val line : t -> int
  val col : t -> int

  (** Obtain next token *)

  type token =
    | Open
    | Close
    | Atom of string
  (** An individual S-exp token *)

  val next : t -> token partial_result
  (** Obtain the next token, an error, or block/end stream *)
end

(** {6 Generator with errors} *)
module ParseGen : sig
  type 'a t = unit -> 'a parse_result
  (** A generator-like structure, but with the possibility of errors.
      When called, it can yield a new element, signal the end of stream,
      or signal an error. *)

  val to_list : 'a t -> 'a list or_error

  val head : 'a t -> 'a or_error

  val head_exn : 'a t -> 'a

  val take : int -> 'a t -> 'a t
end

(** {6 Stream Parser}
Returns a lazy stream of S-expressions. *)

val parse_string : string -> t ParseGen.t
(** Parse a string *)

val parse_chan : ?bufsize:int -> in_channel -> t ParseGen.t
(** Parse a channel *)

val parse_gen : string gen -> t ParseGen.t
(** Parse chunks of string *)

(** {6 Blocking API}
Parse one S-expression from some source.  *)

val of_chan : in_channel -> t or_error
(** Parse a S-expression from the given channel. Can read more data than
    necessary, so don't use this if you need finer-grained control (e.g.
    to read something else {b after} the S-exp) *)

val of_string : string -> t or_error

val of_file : string -> t or_error
(** Open the file and read a S-exp from it *)

(** {6 Lists of S-exps} *)

module L : sig
  val to_buf : Buffer.t -> t list -> unit

  val to_string : t list -> string

  val to_file : string -> t list -> unit

  val to_chan : out_channel -> t list -> unit

  val of_chan : ?bufsize:int -> in_channel -> t list or_error

  val of_file : ?bufsize:int -> string -> t list or_error

  val of_string : string -> t list or_error

  val of_gen : string gen -> t list or_error

  val of_seq : string sequence -> t list or_error
end
