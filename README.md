# obd2 — SAE J1979 OBD-II services in pure Racket

[![CI](https://github.com/turinglambdaai/obd2/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/obd2/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`obd2` implements the message layer of **OBD-II** — the SAE J1979
diagnostic services ("modes") that every road vehicle sold in major
markets must answer: live sensor PIDs, stored and pending diagnostic
trouble codes, freeze frames, vehicle information and emissions readiness.

Everything is implemented in pure Racket.  The Mode 01 PID table is a
frozen port of Python's [python-OBD](https://github.com/brendan-w/python-OBD)
(0.7.3), whose live decoders also provide the arithmetic test anchors.
DTC text forms are shared with the [uds](https://github.com/turinglambdaai/uds)
package (ISO 14229), keeping the letter/number format identical across
both diagnostic worlds.

## Installation

```
raco pkg install obd2
```

## Usage

```racket
(require obd2)

;; ask for engine RPM, then decode a positive response
(make-request #x01 #x0C)                       ; => #"\1\f"
(define r (parse-response #x01 (bytes #x41 #x0C #x0E #x70)))
(obd-response-value r)                         ; => '(924.0 . "rpm")

;; which PIDs does the vehicle support?
(decoded (pid-for #x00) (bytes #xBE #x1F #xA8 #x13))
;; => '(1 3 4 5 6 7 12 13 14 15 16 17 19 20 22 23 24)

;; stored trouble codes (mode 03)
(obd-response-value
 (parse-response #x03 (bytes #x43 #x02 #x04 #x20 #x01 #x23)))
;; => '("P0420" "P0123")

;; MIL status: on, 2 codes, spark ignition
(status-word (bytes #x82 #x07 #x65 #x04))      ; => '(#t 2 spark)

;; VIN from a service 09 response
(vin-from-response payload)
```

### Scope

- Mode 01: all 96 standard PIDs (00-5F) with the J1979 formulas — engine
  load, temperatures, RPM, MAF, fuel trims, O2 sensors, catalyst and rail
  pressures, equivalence ratio (J1979-exact /32768), supported bitmaps,
  MIL/DTC status word, and the text tables (fuel/air status, OBD
  compliance, fuel type).
- Modes 02/03/04/07/09/0A: freeze-frame DTCs, stored/pending/permanent DTC
  lists, clear codes, vehicle info with VIN extraction.
- Negative responses (`7F <mode> <nrc>`) are surfaced as
  `obd-response` values with `negative?`/`nrc`.

Transport (ISO 15765-2 / isotp) and the raw CAN layer are out of scope —
feed `parse-response` the reassembled diagnostic payload.

## License

[MIT](LICENSE).  The PID table is ported from python-OBD (MIT).
