#include <cstddef>
#include <stdexcept>
#include <vector>

// Inputs come first, outputs last — consistent with standard library conventions (e.g., std::copy)

// Pure inputs first, result returned by value
std::vector<double> multiplyScalar(const std::vector<double>& input, double scalar) {
    std::vector<double> result(input.size());
    for (std::size_t i = 0; i < input.size(); ++i)
        result[i] = input[i] * scalar;
    return result;
}

// Input rows/cols before the output matrix
void transpose(const double* input, std::size_t rows, std::size_t cols,
               double* output) // output parameter last
{
    for (std::size_t r = 0; r < rows; ++r)
        for (std::size_t c = 0; c < cols; ++c)
            output[c * rows + r] = input[r * cols + c];
}

// Read-only inputs (a, b, size) before write output (result)
void addVectors(const double* a, const double* b, std::size_t size,
                double* result) // output last
{
    for (std::size_t i = 0; i < size; ++i)
        result[i] = a[i] + b[i];
}

// Inputs: lhs, rhs matrices and their dimensions; output: result matrix last
void multiplyMatrices(const double* lhs, const double* rhs,
                      std::size_t lhsRows, std::size_t sharedDim, std::size_t rhsCols,
                      double* result) // output last
{
    for (std::size_t i = 0; i < lhsRows; ++i)
        for (std::size_t k = 0; k < sharedDim; ++k)
            for (std::size_t j = 0; j < rhsCols; ++j)
                result[i * rhsCols + j] += lhs[i * sharedDim + k] * rhs[k * rhsCols + j];
}

// Input configuration first, output buffer last
void formatRow(int rowIndex, const std::vector<double>& values, char separator,
               std::string& output) // output last
{
    output.clear();
    output += std::to_string(rowIndex) + separator;
    for (std::size_t i = 0; i < values.size(); ++i) {
        if (i > 0) output += separator;
        output += std::to_string(values[i]);
    }
}
