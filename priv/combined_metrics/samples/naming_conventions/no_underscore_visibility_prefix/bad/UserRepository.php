<?php

namespace App\Repository;

use PDO;

// Underscore prefix used to hint at visibility — PSR-12 violation
class UserRepository
{
    // Single underscore used to signal "protected"
    protected $_connection;
    protected $_cache = [];
    protected $_tableName = 'users';

    // Double underscore used to signal "private"
    private $__cacheEnabled = true;

    public function __construct($connection)
    {
        $this->_connection = $connection;
    }

    public function findById($id)
    {
        if ($this->__cacheEnabled && isset($this->_cache[$id])) {
            return $this->_cache[$id];
        }

        $user = $this->_fetchById($id);

        if ($user !== null && $this->__cacheEnabled) {
            $this->_cache[$id] = $user;
        }

        return $user;
    }

    public function findByEmail($email)
    {
        $stmt = $this->_connection->prepare(
            "SELECT * FROM {$this->_tableName} WHERE email = :email AND deleted_at IS NULL"
        );
        $stmt->execute(['email' => strtolower($email)]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        return $row ? $this->_hydrateRow($row) : null;
    }

    public function save($user)
    {
        if ($user->getId() === null) {
            $this->__insertRow($user);
        } else {
            $this->__updateRow($user);
        }

        $this->__invalidateCache($user->getId());
    }

    // Single underscore conventionally means "protected" — but explicit modifier is required
    protected function _fetchById($id)
    {
        $stmt = $this->_connection->prepare(
            "SELECT * FROM {$this->_tableName} WHERE id = :id AND deleted_at IS NULL"
        );
        $stmt->execute(['id' => $id]);
        return $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    }

    // Double underscore conventionally means "private" — but explicit modifier is required
    private function __hydrateRow($row)
    {
        return (object) $row;
    }

    private function __invalidateCache($id): void
    {
        if ($id !== null) {
            unset($this->_cache[$id]);
        }
    }

    private function __insertRow($user): void
    {
        // insert logic
    }

    private function __updateRow($user): void
    {
        // update logic
    }
}
