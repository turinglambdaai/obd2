# obd2 — SAE J1979 OBD-II services in pure Racket

**English** · [中文](README.zh-CN.md)

[![CI](https://github.com/turlamai/obd2/actions/workflows/ci.yml/badge.svg)](https://github.com/turlamai/obd2/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`obd2` implements the message layer of **OBD-II** — the SAE J1979
diagnostic services ("modes") that every road vehicle sold in major
markets must answer: live sensor PIDs, stored and pending diagnostic
trouble codes, freeze frames, vehicle information and emissions readiness.

Everything is implemented in pure Racket.  The Mode 01 PID table is a
frozen port of Python's [python-OBD](https://github.com/brendan-w/python-OBD)
(0.7.3), whose live decoders also provide the arithmetic test anchors.
DTC text forms are shared with the [uds](https://github.com/turlamai/uds)
package (ISO 14229), keeping the letter/number format identical across
both diagnostic worlds.

## Installation

```
raco pkg install obd2
```

## Usage

This copy/paste example uses synthetic, already reassembled diagnostic payloads;
it needs no CAN adapter, vehicle or ISO-TP transport. A request is not sent
automatically: the caller owns transport and timeout handling.

```racket
#lang racket/base
(require obd2)
(make-request #x01 #x0C) ; => (bytes #x01 #x0C), request engine RPM
(define rpm (parse-response #x01 (bytes #x41 #x0C #x0E #x70)))
(obd-response-value rpm) ; => '(924.0 . "rpm")
(decode-pid (pid-for #x00) (bytes #xBE #x1F #xA8 #x13))
;; => '(1 3 4 5 6 7 12 13 14 15 16 17 19 21 28 31 32)
(obd-response-value
 (parse-response #x03 (bytes #x43 #x02 #x04 #x20 #x01 #x23)))
;; => '("P0420" "P0123")
(status-word (bytes #x82 #x07 #x65 #x04)) ; => '(#t 2 spark)
(vin-from-response
 (bytes-append (bytes #x49 #x02 #x01) #"1M8GDM9AXKP042788"))
;; => "1M8GDM9AXKP042788" (synthetic test fixture)
```

The [executable quickstart](examples/quickstart.rkt) asserts all of these
reference vectors. The [Scribble API manual](obd2/scribblings/obd2.scrbl)
defines the public contracts and error behavior.

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

## Development

From a repository checkout with Racket installed:

```sh
raco pkg install --auto --link "$(pwd)"
raco test -p obd2
racket examples/quickstart.rkt
raco setup --check-pkg-deps -l obd2
```

CI exercises tests, this synthetic example and the Scribble/dependency gate
on Linux, macOS and Windows. Please report a minimal, non-sensitive fixture
and Racket version via [GitHub Issues](https://github.com/turlamai/obd2/issues).

## License

[MIT](LICENSE).  The PID table is ported from python-OBD (MIT).
