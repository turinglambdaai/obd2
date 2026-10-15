#lang racket/base

;; The PID (Parameter ID) record of the SAE J1979 Mode 01 service.

(require racket/contract)

(provide (contract-out
          (struct pid ((number exact-nonnegative-integer?)
                       (name string?)
                       (data-bytes (integer-in 0 255))
                       (decode symbol?)))))

(struct pid (number name data-bytes decode) #:transparent)
