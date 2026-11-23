<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'Admin access') · Cyvora</title>
    <link rel="stylesheet" href="{{ asset('admin.css') }}">
</head>
<body class="auth-page">
    <main class="auth-card">
        <a class="brand brand-auth" href="{{ route('admin.login') }}">
            <span class="brand-mark">C</span>
            <span><strong>CYVORA</strong><small>SUPER ADMIN</small></span>
        </a>
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
</body>
</html>
