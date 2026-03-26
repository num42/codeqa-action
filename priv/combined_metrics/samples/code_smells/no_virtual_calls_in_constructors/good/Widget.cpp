#include <string>
#include <vector>
#include <memory>

// Deferred initialization pattern: virtual methods are not called from constructors.
// Initialization that depends on virtual behavior uses a factory or a separate init step.

class Renderer {
public:
    virtual ~Renderer() = default;
    virtual void draw(const std::string& label) = 0;
};

class Widget {
public:
    explicit Widget(std::string label)
        : label_(std::move(label)), initialized_(false)
    {
        // Constructor only sets plain data — no virtual calls
    }

    virtual ~Widget() = default;

    // Separate initialization method that can safely call virtual members
    void initialize() {
        if (initialized_) return;
        setupLayout();   // virtual — called after construction, when vtable is correct
        loadResources(); // virtual — same
        initialized_ = true;
    }

    virtual void render(Renderer& renderer) const {
        renderer.draw(label_);
    }

    const std::string& label() const noexcept { return label_; }
    bool isInitialized() const noexcept { return initialized_; }

protected:
    virtual void setupLayout() {}
    virtual void loadResources() {}

    std::string label_;
    bool initialized_;
};

class Button : public Widget {
public:
    explicit Button(std::string label, std::string action)
        : Widget(std::move(label)), action_(std::move(action)) {}

    void render(Renderer& renderer) const override {
        renderer.draw("[" + label_ + "]");
    }

protected:
    void setupLayout() override {
        // Button-specific layout — runs after construction, vtable is fully set
        minWidth_ = static_cast<int>(label_.size()) + 4;
    }

    void loadResources() override {
        // Load button-specific resources
    }

private:
    std::string action_;
    int minWidth_ = 0;
};

// Factory ensures initialize() is called on the fully-constructed object
template<typename T, typename... Args>
std::unique_ptr<T> makeWidget(Args&&... args) {
    auto widget = std::make_unique<T>(std::forward<Args>(args)...);
    widget->initialize(); // safe: called after full construction
    return widget;
}
