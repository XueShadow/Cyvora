@extends('admin.auth.layout')

@section('title', 'Choose a new password')

@section('content')
    <div class="auth-heading">
        <p class="eyebrow">ACCOUNT RECOVERY</p>
        <h1>Choose a new password</h1>
        <p>Use at least 12 characters. The one-time recovery token is sent directly to Supabase and is not saved in the panel session.</p>
    </div>
    <form method="post" action="{{ route('admin.password.update') }}" class="stack-form" data-reset-form>
        @csrf
        <input type="hidden" name="access_token" value="">
        <label for="password">New password</label>
        <input id="password" name="password" type="password" autocomplete="new-password" minlength="12" maxlength="128" required>
        <label for="password_confirmation">Confirm new password</label>
        <input id="password_confirmation" name="password_confirmation" type="password" autocomplete="new-password" minlength="12" maxlength="128" required>
        <p class="form-help" data-reset-message role="status">Validating recovery link…</p>
        <button class="button button-primary button-wide" type="submit" disabled>Update password</button>
    </form>
    <a class="text-link" href="{{ route('admin.login') }}">Return to sign in</a>
    <script src="{{ asset('admin-password-reset.js') }}" defer></script>
@endsection
