<?php

namespace App\Http\Controllers;

use App\Http\ApiResponse;
use App\Http\Resources\MemoryResource;
use App\Location\Geo;
use App\Media\PrivateImage;
use App\Memories\MemorySources;
use App\Models\City;
use App\Models\Memory;
use App\Models\MemoryMedia;
use App\Models\Place;
use App\Models\User;
use App\Safety\Blocks;
use App\Safety\ContentGuard;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

/**
 * Anılar (memories). The profile list, detail, create / edit (with 0–5 photos, in any order), hide, delete and the
 * protected photo routes. Who may see what is decided only by {@see Memory::scopeVisibleTo()}.
 */
class MemoryController extends Controller
{
    private const WITH = ['media', 'city', 'place', 'author'];

    /** A person's memories, newest event first. Others get exactly the ones the visibility rules let them see. */
    public function index(Request $request, string $username): JsonResponse
    {
        $viewer = $request->user();
        $owner = Blocks::exclude(User::where('account_status', 'active'), $viewer->id, 'users.id')
            ->where('username', Str::lower($username))->firstOrFail();
        $page = Memory::visibleTo($viewer)->where('memories.user_id', $owner->id)->with(self::WITH)
            ->orderByDesc('memories.occurred_at')->orderByDesc('memories.id')
            ->simplePaginate((int) config('memories.page_size'));

        return ApiResponse::page($page, MemoryResource::class);
    }

    public function show(Request $request, int $memory): JsonResponse
    {
        return ApiResponse::ok(new MemoryResource($this->visible($request, $memory)));
    }

    /**
     * "Anılarıma Ekle": what a new memory made from one of the viewer's own map notes / posts starts with (the source is
     * only read), or the memory that already exists for it so it is never copied twice.
     */
    public function prefill(Request $request): JsonResponse
    {
        $data = $request->validate(['source_type' => ['required', Rule::in(Memory::SOURCES)], 'source_id' => ['required', 'integer', 'min:1']]);
        $viewer = $request->user();
        $source = MemorySources::snapshot($viewer, $data['source_type'], (int) $data['source_id']);
        $existing = MemorySources::existing($viewer, $data['source_type'], (int) $data['source_id']);
        $city = $source['city_id'] ? City::find($source['city_id']) : null;
        $place = $source['place_id'] ? Place::find($source['place_id']) : null;
        // An anonymous source never starts as something others can see.
        $visibility = $source['anonymous'] ? Memory::PRIVATE : $this->defaultVisibility($viewer, $source['city_id']);

        return ApiResponse::ok([
            'existing' => $existing ? new MemoryResource($existing->load(self::WITH)) : null,
            'prefill' => [
                'source_type' => $source['type'],
                'body' => $source['body'],
                'occurred_at' => $source['occurred_at']->toISOString(),
                'city' => $city?->only('id', 'name', 'slug'),
                'place' => $place?->summary(),
                'place_label' => $source['place_label'] ? ApiResponse::localize((string) $source['place_label']) : $city?->name,
                'visibility' => $visibility,
                'media' => array_map(fn ($media) => ['ref' => $media['ref'], 'url' => $media['url'], 'width' => $media['width'], 'height' => $media['height']], $source['media']),
            ],
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            ...$this->rules(),
            'occurred_at' => ['required', ...$this->dateRules()],
            'request_id' => ['required', 'uuid'],
            'source_type' => ['sometimes', 'required_with:source_id', Rule::in(Memory::SOURCES)],
            'source_id' => ['sometimes', 'required_with:source_type', 'integer', 'min:1'],
        ], $this->messages());
        PlaceController::apply($data);
        $viewer = $request->user();
        $files = $request->file('media', []);
        $written = [];
        try {
            [$memory, $created] = DB::transaction(function () use ($viewer, $data, $files, &$written) {
                User::whereKey($viewer->id)->lockForUpdate()->firstOrFail();
                $existing = Memory::withTrashed()->where('user_id', $viewer->id)->where('request_id', $data['request_id'])->first();
                if ($existing) {
                    return [$existing, false];
                }
                $source = isset($data['source_type']) ? MemorySources::snapshot($viewer, $data['source_type'], (int) $data['source_id']) : null;
                if ($source && ($already = MemorySources::existing($viewer, $source['type'], $source['id']))) {
                    // One memory per source: asking again returns the one that exists.
                    return [$already, false];
                }
                $body = trim((string) ($data['body'] ?? ''));
                app(ContentGuard::class)->check($viewer->id, $body, 'memories');
                $layout = $data['layout'] ?? array_map(fn ($index) => 'n'.$index, array_keys($files));
                $rows = $this->mediaRows($layout, $files, $source, null, $written);
                if ($body === '' && $rows === []) {
                    throw ValidationException::withMessages(['body' => 'Anı için bir metin yaz veya fotoğraf ekle.']);
                }
                $place = $this->placeFields($data, $source);
                $visibility = $data['visibility'] ?? $this->defaultVisibility($viewer, $place['city_id'] ?? null);
                $this->assertAreaHasPlace($visibility, $place['city_id'] ?? null);
                $memory = Memory::create([
                    'user_id' => $viewer->id, 'source_type' => $source['type'] ?? null, 'source_id' => $source['id'] ?? null,
                    'body' => $body, 'occurred_at' => \Illuminate\Support\Carbon::parse($data['occurred_at'])->utc(),
                    'visibility' => $visibility, 'is_hidden' => false, 'content_hash' => ContentGuard::fingerprint($body),
                    'request_id' => $data['request_id'], ...$place,
                ]);
                $this->saveMedia($memory, $rows);

                return [$memory, true];
            });
        } catch (\Throwable $error) {
            $this->discard($written);
            throw $error;
        }

        return ApiResponse::ok(new MemoryResource($memory->load(self::WITH)),
            $created ? 'Anı kaydedildi.' : 'Bu içerik zaten Anılarında.', $created ? 201 : 200);
    }

