<?php

namespace App\Admin;

final readonly class AdminIdentity
{
    public function __construct(
        public string $id,
        public string $email,
        public AdminRole $role,
    ) {}

    public function can(string $permission): bool
    {
        return $this->role->can($permission);
    }
}
