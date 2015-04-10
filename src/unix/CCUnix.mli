
(*
copyright (c) 2013-2015, simon cruanes
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

(** {1 High-level Functions on top of Unix}

Some useful functions built on top of Unix.

{b status: unstable}
@since 0.10 *)

type 'a or_error = [`Ok of 'a | `Error of string]
type 'a gen = unit -> 'a option

(** {2 Calling Commands} *)

val escape_str : Buffer.t -> string -> unit
(** Escape a string so it can be a shell argument.
*)

(*$T
  CCPrint.sprintf "%a" escape_str "foo" = "foo"
  CCPrint.sprintf "%a" escape_str "foo bar" = "'foo bar'"
  CCPrint.sprintf "%a" escape_str "fo'o b'ar" = "'fo''o b''ar'"
*)

type call_result =
  < stdout:string;
    stderr:string;
    status:Unix.process_status;
    errcode:int; (** extracted from status *)
  >

val call : ?bufsize:int ->
           ?stdin:[`Gen of string gen | `Str of string] ->
           ?env:string array ->
           ('a, Buffer.t, unit, call_result) format4 ->
           'a
(** [call cmd] wraps the result of [Unix.open_process_full cmd] into an
    object. It reads the full stdout and stderr of the subprocess before
    returning.
    @param stdin if provided, the generator or string is consumed and fed to
      the subprocess input channel, which is then closed.
    @param bufsize buffer size used to read stdout and stderr
    @param env environment to run the command in
*)

(*$T
  (call ~stdin:(`Str "abc") "cat")#stdout = "abc"
  (call "echo %a" escape_str "a'b'c")#stdout = "abc\n"
  (call "echo %s" "a'b'c")#stdout = "abc\n"
*)



