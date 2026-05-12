# ``Zlib``

RFC 1950 zlib codec — decoder (v0.1+) and encoder (v0.2+). Sendable, Foundation-free.

## Overview

`Zlib` provides both halves of RFC 1950:

- ``Zlib/decode(_:)`` — v0.1+. Parses the 2-byte header (with the `(CMF*256+FLG) % 31 == 0` check), inflates the DEFLATE body via swift-deflate, validates the 4-byte big-endian ADLER32 trailer.
- ``Zlib/encode(_:level:)`` — v0.2+. Emits CMF=0x78 (CM=8 deflate, CINFO=7 → 32 KiB window) + FLG with FLEVEL hint and matching FCHECK, the DEFLATE body, and the big-endian ADLER32 trailer.

```swift
import Zlib
import Bytes

let encoded = Zlib.encode(payload, level: .default)
let back = try Zlib.decode(encoded)  // round-trip
```

**HTTP `Content-Encoding: deflate`** actually means zlib-framed DEFLATE in practice — RFC 7230 § 4.2.2 acknowledges that some implementations send raw DEFLATE under the same name, but every mainstream web server / client uses zlib framing. Use this package, not raw swift-deflate, for `Content-Encoding: deflate` payloads.

Per [RFC-0014](https://github.com/bare-swift/bare-swift/blob/main/rfcs/0014-phase-9-anchor-compression-encoder-sweep.md), v0.2 commits to **correctness** — zopfli-style size tuning lands as v0.2.x patch releases. Preset dictionaries (FDICT=1) remain out of scope; the decoder still throws ``ZlibError/presetDictionaryUnsupported`` and the encoder always emits FDICT=0.

## Topics

### Decode (v0.1+)

- ``Zlib/decode(_:)``

### Encode (v0.2+)

- ``Zlib/encode(_:level:)``
- ``Zlib/Encoder``
- ``Zlib/Encoder/Level``

### Errors

- ``ZlibError``
