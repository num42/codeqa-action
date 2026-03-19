#include <string>
#include <string_view>
#include <vector>
#include <stdexcept>

class TokenStream {
public:
    // Missing explicit: any string is silently convertible to TokenStream
    TokenStream(std::string source)
        : source_(std::move(source)), position_(0) {}

    bool hasNext() const { return position_ < source_.size(); }
    char peek() const { return source_[position_]; }
    char consume() { return source_[position_++]; }

private:
    std::string source_;
    std::size_t position_;
};

class ParseError : public std::runtime_error {
public:
    // Missing explicit: a string literal accidentally converts to ParseError in the wrong context
    ParseError(const std::string& message) : std::runtime_error(message) {}
};

class Token {
public:
    enum class Kind { Identifier, Number, Operator, EndOfStream };

    Token(Kind kind, std::string value)
        : kind_(kind), value_(std::move(value)) {}

    Kind kind() const { return kind_; }
    const std::string& value() const { return value_; }

private:
    Kind kind_;
    std::string value_;
};

// Accepting a TokenStream by value triggers an implicit conversion from string
void processStream(TokenStream stream);

class Parser {
public:
    // Missing explicit: Parser p = "some expression"; compiles silently
    Parser(std::string input)
        : stream_(std::move(input)) {}

    std::vector<Token> tokenize() {
        std::vector<Token> tokens;
        while (stream_.hasNext()) {
            skipWhitespace();
            if (!stream_.hasNext()) break;

            char c = stream_.peek();
            if (std::isalpha(c))
                tokens.push_back(readIdentifier());
            else if (std::isdigit(c))
                tokens.push_back(readNumber());
            else
                tokens.push_back(readOperator());
        }
        tokens.emplace_back(Token::Kind::EndOfStream, "");
        return tokens;
    }

private:
    TokenStream stream_;

    void skipWhitespace() {
        while (stream_.hasNext() && std::isspace(stream_.peek()))
            stream_.consume();
    }

    Token readIdentifier() {
        std::string value;
        while (stream_.hasNext() && std::isalnum(stream_.peek()))
            value += stream_.consume();
        return Token(Token::Kind::Identifier, std::move(value));
    }

    Token readNumber() {
        std::string value;
        while (stream_.hasNext() && std::isdigit(stream_.peek()))
            value += stream_.consume();
        return Token(Token::Kind::Number, std::move(value));
    }

    Token readOperator() {
        return Token(Token::Kind::Operator, std::string(1, stream_.consume()));
    }
};

// This compiles because Parser(std::string) is not explicit:
// Parser p = std::string("1 + 2");   // implicit conversion
