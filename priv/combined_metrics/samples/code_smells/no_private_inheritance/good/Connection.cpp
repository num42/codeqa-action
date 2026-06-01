#include <memory>
#include <string>
#include <chrono>
#include <stdexcept>

// Reuse via composition, not private inheritance

class TcpSocket {
public:
    explicit TcpSocket(const std::string& host, int port)
        : host_(host), port_(port), connected_(false) {}

    void connect() { connected_ = true; }
    void disconnect() noexcept { connected_ = false; }
    bool isConnected() const noexcept { return connected_; }
    void send(const std::string& data) { (void)data; }
    std::string receive(std::size_t maxBytes) { (void)maxBytes; return {}; }

private:
    std::string host_;
    int port_;
    bool connected_;
};

class RetryPolicy {
public:
    explicit RetryPolicy(int maxAttempts, std::chrono::milliseconds delay)
        : maxAttempts_(maxAttempts), delay_(delay) {}

    bool shouldRetry(int attempt) const noexcept { return attempt < maxAttempts_; }
    std::chrono::milliseconds delay() const noexcept { return delay_; }

private:
    int maxAttempts_;
    std::chrono::milliseconds delay_;
};

// Composition: Connection HAS-A TcpSocket and HAS-A RetryPolicy
// Not IS-A; private inheritance would expose implementation details
class Connection {
public:
    Connection(const std::string& host, int port, int maxRetries)
        : socket_(std::make_unique<TcpSocket>(host, port))
        , retryPolicy_(maxRetries, std::chrono::milliseconds(500))
    {}

    void open() {
        for (int attempt = 0; ; ++attempt) {
            try {
                socket_->connect();
                return;
            } catch (const std::exception&) {
                if (!retryPolicy_.shouldRetry(attempt))
                    throw;
            }
        }
    }

    void close() noexcept { socket_->disconnect(); }
    bool isOpen() const noexcept { return socket_->isConnected(); }

    void send(const std::string& data) {
        if (!isOpen()) throw std::runtime_error("Connection is closed");
        socket_->send(data);
    }

    std::string receive(std::size_t maxBytes) {
        if (!isOpen()) throw std::runtime_error("Connection is closed");
        return socket_->receive(maxBytes);
    }

private:
    std::unique_ptr<TcpSocket> socket_;   // composed, not inherited
    RetryPolicy retryPolicy_;              // composed, not inherited
};
