# ``Zlib``

RFC 1950 zlib decoder — Sendable, Foundation-free; wraps swift-deflate.

## Overview

`Zlib.decode(_:)` strips the 2-byte zlib header, calls
`Deflate.inflate(_:)` on the body, and validates the 4-byte ADLER32
trailer (big-endian, unlike gzip's little-endian CRC32).

```swift
import Zlib
import Bytes

let zlibFramed: Bytes = ...   // 2-byte header + DEFLATE + 4-byte ADLER32
let plain = try Zlib.decode(zlibFramed)
```

**HTTP `Content-Encoding: deflate`** actually means zlib-framed
DEFLATE in practice — RFC 7230 § 4.2.2 acknowledges that some
implementations send raw DEFLATE under the same name, but every
mainstream web server / client uses zlib framing. Use this package,
not raw swift-deflate, for `Content-Encoding: deflate` payloads.

Per [RFC-0012](https://github.com/bare-swift/bare-swift/blob/main/rfcs/0012-phase-7-anchor-http-body-codecs.md),
**v0.1 ships decoding only**. The encoder lands in v0.2 once
swift-deflate's DEFLATE encoder is stable. Preset dictionaries
(FDICT) are also v0.2 — v0.1 throws ``ZlibError/presetDictionaryUnsupported``.

## Topics

### Essentials

- ``ZlibError``
