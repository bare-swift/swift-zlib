# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.5.0] — 2026-05-17

### Added
- **`Zlib.Streaming.Decoder`** — streaming-decode counterpart to v0.3's `Streaming.Encoder`. Mirrors the canonical streaming shape: `init() / update(_:) / finish() throws -> Bytes`. Wraps `Deflate.Streaming.Decoder` (swift-deflate v0.5). Buffers compressed input internally; at `finish()`, calls `Zlib.decode(_:)` one-shot which parses the 2-byte CMF/FLG header, decompresses the DEFLATE body, verifies the big-endian ADLER32 trailer, and returns the decompressed output.
- `ZlibError.decoderFinished` — thrown when `finish()` is called on an already-finished decoder.
- 10 new tests covering round-trip via v0.2 encoder (single chunk, multi-chunk, tiny chunks, 70 KiB payload, single-byte payload), truncated-input error, bad-header error, double-finish error, update-after-finish no-op, empty-update no-op.

### v0.5 implementation note (honest scope under limitation)
- The decoder buffers all compressed input internally; decoded output is **not yielded incrementally** during `update(_:)`. Ships the streaming-symmetric API surface; true memory-streaming zlib decode is a v0.6+ candidate (inherits when swift-deflate v0.6 ships state-machine-refactored streaming inflate).
- Honest-scope-under-limitation pattern (Phase 25 → 28 → 30 → 31 instance).

### Dependencies
- swift-deflate dep bumped 0.4.0 → 0.5.0 (for `Deflate.Streaming.Decoder`).

### Migration (v0.4 → v0.5)
- **Additive only — non-breaking.** All v0.1-v0.4 APIs unchanged.
- `ZlibError` adds 1 new case (additive).

