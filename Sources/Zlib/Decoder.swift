// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes
import Deflate

/// RFC 1950 zlib decoder. 2-byte header (CMF + FLG), DEFLATE body,
/// 4-byte big-endian ADLER32 trailer.
enum Decoder {
    static func decode(_ bytes: Bytes) throws(ZlibError) -> Bytes {
        let raw = bytes.storage
        if raw.count < 6 {  // 2-byte header + 4-byte trailer minimum
            throw .truncated
        }

        let cmf = raw[0]
        let flg = raw[1]
        let cm = cmf & 0x0F
        let cinfo = (cmf >> 4) & 0x0F
        if cm != 8 {
            throw .unsupportedCompressionMethod(cm)
        }
        if cinfo > 7 {
            throw .invalidWindowSize(cinfo)
        }
        // RFC 1950 § 2.2: (CMF * 256 + FLG) must be a multiple of 31.
        if ((UInt32(cmf) << 8) | UInt32(flg)) % 31 != 0 {
            throw .headerCheckFailed
        }
        if flg & 0x20 != 0 {
            // FDICT bit — preset dictionary present.
            throw .presetDictionaryUnsupported
        }

        // DEFLATE body lives between the 2-byte header and the 4-byte trailer.
        let trailerStart = raw.count - 4
        guard trailerStart >= 2 else { throw .truncated }

        var bodyBytes = Bytes(reservingCapacity: trailerStart - 2)
        for i in 2..<trailerStart {
            bodyBytes.append(raw[i])
        }

        let decompressed: Bytes
        do {
            decompressed = try Deflate.inflate(bodyBytes)
        } catch {
            throw .malformedDeflate(error)
        }

        // ADLER32 is big-endian per RFC 1950 § 2.2 (unlike gzip's LE CRC32).
        let adlerExpected =
            (UInt32(raw[trailerStart]) << 24)
            | (UInt32(raw[trailerStart + 1]) << 16)
            | (UInt32(raw[trailerStart + 2]) << 8)
            | UInt32(raw[trailerStart + 3])

        let adlerActual = Adler32.compute(decompressed.storage)
        if adlerActual != adlerExpected {
            throw .adler32Mismatch
        }

        return decompressed
    }
}
