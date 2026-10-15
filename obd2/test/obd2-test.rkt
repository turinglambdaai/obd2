#lang racket/base

;; Tests for the obd2 package.  Arithmetic anchors were produced with the
;; Python python-OBD library (0.7.3) live decoders; the PID table is a
;; frozen port of its Mode 01 table.  One documented deviation: the
;; commanded equivalence ratio is decoded with the J1979-exact /32768
;; instead of python-OBD's truncated 3.05e-05 scale.

(require rackunit
         racket/list
         obd2/pid
         obd2/pid-table
         obd2/decode
         obd2/service)

;; ---------------------------------------------------------------------------
;; the PID table

(test-case "mode-01 table shape"
  (check-equal? (length mode-01-pids) 96)
  (check-equal? (pid-number (car mode-01-pids)) 0)
  (check-equal? (pid-name (pid-for #x0C)) "RPM")
  (check-equal? (pid-data-bytes (pid-for #x0C)) 2)
  (check-false (pid-for #xFF)))

;; ---------------------------------------------------------------------------
;; arithmetic decoders (anchors from python-OBD live decodes)

(define (decoded pid-number . payload)
  (decode-pid (pid-for pid-number) (list->bytes payload)))

(test-case "engine decoders"
  ;; RPM: 0x0E70 / 4 = 924.0
  (check-equal? (decoded #x0C #x0E #x70) (cons 924.0 "rpm"))
  ;; MAF: 0x07D0 / 100 = 20.0 g/s
  (check-equal? (decoded #x10 #x07 #xD0) (cons 20.0 "g/s"))
  ;; control module voltage: 0x0FA0 / 1000 = 4.0 V
  (check-equal? (decoded #x42 #x0F #xA0) (cons 4.0 "V"))
  ;; distance since clear: 0x2710 km
  (check-equal? (decoded #x31 #x27 #x10) (cons 10000 "km"))
  ;; runtime: 0x0FA0 s
  (check-equal? (decoded #x1F #x0F #xA0) (cons 4000 "count")))

(test-case "percent family"
  ;; engine load 0x80 -> 50.196%
  (check-equal? (decoded #x04 #x80) (cons (/ (* 128 100.0) 255.0) "%"))
  ;; throttle 0x53
  (check-equal? (decoded #x11 #x53) (cons (/ (* 83 100.0) 255.0) "%"))
  ;; short fuel trim 0x54 (84): (84-128)*100/128 = -34.375%
  (check-equal? (decoded #x06 #x54) (cons -34.375 "%"))
  ;; absolute load 0x2710 -> 10000*100/255
  (check-equal? (decoded #x43 #x27 #x10)
                (cons (/ (* 10000 100.0) 255.0) "%")))

(test-case "temperature family"
  ;; coolant 0x50 -> 40 degC
  (check-equal? (decoded #x05 #x50) (cons 40 "degC"))
  ;; intake 0x5A -> 50 degC
  (check-equal? (decoded #x0F #x5A) (cons 50 "degC"))
  ;; ambient 0x3C -> 20 degC
  (check-equal? (decoded #x46 #x3C) (cons 20 "degC"))
  ;; oil temp 0x8C -> 100 degC
  (check-equal? (decoded #x5C #x8C) (cons 100 "degC"))
  ;; catalyst temp 0x0FA0 -> 360 degC
  (check-equal? (decoded #x3C #x0F #xA0) (cons 360.0 "degC")))

(test-case "pressure family"
  ;; barometric 0x63 -> 99 kPa
  (check-equal? (decoded #x33 #x63) (cons 99 "kPa"))
  ;; intake pressure 0x50 -> 80 kPa
  (check-equal? (decoded #x0B #x50) (cons 80 "kPa"))
  ;; fuel pressure 0x21 (33) * 3 -> 99 kPa
  (check-equal? (decoded #x0A #x21) (cons 99 "kPa"))
  ;; fuel rail vac 0x2710 -> 790 kPa
  (check-equal? (decoded #x22 #x27 #x10) (cons 790.0 "kPa"))
  ;; fuel rail direct 0x2710 -> 100000 kPa
  (check-equal? (decoded #x23 #x27 #x10) (cons 100000.0 "kPa")))

(test-case "lambda and O2 sensors"
  ;; equivalence ratio, J1979-exact: 0x8000/32768 = 1.0
  (check-equal? (decoded #x44 #x80 #x00) (cons 1.0 "ratio"))
  ;; O2 sensor voltage (sensor 1): 128 / 200 = 0.64 V
  (check-equal? (decoded #x14 #x80) (cons 0.64 "V"))
  ;; lambda sensor pair: AB ratio, CD voltage 0x0FA0*8/65535
  (check-equal? (decoded #x24 #x80 #x00 #x0F #xA0)
                (cons (/ (* 4000.0 8.0) 65535) "V")))

(test-case "miscellaneous decoders"
  ;; timing advance 0x70: (112-128)/2 = -8 deg
  (check-equal? (decoded #x0E #x70) (cons -8.0 "deg"))
  ;; max MAF 0x19 -> 250 g/s
  (check-equal? (decoded #x50 #x19) (cons 250 "g/s"))
  ;; fuel rate 0x2710 -> 500 L/h
  (check-equal? (decoded #x5E #x27 #x10) (cons 500.0 "L/h"))
  ;; evap pressure alt 0x8000 -> 32768-32767 = 1 Pa
  (check-equal? (decoded #x54 #x80 #x00) (cons 1 "Pa"))
  ;; aux input bit7
  (check-equal? (decoded #x1E #x80) #t)
  (check-equal? (decoded #x1E #x7F) #f))

;; ---------------------------------------------------------------------------
;; symbolic decoders

(test-case "supported PID bitmaps"
  ;; the classic example: BE 1F A8 13
  (check-equal? (decoded #x00 #xBE #x1F #xA8 #x13)
                (list 1 3 4 5 6 7 12 13 14 15 16 17 19 21 28 31 32))
  ;; an empty bitmap supports nothing
  (check-equal? (decoded #x00 0 0 0 0) '()))

(test-case "status word (MIL, DTC count, ignition type)"
  ;; A=0x82: MIL on, 2 DTCs; B=0x07: spark ignition
  (check-equal? (status-word (bytes #x82 #x07 #x65 #x04))
                (list* #t 2 '(spark)))
  ;; A=0x00, B=0x10: MIL off, no DTCs, compression ignition
  (check-equal? (status-word (bytes #x00 #x10 #x00 #x00))
                (list* #f 0 '(compression))))

(test-case "freeze-frame DTC uses the uds text forms"
  ;; 0x0420 -> P0420
  (check-equal? (parse-freeze-dtc (bytes #x04 #x20)) "P0420")
  (check-equal? (parse-freeze-dtc (bytes 0 0)) #f)
  (check-equal? (decoded #x02 #x04 #x20) "P0420"))

(test-case "DTC list services (modes 03/07/0A)"
  ;; count byte 2 then two pairs; 0x0123 -> P0123
  (check-equal? (parse-dtcs (bytes #x02 #x04 #x20 #x01 #x23))
                '("P0420" "P0123"))
  ;; without a count byte
  (check-equal? (parse-dtcs (bytes #x04 #x20 #x01 #x23))
                '("P0420" "P0123"))
  ;; 0000 padding is skipped
  (check-equal? (parse-dtcs (bytes #x02 #x04 #x20 0 0))
                '("P0420"))
  ;; C/B letters: 0x5234 -> C1234, 0xA345 -> B2345
  (check-equal? (parse-dtcs (bytes #x03 #x52 #x34 #xA3 #x45))
                '("C1234" "B2345")))

(test-case "text tables"
  ;; fuel status 0x02 -> closed loop (second entry)
  (check-equal? (decoded #x03 #x02 0)
                (list "Closed loop, using oxygen sensor feedback to determine fuel mix"
                      #f))
  ;; invalid fuel status (zero bits / multiple bits)
  (check-equal? (decoded #x03 0 0) (list #f #f))
  (check-equal? (decoded #x03 #x03 0) (list #f #f))
  ;; air status 0x04 -> from the outside atmosphere or off
  (check-equal? (decoded #x12 #x04)
                "From the outside atmosphere or off")
  ;; OBD compliance type 6 -> EOBD (Europe)
  (check-equal? (decoded #x1C #x06) "EOBD (Europe)")
  ;; fuel type 4 -> Diesel
  (check-equal? (decoded #x51 #x04) "Diesel")
  ;; out-of-range entries degrade to #f
  (check-equal? (decoded #x51 #xFF) #f))

;; ---------------------------------------------------------------------------
;; service layer

(test-case "request construction"
  (check-equal? (make-request #x01 #x0C) (bytes #x01 #x0C))
  (check-equal? (make-request #x03) (bytes #x03)))

(test-case "positive response parsing and decoding"
  (define r (parse-response #x01 (bytes #x41 #x0C #x0E #x70)))
  (check-false (obd-response-negative? r))
  (check-equal? (obd-response-mode r) 1)
  (check-equal? (obd-response-pid r) #x0C)
  (check-equal? (obd-response-value r) (cons 924.0 "rpm"))
  ;; mode 03: DTC list
  (define d (parse-response #x03 (bytes #x43 #x02 #x04 #x20 #x01 #x23)))
  (check-equal? (obd-response-value d) '("P0420" "P0123"))
  ;; mode 04: clear, bare echo
  (define c (parse-response #x04 (bytes #x44)))
  (check-equal? (obd-response-value c) #""))

(test-case "negative responses (7F mode nrc)"
  (define r (parse-response #x01 (bytes #x7F #x01 #x11)))
  (check-true (obd-response-negative? r))
  (check-equal? (obd-response-nrc r) #x11)
  ;; mode mismatch in a negative response is an error
  (check-exn exn:fail? (lambda () (parse-response #x01 (bytes #x7F #x02 #x11)))))

(test-case "echo mismatches are rejected"
  (check-exn exn:fail? (lambda () (parse-response #x01 (bytes #x42 #x0C #x00 #x00))))
  (check-exn exn:fail? (lambda () (parse-response #x01 (bytes #x00))))
  (check-exn exn:fail? (lambda () (parse-response #x01 (bytes #x41 #xFF #x00)))))

;; ---------------------------------------------------------------------------
;; service 09: VIN extraction

(test-case "VIN from a multi-line response"
  (define text "1M8GDM9AXKP042788")
  (define payload
    (bytes-append (bytes #x49 #x02 #x01) #"1M8"
                  (bytes #x49 #x02 #x02) #"GDM9AXKP"
                  (bytes #x49 #x02 #x03) #"042788"))
  (check-equal? (vin-from-response payload) text)
  ;; a single-header reassembled form works too
  (define payload2
    (bytes-append (bytes #x49 #x02 #x01) #"1M8GDM9AXKP042788"))
  (check-equal? (vin-from-response payload2) text))
