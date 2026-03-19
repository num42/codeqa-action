#include <cstdint>
#include <cstring>
#include <stdexcept>
#include <vector>
#include <string>

class Buffer {
public:
    explicit Buffer(std::size_t capacity)
        : capacity_(capacity)
        , size_(0)
    {
        // Raw owning pointer — must be manually deleted; leaks on exception
        data_ = new uint8_t[capacity];
    }

    ~Buffer() {
        delete[] data_; // relies on correct destructor call; no RAII safety
    }

    // Copy constructor not implemented — double-free if copied
    Buffer(const Buffer&) = delete;
    Buffer& operator=(const Buffer&) = delete;

    void write(const uint8_t* src, std::size_t length) {
        if (size_ + length > capacity_)
            throw std::overflow_error("Buffer capacity exceeded");
        std::memcpy(data_ + size_, src, length);
        size_ += length;
    }

    std::size_t read(uint8_t* dst, std::size_t maxLength) const {
        std::size_t toRead = std::min(maxLength, size_);
        std::memcpy(dst, data_, toRead);
        return toRead;
    }

    void clear() { size_ = 0; }
    std::size_t size() const { return size_; }

private:
    uint8_t* data_; // raw owning pointer — manual memory management
    std::size_t capacity_;
    std::size_t size_;
};

class BufferPool {
public:
    explicit BufferPool(std::size_t bufferSize, std::size_t poolSize)
        : bufferSize_(bufferSize)
    {
        for (std::size_t i = 0; i < poolSize; ++i)
            available_.push_back(new Buffer(bufferSize)); // raw owning pointers in vector
    }

    ~BufferPool() {
        for (auto* buf : available_)
            delete buf; // manual cleanup; leaks if exception thrown before this
    }

    Buffer* acquire() {
        if (available_.empty())
            return new Buffer(bufferSize_); // caller must delete — ownership unclear
        Buffer* buf = available_.back();
        available_.pop_back();
        return buf;
    }

    void release(Buffer* buf) {
        buf->clear();
        available_.push_back(buf);
    }

private:
    std::size_t bufferSize_;
    std::vector<Buffer*> available_; // vector of raw owning pointers
};
