<?php

declare(strict_types=1);

namespace App\Repository;

use App\Entity\User;
use PDO;

class UserRepository
{
    public function __construct(private PDO $connection)
    {
    }

    public function search(string $query, string $role, int $limit): array
    {
        // Parameterized query — no user input interpolated into SQL
        $stmt = $this->connection->prepare(
            'SELECT * FROM users
             WHERE (name LIKE :query OR email LIKE :query)
               AND role = :role
               AND deleted_at IS NULL
             ORDER BY created_at DESC
             LIMIT :limit'
        );

        $stmt->bindValue(':query', "%{$query}%", PDO::PARAM_STR);
        $stmt->bindValue(':role', $role, PDO::PARAM_STR);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();

        return array_map([$this, 'hydrate'], $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function findByIds(array $ids): array
    {
        if (empty($ids)) {
            return [];
        }

        // Safe handling of IN clause with bound parameters
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $stmt = $this->connection->prepare(
            "SELECT * FROM users WHERE id IN ({$placeholders}) AND deleted_at IS NULL"
        );
        $stmt->execute(array_values($ids));

        return array_map([$this, 'hydrate'], $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function updateLastLogin(int $userId, string $ip): void
    {
        $stmt = $this->connection->prepare(
            'UPDATE users SET last_login_at = NOW(), last_login_ip = :ip WHERE id = :id'
        );
        $stmt->execute(['ip' => $ip, 'id' => $userId]);
    }

    private function hydrate(array $row): User
    {
        return new User(
            id: (int) $row['id'],
            email: $row['email'],
            name: $row['name'],
            role: $row['role']
        );
    }
}
