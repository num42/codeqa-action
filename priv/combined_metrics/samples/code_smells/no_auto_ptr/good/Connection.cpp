#include <memory>
#include <string>
#include <vector>
#include <stdexcept>

class Socket {
public:
    explicit Socket(const std::string& host, int port)
        : host_(host), port_(port), connected_(false) {}

    void connect() { connected_ = true; }
    void disconnect() noexcept { connected_ = false; }
    bool isConnected() const noexcept { return connected_; }
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
        : socket_(std::make_unique<Socket>(host, port)) // unique_ptr — clear ownership
    {
        socket_->connect();
    }

    ~Connection() {
        if (socket_ && socket_->isConnected())
            socket_->disconnect();
    }

    // Move is well-defined with unique_ptr
    Connection(Connection&&) noexcept = default;
    Connection& operator=(Connection&&) noexcept = default;

    Connection(const Connection&) = delete;
    Connection& operator=(const Connection&) = delete;

    bool isAlive() const noexcept {
        return socket_ && socket_->isConnected();
    }

    std::string endpoint() const {
        return socket_->host() + ":" + std::to_string(socket_->port());
    }

private:
    std::unique_ptr<Socket> socket_;
};

class ConnectionPool {
public:
    explicit ConnectionPool(const std::string& host, int port, std::size_t size) {
        connections_.reserve(size);
        for (std::size_t i = 0; i < size; ++i)
            connections_.push_back(std::make_unique<Connection>(host, port));
    }

    Connection* acquire() {
        for (auto& conn : connections_) {
            if (conn && conn->isAlive())
                return conn.get();
        }
        throw std::runtime_error("No available connections in pool");
    }

private:
    std::vector<std::unique_ptr<Connection>> connections_;
};
