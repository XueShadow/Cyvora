@extends('admin.auth.layout')

@section('title', 'Set up multi-factor authentication')

@section('content')
    <div class="auth-heading">
        <p class="eyebrow">REQUIRED ACCOUNT SECURITY</p>
        <h1>Set up an authenticator</h1>
        <p>Administrative access requires a verified authenticator app. This setup secret is visible only during this short enrollment session.</p>
    </div>
    <div class="stack-form">
        <img src="{{ $qrCode }}" alt="Authenticator setup QR code" width="220" height="220">
        <p>Scan the QR code with your authenticator app. If you cannot scan it, enter this secret manually:</p>
        <code>{{ $secret }}</code>
        <details>
            <summary>Show setup URI</summary>
            <code>{{ $uri }}</code>
        </details>
        <form method="post" action="{{ route('admin.mfa.enroll.verify') }}" class="stack-form">
            @csrf
            <label for="code">Six-digit authenticator code</label>
            <input id="code" name="code" type="text" inputmode="numeric" pattern="[0-9]{6}" autocomplete="one-time-code" minlength="6" maxlength="6" required autofocus>
            <button class="button button-primary button-wide" type="submit">Verify and continue</button>
        </form>
        <form method="post" action="{{ route('admin.mfa.enroll.cancel') }}">
            @csrf
            <button class="button button-wide" type="submit">Cancel setup and sign out</button>
        </form>
    </div>
    @error('code')
        <p role="alert">{{ $message }}</p>
    @enderror
    <p class="auth-footnote">Do not share this QR code or secret. After setup, sign-ins require your password and a current authenticator code.</p>
@endsection
