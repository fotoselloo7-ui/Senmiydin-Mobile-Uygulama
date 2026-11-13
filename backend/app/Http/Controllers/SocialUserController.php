<?php

namespace App\Http\Controllers;

use App\Http\ApiResponse;
use App\Http\Resources\PostResource;
use App\Http\Resources\PublicUserResource;
use App\Models\EncounterRequest;
use App\Models\Post;
use App\Models\User;
use App\Notifications\Inbox;
use App\Safety\Blocks;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class SocialUserController extends Controller
{
    public function show(Request $request, string $username): JsonResponse
    {
        $viewer = $request->user();
        $user = $this->activeUsers($viewer)->with(['city', 'interests'])
            ->withCount([
                'posts' => fn (Builder $posts) => $posts->publishedOrOrdinary()->where(fn (Builder $visible) => $visible
                    ->where('user_id', $viewer->id)
                    ->orWhere(fn (Builder $public) => $public->where('is_anonymous', false)->where('visibility', 'city'))),
                'followers' => fn (Builder $users) => $users->where('account_status', 'active'),
                'following' => fn (Builder $users) => $users->where('account_status', 'active'),
            ])
            ->selectSub(EncounterRequest::query()->selectRaw('COUNT(*)')
                ->where('status', EncounterRequest::ACCEPTED)
                ->where(fn (Builder $pair) => $pair->whereColumn('requester_id', 'users.id')
                    ->orWhereColumn('target_user_id', 'users.id')), 'encounter_count')
            ->where('username', Str::lower($username))->firstOrFail();

        return ApiResponse::ok(new PublicUserResource($user));
    }

    public function posts(Request $request, string $username): JsonResponse
    {
        $viewer = $request->user();
        $owner = $this->find($username, $request->user());
        $posts = $owner->posts()->visibleTo($viewer)->publishedOrOrdinary()->forViewer($viewer);
        if ($owner->id !== $viewer->id) {
            $posts->where('is_anonymous', false)->where('visibility', 'city');
        }

        return ApiResponse::page($posts->latest()->orderByDesc('id')->simplePaginate(20), PostResource::class);
    }

    public function follow(Request $request, string $username): JsonResponse
    {
        $viewer = $request->user();
        $target = $this->find($username, $request->user());
        if ($viewer->id === $target->id) {
            throw ValidationException::withMessages(['username' => 'Kendi hesabını takip edemezsin.']);
        }
        $key = ['follower_id' => $viewer->id, 'followed_id' => $target->id];
        DB::transaction(function () use ($viewer, $target, $request, $key): void {
            Blocks::lockPair($viewer->id, $target->id);
            abort_if(Blocks::between($viewer->id, $target->id), 403);
            if ($request->isMethod('DELETE')) {
                DB::table('user_follows')->where($key)->delete();
            } elseif (DB::table('user_follows')->insertOrIgnore([...$key, 'created_at' => now()])) {
                Inbox::add($target->id, $viewer->id, 'follow', $viewer->id);
            }
        });

        return $this->show($request, $username);
    }

    public function followers(Request $request, string $username): JsonResponse
    {
        return $this->connections($request, $username, 'followers');
    }

    public function following(Request $request, string $username): JsonResponse
    {
        return $this->connections($request, $username, 'following');
    }

    private function connections(Request $request, string $username, string $relation): JsonResponse
    {
        $users = $this->find($username, $request->user())->{$relation}()->with('city')->where('account_status', 'active')
            ->withExists(['followers as followed_by_viewer' => fn (Builder $followers) => $followers->where($followers->qualifyColumn('id'), $request->user()->id)])
            ->orderBy('users.id');

        Blocks::exclude($users->getQuery(), $request->user()->id, 'users.id');
        return ApiResponse::page($users->simplePaginate(20), PublicUserResource::class);
    }

    public function search(Request $request): JsonResponse
    {
        $data = $request->validate([
            'q' => ['required', 'string', 'min:2', 'max:80'],
            'type' => ['required', Rule::in(['users', 'posts'])],
            'encounter' => ['sometimes', 'boolean'],
            'city_id' => ['sometimes', 'integer', Rule::exists('cities', 'id')->where('is_active', true)],
        ], ['q.min' => 'En az iki karakter gir.']);
        $viewer = $request->user();
        $query = Str::lower(ltrim($data['q'], '@'));
        if (mb_strlen($query) < 2) {
            throw ValidationException::withMessages(['q' => 'En az iki karakter gir.']);
        }
        $pattern = str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $query);
        if ($data['type'] === 'users') {
            $users = $this->activeUsers($viewer)->with('city')
                ->where(fn (Builder $matches) => $matches
                    ->whereRaw("username LIKE ? ESCAPE '!'", [$pattern.'%'])
                    ->orWhereRaw("LOWER(name) LIKE ? ESCAPE '!'", ['%'.$pattern.'%']));
            if ($data['encounter'] ?? false) {
                $users->whereKeyNot($viewer->id)
                    ->orderByRaw("CASE WHEN username = ? THEN 0 WHEN username LIKE ? ESCAPE '!' THEN 1 ELSE 2 END",
                        [$query, $pattern.'%']);
                return ApiResponse::ok([
                    'items' => PublicUserResource::collection($users->orderBy('username')->limit(20)->get()),
                    'next_page' => null,
                ]);
            }
            $users->orderBy('username');

            return ApiResponse::page($users->simplePaginate(20), PublicUserResource::class);
        }

        $posts = Post::visibleTo($viewer)->forViewer($viewer)->where('visibility', 'city')
            ->where('city_id', $data['city_id'] ?? $viewer->city_id)
            ->whereRaw("LOWER(body) LIKE ? ESCAPE '!'", ['%'.$pattern.'%'])
            ->latest()->orderByDesc('id');

        return ApiResponse::page($posts->simplePaginate(20), PostResource::class);
    }

    private function activeUsers(User $viewer): Builder
    {
        return Blocks::exclude(User::where('account_status', 'active'), $viewer->id, 'users.id')->withExists([
            'followers as followed_by_viewer' => fn (Builder $users) => $users->where($users->qualifyColumn('id'), $viewer->id),
        ]);
    }

    private function find(string $username, User $viewer): User
    {
        return $this->activeUsers($viewer)->where('username', Str::lower($username))->firstOrFail();
    }
}
