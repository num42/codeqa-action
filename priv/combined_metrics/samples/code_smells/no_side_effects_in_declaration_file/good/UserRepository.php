<?php

declare(strict_types=1);

namespace App\Repository;

use App\Entity\User;
use App\Exception\UserNotFoundException;
use PDO;

/**
 * Declares a class only. No side effects when this file is included.
 */
class UserRepository
{
    public function __construct(private PDO $connection)
    {
    }

    public function findById(int $id): ?User
    {
        $stmt = $this->connection->prepare(
            'SELECT * FROM users WHERE id = :id'
        );
        $stmt->execute(['id' => $id]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        return $row ? $this->hydrate($row) : null;
    }

    public function findByEmail(string $email): ?User
    {
        $stmt = $this->connection->prepare(
            'SELECT * FROM users WHERE email = :email'
        );
        $stmt->execute(['email' => mb_strtolower($email)]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        return $row ? $this->hydrate($row) : null;
    }

    public function save(User $user): void
    {
        if ($user->getId() === null) {
            $this->insert($user);
        } else {
            $this->update($user);
        }
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

    private function insert(User $user): void
    {
        $stmt = $this->connection->prepare(
            'INSERT INTO users (email, name, role, created_at) VALUES (:email, :name, :role, NOW())'
        );
        $stmt->execute([
            'email' => $user->getEmail(),
            'name'  => $user->getName(),
            'role'  => $user->getRole(),
        ]);
    }

    private function update(User $user): void
    {
        $stmt = $this->connection->prepare(
            'UPDATE users SET email = :email, name = :name WHERE id = :id'
        );
        $stmt->execute([
            'email' => $user->getEmail(),
            'name'  => $user->getName(),
            'id'    => $user->getId(),
        ]);
    }
}
