<?php

namespace App\Repository;

use App\Entity\User;
use PDO;

class UserRepository
{
    public function __construct($connection)  // no type hint
    {
        $this->connection = $connection;
    }

    // No type hints on parameters
    public function findById($id)
    {
        $stmt = $this->connection->prepare(
            'SELECT * FROM users WHERE id = :id AND deleted_at IS NULL'
        );
        $stmt->execute(['id' => $id]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        return $row ? $this->hydrate($row) : null;
    }

    // No type hints — $email could be anything
    public function findByEmail($email)
    {
        $stmt = $this->connection->prepare(
            'SELECT * FROM users WHERE email = :email AND deleted_at IS NULL'
        );
        $stmt->execute(['email' => strtolower($email)]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        return $row ? $this->hydrate($row) : null;
    }

    // No type hints — $role, $limit, $offset unconstrained
    public function findActiveByRole($role, $limit = 50, $offset = 0)
    {
        $stmt = $this->connection->prepare(
            'SELECT * FROM users WHERE role = :role AND status = :status LIMIT :limit OFFSET :offset'
        );
        $stmt->execute(['role' => $role, 'status' => 'active', 'limit' => $limit, 'offset' => $offset]);

        return array_map([$this, 'hydrate'], $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    // No type hint on $user
    public function save($user)
    {
        if ($user->getId() === null) {
            $this->insert($user);
        } else {
            $this->update($user);
        }
    }

    // No type hints on $id or $deletedAt
    public function softDelete($id, $deletedAt)
    {
        $stmt = $this->connection->prepare(
            'UPDATE users SET deleted_at = :deleted_at WHERE id = :id'
        );
        $stmt->execute(['deleted_at' => $deletedAt->format('Y-m-d H:i:s'), 'id' => $id]);

        return $stmt->rowCount() > 0;
    }

    private function hydrate($row)
    {
        return new User(
            id: (int) $row['id'],
            email: $row['email'],
            name: $row['name'],
            role: $row['role'],
            status: $row['status']
        );
    }

    private function insert($user)
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

    private function update($user)
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
