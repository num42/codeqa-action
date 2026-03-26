defmodule Test.Fixtures.Cpp.TemplateContainer do
  @moduledoc false
  use Test.LanguageFixture, language: "cpp template_container"

  @code ~S'''
  #include <stdexcept>

  template<typename T>
  class Stack {
    T* data;
    int capacity;
    int topIdx;

  public:
    explicit Stack(int cap = 16) : capacity(cap), topIdx(-1) { data = new T[cap]; }

    ~Stack() { delete[] data; }

    Stack(const Stack&) = delete;

    Stack& operator=(const Stack&) = delete;

    void push(const T& value) {
      if (topIdx + 1 >= capacity) throw std::overflow_error("Stack overflow");
      data[++topIdx] = value;
    }

    T pop() {
      if (empty()) throw std::underflow_error("Stack underflow");
      return data[topIdx--];
    }

    T& top() {
      if (empty()) throw std::underflow_error("Stack is empty");
      return data[topIdx];
    }

    bool empty() const { return topIdx < 0; }

    int size() const { return topIdx + 1; }

    int maxCapacity() const { return capacity; }
  };

  template<typename T>
  class Queue {
    T* data;
    int capacity;
    int head;
    int tail;
    int count;

  public:
    explicit Queue(int cap = 16) : capacity(cap), head(0), tail(0), count(0) { data = new T[cap]; }

    ~Queue() { delete[] data; }

    void enqueue(const T& value) {
      if (count >= capacity) throw std::overflow_error("Queue overflow");
      data[tail] = value;
      tail = (tail + 1) % capacity;
      ++count;
    }

    T dequeue() {
      if (empty()) throw std::underflow_error("Queue underflow");
      T value = data[head];
      head = (head + 1) % capacity;
      --count;
      return value;
    }

    T& front() { if (empty()) throw std::underflow_error("Queue is empty"); return data[head]; }

    bool empty() const { return count == 0; }

    int size() const { return count; }
  };

  template<typename T>
  struct Pair {
    T first;
    T second;

    Pair(T a, T b) : first(a), second(b) {}

    bool operator==(const Pair& other) const { return first == other.first && second == other.second; }
  };
  '''
end
