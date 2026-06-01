#include <cstddef>
#include <stdexcept>
#include <vector>
#include <string>

// Output parameters appear before inputs — confusing parameter order

// Output result comes first — counterintuitive
void multiplyScalar(std::vector<double>& result,     // output first — confusing
                    const std::vector<double>& input, // input second
                    double scalar)
{
    result.resize(input.size());
    for (std::size_t i = 0; i < input.size(); ++i)
        result[i] = input[i] * scalar;
}

// Output before input dimensions — reader must study the body to understand the order
void transpose(double* output,           // output first
               const double* input,      // input second
               std::size_t rows, std::size_t cols)
{
    for (std::size_t r = 0; r < rows; ++r)
        for (std::size_t c = 0; c < cols; ++c)
            output[c * rows + r] = input[r * cols + c];
}

// Output interleaved with inputs — no clear convention
void addVectors(double* result,          // output first
                const double* a,         // input
                std::size_t size,        // input dimension
                const double* b)         // second input — split from first by size
{
    for (std::size_t i = 0; i < size; ++i)
        result[i] = a[i] + b[i];
}

// Output buried in the middle of the parameter list
void multiplyMatrices(const double* lhs,
                      std::size_t lhsRows,
                      double* result,         // output in the middle
                      const double* rhs,
                      std::size_t sharedDim,
                      std::size_t rhsCols)
{
    for (std::size_t i = 0; i < lhsRows; ++i)
        for (std::size_t k = 0; k < sharedDim; ++k)
            for (std::size_t j = 0; j < rhsCols; ++j)
                result[i * rhsCols + j] += lhs[i * sharedDim + k] * rhs[k * rhsCols + j];
}

// Output first, then all inputs
void formatRow(std::string& output,           // output first
               int rowIndex,
               const std::vector<double>& values,
               char separator)
{
    output.clear();
    output += std::to_string(rowIndex) + separator;
    for (std::size_t i = 0; i < values.size(); ++i) {
        if (i > 0) output += separator;
        output += std::to_string(values[i]);
    }
}
