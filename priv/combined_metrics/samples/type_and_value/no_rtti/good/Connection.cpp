#include <memory>
#include <string>
#include <vector>

// Polymorphism via virtual methods — no dynamic_cast or typeid needed

class Connection {
public:
    virtual ~Connection() = default;

    virtual void send(const std::string& data) = 0;
    virtual std::string receive(std::size_t maxBytes) = 0;
    virtual bool isAlive() const noexcept = 0;
    virtual std::string description() const = 0;

    // Type-specific behavior exposed through the interface — no casting required
    virtual void flush() {}
    virtual bool supportsTls() const noexcept = 0;
};

class TcpConnection : public Connection {
public:
    explicit TcpConnection(std::string host, int port)
        : host_(std::move(host)), port_(port), alive_(true) {}

    void send(const std::string& data) override { (void)data; }
    std::string receive(std::size_t maxBytes) override { (void)maxBytes; return {}; }
    bool isAlive() const noexcept override { return alive_; }
    bool supportsTls() const noexcept override { return false; }
    std::string description() const override {
        return "TCP:" + host_ + ":" + std::to_string(port_);
    }

private:
    std::string host_;
    int port_;
    bool alive_;
};

class TlsConnection : public Connection {
public:
    explicit TlsConnection(std::string host, int port)
        : host_(std::move(host)), port_(port), alive_(true) {}

    void send(const std::string& data) override { (void)data; }
    std::string receive(std::size_t maxBytes) override { (void)maxBytes; return {}; }
    bool isAlive() const noexcept override { return alive_; }
    bool supportsTls() const noexcept override { return true; }
    void flush() override { /* flush TLS buffer */ }
    std::string description() const override {
        return "TLS:" + host_ + ":" + std::to_string(port_);
    }

private:
    std::string host_;
    int port_;
    bool alive_;
};

// Works with any Connection subtype via the interface — no RTTI needed
void broadcastMessage(const std::vector<std::unique_ptr<Connection>>& connections,
                      const std::string& message)
{
    for (const auto& conn : connections) {
        if (!conn->isAlive()) continue;
        conn->send(message);
        conn->flush(); // virtual dispatch — no type check needed
    }
}
