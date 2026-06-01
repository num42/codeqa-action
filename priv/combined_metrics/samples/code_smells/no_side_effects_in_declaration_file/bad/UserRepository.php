<?php

namespace App\Repository;

use PDO;

// Side effect: echoing output at include time (PSR-1 violation)
echo "Loading UserRepository...\n";

// Side effect: modifying global state at include time
ini_set('display_errors', '1');
error_reporting(E_ALL);

// Side effect: connecting to a database at include time
$pdo = new PDO('mysql:host=localhost;dbname=app', 'root', '');
$GLOBALS['db'] = $pdo;

// Side effect: defining a global function at include time
function get_user($id) {
    return $GLOBALS['db']->query("SELECT * FROM users WHERE id = $id")->fetch();
}

class UserRepository
{
    private PDO $connection;

    public function __construct(PDO $connection)
    {
        $this->connection = $connection;

        // Side effect: running a query in the constructor (at class use time)
        $this->connection->exec("SET NAMES utf8mb4");
    }

    public function findById(int $id): ?array
    {
        $stmt = $this->connection->prepare('SELECT * FROM users WHERE id = :id');
        $stmt->execute(['id' => $id]);
        return $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    }

    public function findByEmail(string $email): ?array
    {
        $stmt = $this->connection->prepare('SELECT * FROM users WHERE email = :email');
        $stmt->execute(['email' => strtolower($email)]);
        return $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    }
}

// Side effect: running code at include time — creates a user unconditionally
$repo = new UserRepository($GLOBALS['db']);
$adminUser = $repo->findByEmail('admin@example.com');
if (!$adminUser) {
    echo "Warning: no admin user found\n";
}
