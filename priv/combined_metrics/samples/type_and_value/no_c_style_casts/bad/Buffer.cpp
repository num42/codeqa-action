#include <cstdint>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <vector>

class Buffer {
public:
    explicit Buffer(std::size_t capacity)
        : data_(new uint8_t[capacity])
        , capacity_(capacity)
        , size_(0)
    {}

    ~Buffer() { delete[] data_; }

    void writeInt32(int32_t value) {
        if (size_ + sizeof(int32_t) > capacity_)
            throw std::overflow_error("Buffer capacity exceeded");

        // C-style cast: unclear whether this is a reinterpret, static, or const cast
        std::memcpy(data_ + size_, (const uint8_t*)(&value), sizeof(int32_t));
        size_ += sizeof(int32_t);
    }

    int32_t readInt32(std::size_t offset) const {
        if (offset + sizeof(int32_t) > size_)
            throw std::out_of_range("Read past end of buffer");

        int32_t value;
        std::memcpy(&value, data_ + offset, sizeof(int32_t));
        return value;
    }

    // C-style cast: hides potential narrowing from uint64_t to double
    double averageByteValue() const {
        if (size_ == 0) return 0.0;
        uint64_t sum = 0;
        for (std::size_t i = 0; i < size_; ++i)
            sum += data_[i];
        return (double)sum / (double)size_; // C-style cast — intent unclear
    }

    // C-style cast removes const — silent and dangerous; no indication it's intentional
    void legacyCopy(const uint8_t* src, std::size_t length) {
        uint8_t* mutableSrc = (uint8_t*)src; // strips const — could allow modification
        std::memcpy(data_ + size_, mutableSrc, length);
        size_ += length;
    }

    // C-style cast from unrelated pointer types — undefined behavior; reinterpret_cast
    // would at least make the danger explicit
    void writeRawObject(const void* obj, std::size_t bytes) {
        const uint8_t* raw = (const uint8_t*)obj; // C-style cast of void*
        std::memcpy(data_ + size_, raw, bytes);
        size_ += bytes;
    }

    std::size_t size() const { return size_; }

private:
    uint8_t* data_;
    std::size_t capacity_;
    std::size_t size_;
};
