#include <string>
#include <vector>
#include <memory>

class Renderer {
public:
    virtual ~Renderer() = default;
    virtual void draw(const std::string& label) = 0;
};

class Widget {
public:
    explicit Widget(std::string label)
        : label_(std::move(label))
    {
        // Calls virtual methods in the constructor — at this point the vtable
        // points to Widget's implementations, not the derived class overrides.
        // This is almost certainly a bug when derived classes override these.
        setupLayout();    // virtual call in ctor — dispatches to Widget::setupLayout
        loadResources();  // virtual call in ctor — dispatches to Widget::loadResources
    }

    virtual ~Widget() = default;

    virtual void render(Renderer& renderer) const {
        renderer.draw(label_);
    }

protected:
    virtual void setupLayout() {
        // Base implementation — called even when derived class overrides it
        minWidth_ = static_cast<int>(label_.size());
    }

    virtual void loadResources() {
        // Base implementation — derived class version is never called from ctor
    }

    std::string label_;
    int minWidth_ = 0;
};

class Button : public Widget {
public:
    explicit Button(std::string label, std::string action)
        : Widget(std::move(label))  // Widget ctor calls setupLayout/loadResources...
        , action_(std::move(action))
    {
        // ...but Button::setupLayout and Button::loadResources were NOT called above.
        // The Button is not properly initialized after construction.
    }

    void render(Renderer& renderer) const override {
        renderer.draw("[" + label_ + "]");
    }

protected:
    void setupLayout() override {
        // This override is NEVER called from Widget's constructor
        minWidth_ = static_cast<int>(label_.size()) + 4; // button-specific padding
        paddingSet_ = true;
    }

    void loadResources() override {
        resourcesLoaded_ = true;
    }

private:
    std::string action_;
    bool paddingSet_ = false;     // always false after construction
    bool resourcesLoaded_ = false; // always false after construction
};
