#include <string>
#include <string_view>
#include <vector>
#include <stdexcept>

class TokenStream {
public:
    explicit TokenStream(std::string source)  // explicit: prevents implicit string -> TokenStream
        : source_(std::move(source)), position_(0) {}

    bool hasNext() const noexcept { return position_ < source_.size(); }
    char peek() const { return source_[position_]; }
    char consume() { return source_[position_++]; }

private:
    std::string source_;
    std::size_t position_;
};

class ParseError : public std::runtime_error {
public:
    explicit ParseError(const std::string& message)  // explicit: single-arg exception ctor
        : std::runtime_error(message) {}

    explicit ParseError(std::string_view message)
        : std::runtime_error(std::string(message)) {}
};

class Token {
public:
    enum class Kind { Identifier, Number, Operator, EndOfStream };

    Token(Kind kind, std::string value)  // two-arg ctor: explicit not required but consistent
        : kind_(kind), value_(std::move(value)) {}

    Kind kind() const noexcept { return kind_; }
    const std::string& value() const noexcept { return value_; }

private:
    Kind kind_;
    std::string value_;
};

class Parser {
public:
    // explicit: prevents accidental conversion from string to Parser
    explicit Parser(std::string input)
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
