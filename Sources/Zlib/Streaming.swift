// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes
import Deflate

extension Zlib.Streaming {
    /// Streaming zlib encoder (RFC 1950). Feed chunks via ``update(_:)``
    /// and terminate with ``finish()``. The encoder wraps a
    /// `Deflate.Streaming.Encoder` for the body + an incremental ADLER32
    /// over uncompressed bytes + 2-byte zlib header + 4-byte big-endian
    /// ADLER32 trailer.
    ///
    /// Usage:
    /// ```swift
    /// var encoder = Zlib.Streaming.Encoder(level: .default)
    /// encoder.update(chunk1)
    /// encoder.update(chunk2)
    /// let framed = try encoder.finish()
    /// let plain = try Zlib.decode(framed)
    /// // plain == chunk1 + chunk2
    /// ```
    ///
    /// `Encoder` is a value type. Copying mid-stream produces two
    /// divergent encoders. Treat as single-owner.
    ///
    /// After ``finish()`` the encoder is in the finished state.
    /// ``update(_:)`` after finish is a silent no-op; double-finish throws
    /// ``ZlibError/encoderFinished``.
    public struct Encoder: Sendable {
        public typealias Level = Deflate.Encoder.Level

        private enum State: Sendable {
            case open
            case finished
        }

        public let level: Level

        private var headerBytes: (UInt8, UInt8)
        private var deflateEncoder: Deflate.Streaming.Encoder
        private var adler: Adler32.Digest
        private var state: State

        public init(level: Level = .default) {
            self.level = level
            self.headerBytes = Self.buildHeader(level: level)
            self.deflateEncoder = Deflate.Streaming.Encoder(level: level)
            self.adler = Adler32.Digest()
            self.state = .open
        }

        /// Feed a chunk. Updates the inner DEFLATE encoder and the running
        /// ADLER32 over uncompressed bytes. Empty chunk = no-op. Silent
        /// no-op when called after ``finish()``.
        public mutating func update(_ chunk: Bytes) {
            guard case .open = state else { return }
            if chunk.isEmpty { return }
            deflateEncoder.update(chunk)
            adler.update(chunk.storage)
        }

        /// Finalize the zlib stream: emit 2-byte header + DEFLATE body +
        /// 4-byte big-endian ADLER32 trailer. Throws
        /// ``ZlibError/encoderFinished`` on double-call.
        public mutating func finish() throws(ZlibError) -> Bytes {
            guard case .open = state else { throw .encoderFinished }
            state = .finished

            let deflateBytes: Bytes
            do {
                deflateBytes = try deflateEncoder.finish()
            } catch {
                throw .malformedDeflate(error)
            }

            var out = ContiguousArray<UInt8>()
            out.reserveCapacity(2 + deflateBytes.storage.count + 4)
            out.append(headerBytes.0)
            out.append(headerBytes.1)
            out.append(contentsOf: deflateBytes.storage)

            // ADLER32 big-endian per RFC 1950 § 2.2.
            let value = adler.finalize()
            out.append(UInt8(truncatingIfNeeded: (value >> 24) & 0xFF))
            out.append(UInt8(truncatingIfNeeded: (value >> 16) & 0xFF))
            out.append(UInt8(truncatingIfNeeded: (value >> 8) & 0xFF))
            out.append(UInt8(truncatingIfNeeded: value & 0xFF))

            return Bytes(out)
        }

        // MARK: - Header

        private static func buildHeader(level: Level) -> (UInt8, UInt8) {
            // RFC 1950 § 2.2 — CMF + FLG.
            // CMF: CM=8 (DEFLATE), CINFO=7 (32 KiB window).
            let cmf: UInt8 = 0x78
            // FLG: FDICT=0; FLEVEL hint matches level.
            let flevel: UInt8
            switch level {
            case .none, .fast: flevel = 0
            case .default:     flevel = 2
            case .best:        flevel = 3
            }
            var flg: UInt8 = flevel << 6
            // Compute FCHECK so (CMF*256 + FLG) is divisible by 31.
            let partial = (UInt32(cmf) << 8) | UInt32(flg)
            let remainder = partial % 31
            let fcheck = (31 - remainder) % 31
            flg |= UInt8(fcheck)
            return (cmf, flg)
        }
    }
}
