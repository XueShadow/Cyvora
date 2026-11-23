<?php

use App\Exceptions\SupabaseConfigurationException;
use App\Exceptions\SupabaseRequestException;
use App\Exceptions\SupabaseUnavailableException;
use App\Http\Middleware\AdminSecurityHeaders;
use App\Http\Middleware\EnsureAdmin;
use App\Http\Middleware\EnsureAdminPermission;
use App\Http\Middleware\EnsureAdminReauthentication;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'admin.auth' => EnsureAdmin::class,
            'admin.permission' => EnsureAdminPermission::class,
            'admin.reauth' => EnsureAdminReauthentication::class,
            'admin.headers' => AdminSecurityHeaders::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
        $exceptions->render(function (
            SupabaseConfigurationException|SupabaseUnavailableException $exception,
            Request $request,
        ) {
            if ($request->is('admin/*')) {
                return response()->view('admin.errors.unavailable', [
                    'message' => 'The Supabase service is unavailable or not fully configured. Check the server-side application settings.',
                ], 503);
            }
        });
        $exceptions->render(function (SupabaseRequestException $exception, Request $request) {
            if ($request->is('admin/*')) {
                return response()->view('admin.errors.unavailable', [
                    'message' => 'The Supabase service rejected an administrative request (HTTP '.$exception->status.'). Check the required migrations and server logs.',
                ], 502);
            }
        });
    })->create();
