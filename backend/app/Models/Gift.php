<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/** One entry of the server-controlled gift catalog. Clients may only send the slug of an active entry. */
class Gift extends Model
{
    protected $fillable = ['slug', 'name_tr', 'name_en', 'asset', 'is_active', 'sort_order', 'price_minor', 'currency'];

    protected function casts(): array
    {
        return ['is_active' => 'boolean', 'sort_order' => 'integer', 'price_minor' => 'integer'];
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true)->orderBy('sort_order')->orderBy('id');
    }

    /** Name in the request language (Turkish unless the account/header says English). */
    public function name(): string
    {
        return app()->getLocale() === 'en' && filled($this->name_en) ? $this->name_en : $this->name_tr;
    }

    public function toApi(): array
    {
        return ['slug' => $this->slug, 'name' => $this->name(), 'asset' => $this->asset,
            'price_minor' => $this->price_minor, 'currency' => $this->currency];
    }
}
