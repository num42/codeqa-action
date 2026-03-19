defmodule Test.Fixtures.Cpp.ObserverPattern do
  @moduledoc false
  use Test.LanguageFixture, language: "cpp observer_pattern"

  @code ~S'''
  #include <vector>
  #include <functional>

  template<typename Event>
  class Observer {
  public:
    virtual void onEvent(const Event& event) = 0;

    virtual ~Observer() = default;
  };

  template<typename Event>
  class Subject {
    std::vector<Observer<Event>*> observers;

  public:
    void attach(Observer<Event>* observer) { observers.push_back(observer); }

    void detach(Observer<Event>* observer) {
      observers.erase(
        std::remove(observers.begin(), observers.end(), observer),
        observers.end()
      );
    }

    void notify(const Event& event) {
      for (auto* obs : observers) obs->onEvent(event);
    }
  };

  struct StockEvent {
    std::string symbol;
    double price;
    double previousPrice;

    double change() const { return price - previousPrice; }

    double changePercent() const { return previousPrice > 0 ? change() / previousPrice * 100.0 : 0.0; }
  };

  class StockTicker : public Subject<StockEvent> {
    std::map<std::string, double> prices;

  public:
    void updatePrice(const std::string& symbol, double newPrice) {
      double prev = prices.count(symbol) ? prices[symbol] : newPrice;
      prices[symbol] = newPrice;
      notify(StockEvent{symbol, newPrice, prev});
    }

    double getPrice(const std::string& symbol) const {
      auto it = prices.find(symbol);
      return it != prices.end() ? it->second : 0.0;
    }
  };

  class AlertObserver : public Observer<StockEvent> {
    double threshold;

  public:
    explicit AlertObserver(double threshold) : threshold(threshold) {}

    void onEvent(const StockEvent& event) override {}
  };
  '''
end
