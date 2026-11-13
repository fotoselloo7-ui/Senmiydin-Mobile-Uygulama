@if($rows->hasPages())
<nav class="pager" aria-label="Sayfalar">
    @if($rows->previousPageUrl())<a href="{{ $rows->previousPageUrl() }}">← Önceki</a>@endif
    <span>{{ $rows->currentPage() }} / {{ $rows->lastPage() }}</span>
    @if($rows->nextPageUrl())<a href="{{ $rows->nextPageUrl() }}">Sonraki →</a>@endif
</nav>
@endif
