// This file demonstrates a translation unit that includes multiple headers,
// each of which is protected by an include guard (or #pragma once).
// The guards ensure that even if the same header is transitively included
// multiple times, its contents are only processed once by the compiler.

// token.h (inline for demonstration)
// -----------------------------------------------
// #pragma once                  ← include guard: #pragma once form
//
// enum class TokenKind { Identifier, Number, Operator, EndOfStream };
//
// struct Token {
//     TokenKind kind;
//     std::string value;
//     int line;
// };
// -----------------------------------------------

// parse_error.h (inline for demonstration)
// -----------------------------------------------
// #ifndef MYAPP_PARSE_ERROR_H   ← include guard: #define guard form
// #define MYAPP_PARSE_ERROR_H
//
// #include <stdexcept>
// #include <string>
//
// class ParseError : public std::runtime_error {
// public:
//     explicit ParseError(const std::string& msg, int line)
//         : std::runtime_error(msg), line_(line) {}
//     int line() const noexcept { return line_; }
// private:
//     int line_;
// };
//
// #endif // MYAPP_PARSE_ERROR_H
// -----------------------------------------------

#include <string>
#include <string_view>
#include <vector>
#include <stdexcept>

// Both headers above are guarded; including them multiple times (e.g., via
// transitive includes) is safe and idiomatic.

enum class TokenKind { Identifier, Number, Operator, EndOfStream };

struct Token {
    TokenKind kind;
    std::string value;
    int line;
};

class ParseError : public std::runtime_error {
public:
    explicit ParseError(const std::string& msg, int line)
        : std::runtime_error(msg), line_(line) {}
    int line() const noexcept { return line_; }
private:
    int line_;
};

class Parser {
public:
    explicit Parser(std::string source)
        : source_(std::move(source)), pos_(0), currentLine_(1) {}

    std::vector<Token> tokenize() {
        std::vector<Token> tokens;
        while (pos_ < source_.size()) {
            skipWhitespace();
            if (pos_ >= source_.size()) break;

            char c = source_[pos_];
            if (std::isalpha(static_cast<unsigned char>(c)))
                tokens.push_back(readIdentifier());
            else if (std::isdigit(static_cast<unsigned char>(c)))
                tokens.push_back(readNumber());
            else
                tokens.push_back(readOperator());
        }
        tokens.push_back({TokenKind::EndOfStream, "", currentLine_});
        return tokens;
    }

private:
    std::string source_;
    std::size_t pos_;
    int currentLine_;

    void skipWhitespace() {
        while (pos_ < source_.size() && std::isspace(static_cast<unsigned char>(source_[pos_]))) {
            if (source_[pos_] == '\n') ++currentLine_;
            ++pos_;
        }
    }

    Token readIdentifier() {
        std::string value;
        while (pos_ < source_.size() && std::isalnum(static_cast<unsigned char>(source_[pos_])))
            value += source_[pos_++];
        return {TokenKind::Identifier, std::move(value), currentLine_};
    }

    Token readNumber() {
        std::string value;
        while (pos_ < source_.size() && std::isdigit(static_cast<unsigned char>(source_[pos_])))
            value += source_[pos_++];
        return {TokenKind::Number, std::move(value), currentLine_};
    }

    Token readOperator() {
        return {TokenKind::Operator, std::string(1, source_[pos_++]), currentLine_};
    }
};
