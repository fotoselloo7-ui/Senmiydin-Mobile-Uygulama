<?php

namespace Database\Seeders;

use App\Location\Geo;
use App\Location\LocationData;
use App\Media\PrivateImage;
use App\Models\City;
use App\Models\Encounter;
use App\Models\EncounterRequest;
use App\Models\Interest;
use App\Models\Post;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class DemoDataSeeder extends Seeder
{
    public const LATITUDE = 36.544;

    public const LONGITUDE = 32.000;

    public function run(): void
    {
        if (! app()->environment('local', 'development')) {
            throw new \RuntimeException('Demo accounts require a local or development environment.');
        }

        $alanya = City::where('slug', 'alanya')->firstOrFail();
        $antalya = City::where('slug', 'antalya')->firstOrFail();
        $interests = Interest::orderBy('sort_order')->limit(6)->pluck('id');
        $people = [
            ['demo', 'Demo Kullanıcı', 36.544, 32.000, 'Şehirdeki küçük ayrıntıları ve sahil yürüyüşlerini seviyorum.'],
            ['ahmet', 'Ahmet D.', 36.544, 32.004, 'Sahilde bu akşam hava çok güzeldi.'],
            ['elif', 'Elif B.', 36.548, 32.005, 'Sabah kahvemi sahile karşı içtim.'],
            ['deniz', 'Deniz A.', 36.550, 32.012, 'Bisikletle şehir turu yaptım.'],
            ['zeynep', 'Zeynep D.', 36.563, 32.023, 'Bugün yeni bir yürüyüş rotası buldum.'],
            ['kaan', 'Kaan Y.', 36.555, 32.047, 'Deniz kenarında bir kitap bitirdim.'],
            ['selin', 'Selin K.', 36.562, 32.065, 'Akşam ışığı görülmeye değerdi.'],
            ['mert', 'Mert A.', 36.580, 32.080, 'Şehirden uzaklaşınca sessizlik iyi geldi.'],
            ['ece', 'Ece Y.', 36.594, 32.092, 'Yeni bir kahve molası noktası keşfettim.'],
            ['burak', 'Burak S.', 36.578, 32.115, 'Güneş batarken yola çıktım.'],
            ['ceren', 'Ceren A.', 36.615, 32.120, 'Bugün şehir manzarasını fotoğrafladım.'],
            ['duru', 'Duru Ç.', 36.620, 32.145, 'Hafta sonu gezisi kısa ama güzeldi.'],
            ['arda', 'Arda E.', 36.888, 30.707, 'Antalya’da sahil yürüyüşü.'],
            ['elifdemo', 'Elif B.', 36.548, 32.006, 'Sahile yakın bir kahve molası.'],
        ];

        foreach ($people as $index => [$handle, $name, $latitude, $longitude, $body]) {
            $username = match ($handle) {
                'demo', 'elifdemo' => $handle,
                default => 'demo_'.$handle,
            };
            $email = ($handle === 'elifdemo' ? 'elif' : $username).'@senmiydin.local';
            $city = $handle === 'arda' ? $antalya : $alanya;
            $existing = User::where('username', $username)->first();
            if ($existing && $existing->email !== $email) {
                throw new \RuntimeException("Demo username is already in use: $username");
            }
            $user = $existing ?? new User(['username' => $username, 'email' => $email, 'password' => 'Demo1234!']);
            $uuid = sprintf('d3000000-0000-4000-8000-%012d', $index + 1);
            $avatar = 'avatars/'.$uuid.'.jpg';
            $source = dirname(base_path()).'/assets/images/user_'.($handle === 'elifdemo' ? 1 : $index % 12).'.jpg';
            if (is_file($source)) {
                Storage::disk(config('mobile.avatar_disk'))->put($avatar, file_get_contents($source));
            } else {
                $avatar = null;
            }
            $user->forceFill([
                'name' => $name, 'city_id' => $city->id, 'birth_date' => '1995-04-12',
                'avatar' => $avatar, 'bio' => $index === 0 ? $body : 'Kahve, müzik ve şehir yürüyüşleri.',
                'nearby_visible' => true, 'city_discovery' => true, 'encounter_suggestions' => true,
                'onboarding_step' => 3, 'location_history_enabled' => false,
            ])->save();
            $user->interests()->sync($interests);
            LocationData::clearHistory($user->id);
            DB::table('user_locations')->upsert([[
                'user_id' => $user->id, 'city_id' => $city->id,
                'latitude' => $latitude, 'longitude' => $longitude, 'accuracy' => 35,
                'recorded_at' => now(), 'visibility' => true, 'created_at' => now(), 'updated_at' => now(),
            ]], ['user_id'], ['city_id', 'latitude', 'longitude', 'accuracy', 'recorded_at', 'visibility', 'updated_at']);

            if ($index === 0) {
                continue;
            }
            $post = Post::withTrashed()->firstOrNew(['user_id' => $user->id, 'request_id' => $uuid]);
            if (! $post->exists) {
                $grid = config('location.post_grid');
                $post->forceFill([
                    'body' => $body, 'type' => 'moment', 'city_id' => $city->id, 'visibility' => 'city',
                    'approx_latitude' => Geo::grid($latitude, $grid),
                    'approx_longitude' => Geo::grid($longitude, $grid),
                ])->save();
            }
        }
        $this->stories($alanya->id);
    }

    private function stories(int $city): void
    {
        $demo = User::where('email', 'demo@senmiydin.local')->firstOrFail();
        $elif = User::where('email', 'elif@senmiydin.local')->firstOrFail();
        foreach ([
            ['d4000000-0000-4000-8000-000000000001', 'd4000000-0000-4000-8000-000000000002',
                'Sahilde ikinci merhaba', 'Deniz kenarında yürürken yeniden karşılaştık.', []],
            ['d4000000-0000-4000-8000-000000000003', 'd4000000-0000-4000-8000-000000000004',
                'Birlikte bir sahil yürüyüşü', 'Gün batımında yollarımız yeniden kesişti.', ['coast.jpg', 'sunset.jpg']],
        ] as $index => [$sourceKey, $storyKey, $title, $body, $photos]) {
            $sourceBody = $index === 0
                ? 'Alanya sahilinde selamlaştığımız o akşamı hatırlıyorum.'
                : 'İskelede gün batımını izlerken yollarımız kesişti.';
            $source = Post::withTrashed()->firstOrCreate(['user_id' => $demo->id, 'request_id' => $sourceKey], [
                'city_id' => $city, 'type' => 'encounter', 'body' => $sourceBody,
                'visibility' => 'city', 'is_anonymous' => false,
            ]);
            if ($source->trashed()) {
                continue;
            }
            if ($source->body === 'Bir sahil yürüyüşünde yollarımız kesişti.') {
                $source->forceFill(['body' => $sourceBody])->save();
            }
            $request = EncounterRequest::firstOrCreate(['source_post_id' => $source->id], [
                'requester_id' => $demo->id, 'target_user_id' => $elif->id, 'status' => 'accepted', 'responded_at' => now(),
            ]);
            if ($request->requester_id !== $demo->id || $request->target_user_id !== $elif->id) {
                throw new \RuntimeException('Canonical encounter ownership differs.');
            }
            $encounter = Encounter::firstOrCreate(['request_id' => $request->id], ['confirmed_at' => now()]);
            if (Post::withTrashed()->where('user_id', $demo->id)->where('request_id', $storyKey)->exists()) {
                continue;
            }
            $story = new Post(['user_id' => $demo->id, 'request_id' => $storyKey, 'city_id' => $city, 'body' => $body,
                'type' => 'encounter', 'visibility' => 'city', 'is_anonymous' => false]);
            $story->forceFill(['encounter_id' => $encounter->id, 'story_title' => $title, 'story_status' => 'published',
                'story_revision' => 1, 'featured_rank' => $index + 1])->save();
            foreach ($photos as $order => $name) {
                $file = dirname(base_path()).'/assets/images/'.$name;
                if (! is_file($file)) {
                    continue;
                }
                [$bytes,$width,$height] = PrivateImage::jpeg(new UploadedFile($file, $name, null, null, true), 'media');
                $path = 'posts/'.Str::uuid().'.jpg';
                $disk = config('mobile.post_media_disk');
                Storage::disk($disk)->put($path, $bytes, 'private');
                $story->media()->create(['file_path' => $path, 'disk' => $disk, 'sort_order' => $order,
                    'width' => $width, 'height' => $height, 'mime_type' => 'image/jpeg']);
            }
        }
    }
}
