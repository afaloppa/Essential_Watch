import Foundation

struct SampleBuffer: Sendable {
    let capacity: Int
    private var storage: [AccelerometerSample]
    private var writeIndex: Int = 0
    private var filled: Bool = false

    init(capacity: Int = 100) {
        let safeCapacity = max(1, capacity)
        self.capacity = safeCapacity
        self.storage = []
        self.storage.reserveCapacity(safeCapacity)
    }

    var isFull: Bool { filled }

    var count: Int { filled ? capacity : storage.count }

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

    var snapshot: [AccelerometerSample] {
        guard filled else { return storage }
        let tail = storage[writeIndex..<capacity]
        let head = storage[0..<writeIndex]
        return Array(tail) + Array(head)
    }
}
