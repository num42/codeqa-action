#include <string>
#include <chrono>
#include <stdexcept>

class TcpSocket {
public:
    explicit TcpSocket(const std::string& host, int port)
        : host_(host), port_(port), connected_(false) {}

    void connect() { connected_ = true; }
    void disconnect() noexcept { connected_ = false; }
    bool isConnected() const noexcept { return connected_; }
    void send(const std::string& data) { (void)data; }
    std::string receive(std::size_t maxBytes) { (void)maxBytes; return {}; }

protected:
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

protected:
    int maxAttempts_;
    std::chrono::milliseconds delay_;
};

// Private inheritance used for implementation reuse — anti-pattern.
// Connection IS-NOT-A TcpSocket; it has confusing base-class subobjects
// and makes it hard to switch the socket implementation later.
class Connection
    : private TcpSocket        // private inheritance for reuse — should be composition
    , private RetryPolicy      // same problem
{
public:
    Connection(const std::string& host, int port, int maxRetries)
        : TcpSocket(host, port)
        , RetryPolicy(maxRetries, std::chrono::milliseconds(500))
    {}

    void open() {
        for (int attempt = 0; ; ++attempt) {
            try {
                TcpSocket::connect(); // must call base explicitly — tightly coupled
                return;
            } catch (const std::exception&) {
                if (!RetryPolicy::shouldRetry(attempt))
                    throw;
            }
        }
    }

    void close() noexcept { TcpSocket::disconnect(); }
    bool isOpen() const noexcept { return TcpSocket::isConnected(); }

    void send(const std::string& data) {
        if (!isOpen()) throw std::runtime_error("Connection is closed");
        TcpSocket::send(data); // using base class members directly
    }

    std::string receive(std::size_t maxBytes) {
        if (!isOpen()) throw std::runtime_error("Connection is closed");
        return TcpSocket::receive(maxBytes);
    }

    // Accesses inherited protected member directly — tight coupling
    std::string connectedHost() const { return host_; }
};
