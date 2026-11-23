<?php

namespace App\Http\Middleware;

use App\Admin\AdminSession;
use App\Exceptions\AdminMfaRequiredException;
use App\Exceptions\SupabaseConfigurationException;
use App\Exceptions\SupabaseUnavailableException;
use App\Services\AdminAuditLogger;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureAdmin
{
    public function __construct(
        private AdminSession $adminSession,
        private AdminAuditLogger $audit,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        try {
            $admin = $this->adminSession->current($request);
        } catch (AdminMfaRequiredException) {
            return redirect()
                ->route('admin.login')
                ->withErrors(['email' => 'Your session needs a new multi-factor sign-in.']);
        } catch (SupabaseConfigurationException|SupabaseUnavailableException) {
            return response()->view('admin.errors.unavailable', [
                'message' => 'Admin authentication is temporarily unavailable. Check the server-side Supabase configuration and connectivity.',
            ], 503);
        }

        if ($admin === null) {
            $this->audit->record(
                $request,
                null,
                'admin.access.denied',
                'route',
                $request->route()?->getName(),
                'denied',
            );

            return redirect()->guest(route('admin.login'));
        }

        $request->attributes->set('admin', $admin);

        return $next($request);
    }
}
