<?php

use App\Http\Middleware\EnsureActiveUser;
use App\Http\Middleware\EnsureAdmin;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'active' => EnsureActiveUser::class,
            'admin' => EnsureAdmin::class,
        ]);
    })
    ->withSchedule(function (Schedule $schedule): void {
        $schedule->command('orders:cancel-expired')->everyMinute();
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })->create();
