#lang racket/base

;; SAE J1979 decoders: one function per formula family, dispatched on the
;; table's decode kind.  A decoder receives the response payload AFTER the
;; mode and PID echo bytes and returns (cons value unit-string); the
;; symbolic decoders (status, bitmaps, text tables) return richer values
;; documented per function.

(require racket/contract
         racket/list
         (only-in uds dtc-number->text)
         "pid.rkt"
         "pid-table.rkt")

(provide (contract-out
          [decode-pid (-> pid? bytes? (or/c pair? exact-integer? boolean? string?
                                         (listof exact-integer?) #f
                                         (listof (or/c string? #f))))]
          [status-word
           (-> bytes? (cons/c boolean? (cons/c exact-nonnegative-integer? list?)))]
          [supported-pids (-> exact-nonnegative-integer? bytes? (listof exact-nonnegative-integer?))]
          [parse-freeze-dtc (-> bytes? (or/c string? #f))]
          [parse-dtcs (-> bytes? (listof string?))]))

(define (u16 a b) (+ (* a 256) b))

;; Two's complement of an n-bit value.
(define (twos-comp v n)
  (if (>= v (arithmetic-shift 1 (sub1 n)))
      (- v (arithmetic-shift 1 n))
      v))

;; The J1979 text tables, ported from python-OBD 0.7.3.
(define fuel-status-table
  '#("Open loop due to insufficient engine temperature"
     "Closed loop, using oxygen sensor feedback to determine fuel mix"
     "Open loop due to engine load OR fuel cut due to deceleration"
     "Open loop due to system failure"
     "Closed loop, using at least one oxygen sensor but there is a fault in the feedback system"))
(define air-status-table
  '#("Upstream"
     "Downstream of catalytic converter"
     "From the outside atmosphere or off"
     "Pump commanded on for diagnostics"))
(define obd-compliance-table
  '#("Undefined" "OBD-II as defined by the CARB" "OBD as defined by the EPA"
     "OBD and OBD-II" "OBD-I" "Not OBD compliant" "EOBD (Europe)"
     "EOBD and OBD-II" "EOBD and OBD" "EOBD, OBD and OBD II" "JOBD (Japan)"
     "JOBD and OBD II" "JOBD and EOBD" "JOBD, EOBD, and OBD II" "Reserved"
     "Reserved" "Reserved"
     "Engine Manufacturer Diagnostics (EMD)"
     "Engine Manufacturer Diagnostics Enhanced (EMD+)"
     "Heavy Duty On-Board Diagnostics (Child/Partial) (HD OBD-C)"
     "Heavy Duty On-Board Diagnostics (HD OBD)"
     "World Wide Harmonized OBD (WWH OBD)" "Reserved"
     "Heavy Duty Euro OBD Stage I without NOx control (HD EOBD-I)"
     "Heavy Duty Euro OBD Stage I with NOx control (HD EOBD-I N)"
     "Heavy Duty Euro OBD Stage II without NOx control (HD EOBD-II)"
     "Heavy Duty Euro OBD Stage II with NOx control (HD EOBD-II N)" "Reserved"
     "Brazil OBD Phase 1 (OBDBr-1)" "Brazil OBD Phase 2 (OBDBr-2)"
     "Korean OBD (KOBD)" "India OBD I (IOBD I)" "India OBD II (IOBD II)"
     "Heavy Duty Euro OBD Stage VI (HD EOBD-IV)"))
(define fuel-type-table
  '#("Not available" "Gasoline" "Methanol" "Ethanol" "Diesel" "LPG" "CNG"
     "Propane" "Electric" "Bifuel running Gasoline" "Bifuel running Methanol"
     "Bifuel running Ethanol" "Bifuel running LPG" "Bifuel running CNG"
     "Bifuel running Propane" "Bifuel running Electricity"
     "Bifuel running electric and combustion engine" "Hybrid gasoline"
     "Hybrid Ethanol" "Hybrid Diesel" "Hybrid Electric"
     "Hybrid running electric and combustion engine" "Hybrid Regenerative"
     "Bifuel running diesel"))

;; A nibble-set text decoder: exactly one bit of the byte may be set; the
;; table indexes from the LSB end of the valid range (0x01 -> entry 0,
;; 0x02 -> 1, ... 0x10 -> 4 for the five fuel-status entries).
(define (one-hot-byte->text byte table)
  (define ones (for/sum ([i (in-range 8)])
                 (if (zero? (bitwise-and byte (arithmetic-shift 1 i))) 0 1)))
  (if (= 1 ones)
      (let ([index (sub1 (integer-length byte))])
        (and (< index (vector-length table))
             (vector-ref table index)))
      #f))

;; MIL on?, DTC count, ignition type (PID 01 / 41 first bytes).
(define (status-word data)
  (define a (bytes-ref data 0))
  (define b (bytes-ref data 1))
  ;; ignition type lives in B's bit 4 (python-OBD bits[12])
  (list (not (zero? (bitwise-and a #x80)))
        (bitwise-and a #x7F)
        (if (zero? (bitwise-and b #x10)) 'spark 'compression)))

;; The PIDs declared supported by a 32-bit bitmap whose MSB is the PID
;; right after `base` (00 -> 01..20, 20 -> 21..40, ...).
(define (supported-pids base bitmap)
  (for/list ([i (in-range 32)]
             #:when (not (zero? (bitwise-and
                                 (bytes-ref bitmap (quotient i 8))
                                 (arithmetic-shift 1 (- 7 (remainder i 8)))))))
    (+ base 1 i)))

;; The single freeze-frame DTC of PID 02 (zero or empty = no DTC).
(define (parse-freeze-dtc data)
  (and (= 2 (bytes-length data))
       (let ([n (u16 (bytes-ref data 0) (bytes-ref data 1))])
         (and (not (zero? n))
              (dtc-number->text n)))))

;; The 2-byte DTC list of modes 03/07/0A.  `data` follows the mode echo; if
;; its length is odd the first byte is the DTC count.  0000 pairs are
;; padding.
(define (parse-dtcs data)
  (define bytes*
    (if (odd? (bytes-length data))
        (subbytes data 1)
        data))
  (for/list ([i (in-range 0 (- (bytes-length bytes*) 1) 2)]
             #:unless (and (zero? (bytes-ref bytes* i))
                           (zero? (bytes-ref bytes* (+ i 1)))))
    (dtc-number->text (u16 (bytes-ref bytes* i) (bytes-ref bytes* (+ i 1))))))

(define (vector-ref* v i)
  (and (< i (vector-length v)) (vector-ref v i)))

;; Decode a PID response payload (after the mode/PID echo) according to the
;; table's kind.  Arithmetic decoders return (cons value unit); symbolic
;; decoders return their natural Racket values (see each helper).
(define (decode-pid p data)
  (define (arith v unit) (cons v unit))
  (case (pid-decode p)
    [(percent) (arith (/ (* (bytes-ref data 0) 100.0) 255.0) "%")]
    [(percent-centered)
     (arith (/ (* (- (bytes-ref data 0) 128) 100.0) 128.0) "%")]
    [(temp) (arith (- (bytes-ref data 0) 40) "degC")]
    [(pressure) (arith (bytes-ref data 0) "kPa")]
    [(fuel-pressure) (arith (* 3 (bytes-ref data 0)) "kPa")]
    [(sensor-voltage) (arith (/ (bytes-ref data 0) 200.0) "V")]
    [(sensor-voltage-big)
     (arith (/ (* (u16 (bytes-ref data 2) (bytes-ref data 3)) 8.0) 65535) "V")]
    [(current-centered)
     (arith (- (/ (u16 (bytes-ref data 2) (bytes-ref data 3)) 256.0) 128) "mA")]
    [(counts8) (arith (bytes-ref data 0) "count")]
    [(counts16) (arith (u16 (bytes-ref data 0) (bytes-ref data 1)) "count")]
    [(rpm) (arith (/ (u16 (bytes-ref data 0) (bytes-ref data 1)) 4.0) "rpm")]
    [(speed) (arith (bytes-ref data 0) "km/h")]
    [(voltage) (arith (/ (u16 (bytes-ref data 0) (bytes-ref data 1)) 1000.0) "V")]
    [(catalyst-temp)
     (arith (- (/ (u16 (bytes-ref data 0) (bytes-ref data 1)) 10.0) 40) "degC")]
    [(fuel-rail-vac)
     (arith (* (u16 (bytes-ref data 0) (bytes-ref data 1)) 0.079) "kPa")]
    [(fuel-rail-direct)
     (arith (* (u16 (bytes-ref data 0) (bytes-ref data 1)) 10.0) "kPa")]
    [(equiv-ratio)
     (arith (/ (u16 (bytes-ref data 0) (bytes-ref data 1)) 32768.0) "ratio")]
    [(distance) (arith (u16 (bytes-ref data 0) (bytes-ref data 1)) "km")]
    [(maf) (arith (/ (u16 (bytes-ref data 0) (bytes-ref data 1)) 100.0) "g/s")]
    [(absolute-load)
     (arith (/ (* (u16 (bytes-ref data 0) (bytes-ref data 1)) 100.0) 255.0) "%")]
    [(timing-advance)
     (arith (/ (- (bytes-ref data 0) 128) 2.0) "deg")]
    [(max-maf) (arith (* 10 (bytes-ref data 0)) "g/s")]
    [(fuel-rate)
     (arith (* (u16 (bytes-ref data 0) (bytes-ref data 1)) 0.05) "L/h")]
    [(inject-timing)
     (arith (/ (- (u16 (bytes-ref data 0) (bytes-ref data 1)) 26880) 128.0) "deg")]
    [(evap-pressure)
     (define a (twos-comp (bytes-ref data 0) 8))
     (define b (twos-comp (bytes-ref data 1) 8))
     (arith (/ (+ (* a 256.0) b) 4.0) "Pa")]
    [(evap-pressure-alt)
     (arith (- (u16 (bytes-ref data 0) (bytes-ref data 1)) 32767) "Pa")]
    [(abs-evap-pressure)
     (arith (/ (u16 (bytes-ref data 0) (bytes-ref data 1)) 200.0) "kPa")]
    [(aux-input) (not (zero? (bitwise-and (bytes-ref data 0) #x80)))]
    [(supported-pids)
     (supported-pids (pid-number p) data)]
    [(status) (status-word data)]
    [(monitor-status) (status-word data)]
    [(freeze-dtc) (parse-freeze-dtc data)]
    [(fuel-status)
     (list (one-hot-byte->text (bytes-ref data 0) fuel-status-table)
           (one-hot-byte->text (bytes-ref data 1) fuel-status-table))]
    [(air-status)
     (one-hot-byte->text (bytes-ref data 0) air-status-table)]
    [(obd-compliance)
     (vector-ref* obd-compliance-table (bytes-ref data 0))]
    [(fuel-type)
     (vector-ref* fuel-type-table (bytes-ref data 0))]
    [(o2-presence) (supported-pids 0 data)]
    [else ;; raw
     data]))