    /**
     * Edits only the memory: text, event date, area, visibility, photos and their order. The source post / map note is
     * never touched. A POST (not PUT) because the photos travel as a multipart form.
     */
    public function update(Request $request, int $memory): JsonResponse
    {
        $data = $request->validate([...$this->rules(), 'occurred_at' => ['sometimes', ...$this->dateRules()]], $this->messages());
        PlaceController::apply($data);
        $viewer = $request->user();
        $files = $request->file('media', []);
        $written = [];
        $removed = collect();
        try {
            DB::transaction(function () use ($viewer, $memory, $data, $files, $request, &$written, &$removed): void {
                $entry = Memory::where('user_id', $viewer->id)->whereNull('moderated_at')->with('media')->lockForUpdate()->findOrFail($memory);
                $attributes = [];
                if (array_key_exists('body', $data)) {
                    $body = trim((string) $data['body']);
                    app(ContentGuard::class)->check($viewer->id, $body, 'memories', $entry->id);
                    $attributes += ['body' => $body, 'content_hash' => ContentGuard::fingerprint($body)];
                }
                if (isset($data['occurred_at'])) {
                    $attributes['occurred_at'] = \Illuminate\Support\Carbon::parse($data['occurred_at'])->utc();
                }
                if (isset($data['place_id']) || isset($data['city_id'])) {
                    $attributes += $this->placeFields($data, null);
                }
                $layout = $request->has('layout') ? ($data['layout'] ?? []) : [
                    ...$entry->media->map(fn ($item) => 'm'.$item->id)->all(), ...array_map(fn ($index) => 'n'.$index, array_keys($files)),
                ];
                $rows = $this->mediaRows($layout, $files, null, $entry, $written);
                $final = [...$entry->getAttributes(), ...$attributes];
                if (trim((string) $final['body']) === '' && $rows === []) {
                    throw ValidationException::withMessages(['body' => 'Anı için bir metin yaz veya fotoğraf ekle.']);
                }
                $visibility = $data['visibility'] ?? $entry->visibility;
                $this->assertAreaHasPlace($visibility, $attributes['city_id'] ?? $entry->city_id);
                $entry->forceFill($attributes + ['visibility' => $visibility])->save();
                $kept = collect($rows)->pluck('keep')->filter()->all();
                $removed = $entry->media->reject(fn ($item) => in_array($item->id, $kept, true))->values();
                $this->saveMedia($entry, $rows);
                MemoryMedia::whereIn('id', $removed->pluck('id'))->delete();
                // A memory edit is never a "new" thing: it only touches this row.
                $entry->touch();
            });
        } catch (\Throwable $error) {
            $this->discard($written);
            throw $error;
        }
        Memory::removeFiles($removed);

        return ApiResponse::ok(new MemoryResource($this->visible($request, $memory)), 'Anı güncellendi.');
    }

    public function hide(Request $request, int $memory): JsonResponse
    {
        return $this->setHidden($request, $memory, true);
    }

    public function unhide(Request $request, int $memory): JsonResponse
    {
        return $this->setHidden($request, $memory, false);
    }

    private function setHidden(Request $request, int $memory, bool $hidden): JsonResponse
    {
        $entry = $this->own($request, $memory);
        if ($entry->is_hidden !== $hidden) {
            $entry->forceFill(['is_hidden' => $hidden])->save();
        }

        return ApiResponse::ok(new MemoryResource($this->visible($request, $memory)), $hidden ? 'Anı gizlendi.' : 'Anı tekrar görünür.');
    }

