#lang racket/base
;; Hardware-free SAE J1979 message-layer smoke. All responses are synthetic.
(require obd2)

(define (verify actual expected label)
  (unless (equal? actual expected)
    (error 'obd2-quickstart "~a: got ~v, expected ~v" label actual expected)))

(verify (make-request #x01 #x0C) (bytes #x01 #x0C) "RPM request")
(define rpm (parse-response #x01 (bytes #x41 #x0C #x0E #x70)))
(verify (obd-response-value rpm) (cons 924.0 "rpm") "RPM decode")
(verify (decode-pid (pid-for #x00) (bytes #xBE #x1F #xA8 #x13))
        '(1 3 4 5 6 7 12 13 14 15 16 17 19 21 28 31 32)
        "supported PID bitmap")
(verify (obd-response-value
         (parse-response #x03 (bytes #x43 #x02 #x04 #x20 #x01 #x23)))
        '("P0420" "P0123") "DTC list")
(verify (status-word (bytes #x82 #x07 #x65 #x04))
        '(#t 2 spark) "MIL status")
(verify (vin-from-response
         (bytes-append (bytes #x49 #x02 #x01) #"1M8GDM9AXKP042788"))
        "1M8GDM9AXKP042788" "synthetic VIN")
(displayln "OBD-II quickstart OK")
