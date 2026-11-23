<?php

use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\ManagementController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect()->route('admin.login');
});

Route::middleware('admin.headers')->prefix('admin')->name('admin.')->group(function (): void {
    Route::get('/login', [AuthController::class, 'showLogin'])->name('login');
    Route::post('/login', [AuthController::class, 'login'])
        ->middleware('throttle:admin-login')
        ->name('login.submit');
    Route::get('/forgot-password', [AuthController::class, 'showForgotPassword'])->name('password.request');
    Route::post('/forgot-password', [AuthController::class, 'sendPasswordReset'])
        ->middleware('throttle:admin-password-reset')
        ->name('password.email');
    Route::get('/password/reset', [AuthController::class, 'showResetPassword'])->name('password.reset');
    Route::post('/password/reset', [AuthController::class, 'resetPassword'])
        ->middleware('throttle:admin-password-reset')
        ->name('password.update');
    Route::get('/mfa', [AuthController::class, 'showMfa'])->name('mfa.show');
    Route::post('/mfa', [AuthController::class, 'verifyMfa'])
        ->middleware('throttle:admin-mfa')
        ->name('mfa.verify');

    Route::middleware(['throttle:admin-access', 'admin.auth'])->group(function (): void {
        Route::post('/logout', [AuthController::class, 'logout'])->name('logout');
        Route::get('/', DashboardController::class)
            ->middleware('admin.permission:dashboard.view')
            ->name('dashboard');
        Route::get('/users', [ManagementController::class, 'users'])
            ->middleware('admin.permission:users.view')
            ->name('users.index');
        Route::post('/users/{userId}/suspend', [ManagementController::class, 'suspendUser'])
            ->middleware('admin.permission:users.manage')
            ->name('users.suspend');
        Route::post('/users/{userId}/reactivate', [ManagementController::class, 'reactivateUser'])
            ->middleware('admin.permission:users.manage')
            ->name('users.reactivate');
        Route::post('/users/{userId}/deletion-requests', [ManagementController::class, 'requestDeletion'])
            ->middleware('admin.permission:users.delete.request')
            ->name('users.deletion-requests.store');
        Route::get('/deletion-requests', [ManagementController::class, 'deletionRequests'])
            ->middleware('admin.permission:users.delete.review')
            ->name('deletion-requests.index');
        Route::post('/deletion-requests/{requestId}/review', [ManagementController::class, 'reviewDeletionRequest'])
            ->middleware('admin.permission:users.delete.review')
            ->name('deletion-requests.review');
        Route::post('/deletion-requests/{requestId}/execute', [ManagementController::class, 'executeDeletionRequest'])
            ->middleware('admin.permission:users.delete.review')
            ->name('deletion-requests.execute');
        Route::get('/families', [ManagementController::class, 'families'])
            ->middleware('admin.permission:families.view')
            ->name('families.index');
        Route::get('/families/{familyId}', [ManagementController::class, 'familyDetails'])
            ->middleware('admin.permission:families.view')
            ->name('families.show');
        Route::post('/family-invitations/{invitationId}/revoke', [ManagementController::class, 'revokeInvitation'])
            ->middleware('admin.permission:families.invites.revoke')
            ->name('family-invitations.revoke');
        Route::get('/scans', [ManagementController::class, 'scans'])
            ->middleware('admin.permission:scans.view')
            ->name('scans.index');
        Route::get('/reports', [ManagementController::class, 'reports'])
            ->middleware('admin.permission:scans.view')
            ->name('reports.index');
        Route::get('/intelligence', [ManagementController::class, 'intelligence'])
            ->middleware('admin.permission:intelligence.view')
            ->name('intelligence.index');
        Route::post('/intelligence/review', [ManagementController::class, 'reviewExample'])
            ->middleware('admin.permission:intelligence.review')
            ->name('intelligence.review');
        Route::post('/intelligence/resolve-dispute', [ManagementController::class, 'resolveDispute'])
            ->middleware('admin.permission:intelligence.manage')
            ->name('intelligence.resolve-dispute');
        Route::post('/intelligence/evaluate-dataset', [ManagementController::class, 'evaluateDataset'])
            ->middleware('admin.permission:intelligence.manage')
            ->name('intelligence.evaluate');
        Route::post('/intelligence/release-dataset', [ManagementController::class, 'releaseDataset'])
            ->middleware('admin.permission:intelligence.manage')
            ->name('intelligence.release');
        Route::get('/providers', [ManagementController::class, 'providers'])
            ->middleware('admin.permission:providers.view')
            ->name('providers.index');
        Route::get('/usage', [ManagementController::class, 'usage'])
            ->middleware('admin.permission:analytics.view')
            ->name('usage.index');
        Route::get('/security', [ManagementController::class, 'securityEvents'])
            ->middleware('admin.permission:audit.view')
            ->name('security.index');
        Route::get('/audit-logs', [ManagementController::class, 'auditLogs'])
            ->middleware('admin.permission:audit.view')
            ->name('audit.index');
        Route::get('/admins', [ManagementController::class, 'admins'])
            ->middleware('admin.permission:admins.manage')
            ->name('admins.index');
        Route::post('/admins/role', [ManagementController::class, 'assignAdminRole'])
            ->middleware('admin.permission:admins.manage')
            ->name('admins.role');
    });
});