    /**
     * The memory and its photos are removed now. Never the source post / map note. A memory somebody reported is only
     * soft-deleted (its files stay) so moderation can still review it until the retention window ends.
     */
    public function destroy(Request $request, int $memory): JsonResponse
    {
        $entry = $this->own($request, $memory);
        DB::transaction(function () use ($entry): void {
            $reported = DB::table('reports')->where('target_type', 'memory')->where('target_id', $entry->id)->exists();
            $reported ? $entry->delete() : $entry->forceDelete();
        });

        return ApiResponse::ok(message: 'Anı silindi.');
    }

    public function media(Request $request, int $media): Response
    {
        return $this->serve($request, $media, false);
    }

    public function thumb(Request $request, int $media): Response
    {
        return $this->serve($request, $media, true);
    }

    /** A photo is served only to someone who may see its memory right now (same authorization as the memory). */
    private function serve(Request $request, int $media, bool $thumb): Response
    {
        $viewer = $request->user();
        $item = MemoryMedia::whereHas('memory', fn (Builder $memories) => $memories->visibleTo($viewer))->findOrFail($media);
        $path = $thumb ? ($item->thumb_path ?: $item->path) : $item->path;
        $disk = Storage::disk($item->disk);
        abort_unless($disk->exists($path), 404);

        return $disk->response($path, 'ani.jpg', [
            'Content-Type' => 'image/jpeg', 'X-Content-Type-Options' => 'nosniff', 'Cache-Control' => 'private, no-store',
        ]);
    }

    private function visible(Request $request, int $id): Memory
    {
        return Memory::visibleTo($request->user())->with(self::WITH)->findOrFail($id);
    }

    private function own(Request $request, int $id): Memory
    {
        return Memory::where('user_id', $request->user()->id)->whereNull('moderated_at')->findOrFail($id);
    }

    private function defaultVisibility(User $viewer, ?int $city): string
    {
        $visibility = in_array($viewer->memory_default_visibility, Memory::VISIBILITIES, true) ? $viewer->memory_default_visibility : Memory::PRIVATE;

        return $visibility === Memory::AREA && $city === null ? Memory::PRIVATE : $visibility;
    }

    private function assertAreaHasPlace(string $visibility, ?int $city): void
    {
        if ($visibility === Memory::AREA && $city === null) {
            throw ValidationException::withMessages(['visibility' => 'Bu Bölgedekiler için bir yer seç.']);
        }
    }

    /** @return array<string,mixed> */
    private function rules(): array
    {
        $photos = (int) config('memories.max_media');

        return [
            'body' => ['sometimes', 'nullable', 'string', 'max:'.config('memories.max_body')],
            ...PlaceController::rules(required: false),
            'visibility' => ['sometimes', Rule::in(Memory::VISIBILITIES)],
            // The final photo order: "m<id>" a photo the memory already has, "s<id>" a photo of the source it is made
            // from, "n<index>" a new upload (media[<index>]).
            'layout' => ['sometimes', 'array', 'list', 'max:'.$photos],
            'layout.*' => ['string', 'regex:/^[mns]\d{1,10}$/'],
            'media' => ['sometimes', 'array', 'list', 'max:'.$photos],
            'media.*' => array_merge([PrivateImage::safeName()], explode('|', PrivateImage::RULES)),
        ];
    }

    /** @return list<mixed> */
    private function dateRules(): array
    {
        return ['date', 'before_or_equal:'.now()->addDay()->toISOString(), 'after_or_equal:1900-01-01'];
    }

    /** @return array<string,string> */
    private function messages(): array
    {
        $photos = (int) config('memories.max_media');

        return [
            'media.max' => 'En fazla '.$photos.' fotoğraf ekleyebilirsin.',
            'layout.max' => 'En fazla '.$photos.' fotoğraf ekleyebilirsin.',
            'media.*.*' => 'Her fotoğraf JPEG, PNG veya WebP biçiminde, en fazla 5 MB ve 2048 piksel olmalı.',
        ];
    }

