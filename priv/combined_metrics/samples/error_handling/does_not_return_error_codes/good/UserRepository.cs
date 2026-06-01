using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace UserService
{
    public class UserRepository
    {
        private readonly string _connectionString;

        public UserRepository(string connectionString)
        {
            _connectionString = connectionString;
        }

        public User GetById(int userId)
        {
            using var connection = new SqlConnection(_connectionString);
            connection.Open();
            var command = new SqlCommand("SELECT * FROM Users WHERE Id = @id", connection);
            command.Parameters.AddWithValue("@id", userId);

            using var reader = command.ExecuteReader();
            if (!reader.Read())
                throw new UserNotFoundException($"User with ID {userId} does not exist.");

            return MapUser(reader);
        }

        public void Create(User user)
        {
            if (user == null) throw new ArgumentNullException(nameof(user));
            if (string.IsNullOrWhiteSpace(user.Email))
                throw new ArgumentException("Email is required.", nameof(user));

            using var connection = new SqlConnection(_connectionString);
            connection.Open();

            if (EmailExists(connection, user.Email))
                throw new DuplicateEmailException($"Email '{user.Email}' is already registered.");

            var command = new SqlCommand(
                "INSERT INTO Users (Email, Name) VALUES (@email, @name)", connection);
            command.Parameters.AddWithValue("@email", user.Email);
            command.Parameters.AddWithValue("@name", user.Name);
            command.ExecuteNonQuery();
        }

        public IReadOnlyList<User> GetByRole(string role)
        {
            if (string.IsNullOrWhiteSpace(role))
                throw new ArgumentException("Role must not be empty.", nameof(role));

            using var connection = new SqlConnection(_connectionString);
            connection.Open();
            var command = new SqlCommand("SELECT * FROM Users WHERE Role = @role", connection);
            command.Parameters.AddWithValue("@role", role);

            var users = new List<User>();
            using var reader = command.ExecuteReader();
            while (reader.Read())
                users.Add(MapUser(reader));

            return users.AsReadOnly();
        }

        private bool EmailExists(SqlConnection connection, string email)
        {
            var command = new SqlCommand(
                "SELECT COUNT(1) FROM Users WHERE Email = @email", connection);
            command.Parameters.AddWithValue("@email", email);
            return (int)command.ExecuteScalar() > 0;
        }

        private User MapUser(SqlDataReader reader) =>
            new User(reader.GetInt32(0), reader.GetString(1), reader.GetString(2));
    }
}
