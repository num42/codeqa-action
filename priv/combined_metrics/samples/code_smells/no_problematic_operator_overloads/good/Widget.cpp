#include <memory>
#include <string>
#include <vector>

// Overloads only operators with predictable, well-defined semantics.
// Does NOT overload &&, ||, comma, or unary &.

class WidgetId {
public:
    explicit WidgetId(int value) : value_(value) {}

    bool operator==(const WidgetId& rhs) const noexcept { return value_ == rhs.value_; }
    bool operator!=(const WidgetId& rhs) const noexcept { return !(*this == rhs); }
    bool operator<(const WidgetId& rhs) const noexcept { return value_ < rhs.value_; }

    int value() const noexcept { return value_; }

private:
    int value_;
};

class Widget {
public:
    Widget(WidgetId id, std::string label, int priority)
        : id_(id), label_(std::move(label)), priority_(priority) {}

    // Comparison by priority — clear semantic
    bool operator<(const Widget& rhs) const noexcept { return priority_ < rhs.priority_; }
    bool operator==(const Widget& rhs) const noexcept { return id_ == rhs.id_; }

    // Arithmetic with clear meaning: combine widget priority scores
    Widget operator+(int extraPriority) const {
        return Widget(id_, label_, priority_ + extraPriority);
    }

    WidgetId id() const noexcept { return id_; }
    const std::string& label() const noexcept { return label_; }
    int priority() const noexcept { return priority_; }

    // Logical conditions are free functions using && and || naturally —
    // no overloaded && or || to break short-circuit evaluation
    static bool isHighPriority(const Widget& w) { return w.priority_ > 100; }
    static bool isVisible(const Widget& w) { return !w.label_.empty(); }

private:
    WidgetId id_;
    std::string label_;
    int priority_;
};

class WidgetCollection {
public:
    void add(Widget w) { items_.push_back(std::move(w)); }

    // operator[] with clear semantics
    Widget& operator[](std::size_t index) { return items_[index]; }
    const Widget& operator[](std::size_t index) const { return items_[index]; }

    std::size_t size() const noexcept { return items_.size(); }
    bool empty() const noexcept { return items_.empty(); }

    // Natural use of && and || without overloading:
    bool hasHighPriorityVisible() const {
        for (const auto& w : items_)
            if (Widget::isHighPriority(w) && Widget::isVisible(w))
                return true;
        return false;
    }

private:
    std::vector<Widget> items_;
};
