<?php

namespace Database\Seeders;

use App\Models\Admin;
use Illuminate\Database\Seeder;

class DevelopmentAdminSeeder extends Seeder
{
    public function run(): void
    {
        if (! app()->environment('local', 'development')) {
            throw new \RuntimeException('Development admin can only be created in local or development environments.');
        }
        Admin::firstOrCreate(['email' => 'admin@senmiydin.local'], [
            'name' => 'Yerel Yönetici', 'password' => 'Admin1234!', 'role' => 'super_admin', 'is_active' => true,
        ]);
    }
}
