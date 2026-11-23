@extends('admin.auth.layout')

@section('title', 'Service unavailable')

@section('content')
    <div class="auth-heading">
        <p class="eyebrow">SERVICE STATUS</p>
        <h1>Admin service unavailable</h1>
        <p>{{ $message }}</p>
    </div>
    <a class="button button-secondary button-wide" href="{{ route('admin.login') }}">Return to sign in</a>
@endsection
