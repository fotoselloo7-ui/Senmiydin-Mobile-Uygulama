<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $cities = explode('|', 'Adana|Adıyaman|Afyonkarahisar|Ağrı|Amasya|Ankara|Antalya|Artvin|Aydın|Balıkesir|Bilecik|Bingöl|Bitlis|Bolu|Burdur|Bursa|Çanakkale|Çankırı|Çorum|Denizli|Diyarbakır|Edirne|Elazığ|Erzincan|Erzurum|Eskişehir|Gaziantep|Giresun|Gümüşhane|Hakkâri|Hatay|Isparta|Mersin|İstanbul|İzmir|Kars|Kastamonu|Kayseri|Kırklareli|Kırşehir|Kocaeli|Konya|Kütahya|Malatya|Manisa|Kahramanmaraş|Mardin|Muğla|Muş|Nevşehir|Niğde|Ordu|Rize|Sakarya|Samsun|Siirt|Sinop|Sivas|Tekirdağ|Tokat|Trabzon|Tunceli|Şanlıurfa|Uşak|Van|Yozgat|Zonguldak|Aksaray|Bayburt|Karaman|Kırıkkale|Batman|Şırnak|Bartın|Ardahan|Iğdır|Yalova|Karabük|Kilis|Osmaniye|Düzce|Alanya');
        DB::table('cities')->upsert(array_map(fn ($name) => [
            'name' => $name, 'slug' => Str::slug($name, '-', 'tr'),
        ], $cities), ['slug'], ['name']);
        \App\Places\Areas::describeLegacy();

        $interests = [
            'Kahve' => 'coffee', 'Müzik' => 'music', 'Kitap' => 'book', 'Seyahat' => 'travel',
            'Sahil yürüyüşü' => 'walk', 'Sinema' => 'film', 'Fotoğraf' => 'camera',
            'Fitness' => 'fitness', 'Kamp' => 'camp', 'Yemek' => 'food', 'Bisiklet' => 'bike',
            'Kediler' => 'cat', 'Köpekler' => 'dog', 'Oyun' => 'game',
            'Girişimcilik' => 'business', 'Teknoloji' => 'technology', 'Sanat' => 'art',
            'Doğa' => 'nature', 'Spor' => 'sports', 'Etkinlik' => 'event', 'Gece yürüyüşü' => 'night-walk',
        ];

        $rows = [];
        foreach ($interests as $name => $icon) {
            $rows[] = ['name' => $name, 'slug' => Str::slug($name, '-', 'tr'), 'icon' => $icon, 'sort_order' => count($rows)];
        }
        DB::table('interests')->upsert($rows, ['slug'], ['name', 'icon', 'sort_order']);
    }
}
