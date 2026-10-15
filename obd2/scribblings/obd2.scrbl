#lang scribble/manual
@(require (for-label racket/base
                     racket/contract
                     obd2)
          scribble/example)

@(define obd2-eval (make-base-eval #:lang 'racket/base '(require obd2)))

@title[#:tag "obd2"]{obd2: SAE J1979 OBD-II services}
@author{turinglambdaai}

@defmodule[obd2]

The @filepath{obd2} package implements the message layer of
@deftech{OBD-II} — the SAE @hyperlink["https://www.sae.org/standards/content/j1979/"]{J1979}
diagnostic services ("modes") that every road vehicle sold in major
markets must answer: live sensor PIDs, stored and pending diagnostic
trouble codes, freeze frames, vehicle information and emissions readiness.

Everything is implemented in pure Racket.  The Mode 01 PID table is a
frozen port of the Python
@hyperlink["https://github.com/brendan-w/python-OBD"]{@tt{python-OBD}}
library (0.7.3), whose live decoders also provide the arithmetic test
anchors.  DTC text forms are shared with the
@racketlink[uds]{uds} package.

@section{Quick start}

@examples[
#:eval obd2-eval
;; ask for engine RPM, then decode a positive response
(make-request #x01 #x0C)
(define r (parse-response #x01 (bytes #x41 #x0C #x0E #x70)))
(obd-response-pid r)
(obd-response-value r)
;; which PIDs does the vehicle support?
(decode-pid (pid-for #x00) (bytes #xBE #x1F #xA8 #x13))
]

@section{The PID table}

@defstruct*[pid ([number exact-nonnegative-integer?]
                 [name string?]
                 [data-bytes (integer-in 0 255)]
                 [decode symbol?])]{
 One Mode 01 parameter: its J1979 number, python-OBD name, response
 payload length (after the mode and PID echo bytes) and the decode kind
 naming a formula in @racket[decode-pid].
}

@defthing[mode-01-pids (listof pid?)]{
 All 96 Mode 01 PIDs of the standard table (00 through 5F).
}

@defproc[(pid-for [number exact-nonnegative-integer?]) (or/c pid? #f)]{
 The table entry for @racket[number], or @racket[#f].
}

@section{Decoding}

@defproc[(decode-pid [p pid?] [payload bytes?])
         (or/c pair? exact-integer? boolean? string? (listof exact-integer?) #f
               (listof (or/c string? #f)))]{
 Decodes a response payload (after the mode and PID echo) according to
 the entry's kind.  Arithmetic decoders return @racket[(cons value unit)]
 with the J1979 formulas (RPM @tt{/4}, MAF @tt{/100}, temperatures
 @tt{-40}, equivalence ratio @tt{/32768}, ...); symbolic decoders return:

 @itemlist[
  @item{@racket['supported-pids] and @racket['o2-presence] — the list of
   PID numbers declared by a 32-bit bitmap;}
  @item{@racket['status] / @racket['monitor-status] —
   @racket[(list* mil-on? dtc-count ignition-type)] via
   @racket[status-word];}
  @item{@racket['freeze-dtc] — the DTC text (e.g. @tt{"P0420"}) or
   @racket[#f];}
  @item{@racket['fuel-status] / @racket['air-status] /
   @racket['obd-compliance] / @racket['fuel-type] — the J1979 text tables,
   with @racket[#f] for invalid or out-of-range entries.}
 ]
}

@defproc[(status-word [data bytes?])
         (list* boolean? exact-nonnegative-integer? list?)]{
 The MIL/DTC word of PIDs 01 and 41: MIL on?, the DTC count (A & 0x7F)
 and @racket['spark] / @racket['compression] / @racket['reserved] from B.
}

@defproc[(supported-pids [base exact-nonnegative-integer?] [bitmap bytes?])
         (listof exact-nonnegative-integer?)]{
 The PIDs declared by a 32-bit bitmap whose MSB is @racket[(+ base 1)].
}

@defproc[(parse-freeze-dtc [data bytes?]) (or/c string? #f)]{
 The single PID 02 DTC in the 16-bit letter form, or @racket[#f] for
 zeros.
}

@defproc[(parse-dtcs [data bytes?]) (listof string?)]{
 The 2-byte DTC list of modes 03, 07 and 0A.  An odd-length payload is
 prefixed by the DTC count byte; 0000 pairs are padding.  Letters decode
 through @racket[uds]'s @tt{dtc-number->text}: @tt{0x0420} →
 @tt{"P0420"}.
}

@section{Services}

@defstruct*[obd-response ([mode exact-nonnegative-integer?]
                          [pid (or/c exact-nonnegative-integer? #f)]
                          [negative? boolean?]
                          [nrc (or/c exact-nonnegative-integer? #f)]
                          [value any/c])]{
 One parsed response: the requested mode, the echoed PID (modes 01/02),
 whether the ECU answered negatively (@tt{7F <mode> <nrc>}), the negative
 response code, and the decoded value (modes 01/02), DTC text list
 (modes 03/07/0A) or raw payload (other modes).
}

@defproc[(make-request [mode exact-nonnegative-integer?]
                       [pid exact-nonnegative-integer?])
         bytes?]{
 The request bytes: the mode, optionally followed by the PID.
}

@defproc[(parse-response [mode exact-nonnegative-integer?] [data bytes?])
         obd-response?]{
 Parses and decodes a response.  The echo must equal @tt{mode + 0x40}
 (or a negative response must start with @tt{7F}); violations — and
 unknown PIDs or short payloads — raise @racket[exn:fail].
}

@defproc[(vin-from-response [data bytes?]) string?]{
 The VIN from a service 09, info type 02 response.  The @tt{49 02 N}
 line headers are stripped wherever they appear (a VIN cannot contain
 the 0x02 byte, so the scan is unambiguous) and the rest is read as
 ASCII.
}

@section{License}

MIT.  The PID table is ported from python-OBD (MIT).
