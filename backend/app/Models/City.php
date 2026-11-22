<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Model;

/**
 * An area: the unit feeds, the map and "nearby" are scoped to. Rows without a provider are the original Turkish
 * catalogue; the others were created from a place provider (see App\Places\Areas).
 */
class City extends Model
{
    public $timestamps = false;

    protected $guarded = [];

    protected $casts = ['is_active' => 'boolean', 'labels' => 'array', 'latitude' => 'float', 'longitude' => 'float'];

    /**
     * The areas a picked place covers. A province-level place (Antalya: its name is its province) covers every district
     * and neighbourhood record of that province, so choosing it shows the whole province; a district (Alanya) covers
     * only itself, so searching and filtering it never shows its neighbours.
     *
     * @return list<int>
     */
    public static function coveredIds(int $id): array
    {
        $city = static::query()->find($id);
        if (! $city) {
            return [$id];
        }
        $province = (string) $city->admin1;
        $own = (string) $city->getRawOriginal('name');
        if ($province === '' || $city->country_code === null
            || \Illuminate\Support\Str::slug($own, '-', 'tr') !== \Illuminate\Support\Str::slug($province, '-', 'tr')) {
            return [$id];
        }

        return array_map('intval', static::query()->where('country_code', $city->country_code)
            ->where('admin1', $province)->where('is_active', true)->pluck('id')->push($id)->unique()->values()->all());
    }

    /** The area name in the request language when the provider gave one for it; otherwise the stored name. */
    protected function name(): Attribute
    {
        return Attribute::get(function (?string $value, array $attributes) {
            $labels = json_decode($attributes['labels'] ?? 'null', true);

            return $labels[app()->getLocale()]['name'] ?? $value;
        });
    }
}
