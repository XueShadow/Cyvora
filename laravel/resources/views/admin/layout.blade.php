@php($admin = request()->attributes->get('admin'))
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'Overview') · Cyvora Super Admin</title>
    <link rel="stylesheet" href="{{ asset('admin.css') }}">
</head>
<body class="panel-page">
    <div class="app-shell">
        <aside class="sidebar" id="admin-sidebar">
            <a class="brand" href="{{ route('admin.dashboard') }}">
                <span class="brand-mark">C</span>
                <span><strong>CYVORA</strong><small>SUPER ADMIN</small></span>
            </a>
            <div class="nav-caption">WORKSPACE</div>
            <nav class="side-nav" aria-label="Administration">
                @if ($admin?->can('dashboard.view'))
                    <a class="{{ request()->routeIs('admin.dashboard') ? 'active' : '' }}" href="{{ route('admin.dashboard') }}"><span>Overview</span></a>
                @endif
                @if ($admin?->can('users.view'))
                    <a class="{{ request()->routeIs('admin.users.*') ? 'active' : '' }}" href="{{ route('admin.users.index') }}"><span>User management</span></a>
                @endif
                @if ($admin?->can('families.view'))
                    <a class="{{ request()->routeIs('admin.families.*') ? 'active' : '' }}" href="{{ route('admin.families.index') }}"><span>Family protection</span></a>
                @endif
                @if ($admin?->can('scans.view'))
                    <a class="{{ request()->routeIs('admin.scans.*') ? 'active' : '' }}" href="{{ route('admin.scans.index') }}"><span>Scan history</span></a>
                    <a class="{{ request()->routeIs('admin.reports.*') ? 'active' : '' }}" href="{{ route('admin.reports.index') }}"><span>Scam reports</span></a>
                @endif
                @if ($admin?->can('intelligence.view'))
                    <a class="{{ request()->routeIs('admin.intelligence.*') ? 'active' : '' }}" href="{{ route('admin.intelligence.index') }}"><span>Scam intelligence</span></a>
                @endif
                @if ($admin?->can('providers.view'))
                    <a class="{{ request()->routeIs('admin.providers.*') ? 'active' : '' }}" href="{{ route('admin.providers.index') }}"><span>AI providers</span></a>
                @endif
                @if ($admin?->can('analytics.view'))
                    <a class="{{ request()->routeIs('admin.usage.*') ? 'active' : '' }}" href="{{ route('admin.usage.index') }}"><span>Usage analytics</span></a>
                @endif
                @if ($admin?->can('audit.view'))
                    <a class="{{ request()->routeIs('admin.security.*') ? 'active' : '' }}" href="{{ route('admin.security.index') }}"><span>Security events</span></a>
                @endif
                @if ($admin?->can('users.delete.review'))
                    <a class="{{ request()->routeIs('admin.deletion-requests.*') ? 'active' : '' }}" href="{{ route('admin.deletion-requests.index') }}"><span>Deletion requests</span></a>
                @endif
                @if ($admin?->can('audit.view'))
                    <a class="{{ request()->routeIs('admin.audit.*') ? 'active' : '' }}" href="{{ route('admin.audit.index') }}"><span>Audit log</span></a>
                @endif
                @if ($admin?->can('admins.manage'))
                    <a class="{{ request()->routeIs('admin.admins.*') ? 'active' : '' }}" href="{{ route('admin.admins.index') }}"><span>Admin management</span></a>
                @endif
            </nav>
            <div class="sidebar-foot">
                <span class="security-dot"></span>
                <span>Privileged session</span>
            </div>
        </aside>
        <div class="main-shell">
            <header class="topbar">
                <button class="nav-toggle" type="button" aria-label="Toggle navigation" aria-expanded="false" aria-controls="admin-sidebar" data-nav-toggle>☰</button>
                <form class="global-search" method="get" action="{{ route('admin.users.index') }}">
                    @if ($admin?->can('users.view'))
                        <label class="sr-only" for="global-search">Search users</label>
                        <input id="global-search" type="search" name="search" value="{{ request()->routeIs('admin.users.*') ? request('search') : '' }}" placeholder="Search users by email">
                        <button class="search-submit" type="submit">Search</button>
                    @endif
                </form>
                <details class="profile-menu">
                    <summary>
                        <span class="profile-avatar">{{ mb_strtoupper(mb_substr($admin?->email ?? 'A', 0, 1)) }}</span>
                        <span class="profile-label"><strong>{{ $admin?->email }}</strong><small>{{ $admin?->role->value }}</small></span>
                    </summary>
                    <div class="profile-popover">
                        <p>Signed in as <strong>{{ $admin?->role->value }}</strong></p>
                        <form method="post" action="{{ route('admin.logout') }}">
                            @csrf
                            <button class="button button-secondary button-wide" type="submit">Sign out</button>
                        </form>
                    </div>
                </details>
            </header>
            <main class="content">
                @if (session('status'))
                    <div class="notice notice-success" role="status">{{ session('status') }}</div>
                @endif
                @if ($errors->any())
                    <div class="notice notice-error" role="alert">
                        <ul>
                            @foreach ($errors->all() as $error)
                                <li>{{ $error }}</li>
                            @endforeach
                        </ul>
                    </div>
                @endif
                @yield('content')
            </main>
        </div>
    </div>
    <script src="{{ asset('admin.js') }}" defer></script>
</body>
</html>
