#include <cstring>
#include <stdexcept>

// Copyability is NOT explicitly declared — relies on compiler-generated defaults.
// The compiler-generated copy performs a shallow copy of the raw pointer,
// resulting in double-free and use-after-free bugs.

class Matrix {
public:
    Matrix(std::size_t rows, std::size_t cols)
        : rows_(rows), cols_(cols)
        , data_(new double[rows * cols])
    {
        for (std::size_t i = 0; i < rows * cols; ++i)
            data_[i] = 0.0;
    }

    // Destructor defined — but copy/move not declared.
    // This violates the Rule of Three/Five: compiler-generated copy will shallow-copy data_.
    ~Matrix() {
        delete[] data_;
    }

    // No copy constructor declared:
    // Matrix a(3, 3);
    // Matrix b = a;  // compiler copies data_ pointer — both a and b point to same memory
    //                // ~Matrix() called twice on same pointer → double-free (UB)

    // No copy assignment declared:
    // Matrix a(3, 3), b(2, 2);
    // b = a;  // shallow copy of data_ → memory leak of b's old data_, double-free on destruction

    // No move constructor declared:
    // std::vector<Matrix> v;
    // v.push_back(Matrix(4, 4));  // may copy (shallow) instead of move → double-free

    // No move assignment declared

    double& at(std::size_t r, std::size_t c) {
        return data_[r * cols_ + c];
    }

    double at(std::size_t r, std::size_t c) const {
        return data_[r * cols_ + c];
    }

    std::size_t rows() const { return rows_; }
    std::size_t cols() const { return cols_; }

private:
    std::size_t rows_;
    std::size_t cols_;
    double* data_; // raw owning pointer — copy semantics are wrong without explicit Rule of Five
};

void demonstrateBug() {
    Matrix a(3, 3);
    a.at(0, 0) = 42.0;

    Matrix b = a;          // shallow copy: b.data_ == a.data_
    b.at(0, 0) = 99.0;    // modifies a.data_ too — unintentional aliasing

    // When a and b go out of scope, delete[] is called twice on the same pointer — UB
}
