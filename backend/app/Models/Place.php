<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A real place somebody picked: a neighbourhood, suburb, village, town, city or province, inside one area (`cities`).
 * Coordinates are the public centre of the place itself; a person's own position is never stored here.
 */
class Place extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return ['labels' => 'array', 'latitude' => 'float', 'longitude' => 'float'];
    }

    public function city(): BelongsTo
    {
        return $this->belongsTo(City::class);
    }

    /**
     * Texts for one place: its own name, the hierarchy above it ("Alanya · Antalya · Türkiye") and a compact label
     * ("Oba Mahallesi, Alanya, Antalya"). Built only from what the provider returned; nothing is translated here.
     *
     * @param  array{name:string,suburb?:?string,locality?:?string,admin1?:?string,country?:?string}  $parts
     * @return array{name:string,context:string,label:string}
     */
    public static function describe(array $parts): array
    {
        $name = $parts['name'];
        $seen = [mb_strtolower($name) => true];
        $chain = [];
        foreach (['suburb', 'locality', 'admin1', 'country'] as $level) {
            $value = trim((string) ($parts[$level] ?? ''));
            if ($value === '' || isset($seen[mb_strtolower($value)])) {
                continue;
            }
            $seen[mb_strtolower($value)] = true;
            $chain[$level] = $value;
        }
        $label = array_slice(array_values(array_filter([$name, $chain['locality'] ?? null, $chain['admin1'] ?? null])), 0, 3);
        if (count($label) < 3 && isset($chain['country'])) {
            $label[] = $chain['country'];
        }

        return ['name' => $name, 'context' => implode(' · ', $chain), 'label' => implode(', ', $label)];
    }

    /** @return array{name:string,context:string,label:string} */
    public function display(?string $locale = null): array
    {
        return $this->labels[$locale ?? app()->getLocale()] ?? self::describe([
            'name' => $this->name, 'suburb' => $this->suburb, 'locality' => $this->locality,
            'admin1' => $this->admin1, 'country' => $this->country_name,
        ]);
    }

    /** The shape every API response uses for a place. */
    public function summary(): array
    {
        return ['id' => $this->id, 'type' => $this->type, 'country_code' => $this->country_code] + $this->display();
    }
}
