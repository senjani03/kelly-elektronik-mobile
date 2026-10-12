<?php

namespace Tests\Feature\Api;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_customer_can_register_login_and_logout_with_a_sanctum_token(): void
    {
        $registration = $this->postJson('/api/register', [
            'name' => 'Dewi',
            'email' => 'dewi@example.test',
            'phone' => '081234567890',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
        ]);

        $registration->assertCreated()
            ->assertJsonPath('user.name', 'Dewi')
            ->assertJsonPath('user.role', 'customer')
            ->assertJsonStructure(['token', 'user' => ['id', 'name', 'email', 'phone', 'role']]);

        $login = $this->postJson('/api/login', [
            'email' => 'dewi@example.test',
            'password' => 'Password123!',
        ]);
        $login->assertOk()->assertJsonStructure(['token', 'user']);

        $headers = ['Authorization' => 'Bearer '.$login->json('token')];
        $this->getJson('/api/me', $headers)
            ->assertOk()
            ->assertJsonPath('data.email', 'dewi@example.test');

        $this->postJson('/api/logout', [], $headers)->assertOk();
        $tokenId = explode('|', $login->json('token'), 2)[0];
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $tokenId]);
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/me', $headers)->assertUnauthorized();
    }

    public function test_registration_requires_matching_password_confirmation_and_unique_email(): void
    {
        User::factory()->create(['email' => 'taken@example.test']);

        $this->postJson('/api/register', [
            'name' => 'Dewi',
            'email' => 'taken@example.test',
            'phone' => '081234567890',
            'password' => 'Password123!',
            'password_confirmation' => 'Different123!',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['email', 'password']);
    }

    public function test_invalid_login_is_rejected(): void
    {
        $this->postJson('/api/login', [
            'email' => 'missing@example.test',
            'password' => 'Password123!',
        ])->assertUnauthorized();
    }
}
