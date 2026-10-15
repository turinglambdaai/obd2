#lang racket/base

;; SAE J1979 service layer: request construction and response parsing.
;; OBD services are the "modes" 01..0A; a positive response echoes
;; mode + 0x40, a negative response is 7F <mode> <nrc> (ISO 15031-5).

(require racket/contract
         racket/match
         racket/string
         "pid.rkt"
         "pid-table.rkt"
         "decode.rkt")

(struct obd-response (mode pid negative? nrc value) #:transparent)

(provide (contract-out
          [make-request (->* (exact-nonnegative-integer?)
                             (exact-nonnegative-integer?)
                             bytes?)]
          (struct obd-response ((mode exact-nonnegative-integer?)
                                (pid (or/c exact-nonnegative-integer? #f))
                                (negative? boolean?)
                                (nrc (or/c exact-nonnegative-integer? #f))
                                (value any/c)))
          [parse-response
           (-> exact-nonnegative-integer? bytes? obd-response?)]
          [vin-from-response (-> bytes? string?)]))

;; Build a request: the mode, optionally followed by a PID byte.
(define (make-request mode [pid #f])
  (if pid
      (bytes mode pid)
      (bytes mode)))

;; Parse a response payload for a request with the given mode.  A positive
;; response must echo mode + 0x40; mode 01/02 responses are decoded through
;; the PID table, modes 03/07/0A return DTC text lists.
(define (parse-response mode data)
  (unless (>= (bytes-length data) 1)
    (error 'parse-response "empty response"))
  (define echo (bytes-ref data 0))
  (cond
    [(= echo #x7F)
     (unless (>= (bytes-length data) 3)
       (error 'parse-response "truncated negative response"))
     (unless (= (bytes-ref data 1) mode)
       (error 'parse-response
              "negative response for mode #x~a, expected #x~a"
              (number->string (bytes-ref data 1) 16)
              (number->string mode 16)))
     (obd-response mode #f #t (bytes-ref data 2) (subbytes data 3))]
    [(= echo (+ mode #x40))
     (parse-positive mode data)]
    [else
     (error 'parse-response
            "response echo #x~a does not match mode #x~a"
            (number->string echo 16)
            (number->string mode 16))]))

(define (parse-positive mode data)
  (define rest (subbytes data 1))
  (case mode
    [(1 2)
     (unless (>= (bytes-length rest) 1)
       (error 'parse-response "mode ~a response without a PID echo" mode))
     (define pid-number (bytes-ref rest 0))
     (define payload (subbytes rest 1))
     (define p (pid-for pid-number))
     (unless p
       (error 'parse-response "unknown PID #x~a" (number->string pid-number 16)))
     (unless (>= (bytes-length payload) (pid-data-bytes p))
       (error 'parse-response
              "PID #x~a wants ~a data byte(s), got ~a"
              (number->string pid-number 16)
              (pid-data-bytes p)
              (bytes-length payload)))
     (obd-response mode pid-number #f #f (decode-pid p payload))]
    [(3 7 10)
     (obd-response mode #f #f #f (parse-dtcs rest))]
    [else
     ;; modes 04 (clear), 08, 09 (info): the payload is service specific
     (obd-response mode #f #f #f rest)]))

;; Extract the VIN from a service 09 (info type 02) response: the
;; "49 02 N" headers of each line are stripped wherever they appear and
;; the remaining bytes are read as ASCII.  VIN characters are printable
;; ASCII and 0x02 never occurs in them, so the header scan is unambiguous.
(define (vin-from-response data)
  (define bs
    (let loop ([bs (bytes->list data)] [acc '()])
      (match bs
        ['() (reverse acc)]
        [(cons 73 (cons 2 (cons _ rest))) ;; 0x49 0x02 N header
         (loop rest acc)]
        [(cons b rest)
         (loop rest (cons b acc))])))
  (string-trim (list->string (map integer->char bs)) "\0" #:right? #t))
