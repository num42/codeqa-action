#include <cstdint>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <vector>

class Buffer {
public:
    explicit Buffer(std::size_t capacity)
        : data_(std::make_unique<uint8_t[]>(capacity))
        , capacity_(capacity)
        , size_(0)
    {}

    // Move constructor is noexcept: only reassigns pointers and integers — cannot throw
    Buffer(Buffer&& other) noexcept
        : data_(std::move(other.data_))
        , capacity_(other.capacity_)
        , size_(other.size_)
    {
        other.capacity_ = 0;
        other.size_ = 0;
    }

    // Move assignment is noexcept for the same reason
    Buffer& operator=(Buffer&& other) noexcept {
        if (this != &other) {
            data_ = std::move(other.data_);
            capacity_ = other.capacity_;
            size_ = other.size_;
            other.capacity_ = 0;
            other.size_ = 0;
        }
        return *this;
    }

    Buffer(const Buffer& other)
        : data_(std::make_unique<uint8_t[]>(other.capacity_))
        , capacity_(other.capacity_)
        , size_(other.size_)
    {
        std::memcpy(data_.get(), other.data_.get(), other.size_);
    }

    Buffer& operator=(const Buffer& other) {
        if (this != &other) {
            auto newData = std::make_unique<uint8_t[]>(other.capacity_);
            std::memcpy(newData.get(), other.data_.get(), other.size_);
            data_ = std::move(newData);
            capacity_ = other.capacity_;
            size_ = other.size_;
        }
        return *this;
    }

    void append(const uint8_t* src, std::size_t length) {
        if (size_ + length > capacity_)
            throw std::overflow_error("Buffer capacity exceeded");
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

// noexcept move allows std::vector<Buffer> to use move during reallocation
// rather than copying — important for performance
void demonstrateVectorRealloc() {
    std::vector<Buffer> buffers;
    buffers.reserve(4);
    for (int i = 0; i < 8; ++i)
        buffers.emplace_back(1024); // triggers reallocation; uses move ctor (noexcept)
}
