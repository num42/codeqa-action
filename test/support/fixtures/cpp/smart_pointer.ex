defmodule Test.Fixtures.Cpp.SmartPointer do
  @moduledoc false
  use Test.LanguageFixture, language: "cpp smart_pointer"

  @code ~S'''
  #include <memory>
  #include <functional>

  template<typename T>
  class UniquePtr {
    T* ptr;
    std::function<void(T*)> deleter;

  public:
    explicit UniquePtr(T* p = nullptr, std::function<void(T*)> d = std::default_delete<T>())
      : ptr(p), deleter(d) {}

    ~UniquePtr() { if (ptr) deleter(ptr); }

    UniquePtr(const UniquePtr&) = delete;

    UniquePtr& operator=(const UniquePtr&) = delete;

    UniquePtr(UniquePtr&& other) noexcept : ptr(other.ptr), deleter(std::move(other.deleter)) { other.ptr = nullptr; }

    UniquePtr& operator=(UniquePtr&& other) noexcept {
      if (this != &other) { if (ptr) deleter(ptr); ptr = other.ptr; other.ptr = nullptr; }
      return *this;
    }

    T* get() const { return ptr; }

    T& operator*() const { return *ptr; }

    T* operator->() const { return ptr; }

    explicit operator bool() const { return ptr != nullptr; }

    T* release() { T* p = ptr; ptr = nullptr; return p; }

    void reset(T* p = nullptr) { if (ptr) deleter(ptr); ptr = p; }
  };

  template<typename T>
  struct SharedControl {
    T* ptr;
    int refCount;

    SharedControl(T* p) : ptr(p), refCount(1) {}

    ~SharedControl() { delete ptr; }
  };

  template<typename T>
  class SharedPtr {
    SharedControl<T>* ctrl;

  public:
    explicit SharedPtr(T* p = nullptr) : ctrl(p ? new SharedControl<T>(p) : nullptr) {}

    SharedPtr(const SharedPtr& other) : ctrl(other.ctrl) { if (ctrl) ++ctrl->refCount; }

    SharedPtr& operator=(const SharedPtr& other) {
      if (this != &other) { release(); ctrl = other.ctrl; if (ctrl) ++ctrl->refCount; }
      return *this;
    }

    ~SharedPtr() { release(); }

    T* get() const { return ctrl ? ctrl->ptr : nullptr; }

    T& operator*() const { return *ctrl->ptr; }

    T* operator->() const { return ctrl->ptr; }

    int useCount() const { return ctrl ? ctrl->refCount : 0; }

  private:
    void release() { if (ctrl && --ctrl->refCount == 0) { delete ctrl; ctrl = nullptr; } }
  };

  template<typename T, typename... Args>
  UniquePtr<T> makeUnique(Args&&... args) {
    return UniquePtr<T>(new T(std::forward<Args>(args)...));
  }
  '''
end
