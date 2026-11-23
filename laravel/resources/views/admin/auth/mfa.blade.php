@extends('admin.auth.layout')

@section('title', 'Multi-factor verification')

@section('content')
    <div class="auth-heading">
        <p class="eyebrow">STEP-UP AUTHENTICATION</p>
        <h1>Verify your sign-in</h1>
        <p>Enter the six-digit code from your verified {{ $factorType }} factor.</p>
    </div>
    <form method="post" action="{{ route('admin.mfa.verify') }}" class="stack-form">
        @csrf
        <label for="code">Verification code</label>
        <input id="code" name="code" type="text" inputmode="numeric" pattern="[0-9]{6}" autocomplete="one-time-code" minlength="6" maxlength="6" required autofocus>
        <button class="button button-primary button-wide" type="submit">Verify and continue</button>
    </form>
    <a class="text-link" href="{{ route('admin.login') }}">Restart sign in</a>
@endsection
