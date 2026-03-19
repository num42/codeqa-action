#include <algorithm>
#include <cstring>
#include <memory>
#include <stdexcept>

// Copyability is explicitly declared — nothing is left to compiler defaults.
// The Rule of Five is fully stated.

class Matrix {
public:
    Matrix(std::size_t rows, std::size_t cols)
        : rows_(rows), cols_(cols)
        , data_(std::make_unique<double[]>(rows * cols))
    {
        std::fill(data_.get(), data_.get() + rows * cols, 0.0);
    }

    // Explicit copy constructor — deep copies the heap data
    Matrix(const Matrix& other)
        : rows_(other.rows_), cols_(other.cols_)
        , data_(std::make_unique<double[]>(other.rows_ * other.cols_))
    {
        std::copy(other.data_.get(),
                  other.data_.get() + rows_ * cols_,
                  data_.get());
    }

    // Explicit copy assignment — copy-and-swap for strong exception safety
    Matrix& operator=(const Matrix& other) {
        Matrix tmp(other);
        swap(tmp);
        return *this;
    }

    // Explicit move constructor — noexcept: just pointer/integer transfer
    Matrix(Matrix&& other) noexcept
        : rows_(other.rows_), cols_(other.cols_)
        , data_(std::move(other.data_))
    {
        other.rows_ = 0;
        other.cols_ = 0;
    }

    // Explicit move assignment
    Matrix& operator=(Matrix&& other) noexcept {
        if (this != &other) {
            data_ = std::move(other.data_);
            rows_ = other.rows_;
            cols_ = other.cols_;
            other.rows_ = 0;
            other.cols_ = 0;
        }
        return *this;
    }

    ~Matrix() = default;

    double& at(std::size_t r, std::size_t c) {
        return data_[r * cols_ + c];
    }

    double at(std::size_t r, std::size_t c) const {
        return data_[r * cols_ + c];
    }

    std::size_t rows() const noexcept { return rows_; }
    std::size_t cols() const noexcept { return cols_; }

private:
    std::size_t rows_;
    std::size_t cols_;
    std::unique_ptr<double[]> data_;

    void swap(Matrix& other) noexcept {
        std::swap(rows_, other.rows_);
        std::swap(cols_, other.cols_);
        std::swap(data_, other.data_);
    }
};