    /**
     * The area columns of a memory. A chosen place decides its area and approximate point (the public centre of that
     * place, never a person's position); an area alone keeps the source's approximate point when it is the same area.
     *
     * @return array{city_id:?int,place_id:?int,place_label:?string,approx_latitude:?float,approx_longitude:?float}
     */
    private function placeFields(array $data, ?array $source): array
    {
        $grid = (float) config('memories.location_grid');
        if (! empty($data['place_id'])) {
            $place = Place::with('city')->findOrFail($data['place_id']);

            return ['city_id' => $place->city_id, 'place_id' => $place->id, 'place_label' => mb_substr($place->display()['label'], 0, 255),
                'approx_latitude' => Geo::grid((float) $place->latitude, $grid), 'approx_longitude' => Geo::grid((float) $place->longitude, $grid)];
        }
        if (! empty($data['city_id'])) {
            $city = City::findOrFail($data['city_id']);
            $same = $source && (int) $source['city_id'] === (int) $city->id;

            return ['city_id' => $city->id, 'place_id' => null,
                'place_label' => $same && $source['place_label'] ? $source['place_label'] : mb_substr($city->name, 0, 255),
                'approx_latitude' => $same ? $source['latitude'] : null, 'approx_longitude' => $same ? $source['longitude'] : null];
        }
        if ($source) {
            return ['city_id' => $source['city_id'], 'place_id' => $source['place_id'], 'place_label' => $source['place_label'],
                'approx_latitude' => $source['latitude'], 'approx_longitude' => $source['longitude']];
        }

        return ['city_id' => null, 'place_id' => null, 'place_label' => null, 'approx_latitude' => null, 'approx_longitude' => null];
    }

    /**
     * Turns the photo layout into rows to keep / write. Every new photo (an upload or a copy of a source photo) is
     * decoded for real, re-encoded without metadata and stored under a random name together with a small thumbnail.
     *
     * @param  list<string>  $layout
     * @param  array<int,\Illuminate\Http\UploadedFile>  $files
     * @param  list<string>  $written  files created so far (removed again if the request fails)
     * @return list<array<string,mixed>>
     */
    private function mediaRows(array $layout, array $files, ?array $source, ?Memory $memory, array &$written): array
    {
        $limit = (int) config('memories.max_media');
        if (count($layout) > $limit) {
            throw ValidationException::withMessages(['media' => 'En fazla '.$limit.' fotoğraf ekleyebilirsin.']);
        }
        $existing = $memory?->media->keyBy('id') ?? collect();
        $sourceMedia = collect($source['media'] ?? [])->keyBy('ref');
        $diskName = config('mobile.post_media_disk');
        $seen = [];
        $rows = [];
        foreach ($layout as $order => $token) {
            isset($seen[$token]) && $this->invalidLayout();
            $seen[$token] = true;
            $id = (int) substr($token, 1);
            if ($token[0] === 'm') {
                $existing->has($id) || $this->invalidLayout();
                $rows[] = ['keep' => $id, 'sort_order' => $order];

                continue;
            }
            if ($token[0] === 'n') {
                isset($files[$id]) || $this->invalidLayout();
                $encoded = PrivateImage::jpeg($files[$id], 'media');
            } else {
                $sourceMedia->has($token) || $this->invalidLayout();
                $bytes = MemorySources::read($sourceMedia[$token]);
                $bytes ?? throw ValidationException::withMessages(['media' => 'Fotoğraf okunamadı.']);
                $encoded = PrivateImage::jpegFromBytes($bytes, 'media');
            }
            [$bytes, $width, $height] = $encoded;
            [$thumb] = PrivateImage::thumbnail($bytes, (int) config('memories.thumb_edge'));
            $disk = Storage::disk($diskName);
            $path = 'memories/'.Str::uuid().'.jpg';
            $thumbPath = 'memories/'.Str::uuid().'.jpg';
            $written[] = $path;
            abort_unless($disk->put($path, $bytes, 'private'), 503);
            $written[] = $thumbPath;
            abort_unless($disk->put($thumbPath, $thumb, 'private'), 503);
            $rows[] = ['disk' => $diskName, 'path' => $path, 'thumb_path' => $thumbPath, 'sort_order' => $order, 'width' => $width,
                'height' => $height, 'aspect_ratio' => round($width / max(1, $height), 4), 'mime_type' => 'image/jpeg'];
        }

        return $rows;
    }

    private function invalidLayout(): never
    {
        throw ValidationException::withMessages(['layout' => 'Fotoğraf düzeni geçersiz.']);
    }

    /** @param  list<array<string,mixed>>  $rows */
    private function saveMedia(Memory $memory, array $rows): void
    {
        foreach ($rows as $row) {
            if (isset($row['keep'])) {
                MemoryMedia::whereKey($row['keep'])->where('memory_id', $memory->id)->update(['sort_order' => $row['sort_order']]);

                continue;
            }
            $memory->media()->create($row);
        }
    }

    /** @param  list<string>  $paths */
    private function discard(array $paths): void
    {
        if ($paths !== []) {
            Storage::disk(config('mobile.post_media_disk'))->delete($paths);
        }
    }
}
