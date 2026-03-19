package com.example.users;

import java.util.List;
import java.util.Objects;

public class UserRepository extends AbstractRepository<User> implements Auditable {

    private final DataSource dataSource;

    public UserRepository(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    public User findById(long id) {
        return dataSource.query(
            "SELECT * FROM users WHERE id = ?",
            ps -> ps.setLong(1, id),
            UserRepository::mapRow
        );
    }

    @Override
    public List<User> findAll() {
        return dataSource.queryList(
            "SELECT * FROM users ORDER BY created_at DESC",
            UserRepository::mapRow
        );
    }

    @Override
    public void save(User user) {
        if (user.getId() == null) {
            insert(user);
        } else {
            update(user);
        }
    }

    @Override
    public void delete(long id) {
        dataSource.execute("DELETE FROM users WHERE id = ?", ps -> ps.setLong(1, id));
    }

    @Override
    public String auditLabel() {
        return "users";
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof UserRepository)) return false;
        UserRepository that = (UserRepository) o;
        return Objects.equals(dataSource, that.dataSource);
    }

    @Override
    public int hashCode() {
        return Objects.hash(dataSource);
    }

    @Override
    public String toString() {
        return "UserRepository{dataSource=" + dataSource + "}";
    }

    private void insert(User user) {
        dataSource.execute(
            "INSERT INTO users (email, name, created_at) VALUES (?, ?, NOW())",
            ps -> {
                ps.setString(1, user.getEmail());
                ps.setString(2, user.getName());
            }
        );
    }

    private void update(User user) {
        dataSource.execute(
            "UPDATE users SET email = ?, name = ? WHERE id = ?",
            ps -> {
                ps.setString(1, user.getEmail());
                ps.setString(2, user.getName());
                ps.setLong(3, user.getId());
            }
        );
    }

    private static User mapRow(ResultSet rs) throws SQLException {
        return new User(rs.getLong("id"), rs.getString("email"), rs.getString("name"));
    }
}
