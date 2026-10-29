#lang info

(define version "0.1")
;; Multi-collection package shape: the collection is the `obd2/` subdirectory.
(define collection 'multi)
;; rackunit-lib is a run-time dependency because the package ships its test
;; suite and the catalog's dependency check scans shipped modules in run mode.
;; uds is a run-time dependency: the OBD-II DTC text forms are shared.
(define deps '("base" "rackunit-lib" "uds"))
(define build-deps '("base" "scribble-lib" "racket-doc" "rackunit-lib"))
(define pkg-desc "Pure-Racket SAE J1979 OBD-II services (modes 01-0A): the full Mode-01 PID table with J1979 formulas, DTC services, supported bitmaps, MIL status and VIN extraction")
(define pkg-authors '("turlamai"))
(define license 'MIT)
;; Documentation is declared in obd2/info.rkt (collection level) — `raco
;; setup` only discovers scribblings from a collection's own info.rkt for
;; `collection 'multi` packages.
(define test-omit-paths '("obd2/scribblings"))
