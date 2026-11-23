<?php

namespace App\Http\Middleware;

use App\Admin\AdminSession;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureAdminReauthentication
{
    public function __construct(private AdminSession $adminSession) {}

    public function handle(Request $request, Closure $next): Response
    {
        if ($this->adminSession->reauthenticationIsRecent($request)) {
            return $next($request);
        }

        $request->session()->put('url.intended', $request->getRequestUri());

        return redirect()->route('admin.reauth.show');
    }
}
