<?php

namespace App\Http\Controllers;

use App\Http\ApiResponse;
use App\Models\City;
use App\Models\Interest;
use Illuminate\Http\JsonResponse;

class CatalogController extends Controller
{
    public function cities(): JsonResponse
    {
        return ApiResponse::ok(\Illuminate\Support\Facades\Cache::remember('catalog:cities:v1', 300, fn () => City::where('is_active', true)->orderBy('name')->get(['id', 'name', 'slug', 'is_active'])->toArray()));
    }

    public function interests(): JsonResponse
    {
        return ApiResponse::ok(\Illuminate\Support\Facades\Cache::remember('catalog:interests:v1', 300, fn () => Interest::where('is_active', true)
            ->orderBy('sort_order')->get(['id', 'name', 'slug', 'icon', 'sort_order', 'is_active'])->toArray()));
    }
}
