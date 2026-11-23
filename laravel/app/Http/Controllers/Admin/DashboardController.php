<?php

namespace App\Http\Controllers\Admin;

use App\Admin\AdminIdentity;
use App\Exceptions\SupabaseConfigurationException;
use App\Exceptions\SupabaseRequestException;
use App\Exceptions\SupabaseUnavailableException;
use App\Http\Controllers\Controller;
use App\Services\SupabaseAdminRepository;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\View\View;

class DashboardController extends Controller
{
    public function __invoke(Request $request, SupabaseAdminRepository $repository): View|Response
    {
        $filters = $request->validate(['days' => ['nullable', 'integer', 'in:7,30,90']]);
        $days = (int) ($filters['days'] ?? 30);
        $admin = $request->attributes->get('admin');

        try {
            return response()->view('admin.dashboard', [
                'dashboard' => $repository->overview(
                    $days,
                    $admin instanceof AdminIdentity && $admin->can('audit.view'),
                ),
                'dataError' => null,
            ]);
        } catch (SupabaseConfigurationException|SupabaseRequestException|SupabaseUnavailableException) {
            return response()->view('admin.dashboard', [
                'dashboard' => null,
                'dataError' => 'Live dashboard data is unavailable. Verify that the server-side Supabase keys are configured and the Super Admin migrations are applied.',
            ], 503);
        }
    }
}
