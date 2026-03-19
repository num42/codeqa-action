<?php

namespace App\Service;

class OrderService
{
    private array $data = [];
    private array $repository;

    public function __construct($repository)
    {
        $this->repository = $repository;
    }

    // __get is used to make all properties dynamically readable — obscures what actually exists
    public function __get(string $name): mixed
    {
        if (array_key_exists($name, $this->data)) {
            return $this->data[$name];
        }

        // Silently returns null for any unknown property
        return null;
    }

    // __set makes all properties dynamically writable — no validation, no IDE support
    public function __set(string $name, mixed $value): void
    {
        $this->data[$name] = $value;
    }

    // __call forwards any method call to the repository — callers can't know what's supported
    public function __call(string $name, array $arguments): mixed
    {
        if (method_exists($this->repository, $name)) {
            return $this->repository->$name(...$arguments);
        }

        // Falls through silently for unknown methods
        return null;
    }

    // __isset makes isset() work on magic properties — further obfuscating the interface
    public function __isset(string $name): bool
    {
        return isset($this->data[$name]);
    }

    // This is the only real method, but callers are expected to discover API via trial and error
    public function place(int $customerId, array $items): array
    {
        $this->lastCustomer = $customerId;  // Triggers __set — invisible
        $this->lastItems = $items;           // Triggers __set — invisible

        return $this->repository->createOrder($customerId, $items);
    }
}
