# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
