<?php

declare(strict_types=1);

namespace App\Repository;

use App\Entity\User;
use PDO;

// Explicit visibility modifiers — no underscore prefix to hint at visibility
class UserRepository
{
    private PDO $connection;
    private array $cache = [];
    protected string $tableName = 'users';
    public bool $cacheEnabled = true;

    public function __construct(PDO $connection)
    {
        $this->connection = $connection;
    }

    public function findById(int $id): ?User
    {
        if ($this->cacheEnabled && isset($this->cache[$id])) {
            return $this->cache[$id];
        }

        $user = $this->fetchById($id);

        if ($user !== null && $this->cacheEnabled) {
            $this->cache[$id] = $user;
        }

        return $user;
    }

    public function findByEmail(string $email): ?User
    {
        $stmt = $this->connection->prepare(
            "SELECT * FROM {$this->tableName} WHERE email = :email AND deleted_at IS NULL"
        );
        $stmt->execute(['email' => mb_strtolower($email)]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        return $row ? $this->hydrateRow($row) : null;
    }

    public function save(User $user): void
    {
        if ($user->getId() === null) {
            $this->insertRow($user);
        } else {
            $this->updateRow($user);
        }

        $this->invalidateCache($user->getId());
    }

    protected function fetchById(int $id): ?User
    {
        $stmt = $this->connection->prepare(
            "SELECT * FROM {$this->tableName} WHERE id = :id AND deleted_at IS NULL"
        );
        $stmt->execute(['id' => $id]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        return $row ? $this->hydrateRow($row) : null;
    }

    private function hydrateRow(array $row): User
    {
        return new User(id: (int) $row['id'], email: $row['email'], name: $row['name'], role: $row['role']);
    }

    private function invalidateCache(?int $id): void
    {
        if ($id !== null) {
            unset($this->cache[$id]);
        }
    }

    private function insertRow(User $user): void
    {
        $stmt = $this->connection->prepare(
            "INSERT INTO {$this->tableName} (email, name, role, created_at) VALUES (:email, :name, :role, NOW())"
        );
        $stmt->execute(['email' => $user->getEmail(), 'name' => $user->getName(), 'role' => $user->getRole()]);
    }

    private function updateRow(User $user): void
    {
        $stmt = $this->connection->prepare(
            "UPDATE {$this->tableName} SET email = :email, name = :name WHERE id = :id"
        );
        $stmt->execute(['email' => $user->getEmail(), 'name' => $user->getName(), 'id' => $user->getId()]);
    }
}
