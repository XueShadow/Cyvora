@extends('admin.layout')

@section('title', $title)

@section('content')
    <div class="page-heading">
        <div>
            <p class="eyebrow">CYVORA OPERATIONS</p>
            <h1>{{ $title }}</h1>
            <p>{{ $description }}</p>
        </div>
    </div>
    <section class="panel table-panel">
        <div class="table-summary">{{ number_format($total) }} records</div>
        @if (count($rows) === 0)
            <div class="empty-state">No records are available in this data source.</div>
        @else
            <div class="table-scroll">
                <table>
                    <thead><tr>@foreach ($columns as $label)<th scope="col">{{ $label }}</th>@endforeach</tr></thead>
                    <tbody>
                    @foreach ($rows as $row)
                        <tr>
                            @foreach (array_keys($columns) as $field)
                                @php($value = $row[$field] ?? null)
                                <td>
                                    @if (is_array($value))
                                        <code>{{ json_encode($value, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) }}</code>
                                    @elseif (is_bool($value))
                                        {{ $value ? 'Yes' : 'No' }}
                                    @else
                                        {{ $value ?? '—' }}
                                    @endif
                                </td>
                            @endforeach
                        </tr>
                    @endforeach
                    </tbody>
                </table>
            </div>
        @endif
        @php($pageSize = 50)
        @if ($total > $pageSize)
            <nav class="pagination" aria-label="Table pages">
                @if ($page > 1)
                    <a class="button button-secondary" href="{{ request()->fullUrlWithQuery(['page' => $page - 1]) }}">Previous</a>
                @endif
                <span>Page {{ $page }} of {{ (int) ceil($total / $pageSize) }}</span>
                @if ($page * $pageSize < $total)
                    <a class="button button-secondary" href="{{ request()->fullUrlWithQuery(['page' => $page + 1]) }}">Next</a>
                @endif
            </nav>
        @endif
    </section>
@endsection
