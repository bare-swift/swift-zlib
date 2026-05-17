// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Deflate

/// Errors thrown by ``Zlib/decode(_:)``.
public enum ZlibError: Error, Equatable, Sendable {
    /// Decoder ran out of bytes mid-header / mid-trailer.
    case truncated

    /// `CM` field carried a value other than `8`. Only DEFLATE is defined.
    case unsupportedCompressionMethod(UInt8)

    /// `CINFO` value > 7 — RFC 1950 reserves CINFO 8..15.
    case invalidWindowSize(UInt8)

    /// `(CMF * 256 + FLG) % 31 != 0` per RFC 1950 § 2.2.
    case headerCheckFailed

    /// `FDICT` flag set (preset dictionary). v0.1 doesn't support
    /// preset-dictionary decoding; defer to v0.2.
    case presetDictionaryUnsupported

    /// Trailer's ADLER32 didn't match the computed ADLER32 of the
    /// decompressed data.
    case adler32Mismatch

    /// Wrapped DEFLATE-level error from swift-deflate.
    case malformedDeflate(DeflateError)

    /// Encoder: ``Zlib/Streaming/Encoder/finish()`` was called twice on
    /// the same encoder.
    case encoderFinished

    /// Decoder: ``Zlib/Streaming/Decoder/finish()`` was called twice on
    /// the same decoder. Added in v0.5.
    case decoderFinished
}
