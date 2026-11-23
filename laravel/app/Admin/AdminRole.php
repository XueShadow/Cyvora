<?php

namespace App\Admin;

enum AdminRole: string
{
    case SuperAdmin = 'super_admin';
    case Admin = 'admin';
    case Moderator = 'moderator';
    case SupportAdmin = 'support_admin';

    public static function fromSupabase(mixed $role): ?self
    {
        return is_string($role) ? self::tryFrom($role) : null;
    }

    public function can(string $permission): bool
    {
        return in_array($permission, match ($this) {
            self::SuperAdmin => [
                'dashboard.view',
                'users.view',
                'users.manage',
                'users.delete.request',
                'users.delete.review',
                'families.view',
                'families.invites.revoke',
                'scans.view',
                'intelligence.view',
                'intelligence.review',
                'intelligence.manage',
                'providers.view',
                'analytics.view',
                'audit.view',
                'admins.manage',
                'settings.manage',
            ],
            self::Admin => [
                'dashboard.view',
                'users.view',
                'users.manage',
                'users.delete.request',
                'families.view',
                'families.invites.revoke',
                'scans.view',
                'intelligence.view',
                'intelligence.review',
                'intelligence.manage',
                'providers.view',
                'analytics.view',
                'audit.view',
            ],
            self::Moderator => [
                'intelligence.view',
                'intelligence.review',
            ],
            self::SupportAdmin => [
                'dashboard.view',
                'users.view',
            ],
        }, true);
    }
}
