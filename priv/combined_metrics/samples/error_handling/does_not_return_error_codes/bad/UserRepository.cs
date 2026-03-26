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

        // Returns -1 on failure instead of throwing
        public int GetById(int userId, out User user)
        {
            user = null;
            try
            {
                using var connection = new SqlConnection(_connectionString);
                connection.Open();
                var command = new SqlCommand("SELECT * FROM Users WHERE Id = @id", connection);
                command.Parameters.AddWithValue("@id", userId);

                using var reader = command.ExecuteReader();
                if (!reader.Read())
                    return -1; // not found

                user = MapUser(reader);
                return 0; // success
            }
            catch (SqlException)
            {
                return -2; // database error
            }
        }

        // Returns false on failure — caller can't distinguish why it failed
        public bool Create(User user)
        {
            if (user == null) return false;
            if (string.IsNullOrWhiteSpace(user.Email)) return false;

            try
            {
                using var connection = new SqlConnection(_connectionString);
                connection.Open();

                var checkCmd = new SqlCommand(
                    "SELECT COUNT(1) FROM Users WHERE Email = @email", connection);
                checkCmd.Parameters.AddWithValue("@email", user.Email);
                if ((int)checkCmd.ExecuteScalar() > 0)
                    return false; // duplicate email, but caller doesn't know that

                var command = new SqlCommand(
                    "INSERT INTO Users (Email, Name) VALUES (@email, @name)", connection);
                command.Parameters.AddWithValue("@email", user.Email);
                command.Parameters.AddWithValue("@name", user.Name);
                command.ExecuteNonQuery();
                return true;
            }
            catch (SqlException)
            {
                return false;
            }
        }

        // Returns null to signal "no users" or "error" — ambiguous
        public List<User> GetByRole(string role)
        {
            if (string.IsNullOrWhiteSpace(role)) return null;

            try
            {
                using var connection = new SqlConnection(_connectionString);
                connection.Open();
                var command = new SqlCommand("SELECT * FROM Users WHERE Role = @role", connection);
                command.Parameters.AddWithValue("@role", role);

                var users = new List<User>();
                using var reader = command.ExecuteReader();
                while (reader.Read())
                    users.Add(MapUser(reader));

                return users;
            }
            catch (SqlException)
            {
                return null; // error or empty — caller cannot tell the difference
            }
        }

        private User MapUser(SqlDataReader reader) =>
            new User(reader.GetInt32(0), reader.GetString(1), reader.GetString(2));
    }
}
