#include <memory>
#include <string>
#include <typeinfo>
#include <vector>

class Connection {
public:
    virtual ~Connection() = default;
    virtual void send(const std::string& data) = 0;
    virtual std::string receive(std::size_t maxBytes) = 0;
    virtual bool isAlive() const noexcept = 0;
};

class TcpConnection : public Connection {
public:
    explicit TcpConnection(std::string host, int port)
        : host_(std::move(host)), port_(port), alive_(true) {}

    void send(const std::string& data) override { (void)data; }
    std::string receive(std::size_t maxBytes) override { (void)maxBytes; return {}; }
    bool isAlive() const noexcept override { return alive_; }

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
    void flush() { /* flush TLS buffer */ }

private:
    std::string host_;
    int port_;
    bool alive_;
};

// Uses dynamic_cast to discover the runtime type — brittle, must be updated
// every time a new Connection subtype is added
void broadcastMessage(const std::vector<std::unique_ptr<Connection>>& connections,
                      const std::string& message)
{
    for (const auto& conn : connections) {
        if (!conn->isAlive()) continue;
        conn->send(message);

        // dynamic_cast to access TLS-specific behavior — should be a virtual method
        if (auto* tls = dynamic_cast<TlsConnection*>(conn.get())) {
            tls->flush(); // RTTI cast to reach subtype-specific functionality
        }
    }
}

std::string describeConnection(const Connection& conn) {
    // typeid used to branch on type — fragile, does not work with type hierarchies
    if (typeid(conn) == typeid(TcpConnection))
        return "plain TCP connection";
    else if (typeid(conn) == typeid(TlsConnection))
        return "TLS connection";
    else
        return "unknown connection type";
}