### Phase 31
- Tranche 31B of [RFC-0036](https://github.com/bare-swift/bare-swift/blob/main/rfcs/0036-phase-31-anchor-gzip-zlib-v0.5-streaming-inflate.md). Phase 31 COMPLETE — coordinated 2-tranche sweep added `Streaming.Decoder` to swift-gzip + swift-zlib; deflate-family streaming-decode story COMPLETE.

## [0.4.0] — 2026-05-17

### Added
- **`Zlib.Streaming.Encoder.drain() -> Bytes`** — returns the byte-aligned portion of the accumulated stream so far, resetting the internal byte buffer. The encoder remains in the open state; subsequent `update(_:)` and `finish()` calls produce the remainder (including the ADLER32 trailer at finish). The **first** `drain()` call emits the 2-byte zlib header (CMF + FLG) followed by the drained DEFLATE bytes; subsequent drains return only DEFLATE bytes. ADLER32 state accumulates across drains (drain does NOT touch the checksum; trailer is emitted only at `finish()`).
- 6 new tests covering drain semantics (header-emitted-on-first-drain, subsequent-drain-empty), drain+finish round-trip, multiple-drain round-trip, drain-after-finish no-op, byte-equality with non-draining stream.

### Dependencies
- swift-deflate dep bumped 0.3.0 → 0.4.0 (for `Deflate.Streaming.Encoder.drain()`).

### Use case
Multi-coding HTTP `Content-Encoding` streaming via swift-content-encoding v0.6 (Phase 28+).

### Migration (v0.3 → v0.4)
- **Additive only — non-breaking.** All v0.3 APIs unchanged.
- Existing v0.3 streams (no `drain()` calls) produce byte-identical output to v0.3.
- `ZlibError` cases unchanged.

### Phase 27
- Tranche 27D of [RFC-0032](https://github.com/bare-swift/bare-swift/blob/main/rfcs/0032-phase-27-anchor-codec-tier-v0.4-drain-sweep.md). Codec-tier v0.4 drain() API sweep — Phase 27 COMPLETE.

## [0.3.0] — 2026-05-16

### Added
- **Streaming encoder** — `Zlib.Streaming.Encoder` struct with `init(level:)` / `update(_:)` / `finish()`. Wraps `Deflate.Streaming.Encoder` (swift-deflate v0.3) for the DEFLATE body + incremental ADLER32 over uncompressed bytes via new `Adler32.Digest` + 2-byte zlib header + 4-byte big-endian ADLER32 trailer.
- `Zlib.Streaming` public namespace enum.
- `ZlibError.encoderFinished` — thrown when `finish()` is called on an already-finished encoder.
- Internal `Adler32.Digest` struct — incremental ADLER32 (`init` + `update(_:)` + `finalize()`). v0.2's `Adler32.compute(_:)` one-shot still works (now implemented atop `Digest`).
- 15 new tests covering round-trip, all four levels, header check validity, and error/edge cases.

### Dependencies
- swift-deflate dep bumped 0.2.0 → 0.3.0 (for `Deflate.Streaming.Encoder`).

### Stream-format notes
- Streaming output is **valid zlib** that decodes via the same `Zlib.decode(_:)` v0.1 API.
- No window carry across chunks in v0.3 (inherited from swift-deflate v0.3).
- CMF/FLG header check `(CMF*256 + FLG) % 31 == 0` is enforced by construction.

### Migration (v0.2 → v0.3)
- **Additive only — non-breaking.** All v0.2 APIs unchanged.
- `Zlib.encode(_:level:)` continues to emit byte-equal output to v0.2 (regression-tested via existing v0.2 round-trip tests).
- `Zlib.Encoder` struct unchanged.
- `Zlib.decode(_:)` unchanged from v0.1.
- `ZlibError` adds 1 new case (additive; existing cases unchanged).

### Phase 24
- Tranche 24B of [RFC-0029](https://github.com/bare-swift/bare-swift/blob/main/rfcs/0029-phase-24-anchor-gzip-zlib-v0.3-streaming-encoders.md). Completes codec-tier streaming sweep at package level (brotli + deflate + gzip + zlib all stream-capable).

## [0.2.0] - 2026-05-12

### Added
- `Zlib.encode(_:level:)` — RFC 1950 zlib encoder. 2-byte header (CMF=0x78 + FLG with FCHECK / FDICT / FLEVEL) + DEFLATE body (via swift-deflate v0.2) + 4-byte big-endian ADLER32 trailer.
- `Zlib.Encoder` value type — single-shot encoder (streaming ships in v0.3).
- `Zlib.Encoder.Level` typealias for `Deflate.Encoder.Level` (`.none`/`.fast`/`.default`/`.best`); FLEVEL hint is set accordingly (.none/.fast → 0, .default → 2, .best → 3).
- Internal `Adler32` type — extracted from the decoder so encode and decode share one ADLER-32 implementation.
- 12 new tests across 3 suites covering API surface (CMF, header check, FLEVEL hint, FDICT=0), round-trip via v0.1 decoder (empty / ASCII / runs / 64 KiB / all levels / big-endian trailer), and v0.1 stability.

### Changed
- swift-deflate dep bumped from 0.1.0 to 0.2.0 (additive — unlocks `Deflate.encode`).
- Internal: `Decoder.adler32(_:)` static method moved to `Adler32.compute(_:)` (internal refactor, no public API change).

### Unchanged from v0.1
- `Zlib.decode(_:)` — bit-for-bit unchanged.
- `ZlibError` cases — all seven v0.1 cases preserved.

### Limitations (out of scope for v0.2)
- Preset dictionary encoding (FDICT=1). v0.2 always emits FDICT=0.
- Streaming encoding. v0.2 takes a single full `Bytes` input.

## [0.1.0] - 2026-05-10

### Added
- `Zlib.decode(_ bytes: Bytes) throws(ZlibError) -> Bytes` — single-shot RFC 1950 zlib decoder. Validates CMF/FLG header, header check `(CMF*256 + FLG) % 31 == 0`, inflates the DEFLATE body via swift-deflate, validates the big-endian ADLER32 trailer.
- `ZlibError` typed-throws enum (8 cases) including `headerCheckFailed`, `adler32Mismatch`, `presetDictionaryUnsupported`, and `malformedDeflate(DeflateError)`.
- Inline ADLER-32 reference implementation per RFC 1950 § 9 (no `swift-crc` dep — ADLER32 is a Fletcher-style checksum, not a CRC).
- 14 tests across 3 suites covering: simple inputs (empty, 'abc', 'hello world', repeated 'a' with back-references, the quick brown fox via dynamic Huffman), 6 error paths (truncation, wrong CM, invalid CINFO, header check failure, FDICT, ADLER32 mismatch), and standalone ADLER32 unit tests including the canonical 'abc' = 0x024D0127.

All zlib test vectors generated via Python's `zlib.compress()` at default compression level.

### Dependencies
- `swift-deflate` 0.1.0 — DEFLATE inflater.
- `swift-bytes` 0.1.0 — input/output buffer.

### Limitations (out of scope for v0.1)
- **Encoder.** Per RFC-0012's staging pattern (decompression first), the zlib encoder lands in v0.2 alongside swift-deflate's DEFLATE encoder.
- **Preset dictionary** (FDICT). v0.1 throws `.presetDictionaryUnsupported`; defer to v0.2.
- `Codable` bridging — same Foundation-free / non-Codable differentiator as the rest of the ecosystem.
