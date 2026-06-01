package com.example.db;

import java.io.Closeable;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Wraps a JDBC connection. Use try-with-resources to ensure the connection
 * is closed promptly; do not rely on garbage collection for cleanup.
 */
public class DatabaseConnection implements Closeable {

    private static final Logger logger = Logger.getLogger(DatabaseConnection.class.getName());

    private final Connection connection;
    private boolean closed = false;

    public DatabaseConnection(Connection connection) {
        this.connection = connection;
    }

    public QueryResult execute(String sql, Object... params) throws SQLException {
        ensureOpen();
        try (var stmt = connection.prepareStatement(sql)) {
            for (int i = 0; i < params.length; i++) {
                stmt.setObject(i + 1, params[i]);
            }
            return QueryResult.from(stmt.executeQuery());
        }
    }

    public void beginTransaction() throws SQLException {
        ensureOpen();
        connection.setAutoCommit(false);
    }

    public void commit() throws SQLException {
        ensureOpen();
        connection.commit();
    }

    public void rollback() throws SQLException {
        ensureOpen();
        try {
            connection.rollback();
        } catch (SQLException e) {
            logger.log(Level.WARNING, "Rollback failed", e);
            throw e;
        }
    }

    @Override
    public void close() {
        if (!closed) {
            closed = true;
            try {
                connection.close();
            } catch (SQLException e) {
                // Log but do not propagate — close() must not throw checked exceptions.
                // The connection resource is released regardless.
                logger.log(Level.WARNING, "Error closing database connection", e);
            }
        }
    }

    public boolean isClosed() {
        return closed;
    }

    private void ensureOpen() {
        if (closed) {
            throw new IllegalStateException("DatabaseConnection has already been closed");
        }
    }
}
