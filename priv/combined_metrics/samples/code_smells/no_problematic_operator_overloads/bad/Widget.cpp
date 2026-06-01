#include <memory>
#include <string>
#include <vector>

class Widget {
public:
    Widget(int id, std::string label, bool visible)
        : id_(id), label_(std::move(label)), visible_(visible), valid_(true) {}

    // Overloading && — breaks short-circuit evaluation; both operands always evaluated
    bool operator&&(const Widget& rhs) const {
        return valid_ && rhs.valid_;
    }

    // Overloading || — same problem: no short-circuit, confusing semantics
    bool operator||(const Widget& rhs) const {
        return visible_ || rhs.visible_;
    }

    // Overloading comma operator — evaluated left-to-right but breaks comma in function
    // arguments and for-loop expressions in surprising ways
    Widget& operator,(const Widget& rhs) {
        (void)rhs;
        return *this;
    }

    // Overloading unary & — takes the address of Widget, not its actual address
    // Breaks generic code that uses &widget to get a pointer
    Widget* operator&() {
        return nullptr; // returns something other than the real address — very surprising
    }

    int id() const { return id_; }
    const std::string& label() const { return label_; }
    bool isVisible() const { return visible_; }

private:
    int id_;
    std::string label_;
    bool visible_;
    bool valid_;
};

void processWidget(Widget* ptr);

void demonstrate() {
    Widget a(1, "Alpha", true);
    Widget b(2, "Beta", false);

    // Looks like short-circuit but isn't — b.valid_ is ALWAYS evaluated
    if (a && b) { /* ... */ }

    // Comma operator overloaded — (a, b) returns a, not b as expected
    Widget& result = (a, b);

    // &a calls overloaded operator& — does NOT return the real address of a
    processWidget(&a); // silently passes nullptr
}
