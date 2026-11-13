@if($post->media->isNotEmpty())
<div class="media-grid">
    @foreach($post->media as $media)
        <a href="{{ route('admin.media', $media->id) }}"><img src="{{ route('admin.media', $media->id) }}" alt="Paylaşım fotoğrafı {{ $loop->iteration }}" loading="lazy"></a>
    @endforeach
</div>
@endif
