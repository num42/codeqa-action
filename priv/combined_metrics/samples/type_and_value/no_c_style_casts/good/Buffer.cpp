#include <cstdint>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <vector>

// All type conversions use named C++ casts — intent is explicit and greppable

class Buffer {
public:
    explicit Buffer(std::size_t capacity)
        : data_(std::make_unique<uint8_t[]>(capacity))
        , capacity_(capacity)
        , size_(0)
    {}

    void writeInt32(int32_t value) {
        if (size_ + sizeof(int32_t) > capacity_)
            throw std::overflow_error("Buffer capacity exceeded");

        // reinterpret_cast: deliberately reinterpreting an int as raw bytes
        std::memcpy(data_.get() + size_,
                    reinterpret_cast<const uint8_t*>(&value), sizeof(int32_t));
        size_ += sizeof(int32_t);
    }

    int32_t readInt32(std::size_t offset) const {
        if (offset + sizeof(int32_t) > size_)
            throw std::out_of_range("Read past end of buffer");

        int32_t value;
        std::memcpy(&value, data_.get() + offset, sizeof(int32_t));
        return value;
    }

    // static_cast: safe numeric widening
    double averageByteValue() const noexcept {
        if (size_ == 0) return 0.0;
        uint64_t sum = 0;
        for (std::size_t i = 0; i < size_; ++i)
            sum += data_[i];
        return static_cast<double>(sum) / static_cast<double>(size_);
    }

    // const_cast: explicitly removing const to call a legacy C API that promises
    // not to modify the data — documented and intentional
    void legacyCopy(const uint8_t* src, std::size_t length) {
        (void)const_cast<uint8_t*>(src); // would be used to pass to a non-const C API
        std::memcpy(data_.get() + size_, src, length);
        size_ += length;
    }

    std::size_t size() const noexcept { return size_; }
    std::size_t capacity() const noexcept { return capacity_; }

private:
    std::unique_ptr<uint8_t[]> data_;
    std::size_t capacity_;
    std::size_t size_;
};
