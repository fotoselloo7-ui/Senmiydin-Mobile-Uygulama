<?php

namespace App\Http\Controllers;

use App\Http\ApiResponse;
use App\Models\Place;
use App\Places\PlaceDirectory;
use App\Places\PlaceProviderUnavailable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Places for the location picker. Public (the registration screens need it), throttled per caller, and the only way
 * the app reaches a place provider: the app never calls the provider itself.
 */
class PlaceController extends Controller
{
    private const UNAVAILABLE = 'Yer araması şu anda yapılamıyor. Biraz sonra tekrar dene.';

    public function search(Request $request, PlaceDirectory $places): JsonResponse
    {
        $data = $request->validate([
            'q' => ['required', 'string', 'min:2', 'max:80'],
            'country' => ['sometimes', 'nullable', 'string', 'size:2', 'alpha'],
        ]);
        try {
            $items = $places->search($data['q'], app()->getLocale(), isset($data['country']) ? strtolower($data['country']) : null);
        } catch (PlaceProviderUnavailable) {
            return ApiResponse::error(self::UNAVAILABLE, 503);
        }

        return ApiResponse::ok(['items' => $items, 'attribution' => config('places.attribution')]);
    }

    public function reverse(Request $request, PlaceDirectory $places): JsonResponse
    {
        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
        ]);
        try {
            $item = $places->reverse((float) $data['latitude'], (float) $data['longitude'], app()->getLocale());
        } catch (PlaceProviderUnavailable) {
            return ApiResponse::error(self::UNAVAILABLE, 503);
        }

        return ApiResponse::ok(['item' => $item, 'attribution' => config('places.attribution')]);
    }

    public function resolve(Request $request, PlaceDirectory $places): JsonResponse
    {
        $data = $request->validate(['token' => ['required', 'string', 'max:4000']]);
        $place = $places->resolve($data['token']);

        return ApiResponse::ok(self::chosen($place));
    }

    /** A stored place together with the area it belongs to. */
    public static function chosen(Place $place): array
    {
        return ['place' => $place->summary(), 'city' => $place->city->only('id', 'name', 'slug')];
    }

    /** Validation rules shared by every request that may carry a place instead of a bare city. */
    public static function rules(string $place = 'place_id', string $city = 'city_id', bool $required = true): array
    {
        return [
            $place => ['sometimes', 'nullable', 'integer', Rule::exists('places', 'id')],
            $city => [$required ? 'required_without:'.$place : 'sometimes', 'integer', Rule::exists('cities', 'id')->where('is_active', true)],
        ];
    }

    /** When a place was sent, its area is the city: the two can never disagree. */
    public static function apply(array &$data, string $place = 'place_id', string $city = 'city_id'): void
    {
        if (! empty($data[$place])) {
            $data[$city] = Place::whereKey($data[$place])->value('city_id');
        } elseif (array_key_exists($city, $data)) {
            $data[$place] = null;
        }
    }
}
