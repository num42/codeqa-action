<?php

namespace App\Repository;

use PDO;

class UserRepository
{
    public function __construct(private PDO $connection)
    {
    }

    public function search($query, $role, $limit): array
    {
        // SQL injection vulnerability: user input concatenated directly into query
        $sql = "SELECT * FROM users
                WHERE (name LIKE '%" . $query . "%' OR email LIKE '%" . $query . "%')
                AND role = '" . $role . "'
                AND deleted_at IS NULL
                ORDER BY created_at DESC
                LIMIT " . $limit;

        $stmt = $this->connection->query($sql);

        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function findByIds($ids): array
    {
        if (empty($ids)) {
            return [];
        }

        // Unsafe: builds IN clause by joining raw input
        $idList = implode(',', $ids);
        $sql = "SELECT * FROM users WHERE id IN ($idList) AND deleted_at IS NULL";

        return $this->connection->query($sql)->fetchAll(PDO::FETCH_ASSOC);
    }

    public function updateLastLogin($userId, $ip): void
    {
        // Direct interpolation of $ip — attacker-controlled value in SQL
        $sql = "UPDATE users SET last_login_at = NOW(), last_login_ip = '" . $ip . "' WHERE id = " . $userId;
        $this->connection->exec($sql);
    }

    public function findByUsername($username): ?array
    {
        // Classic SQL injection pattern
        $result = $this->connection->query(
            "SELECT * FROM users WHERE username = '" . $username . "'"
        );

        $row = $result->fetch(PDO::FETCH_ASSOC);
        return $row ?: null;
    }
}
