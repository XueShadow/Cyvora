@extends('admin.auth.layout')

@section('title', 'Password recovery')

@section('content')
    <div class="auth-heading">
        <p class="eyebrow">ACCOUNT RECOVERY</p>
        <h1>Reset password</h1>
        <p>We'll send recovery instructions if this email belongs to an authorized account.</p>
    </div>
    <form method="post" action="{{ route('admin.password.email') }}" class="stack-form">
        @csrf
        <label for="email">Email address</label>
        <input id="email" name="email" type="email" autocomplete="username" value="{{ old('email') }}" maxlength="254" required autofocus>
        <button class="button button-primary button-wide" type="submit">Send recovery link</button>
    </form>
    <a class="text-link" href="{{ route('admin.login') }}">Return to sign in</a>
@endsection
