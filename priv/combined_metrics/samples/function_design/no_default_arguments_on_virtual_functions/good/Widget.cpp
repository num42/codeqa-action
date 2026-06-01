#include <string>
#include <memory>

// Virtual functions have no default arguments.
// Overloads are used instead to provide convenience defaults.

class Widget {
public:
    virtual ~Widget() = default;

    // Non-default overload delegates to the virtual one — no default on virtual
    void render() { render(RenderOptions::defaults()); }

    // Virtual function takes all arguments explicitly — no defaults
    virtual void render(const RenderOptions& options) = 0;

    // Non-virtual overload provides the "quick" convenience form
    void resize(int width) { resize(width, width); } // square resize shortcut
    virtual void resize(int width, int height) = 0;

    // Non-virtual overload with default color
    void highlight() { highlight(Color::yellow()); }
    virtual void highlight(const Color& color) = 0;

    virtual std::string describe() const = 0;
};

class Button : public Widget {
public:
    explicit Button(std::string label) : label_(std::move(label)) {}

    // Override takes all parameters — consistent with the virtual signature
    void render(const RenderOptions& options) override {
        (void)options;
        // Renders button using provided options
    }

    void resize(int width, int height) override {
        width_ = width;
        height_ = height;
    }

    void highlight(const Color& color) override {
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
