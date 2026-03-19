#include <cstdint>
#include <memory>
#include <stdexcept>
#include <vector>
#include <string>

class Buffer {
public:
    explicit Buffer(std::size_t capacity)
        : data_(std::make_unique<uint8_t[]>(capacity))
        , capacity_(capacity)
        , size_(0)
    {}

    void write(const uint8_t* src, std::size_t length) {
        if (size_ + length > capacity_)
            throw std::overflow_error("Buffer capacity exceeded");
        std::copy(src, src + length, data_.get() + size_);
        size_ += length;
    }

    std::size_t read(uint8_t* dst, std::size_t maxLength) const {
        std::size_t toRead = std::min(maxLength, size_);
        std::copy(data_.get(), data_.get() + toRead, dst);
        return toRead;
    }

    void clear() noexcept { size_ = 0; }
    std::size_t size() const noexcept { return size_; }
    std::size_t capacity() const noexcept { return capacity_; }

private:
    std::unique_ptr<uint8_t[]> data_; // ownership is explicit and automatic
    std::size_t capacity_;
    std::size_t size_;
};

class BufferPool {
public:
    explicit BufferPool(std::size_t bufferSize, std::size_t poolSize)
        : bufferSize_(bufferSize)
    {
        for (std::size_t i = 0; i < poolSize; ++i)
            available_.push_back(std::make_unique<Buffer>(bufferSize));
    }

    std::unique_ptr<Buffer> acquire() {
        if (available_.empty())
            return std::make_unique<Buffer>(bufferSize_);
        auto buf = std::move(available_.back());
        available_.pop_back();
        return buf;
    }

    void release(std::unique_ptr<Buffer> buf) {
        buf->clear();
        available_.push_back(std::move(buf));
    }

private:
    std::size_t bufferSize_;
    std::vector<std::unique_ptr<Buffer>> available_;
};
