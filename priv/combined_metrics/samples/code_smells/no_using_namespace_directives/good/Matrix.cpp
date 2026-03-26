#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <vector>

// No "using namespace std;" — names are qualified explicitly

class Matrix {
public:
    Matrix(std::size_t rows, std::size_t cols)
        : rows_(rows), cols_(cols), data_(rows * cols, 0.0) {}

    double& at(std::size_t row, std::size_t col) {
        boundsCheck(row, col);
        return data_[row * cols_ + col];
    }

    double at(std::size_t row, std::size_t col) const {
        boundsCheck(row, col);
        return data_[row * cols_ + col];
    }

    std::size_t rows() const noexcept { return rows_; }
    std::size_t cols() const noexcept { return cols_; }

    Matrix operator+(const Matrix& rhs) const {
        checkCompatible(rhs);
        Matrix result(rows_, cols_);
        std::transform(data_.begin(), data_.end(),
                       rhs.data_.begin(), result.data_.begin(),
                       std::plus<double>());
        return result;
    }

    Matrix operator*(const Matrix& rhs) const {
        if (cols_ != rhs.rows_)
            throw std::invalid_argument("Incompatible matrix dimensions for multiplication");

        Matrix result(rows_, rhs.cols_);
        for (std::size_t i = 0; i < rows_; ++i)
            for (std::size_t k = 0; k < cols_; ++k)
                for (std::size_t j = 0; j < rhs.cols_; ++j)
                    result.at(i, j) += at(i, k) * rhs.at(k, j);
        return result;
    }

    double frobeniusNorm() const {
        double sum = 0.0;
        for (double val : data_)
            sum += val * val;
        return std::sqrt(sum);
    }

    void fill(double value) {
        std::fill(data_.begin(), data_.end(), value);
    }

private:
    std::size_t rows_;
    std::size_t cols_;
    std::vector<double> data_;

    void boundsCheck(std::size_t row, std::size_t col) const {
        if (row >= rows_ || col >= cols_)
            throw std::out_of_range("Matrix index out of range");
    }

    void checkCompatible(const Matrix& other) const {
        if (rows_ != other.rows_ || cols_ != other.cols_)
            throw std::invalid_argument("Matrix dimensions do not match");
    }
};
