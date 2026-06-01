#include <string>
#include <memory>

// Virtual functions with default argument values — the default is resolved statically
// at the call site based on the static type, NOT the dynamic type.
// This means the base class defaults are used even when a derived class override is called.

class Widget {
public:
    virtual ~Widget() = default;

    // Default argument on virtual function — resolved at compile time using static type
    virtual void render(const RenderOptions& options = RenderOptions::defaults()) = 0;

    // Default on virtual — if Button overrides this with a different default, the
    // base default is used when called via a Widget pointer or reference
    virtual void resize(int width, int height = 100) = 0;

    virtual void highlight(const Color& color = Color::yellow()) = 0;

    virtual std::string describe() const = 0;
};

class Button : public Widget {
public:
    explicit Button(std::string label) : label_(std::move(label)) {}

    // Override with a DIFFERENT default — this default is NEVER used when called
    // through a Widget pointer/reference; the base class default applies instead
    void render(const RenderOptions& options = RenderOptions::minimal()) override {
        (void)options;
    }

    void resize(int width, int height = 50) override { // different default — silently ignored via base ptr
        width_ = width;
        height_ = height;
    }

    void highlight(const Color& color = Color::blue()) override { // different default — same problem
        highlightColor_ = color;
    }

    std::string describe() const override {
        return "Button(" + label_ + ")";
    }

private:
    std::string label_;
    int width_ = 0;
    int height_ = 0;
    Color highlightColor_;
};

void demonstrate() {
    std::unique_ptr<Widget> w = std::make_unique<Button>("OK");

    // Calls Button::render, but uses Widget's default for options (RenderOptions::defaults()),
    // NOT Button's default (RenderOptions::minimal()) — confusing and bug-prone
    w->render();

    // Same issue: uses height=100 (Widget's default), not height=50 (Button's default)
    w->resize(200);
}
