<?php

namespace App\Http\Controllers;

use App\Http\ApiResponse;
use App\Http\Resources\PostResource;
use App\Models\Post;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Private saved collections ("Sonra Bak", "Alanya", ...). They only group posts the user already saved:
 * nothing here is visible to anyone else and deleting a collection never un-saves a post.
 */
class SavedCollectionController extends Controller
{
    public const MAX_PER_USER = 30;

    public const MAX_NAME = 40;

    public function index(Request $request): JsonResponse
    {
        $viewer = $request->user();
        $data = $request->validate(['post_id' => ['sometimes', 'integer']]);
        $collections = DB::table('saved_collections')->where('user_id', $viewer->id)->orderBy('name_key')->orderBy('id')->get();
        $containing = isset($data['post_id'])
            ? DB::table('saved_collection_posts')->where('post_id', $data['post_id'])->whereIn('collection_id', $collections->pluck('id'))->pluck('collection_id')->flip()
            : collect();

        return ApiResponse::ok([
            'items' => $collections->map(fn ($collection) => $this->present($viewer, $collection, isset($data['post_id']) ? $containing->has($collection->id) : null))->values(),
            'limit' => self::MAX_PER_USER,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $viewer = $request->user();
        $name = $this->name($request);
        $id = DB::transaction(function () use ($viewer, $name): int {
            User::whereKey($viewer->id)->lockForUpdate()->firstOrFail();
            if (DB::table('saved_collections')->where('user_id', $viewer->id)->count() >= self::MAX_PER_USER) {
                throw ValidationException::withMessages(['name' => 'En fazla '.self::MAX_PER_USER.' koleksiyon oluşturabilirsin.']);
            }
            $this->assertFree($viewer, $name);
            try {
                return DB::table('saved_collections')->insertGetId([
                    'user_id' => $viewer->id, 'name' => $name, 'name_key' => $this->key($name), 'created_at' => now(), 'updated_at' => now(),
                ]);
            } catch (QueryException) {
                throw ValidationException::withMessages(['name' => 'Bu isimde bir koleksiyonun zaten var.']);
            }
        });

        return ApiResponse::ok($this->present($viewer, DB::table('saved_collections')->find($id)), 'Koleksiyon oluşturuldu.', 201);
    }

    public function update(Request $request, int $collection): JsonResponse
    {
        $viewer = $request->user();
        $name = $this->name($request);
        DB::transaction(function () use ($viewer, $collection, $name): void {
            User::whereKey($viewer->id)->lockForUpdate()->firstOrFail();
            $this->own($viewer, $collection);
            $this->assertFree($viewer, $name, $collection);
            try {
                DB::table('saved_collections')->where('id', $collection)->update(['name' => $name, 'name_key' => $this->key($name), 'updated_at' => now()]);
            } catch (QueryException) {
                throw ValidationException::withMessages(['name' => 'Bu isimde bir koleksiyonun zaten var.']);
            }
        });

        return ApiResponse::ok($this->present($viewer, DB::table('saved_collections')->find($collection)), 'Koleksiyon güncellendi.');
    }

    /** Removes the collection and its groupings only. The posts stay in the main Kaydedilenler list. */
    public function destroy(Request $request, int $collection): JsonResponse
    {
        $viewer = $request->user();
        DB::transaction(function () use ($viewer, $collection): void {
            $this->own($viewer, $collection);
            DB::table('saved_collection_posts')->where('collection_id', $collection)->delete();
            DB::table('saved_collections')->where('id', $collection)->delete();
        });

        return ApiResponse::ok(message: 'Koleksiyon silindi. Gönderiler Kaydedilenler’de duruyor.');
    }

    public function posts(Request $request, int $collection): JsonResponse
    {
        $viewer = $request->user();
        $this->own($viewer, $collection);
        $posts = Post::visibleTo($viewer)->forViewer($viewer)
            ->join('saved_collection_posts as in_collection', fn ($join) => $join->on('posts.id', '=', 'in_collection.post_id')
                ->where('in_collection.collection_id', $collection))
            ->join('post_saves as viewer_saves', fn ($join) => $join->on('posts.id', '=', 'viewer_saves.post_id')
                ->where('viewer_saves.user_id', $viewer->id))
            ->orderByDesc('in_collection.created_at')->orderByDesc('posts.id');

        return ApiResponse::page($posts->simplePaginate(20), PostResource::class);
    }

    /** A post can sit in several collections, but only a post the user saved can be added. */
    public function add(Request $request, int $collection, int $post): JsonResponse
    {
        $viewer = $request->user();
        DB::transaction(function () use ($viewer, $collection, $post): void {
            $this->own($viewer, $collection);
            $entry = Post::visibleTo($viewer)->lockForUpdate()->findOrFail($post);
            abort_if($entry->encounter_id && $entry->story_status !== Post::STORY_PUBLISHED, 403);
            if (! DB::table('post_saves')->where(['user_id' => $viewer->id, 'post_id' => $post])->exists()) {
                throw ValidationException::withMessages(['post' => 'Önce gönderiyi kaydetmelisin.']);
            }
            DB::table('saved_collection_posts')->insertOrIgnore(['collection_id' => $collection, 'post_id' => $post, 'created_at' => now()]);
        });

        return ApiResponse::ok($this->present($viewer, DB::table('saved_collections')->find($collection), true));
    }

    /** Leaving a collection never un-saves the post. */
    public function remove(Request $request, int $collection, int $post): JsonResponse
    {
        $viewer = $request->user();
        $this->own($viewer, $collection);
        DB::table('saved_collection_posts')->where(['collection_id' => $collection, 'post_id' => $post])->delete();

        return ApiResponse::ok($this->present($viewer, DB::table('saved_collections')->find($collection), false));
    }

    private function name(Request $request): string
    {
        $data = $request->validate(['name' => ['required', 'string', 'max:'.(self::MAX_NAME * 4)]], [
            'name.required' => 'Koleksiyona bir ad ver.',
        ]);
        $name = trim(preg_replace('/\s+/u', ' ', $data['name']));
        if ($name === '') {
            throw ValidationException::withMessages(['name' => 'Koleksiyona bir ad ver.']);
        }
        if (mb_strlen($name) > self::MAX_NAME) {
            throw ValidationException::withMessages(['name' => 'Koleksiyon adı en fazla '.self::MAX_NAME.' karakter olabilir.']);
        }

        return $name;
    }

    private function key(string $name): string
    {
        return mb_strtolower($name);
    }

    private function assertFree(User $viewer, string $name, ?int $except = null): void
    {
        $taken = DB::table('saved_collections')->where('user_id', $viewer->id)->where('name_key', $this->key($name))
            ->when($except, fn ($query) => $query->where('id', '<>', $except))->exists();
        if ($taken) {
            throw ValidationException::withMessages(['name' => 'Bu isimde bir koleksiyonun zaten var.']);
        }
    }

    /** Collections are private: somebody else's id is indistinguishable from a missing one. */
    private function own(User $viewer, int $collection): object
    {
        return DB::table('saved_collections')->where(['id' => $collection, 'user_id' => $viewer->id])->first() ?? abort(404);
    }

    private function present(User $viewer, object $collection, ?bool $contains = null): array
    {
        // Counts only what the viewer can still open (deleted, moderated, blocked and suspended posts are not counted).
        $count = Post::visibleTo($viewer)
            ->whereIn('posts.id', DB::table('saved_collection_posts')->where('collection_id', $collection->id)->select('post_id'))
            ->whereIn('posts.id', DB::table('post_saves')->where('user_id', $viewer->id)->select('post_id'))
            ->count();

        return [
            'id' => $collection->id,
            'name' => $collection->name,
            'posts_count' => $count,
            ...($contains === null ? [] : ['contains_post' => $contains]),
            'created_at' => \Illuminate\Support\Carbon::parse($collection->created_at, 'UTC')->toISOString(),
        ];
    }
}
