1341
((3) 0 () 3 ((q lib "obd2/main.rkt") (q 919 . 7) (q 0 . 6)) () (h ! (equal) ((c def c (c (? . 0) q struct:obd-response)) c (? . 1)) ((c def c (c (? . 0) q pid-number)) c (? . 2)) ((c def c (c (? . 0) q status-word)) q (512 . 4)) ((c def c (c (? . 0) q decode-pid)) q (308 . 6)) ((c def c (c (? . 0) q parse-dtcs)) q (847 . 3)) ((c def c (c (? . 0) q obd-response)) c (? . 1)) ((c def c (c (? . 0) q obd-response-nrc)) c (? . 1)) ((c def c (c (? . 0) q struct:pid)) c (? . 2)) ((c def c (c (? . 0) q parse-freeze-dtc)) q (767 . 3)) ((c def c (c (? . 0) q pid-for)) q (216 . 3)) ((c def c (c (? . 0) q mode-01-pids)) q (178 . 2)) ((c def c (c (? . 0) q obd-response?)) c (? . 1)) ((c def c (c (? . 0) q pid)) c (? . 2)) ((c def c (c (? . 0) q obd-response-mode)) c (? . 1)) ((c def c (c (? . 0) q pid-decode)) c (? . 2)) ((c def c (c (? . 0) q pid-data-bytes)) c (? . 2)) ((c def c (c (? . 0) q supported-pids)) q (621 . 5)) ((c def c (c (? . 0) q obd-response-negative?)) c (? . 1)) ((c def c (c (? . 0) q parse-response)) q (1295 . 4)) ((c def c (c (? . 0) q make-request)) q (1168 . 4)) ((c def c (c (? . 0) q obd-response-value)) c (? . 1)) ((c def c (c (? . 0) q pid?)) c (? . 2)) ((c def c (c (? . 0) q obd-response-pid)) c (? . 1)) ((c def c (c (? . 0) q pid-name)) c (? . 2)) ((c def c (c (? . 0) q vin-from-response)) q (1413 . 3))))
struct
(struct pid (number name data-bytes decode))
  number : exact-nonnegative-integer?
  name : string?
  data-bytes : (integer-in 0 255)
  decode : symbol?
value
mode-01-pids : (listof pid?)
procedure
(pid-for number) -> (or/c pid? #f)
  number : exact-nonnegative-integer?
procedure
(decode-pid p payload)
 -> (or/c pair? exact-integer? boolean? string? (listof exact-integer?) #f
          (listof (or/c string? #f)))
  p : pid?
  payload : bytes?
procedure
(status-word data)
 -> (list* boolean? exact-nonnegative-integer? list?)
  data : bytes?
procedure
(supported-pids base bitmap)
 -> (listof exact-nonnegative-integer?)
  base : exact-nonnegative-integer?
  bitmap : bytes?
procedure
(parse-freeze-dtc data) -> (or/c string? #f)
  data : bytes?
procedure
(parse-dtcs data) -> (listof string?)
  data : bytes?
struct
(struct obd-response (mode pid negative? nrc value))
  mode : exact-nonnegative-integer?
  pid : (or/c exact-nonnegative-integer? #f)
  negative? : boolean?
  nrc : (or/c exact-nonnegative-integer? #f)
  value : any/c
procedure
(make-request mode pid) -> bytes?
  mode : exact-nonnegative-integer?
  pid : exact-nonnegative-integer?
procedure
(parse-response mode data) -> obd-response?
  mode : exact-nonnegative-integer?
  data : bytes?
procedure
(vin-from-response data) -> string?
  data : bytes?
