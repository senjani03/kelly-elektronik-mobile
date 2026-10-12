<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['required', 'string', 'max:30'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = User::create([...$data, 'role' => 'customer']);

        return response()->json([
            'token' => $user->createToken('Kelly Elektronik Mobile')->plainTextToken,
            'user' => $this->userData($user),
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $credentials['email'])->first();

        if ($user === null || ! $user->is_active || ! Hash::check($credentials['password'], $user->password)) {
            return response()->json(['message' => 'Email atau password salah'], 401);
        }

        return response()->json([
            'token' => $user->createToken('Kelly Elektronik Mobile')->plainTextToken,
            'user' => $this->userData($user),
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->userData($request->user())]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json(['message' => 'Berhasil keluar']);
    }

    /**
     * @return array{id: int, name: string, email: string, phone: string, role: string}
     */
    private function userData(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone' => $user->phone,
            'role' => $user->role,
        ];
    }
}
