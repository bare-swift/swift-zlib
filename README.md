# swift-zlib

RFC 1950 zlib codec — decoder (v0.1) + one-shot encoder (v0.2) + streaming encoder (v0.3). Sendable, Foundation-free; wraps swift-deflate.

Part of the [bare-swift](https://github.com/bare-swift) ecosystem.

## Install

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/bare-swift/swift-zlib.git", from: "0.3.0")
```

Then depend on the `Zlib` product:

```swift
.product(name: "Zlib", package: "swift-zlib")
```

## Usage

### Decode (v0.1+)

```swift
import Zlib
import Bytes

let zlibFramed: Bytes = ...   // 2-byte header + DEFLATE + 4-byte ADLER32
let plain = try Zlib.decode(zlibFramed)
```

### Encode (v0.2+)

```swift
import Zlib
import Bytes

let payload: Bytes = ...
let framed = Zlib.encode(payload, level: .default)
// Round-trip property: Zlib.decode(framed) == payload
```

### Streaming encode (v0.3+)

```swift
import Zlib
import Bytes

var encoder = Zlib.Streaming.Encoder(level: .default)
encoder.update(chunk1)
encoder.update(chunk2)
let framed = try encoder.finish()
let plain = try Zlib.decode(framed)
// plain == chunk1 + chunk2
```

`Zlib.Streaming.Encoder` wraps `Deflate.Streaming.Encoder` (swift-deflate
v0.3) for the body + an incremental ADLER32 over uncompressed bytes + 2-byte
zlib header + 4-byte big-endian ADLER32 trailer. Each `update(_:)` feeds
the chunk to the inner DEFLATE encoder and updates the running ADLER32.
Empty chunks are no-ops. `finish()` emits the full zlib stream. After
`finish()` the encoder is consumed — further `update(_:)` calls are silent
no-ops; another `finish()` throws `encoderFinished`.

Levels pass straight through to swift-deflate:

- `.none` / `.fast` → FLEVEL hint = 0
- `.default` → FLEVEL hint = 2
- `.best` → FLEVEL hint = 3

**HTTP `Content-Encoding: deflate`** is what this package handles. Per RFC 7230 § 4.2.2's note, "deflate" in HTTP actually means zlib-framed DEFLATE in every mainstream implementation; raw DEFLATE under that name is rare and non-conformant. Use this package, not raw swift-deflate, for `Content-Encoding: deflate` payloads.

## Scope

`swift-zlib` v0.2 ships **both halves** of RFC 1950:

- Decoder: 2-byte header parse (CMF / FLG with `(CMF*256 + FLG) % 31 == 0` check), DEFLATE body via swift-deflate, 4-byte big-endian ADLER32 trailer validation.
- Encoder: fixed CMF=0x78 (CM=8 deflate, CINFO=7 → 32 KiB window), FLG with FLEVEL hint + FCHECK satisfying the mod-31 check, DEFLATE body via swift-deflate v0.2, big-endian ADLER32 trailer.

Public API:

- `Zlib.decode(_:) throws(ZlibError) -> Bytes`
- `Zlib.encode(_:level:) -> Bytes`
- `Zlib.Encoder` value type with `.encode(_:)` method.
- `Zlib.Encoder.Level` (typealias for `Deflate.Encoder.Level`).
- `ZlibError` typed-throws enum (7 cases).

## Dependencies

- `swift-deflate` 0.2.0 — DEFLATE codec (inflate + deflate).
- `swift-bytes` 0.1.0 — input/output buffer.

(No `swift-crc` dep — ADLER32 is a Fletcher-style checksum, not a CRC, and the implementation is small enough to inline.)

## Out of scope for v0.2

- **Preset dictionary** (FDICT=1). RFC 1950 § 2.2 describes a 4-byte DICTID followed by a pre-shared dictionary that primes the LZ77 sliding window. v0.2 always emits FDICT=0 on encode and throws `.presetDictionaryUnsupported` on decode.
- **Streaming encoding.** v0.2 takes a single full `Bytes` input.
- `Codable` bridging — same Foundation-free / non-Codable differentiator as the rest of the ecosystem.

## Documentation

Full DocC documentation: <https://bare-swift.github.io/swift-zlib/>

## Source

No upstream Rust crate; this is a native bare-swift package implementing RFC 1950 directly.

## License

Apache 2.0 with LLVM exception. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
