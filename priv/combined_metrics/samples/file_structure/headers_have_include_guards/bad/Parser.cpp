// This file demonstrates a translation unit that includes headers WITHOUT
// include guards. If these headers are included more than once — directly
// or transitively — the compiler sees duplicate declarations and definitions,
// causing errors or subtle ODR (One Definition Rule) violations.

// token.h (inline for demonstration — NO include guard)
// -----------------------------------------------
// // No #pragma once and no #ifndef guard
//
// enum class TokenKind { Identifier, Number, Operator, EndOfStream };
//
// struct Token {
//     TokenKind kind;
//     std::string value;
//     int line;
// };
// -----------------------------------------------

// parse_error.h (inline for demonstration — NO include guard)
// -----------------------------------------------
// // No #pragma once and no #ifndef guard
//
// #include <stdexcept>
// #include <string>
//
// // If parse_error.h is included by both Parser.cpp and another header that
// // Parser.cpp also includes, ParseError is defined twice → compile error.
// class ParseError : public std::runtime_error {
// public:
//     explicit ParseError(const std::string& msg, int line)
//         : std::runtime_error(msg), line_(line) {}
//     int line() const noexcept { return line_; }
// private:
//     int line_;
// };
// -----------------------------------------------

#include <string>
#include <vector>
#include <stdexcept>

// Simulated second include of the same unguarded header content:
// In a real project this happens via transitive includes.
// Without guards, the declarations below would appear twice — compile error.

enum class TokenKind { Identifier, Number, Operator, EndOfStream };

struct Token {         // first definition
    TokenKind kind;
    std::string value;
    int line;
};

// struct Token {      ← if the header were included again, this would be a redefinition
//     TokenKind kind;
//     std::string value;
//     int line;
// };

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
