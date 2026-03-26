#include <optional>
#include <string>
#include <string_view>
#include <tuple>
#include <vector>

struct ParsedField {
    std::string name;
    std::string value;
};

struct ParsedRecord {
    std::vector<ParsedField> fields;
    int lineNumber;
};

// Returns value directly — caller receives a clear, named result
std::optional<ParsedField> parseField(std::string_view line) {
    auto sep = line.find('=');
    if (sep == std::string_view::npos)
        return std::nullopt;

    return ParsedField{
        std::string(line.substr(0, sep)),
        std::string(line.substr(sep + 1))
    };
}

// Returns by value — no output parameters needed
ParsedRecord parseRecord(const std::vector<std::string>& lines, int startLine) {
    ParsedRecord record;
    record.lineNumber = startLine;

    for (const auto& line : lines) {
        auto field = parseField(line);
        if (field)
            record.fields.push_back(std::move(*field));
    }

    return record;
}

// Returns structured binding-friendly pair — no out-params
std::pair<bool, std::string> validateField(const ParsedField& field) {
    if (field.name.empty())
        return {false, "Field name must not be empty"};
    if (field.value.empty())
        return {false, "Field value must not be empty"};
    return {true, {}};
}

// Multiple values returned as a struct — readable and composable
struct SplitResult {
    std::string before;
    std::string after;
    bool found;
};

SplitResult splitOnFirst(std::string_view text, char delimiter) {
    auto pos = text.find(delimiter);
    if (pos == std::string_view::npos)
        return {std::string(text), {}, false};
    return {
        std::string(text.substr(0, pos)),
        std::string(text.substr(pos + 1)),
        true
    };
}
