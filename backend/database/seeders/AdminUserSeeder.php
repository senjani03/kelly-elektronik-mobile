<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        $email = env('ADMIN_EMAIL');
        $password = env('ADMIN_PASSWORD');

        if (! is_string($email) || trim($email) === '' || ! is_string($password) || strlen($password) < 12) {
            $this->command?->warn('Admin seed dilewati. Set ADMIN_EMAIL dan ADMIN_PASSWORD (minimal 12 karakter) untuk membuat admin.');

            return;
        }

        User::firstOrCreate(
            ['email' => $email],
            [
                'name' => env('ADMIN_NAME', 'Administrator'),
                'phone' => '',
                'role' => 'admin',
                'is_active' => true,
                'password' => $password,
            ],
        );
    }
}
