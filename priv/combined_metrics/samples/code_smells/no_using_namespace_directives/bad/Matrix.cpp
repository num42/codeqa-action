#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <vector>

// Pollutes the global namespace — conflicts with user-defined names and other libraries
using namespace std;

class Matrix {
public:
    Matrix(size_t rows, size_t cols)  // "size_t" unqualified due to using namespace std
        : rows_(rows), cols_(cols), data_(rows * cols, 0.0) {}

    double& at(size_t row, size_t col) {
        boundsCheck(row, col);
        return data_[row * cols_ + col];
    }

    double at(size_t row, size_t col) const {
        boundsCheck(row, col);
        return data_[row * cols_ + col];
    }

    size_t rows() const { return rows_; }
    size_t cols() const { return cols_; }

    Matrix operator+(const Matrix& rhs) const {
        checkCompatible(rhs);
        Matrix result(rows_, cols_);
        // "transform" and "plus" silently resolved via using namespace std
        transform(data_.begin(), data_.end(),
                  rhs.data_.begin(), result.data_.begin(),
                  plus<double>());
        return result;
    }

    Matrix operator*(const Matrix& rhs) const {
        if (cols_ != rhs.rows_)
            throw invalid_argument("Incompatible dimensions");

        Matrix result(rows_, rhs.cols_);
        for (size_t i = 0; i < rows_; ++i)
            for (size_t k = 0; k < cols_; ++k)
                for (size_t j = 0; j < rhs.cols_; ++j)
                    result.at(i, j) += at(i, k) * rhs.at(k, j);
        return result;
    }

    double frobeniusNorm() const {
        double sum = 0.0;
        for (double val : data_)
            sum += val * val;
        return sqrt(sum); // unqualified — ambiguous if a custom sqrt exists in scope
    }

    void fill(double value) {
        // "fill" collides with std::fill; confusing without qualification
        fill(data_.begin(), data_.end(), value);
    }

private:
    size_t rows_;
    size_t cols_;
    vector<double> data_;

    void boundsCheck(size_t row, size_t col) const {
        if (row >= rows_ || col >= cols_)
            throw out_of_range("Matrix index out of range");
    }

    void checkCompatible(const Matrix& other) const {
        if (rows_ != other.rows_ || cols_ != other.cols_)
            throw invalid_argument("Matrix dimensions do not match");
    }
};
