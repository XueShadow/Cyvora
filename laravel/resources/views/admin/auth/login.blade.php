@extends('admin.auth.layout')

@section('title', 'Administrator sign in')

@section('content')
    <div class="auth-heading">
        <p class="eyebrow">SECURE ADMINISTRATION</p>
        <h1>Sign in</h1>
        <p>Use a verified Cyvora account with a server-assigned administrator role.</p>
    </div>
    <form method="post" action="{{ route('admin.login.submit') }}" class="stack-form">
        @csrf
        <label for="email">Email address</label>
        <input id="email" name="email" type="email" autocomplete="username" value="{{ old('email') }}" maxlength="254" required autofocus>
        <label for="password">Password</label>
        <input id="password" name="password" type="password" autocomplete="current-password" maxlength="1024" required>
        <button class="button button-primary button-wide" type="submit">Continue securely</button>
    </form>
    <a class="text-link" href="{{ route('admin.password.request') }}">Forgot your password?</a>
    <p class="auth-footnote">There is no public administrator registration. Roles are assigned only through trusted provisioning.</p>
@endsection
