<?php

namespace App\Http\Controllers;

use App\Safety\Blocks;

use App\Http\ApiResponse;
use App\Location\Geo;
use App\Location\LocationData;
use App\Models\Post;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class LocationController extends Controller
{
    public function update(Request $request, LocationData $locations): JsonResponse
    {
        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'accuracy' => ['required', 'numeric', 'between:0,100000'],
            'history_only' => ['sometimes', 'boolean'],
            'record_history' => ['sometimes', 'boolean'],
        ]);
        $city = $locations->update($request->user(), $data + ['history_only' => false, 'record_history' => true]);

        return ApiResponse::ok(['city' => $city, 'manual_city_required' => $city === null && !$request->user()->active_city_id]);
    }

    public function selectCity(Request $request): JsonResponse
    {
        $data = $request->validate(PlaceController::rules());
        PlaceController::apply($data);
        $request->user()->forceFill(['active_city_id' => $data['city_id'], 'active_city_source' => 'manual'])->save();
        return ApiResponse::ok(['city' => DB::table('cities')->select('id', 'name', 'slug')->find($data['city_id'])]);
    }

    public function history(Request $request): JsonResponse
    {
        if (!$request->user()->location_history_enabled) return ApiResponse::ok(['items' => [], 'next_page' => null]);
        $page = DB::table('user_location_history as h')->join('cities', 'cities.id', '=', 'h.city_id')
            ->where('h.user_id', $request->user()->id)->where('h.recorded_at', '>=', LocationData::cutoff())
            ->orderByDesc('h.recorded_at')->orderByDesc('h.id')->select('h.id', 'h.city_id', 'cities.name', 'h.recorded_at')->simplePaginate(20);
        return ApiResponse::ok(['items' => collect($page->items())->map(fn ($item) => [
            'id' => $item->id, 'city_id' => $item->city_id, 'city_name' => $item->name,
            'label' => ApiResponse::localize($item->name.' · Yaklaşık bölge'),
            'recorded_at' => \Illuminate\Support\Carbon::parse($item->recorded_at)->startOfHour()->toISOString(),
        ]), 'next_page' => $page->hasMorePages() ? $page->currentPage()+1 : null]);
    }

    public function clear(Request $request): JsonResponse
    {
        DB::table('user_locations')->where('user_id', $request->user()->id)->delete();
        if ($request->user()->active_city_source === 'device') {
            $request->user()->forceFill(['active_city_id' => null, 'active_city_source' => null])->save();
        }

        return ApiResponse::ok();
    }

    public function nearby(Request $request): JsonResponse
    {
        $data = $request->validate([
            'radius' => ['sometimes', 'integer', 'between:100,25000'],
            'limit' => ['sometimes', 'integer', 'between:1,30'],
            'city_id' => ['sometimes', 'integer', Rule::exists('cities', 'id')->where('is_active', true)],
        ]);
        $viewer = $request->user();
        if (! app(\App\Administration\Settings::class)->get('nearby_enabled')) {
            return ApiResponse::ok(['items' => [], 'location_required' => false]);
        }
        $origin = LocationData::active($viewer);
        if (! $origin) {
            return ApiResponse::ok(['items' => [], 'location_required' => true]);
        }

        $radius = (int) ($data['radius'] ?? 10000);
        [$distance, $bindings] = Geo::expression($origin, 'l.latitude', 'l.longitude');
        $people = DB::table('user_locations as l')->join('users', 'users.id', '=', 'l.user_id')
            ->join('cities', 'cities.id', '=', 'l.city_id')
            ->where('l.user_id', '<>', $viewer->id)
            ->where('l.city_id', $data['city_id'] ?? $origin->city_id)
            ->where('l.visibility', true)->where('users.nearby_visible', true)
            ->where('users.account_status', 'active')
            ->where('l.recorded_at', '>=', now()->subMinutes(config('location.active_minutes')))
            ->select(['users.id', 'users.name', 'users.username', 'users.avatar',
                'cities.id as city_id', 'cities.name as city_name', 'cities.slug as city_slug']);
        Blocks::exclude($people, $viewer->id, 'users.id');
        Geo::bound($people, $origin, $radius, 'l.latitude', 'l.longitude');
        $limit = (int) ($data['limit'] ?? 20);
        // Distance stays the primary rule. Shared interests / compatible connection choices only reorder people who fall into
        // the same publicly shown distance step (100 m) and are never a filter, a label or a visible score.
        $candidates = $people->whereRaw("($distance) <= ?", [...$bindings, $radius])
            ->selectRaw("($distance) AS meters", $bindings)->selectRaw('users.connections AS connection_choices')
            ->orderBy('meters')->orderBy('users.id')->limit(max($limit * 4, 60))->get();
        $affinity = $this->discoveryAffinity($viewer, $candidates);
        $items = $candidates->sortBy(fn ($person) => [Geo::publicDistance($person->meters), -($affinity[$person->id] ?? 0), $person->meters, $person->id])
            ->take($limit)->values()->map(fn ($person) => [
                'id' => $person->id,
                'name' => $person->name,
                'username' => $person->username,
                'avatar' => $person->avatar ? route('avatars.show', ['filename' => basename($person->avatar)], false) : null,
                'city' => ['id' => $person->city_id, 'name' => $person->city_name, 'slug' => $person->city_slug],
                'distance_meters' => Geo::publicDistance($person->meters),
            ]);

        return ApiResponse::ok(['items' => $items, 'location_required' => false]);
    }

    /**
     * Internal, low-weight discovery signal (0..4): up to three shared interests plus one point when both people chose at least one
     * common "connections" preference. Never shown to anyone, never a filter: people with different choices are not hidden.
     *
     * @return array<int,int> user id => affinity
     */
    private function discoveryAffinity(User $viewer, $candidates): array
    {
        $ids = $candidates->pluck('id')->all();
        if ($ids === []) {
            return [];
        }
        $mine = DB::table('user_interests')->where('user_id', $viewer->id)->pluck('interest_id')->all();
        $shared = $mine === [] ? collect() : DB::table('user_interests')->whereIn('user_id', $ids)->whereIn('interest_id', $mine)
            ->selectRaw('user_id, COUNT(*) AS total')->groupBy('user_id')->pluck('total', 'user_id');
        $viewerChoices = (array) ($viewer->connections ?? []);
        $scores = [];
        foreach ($candidates as $person) {
            $choices = json_decode((string) ($person->connection_choices ?? '[]'), true) ?: [];
            $scores[$person->id] = min(3, (int) ($shared[$person->id] ?? 0)) + (array_intersect($viewerChoices, $choices) ? 1 : 0);
        }

        return $scores;
    }

    public function map(Request $request): JsonResponse
    {
        $data = $request->validate([
            'city_id' => ['sometimes', 'integer', Rule::exists('cities', 'id')->where('is_active', true)],
            'radius' => ['sometimes', 'integer', Rule::in([5000, 10000, 25000])],
            'sort' => ['sometimes', Rule::in(['new', 'popular'])],
            'use_location' => ['sometimes', 'boolean'],
        ]);
        $viewer = $request->user();
        $origin = ($data['use_location'] ?? true) ? LocationData::active($viewer) : null;
        $city = LocationData::city($viewer, $origin, $data['city_id'] ?? null);
        if (isset($data['radius']) && ! $origin) {
            return ApiResponse::ok(['items' => [], 'location_required' => true]);
        }

        $posts = Post::visibleTo($viewer)->where('posts.visibility', 'city')
            ->where('posts.city_id', $city)->whereNotNull('posts.approx_latitude')
            ->select(['posts.id', 'posts.approx_latitude', 'posts.approx_longitude']);
        if ($origin) {
            [$distance, $bindings] = Geo::expression($origin, 'posts.approx_latitude', 'posts.approx_longitude');
            $posts->selectRaw("($distance) AS meters", $bindings);
            if (isset($data['radius'])) {
                Geo::bound($posts, $origin, $data['radius'], 'posts.approx_latitude', 'posts.approx_longitude');
                $posts->whereRaw("($distance) <= ?", [...$bindings, $data['radius']]);
            }
        }
        if (($data['sort'] ?? '') === 'popular') {
            $posts->withCount(['likes', 'comments'])->orderByRaw('(likes_count + 2 * comments_count) DESC');
        }
        $items = $posts->latest()->orderByDesc('posts.id')->limit(80)->get()->map(fn (Post $post) => [
            'post_id' => $post->id,
            'latitude' => (float) $post->approx_latitude,
            'longitude' => (float) $post->approx_longitude,
            'distance_meters' => Geo::publicDistance($post->meters),
        ]);

        return ApiResponse::ok(['items' => $items, 'location_required' => false]);
    }
}
