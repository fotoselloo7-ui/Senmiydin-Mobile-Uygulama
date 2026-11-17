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

    /** The area name in the request language when the provider gave one for it; otherwise the stored name. */
    protected function name(): Attribute
    {
        return Attribute::get(function (?string $value, array $attributes) {
            $labels = json_decode($attributes['labels'] ?? 'null', true);

            return $labels[app()->getLocale()]['name'] ?? $value;
        });
    }
}
