# swift-zlib

RFC 1950 zlib decoder — Sendable, Foundation-free; wraps swift-deflate.

Part of the [bare-swift](https://github.com/bare-swift) ecosystem.

## Install

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/bare-swift/swift-zlib.git", from: "0.1.0")
```

Then depend on the `Zlib` product:

```swift
.product(name: "Zlib", package: "swift-zlib")
```

## Usage

```swift
import Zlib
import Bytes

let zlibFramed: Bytes = ...   // 2-byte header + DEFLATE + 4-byte ADLER32
let plain = try Zlib.decode(zlibFramed)
```

**HTTP `Content-Encoding: deflate`** is what this package handles. Per RFC 7230 § 4.2.2's note, "deflate" in HTTP actually means zlib-framed DEFLATE in every mainstream implementation; raw DEFLATE under that name is rare and non-conformant. Use this package, not raw swift-deflate, for `Content-Encoding: deflate` payloads.

## Scope

`swift-zlib` v0.1 implements RFC 1950 single-shot zlib decoding:

- 2-byte header parse: CMF (CM=8 deflate, CINFO ≤ 7), FLG (FCHECK + FDICT + FLEVEL), header check `(CMF*256 + FLG) % 31 == 0`.
- DEFLATE body inflated via swift-deflate.
- 4-byte big-endian ADLER32 trailer validated. Inline ADLER32 implementation per RFC 1950 § 9.

Public API:

- `Zlib.decode(_ bytes: Bytes) throws(ZlibError) -> Bytes` — single-shot.
- `ZlibError` typed-throws enum (8 cases including `headerCheckFailed`, `adler32Mismatch`, `presetDictionaryUnsupported`, and `malformedDeflate(DeflateError)`).

## Dependencies

- `swift-deflate` 0.1.0 — DEFLATE inflater.
- `swift-bytes` 0.1.0 — input/output buffer.

(No `swift-crc` dep — ADLER32 is a Fletcher-style checksum, not a CRC, and the implementation is small enough to inline.)

## Out of scope for v0.1

- **Encoder.** Per RFC-0012's staging pattern (decompression first), the zlib encoder lands in v0.2 alongside swift-deflate's DEFLATE encoder.
- **Preset dictionary** (FDICT). RFC 1950 § 2.2 describes a 4-byte DICTID followed by a pre-shared dictionary that primes the LZ77 sliding window. Throws `.presetDictionaryUnsupported` in v0.1; defer to v0.2.
- `Codable` bridging — same Foundation-free / non-Codable differentiator as the rest of the ecosystem.

## Documentation

Full DocC documentation: <https://bare-swift.github.io/swift-zlib/>

## Source

No upstream Rust crate; this is a native bare-swift package implementing RFC 1950 directly.

## License

Apache 2.0 with LLVM exception. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
