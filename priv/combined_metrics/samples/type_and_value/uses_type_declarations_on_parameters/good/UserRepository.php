<?php

declare(strict_types=1);

namespace App\Repository;

use App\Entity\User;
use App\Exception\UserNotFoundException;
use DateTimeImmutable;
use PDO;

class UserRepository
{
    public function __construct(private PDO $connection)
    {
    }

    public function findById(int $id): ?User
    {
        $stmt = $this->connection->prepare(
            'SELECT * FROM users WHERE id = :id AND deleted_at IS NULL'
        );
        $stmt->execute(['id' => $id]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        return $row ? $this->hydrate($row) : null;
    }

    public function findByEmail(string $email): ?User
    {
        $stmt = $this->connection->prepare(
            'SELECT * FROM users WHERE email = :email AND deleted_at IS NULL'
        );
        $stmt->execute(['email' => strtolower($email)]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        return $row ? $this->hydrate($row) : null;
    }

    public function findActiveByRole(string $role, int $limit = 50, int $offset = 0): array
    {
        $stmt = $this->connection->prepare(
            'SELECT * FROM users WHERE role = :role AND status = :status LIMIT :limit OFFSET :offset'
        );
        $stmt->execute(['role' => $role, 'status' => 'active', 'limit' => $limit, 'offset' => $offset]);

        return array_map([$this, 'hydrate'], $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function save(User $user): void
    {
        if ($user->getId() === null) {
            $this->insert($user);
        } else {
            $this->update($user);
        }
    }

    public function softDelete(int $id, DateTimeImmutable $deletedAt): bool
    {
        $stmt = $this->connection->prepare(
            'UPDATE users SET deleted_at = :deleted_at WHERE id = :id'
        );
        $stmt->execute(['deleted_at' => $deletedAt->format('Y-m-d H:i:s'), 'id' => $id]);

        return $stmt->rowCount() > 0;
    }

    private function hydrate(array $row): User
    {
        return new User(
            id: (int) $row['id'],
            email: $row['email'],
            name: $row['name'],
            role: $row['role'],
            status: $row['status']
        );
    }

    private function insert(User $user): void
    {
        $stmt = $this->connection->prepare(
            'INSERT INTO users (email, name, role, status, created_at) VALUES (:email, :name, :role, :status, NOW())'
        );
        $stmt->execute([
            'email' => $user->getEmail(),
            'name' => $user->getName(),
            'role' => $user->getRole(),
            'status' => $user->getStatus(),
        ]);
    }

    private function update(User $user): void
    {
        $stmt = $this->connection->prepare(
            'UPDATE users SET email = :email, name = :name, role = :role, status = :status WHERE id = :id'
        );
        $stmt->execute([
            'email' => $user->getEmail(),
            'name' => $user->getName(),
            'role' => $user->getRole(),
            'status' => $user->getStatus(),
            'id' => $user->getId(),
        ]);
    }
}
