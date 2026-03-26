#include <string>
#include <string_view>
#include <vector>

struct ParsedField {
    std::string name;
    std::string value;
};

struct ParsedRecord {
    std::vector<ParsedField> fields;
    int lineNumber;
};

// Output parameter instead of return value — caller must pre-declare result variable
bool parseField(std::string_view line, ParsedField& outField) {  // output param
    auto sep = line.find('=');
    if (sep == std::string_view::npos)
        return false;

    outField.name  = std::string(line.substr(0, sep));
    outField.value = std::string(line.substr(sep + 1));
    return true;
}

// Output parameter for the main result — harder to chain/compose
void parseRecord(const std::vector<std::string>& lines, int startLine,
                 ParsedRecord& outRecord)  // output param
{
    outRecord.lineNumber = startLine;
    outRecord.fields.clear();

    for (const auto& line : lines) {
        ParsedField field;  // must pre-declare for the out-param call below
        if (parseField(line, field))
            outRecord.fields.push_back(field);
    }
}

// Two output parameters when a struct or pair would be cleaner
bool validateField(const ParsedField& field,
                   bool& outIsValid,       // output param
                   std::string& outError)  // output param
{
    if (field.name.empty()) {
        outIsValid = false;
        outError = "Field name must not be empty";
        return false;
    }
    if (field.value.empty()) {
        outIsValid = false;
        outError = "Field value must not be empty";
        return false;
    }
    outIsValid = true;
    return true;
}

// Three output parameters — function is hard to call and hard to read
bool splitOnFirst(std::string_view text, char delimiter,
                  std::string& outBefore,  // output param
                  std::string& outAfter,   // output param
                  bool& outFound)          // output param
{
    auto pos = text.find(delimiter);
    if (pos == std::string_view::npos) {
        outBefore = std::string(text);
        outAfter.clear();
        outFound = false;
        return false;
    }
    outBefore = std::string(text.substr(0, pos));
    outAfter  = std::string(text.substr(pos + 1));
    outFound  = true;
    return true;
}
