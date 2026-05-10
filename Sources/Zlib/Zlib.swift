// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes
import Deflate

/// Sendable, Foundation-free [RFC 1950](https://www.rfc-editor.org/rfc/rfc1950.html)
/// zlib decoder. Wraps swift-deflate with the 2-byte zlib header and
/// the 4-byte ADLER32 trailer.
///
/// **HTTP `Content-Encoding: deflate` actually means zlib-framed
/// DEFLATE** per RFC 7230 § 4.2.2's "Note: Some non-conformant
/// implementations send the [DEFLATE] data without the zlib wrapper."
/// In practice, web servers and clients send zlib framing under the
/// `deflate` encoding name. Use this package, not raw swift-deflate,
/// for HTTP `Content-Encoding: deflate` payloads.
///
/// ```swift
/// import Zlib
/// import Bytes
///
/// let zlibFramed: Bytes = ...   // 2-byte header + DEFLATE + 4-byte ADLER32
/// let plain = try Zlib.decode(zlibFramed)
/// ```
///
/// Per [RFC-0012](https://github.com/bare-swift/bare-swift/blob/main/rfcs/0012-phase-7-anchor-http-body-codecs.md),
/// **v0.1 ships decoding only**. The encoder lands in v0.2 once
/// swift-deflate's DEFLATE encoder is stable.
public enum Zlib: Sendable {
    /// Decode a zlib-framed payload. Validates header check (CMF/FLG mod 31)
    /// and ADLER32 trailer.
    public static func decode(_ bytes: Bytes) throws(ZlibError) -> Bytes {
        try Decoder.decode(bytes)
    }
}
