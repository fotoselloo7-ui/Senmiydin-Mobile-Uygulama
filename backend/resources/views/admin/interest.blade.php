<form method="post" action="{{ route('admin.interests.save', $entry ? ['id' => $entry->id] : []) }}" class="fields">
    @csrf
    <div class="field-grid">
        <label>Ad<input name="name" required maxlength="80" value="{{ $entry?->name }}"></label>
        <label>Kısa ad<input name="slug" maxlength="100" value="{{ $entry?->slug }}"></label>
        <label>Simge<input name="icon" maxlength="50" value="{{ $entry?->icon }}"></label>
        <label>Sıra<input name="sort_order" required type="number" min="0" max="65535" value="{{ $entry?->sort_order ?? 0 }}"></label>
    </div>
    <label class="toggle"><input type="hidden" name="is_active" value="0"><input type="checkbox" name="is_active" value="1" @checked($entry?->is_active ?? true)> Aktif</label>
    <button class="button outline">{{ $entry ? 'Kaydet' : 'Hobi ekle' }}</button>
</form>
