//
//  SampleBuffer.swift
//  Essential_Watch Watch App
//
//  Fixed-capacity ring buffer of `AccelerometerSample` values.
//  Used as the sliding window that will be fed into a CoreML model.
//

import Foundation

/// A fixed-capacity ring buffer of `AccelerometerSample` values.
///
/// New samples overwrite the oldest entries once the buffer reaches
/// `capacity`. The default capacity of `100` corresponds to roughly
/// two seconds of samples at 50 Hz, which matches the planned input
/// window for the on-device activity model.
struct SampleBuffer: Sendable {
    /// Maximum number of samples retained at any time.
    let capacity: Int

    /// Underlying storage; size is bounded by `capacity`.
    private var storage: [AccelerometerSample]

    /// Write index for the next inserted sample (wraps around).
    private var writeIndex: Int = 0

    /// Whether the buffer has been filled at least once.
    private var filled: Bool = false

    /// Creates a new buffer with the given capacity (default `100`).
    /// - Parameter capacity: The maximum number of samples to retain.
    ///   Values less than `1` are clamped to `1`.
    init(capacity: Int = 100) {
        let safeCapacity = max(1, capacity)
        self.capacity = safeCapacity
        self.storage = []
        self.storage.reserveCapacity(safeCapacity)
    }

    /// `true` once `capacity` samples have been written to the buffer.
    var isFull: Bool {
        filled
    }

    /// The current number of samples held by the buffer.
    var count: Int {
        filled ? capacity : storage.count
    }

    /// Appends a sample, overwriting the oldest entry once full.
    /// - Parameter sample: The new accelerometer sample to store.
    mutating func append(_ sample: AccelerometerSample) {
        if filled {
            storage[writeIndex] = sample
        } else {
            storage.append(sample)
            if storage.count == capacity {
                filled = true
            }
        }
        writeIndex = (writeIndex + 1) % capacity
    }

    /// A copy of the buffer's contents ordered from oldest to newest.
    var snapshot: [AccelerometerSample] {
        guard filled else {
            return storage
        }
        // When full, samples oldest→newest start at `writeIndex`.
        let tail = storage[writeIndex..<capacity]
        let head = storage[0..<writeIndex]
        return Array(tail) + Array(head)
    }
}
