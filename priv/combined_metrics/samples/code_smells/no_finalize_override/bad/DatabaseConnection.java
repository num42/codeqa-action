package com.example.db;

import java.sql.Connection;
import java.sql.SQLException;
import java.util.logging.Level;
import java.util.logging.Logger;

public class DatabaseConnection {

    private static final Logger logger = Logger.getLogger(DatabaseConnection.class.getName());

    private final Connection connection;
    private boolean closed = false;

    public DatabaseConnection(Connection connection) {
        this.connection = connection;
    }

    public QueryResult execute(String sql, Object... params) throws SQLException {
        try (var stmt = connection.prepareStatement(sql)) {
            for (int i = 0; i < params.length; i++) {
                stmt.setObject(i + 1, params[i]);
            }
            return QueryResult.from(stmt.executeQuery());
        }
    }

    public void beginTransaction() throws SQLException {
        connection.setAutoCommit(false);
    }

    public void commit() throws SQLException {
        connection.commit();
    }

    public void rollback() throws SQLException {
        connection.rollback();
    }

    public void close() throws SQLException {
        if (!closed) {
            closed = true;
            connection.close();
        }
    }

    /**
     * Overrides Object.finalize() to close the connection when garbage collected.
     * This is unreliable — finalize() may never run, or run too late, leaving
     * database connections open indefinitely.
     */
    @Override
    protected void finalize() throws Throwable {
        try {
            if (!closed) {
                logger.log(Level.WARNING, "DatabaseConnection was not closed explicitly — closing in finalizer");
                connection.close();
            }
        } finally {
            super.finalize();
        }
    }

    public boolean isClosed() {
        return closed;
    }
}
