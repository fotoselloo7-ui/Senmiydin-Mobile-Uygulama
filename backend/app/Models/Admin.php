<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;

class Admin extends Authenticatable
{
    protected $fillable = ['name', 'email', 'password', 'role', 'is_active'];
    protected $attributes = ['is_active' => true, 'role' => 'moderator'];
    protected $hidden = ['password'];

    protected function casts(): array
    {
        return ['password' => 'hashed', 'is_active' => 'boolean'];
    }

    public function canManageSystem(): bool
    {
        return $this->role === 'super_admin';
    }

    public function canModerate(): bool
    {
        return $this->canManageSystem() || $this->role === 'moderator';
    }
}
