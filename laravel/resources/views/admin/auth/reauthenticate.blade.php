@extends('admin.auth.layout')

@section('title', 'Confirm administrator identity')

@section('content')
    <div class="auth-heading">
        <p class="eyebrow">SENSITIVE ADMINISTRATIVE ACTION</p>
        <h1>Confirm it’s you</h1>
        <p>Enter a fresh authenticator code before continuing with this sensitive action.</p>
    </div>
    @if (is_array($pending) && is_string($pending['reauth_challenge_id'] ?? null))
        <form method="post" action="{{ route('admin.reauth.verify') }}" class="stack-form">
            @csrf
            <label for="code">Six-digit authenticator code</label>
            <input id="code" name="code" type="text" inputmode="numeric" pattern="[0-9]{6}" autocomplete="one-time-code" minlength="6" maxlength="6" required autofocus>
            <button class="button button-primary button-wide" type="submit">Verify and continue</button>
        </form>
        @error('code')
            <p role="alert">{{ $message }}</p>
        @enderror
    @elseif (count($factors) > 0)
        <form method="post" action="{{ route('admin.reauth.challenge') }}" class="stack-form">
            @csrf
            <label for="factor_id">Authenticator</label>
            <select id="factor_id" name="factor_id" required>
                @foreach ($factors as $factor)
                    <option value="{{ $factor['id'] }}">
                        {{ $factor['friendly_name'] ?: ucfirst($factor['factor_type']) }}
                    </option>
                @endforeach
            </select>
            <button class="button button-primary button-wide" type="submit">Send verification challenge</button>
        </form>
        @error('factor_id')
            <p role="alert">{{ $message }}</p>
        @enderror
    @else
        <p role="alert">No verified authenticator is available. Sign out and contact a Super Admin for recovery.</p>
    @endif
    <a class="text-link" href="{{ route('admin.dashboard') }}">Return to dashboard</a>
@endsection
