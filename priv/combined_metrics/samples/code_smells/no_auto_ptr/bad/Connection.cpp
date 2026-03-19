#include <memory>
#include <string>
#include <vector>
#include <stdexcept>

class Socket {
public:
    explicit Socket(const std::string& host, int port)
        : host_(host), port_(port), connected_(false) {}

    void connect() { connected_ = true; }
    void disconnect() { connected_ = false; }
    bool isConnected() const { return connected_; }
    std::string host() const { return host_; }
    int port() const { return port_; }

private:
    std::string host_;
    int port_;
    bool connected_;
};

class Connection {
public:
    explicit Connection(const std::string& host, int port)
        : socket_(new Socket(host, port)) // std::auto_ptr — deprecated and removed in C++17
    {
        socket_->connect();
    }

    ~Connection() {
        if (socket_.get() && socket_->isConnected())
            socket_->disconnect();
        // auto_ptr deletes automatically, but transfer semantics are broken
    }

    // auto_ptr copy "moves" ownership silently — source becomes null after copy
    // This causes bugs when connection is put into a container or passed by value
    Connection(const Connection& other) : socket_(other.socket_) {} // silently steals!

    bool isAlive() const {
        return socket_.get() && socket_->isConnected();
    }

    std::string endpoint() const {
        return socket_->host() + ":" + std::to_string(socket_->port());
    }

private:
    std::auto_ptr<Socket> socket_; // std::auto_ptr: deprecated since C++11, removed in C++17
};

class ConnectionPool {
public:
    explicit ConnectionPool(const std::string& host, int port, std::size_t poolSize) {
        for (std::size_t i = 0; i < poolSize; ++i) {
            // Storing auto_ptr in a vector is undefined behavior —
            // std::vector requires copyable elements; auto_ptr's copy transfers ownership
            connections_.push_back(std::auto_ptr<Connection>(new Connection(host, port)));
        }
    }

    Connection* acquire() {
        for (auto& conn : connections_) {
            if (conn.get() && conn->isAlive())
                return conn.get();
        }
        throw std::runtime_error("No available connections");
    }

private:
    std::vector<std::auto_ptr<Connection>> connections_; // undefined behavior
};
