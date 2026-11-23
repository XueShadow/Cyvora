<?php

namespace App\Http\Middleware;

use App\Admin\AdminIdentity;
use App\Services\AdminAuditLogger;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureAdminPermission
{
    public function __construct(private AdminAuditLogger $audit) {}

    public function handle(Request $request, Closure $next, string $permission): Response
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof AdminIdentity || ! $admin->can($permission)) {
            $this->audit->record(
                $request,
                $admin instanceof AdminIdentity ? $admin : null,
                'admin.permission.denied',
                'route',
                $request->route()?->getName(),
                'denied',
                ['permission' => $permission],
            );

            abort(403);
        }

        return $next($request);
    }
}
