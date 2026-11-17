<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\Place;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Global places: search / reverse / resolve through the provider abstraction (a faked Nominatim), the area model on
 * top of the old city catalogue, and the places carried by accounts, posts and journeys.
 */
class PlacesApiTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    /** Queries the fake provider received, as "path language query". */
    private array $calls = [];

    protected function setUp(): void
    {
        parent::setUp();
        config(['places.provider' => 'nominatim', 'places.nominatim.min_interval_ms' => 0]);
        Http::preventStrayRequests();
        Http::fake(['nominatim.openstreetmap.org/*' => function (Request $request) {
            $path = parse_url($request->url(), PHP_URL_PATH);
            $language = $request['accept-language'];
            $this->calls[] = trim($path.' '.$language.' '.($request['q'] ?? $request['osm_ids'] ?? $request['lat'].','.$request['lon']));
            $this->assertStringContainsString('SenMiydin', $request->header('User-Agent')[0]);

            return Http::response(match ($path) {
                '/search' => self::results(mb_strtolower($request['q']), $language),
                '/lookup' => array_values(array_filter(array_map(fn ($id) => self::byId($id, $language), explode(',', $request['osm_ids'])))),
                '/reverse' => $request['zoom'] == 10 ? self::berlin($language) : self::item('relation', 6002883, 'village', 16, 'Oba Mahallesi', 36.5512, 32.0345,
                    ['village' => 'Oba Mahallesi', 'town' => 'Alanya', 'province' => 'Antalya', 'country' => 'Türkiye', 'country_code' => 'tr']),
                default => [],
            });
        }]);
    }

    private static function item(string $osmType, int $id, string $type, int $rank, string $name, float $lat, float $lng, array $address, string $category = 'boundary'): array
    {
        return ['osm_type' => $osmType, 'osm_id' => $id, 'category' => $category, 'type' => 'administrative', 'addresstype' => $type,
            'place_rank' => $rank, 'name' => $name, 'lat' => (string) $lat, 'lon' => (string) $lng, 'address' => $address];
    }

    private static function london(string $language): array
    {
        return $language === 'tr'
            ? self::item('relation', 175342, 'city', 10, 'Londra', 51.5074, -0.1278, ['city' => 'Londra', 'state' => 'İngiltere', 'country' => 'Birleşik Krallık', 'country_code' => 'gb'])
            : self::item('relation', 175342, 'city', 10, 'London', 51.5074, -0.1278, ['city' => 'London', 'state' => 'England', 'country' => 'United Kingdom', 'country_code' => 'gb']);
    }

    private static function berlin(string $language): array
    {
        return self::item('relation', 62422, 'city', 8, 'Berlin', 52.5170, 13.3889, ['city' => 'Berlin', 'country' => $language === 'tr' ? 'Almanya' : 'Germany', 'country_code' => 'de']);
    }

    private static function byId(string $id, string $language): ?array
    {
        return ['R175342' => self::london($language), 'R62422' => self::berlin($language)][$id] ?? null;
    }

    private static function results(string $query, string $language): array
    {
        $turkey = ['region' => 'Akdeniz Bölgesi', 'country' => 'Türkiye', 'country_code' => 'tr'];

        return match (true) {
            str_contains($query, 'oba') => [
                self::item('relation', 6002883, 'village', 16, 'Oba Mahallesi', 36.55123, 32.03456, ['village' => 'Oba Mahallesi', 'town' => 'Alanya', 'province' => 'Antalya'] + $turkey),
                // A shop, a street and a whole country are not places a person lives in or meets at.
                self::item('node', 99, 'shop', 30, 'Oba Market', 36.55, 32.03, ['shop' => 'Oba Market', 'town' => 'Alanya', 'province' => 'Antalya'] + $turkey, 'shop'),
                self::item('way', 98, 'road', 26, 'Oba Caddesi', 36.55, 32.03, ['road' => 'Oba Caddesi', 'town' => 'Alanya', 'province' => 'Antalya'] + $turkey, 'highway'),
            ],
            str_contains($query, 'mahmutlar') => [
                self::item('node', 252135488, 'village', 19, 'Mahmutlar', 36.4871, 32.0997, ['village' => 'Mahmutlar', 'town' => 'Alanya', 'province' => 'Antalya'] + $turkey, 'place'),
                self::item('node', 1480924499, 'village', 19, 'Mahmutlar', 40.1, 31.9, ['village' => 'Mahmutlar', 'town' => 'Beypazarı', 'province' => 'Ankara', 'country' => 'Türkiye', 'country_code' => 'tr'], 'place'),
            ],
            str_contains($query, 'alanya') => [
                self::item('relation', 1, 'town', 12, 'Alanya', 36.5438, 31.9998, ['town' => 'Alanya', 'province' => 'Antalya'] + $turkey),
                self::item('node', 2, 'town', 16, 'Alanya', 36.5440, 32.0000, ['town' => 'Alanya', 'province' => 'Antalya'] + $turkey, 'place'),
            ],
            str_contains($query, 'kadıköy') => [
                self::item('relation', 1765891, 'town', 12, 'Kadıköy', 40.9819, 29.0576, ['town' => 'Kadıköy', 'province' => 'İstanbul', 'country' => 'Türkiye', 'country_code' => 'tr']),
            ],
            str_contains($query, 'istanbul'), str_contains($query, 'i̇stanbul') => [
                self::item('relation', 223474, 'province', 8, $language === 'tr' ? 'İstanbul' : 'Istanbul', 41.0096, 28.9652,
                    ['province' => $language === 'tr' ? 'İstanbul' : 'Istanbul', 'country' => 'Türkiye', 'country_code' => 'tr']),
            ],
            str_contains($query, 'lond') => [self::london($language)],
            str_contains($query, 'berlin') => [self::berlin($language)],
            str_contains($query, 'new york') => [
                self::item('relation', 175905, 'city', 10, 'New York', 40.7127, -74.0060, ['city' => 'New York', 'state' => 'New York', 'country' => 'United States', 'country_code' => 'us']),
                self::item('relation', 9691750, 'suburb', 14, 'Brooklyn', 40.6526, -73.9497, ['suburb' => 'Brooklyn', 'county' => 'Kings County', 'city' => 'New York', 'state' => 'New York', 'country' => 'United States', 'country_code' => 'us']),
            ],
            str_contains($query, 'tokyo') => [
                self::item('relation', 1543125, 'province', 8, 'Tokyo', 35.6769, 139.7639, ['province' => 'Tokyo', 'country' => 'Japan', 'country_code' => 'jp']),
            ],
            str_contains($query, 'down') => 'not json',
            default => [],
        };
    }

    private function search(string $query, string $language = 'tr'): array
    {
        return $this->withHeader('Accept-Language', $language)->getJson('/api/v1/places/search?q='.urlencode($query))->assertOk()->json('data.items');
    }

    private function choose(string $query, string $language = 'tr', int $index = 0): array
    {
        return $this->withHeader('Accept-Language', $language)
            ->postJson('/api/v1/places/resolve', ['token' => $this->search($query, $language)[$index]['token']])->assertOk()->json('data');
    }

    private function account(string $name): User
    {
        return User::create(['name' => Str::title($name), 'username' => $name, 'email' => "$name@example.test", 'password' => 'Account12345!',
            'birth_date' => '1995-01-01', 'city_id' => City::where('slug', 'alanya')->value('id')]);
    }

    private function as(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('t')->plainTextToken);
    }

    public function test_search_returns_only_settlements_with_their_real_hierarchy_and_never_a_coordinate(): void
    {
        $items = $this->search('Oba');
        $this->assertCount(1, $items, 'The shop and the street are filtered out.');
        $this->assertSame(['name' => 'Oba Mahallesi', 'context' => 'Alanya · Antalya · Türkiye', 'label' => 'Oba Mahallesi, Alanya, Antalya'],
            array_intersect_key($items[0], array_flip(['name', 'context', 'label'])));
        $this->assertSame(['context', 'country_code', 'label', 'name', 'token', 'type'], collect($items[0])->keys()->sort()->values()->all());

        // Two real villages share one name: both stay, told apart by their hierarchy.
        $this->assertSame(['Alanya · Antalya · Türkiye', 'Beypazarı · Ankara · Türkiye'], array_column($this->search('Mahmutlar'), 'context'));
        // The same town mapped as a boundary and as a point is listed once.
        $this->assertCount(1, $this->search('Alanya'));
        $this->assertSame('Antalya · Türkiye', $this->search('Alanya')[0]['context']);
        $this->assertSame('New York · United States', $this->search('New York', 'en')[1]['context']);
        $this->assertSame('Tokyo, Japan', $this->search('Tokyo', 'en')[0]['label']);
        $this->assertSame([], $this->search('zzzz-nothing'));
    }

    public function test_the_same_query_reaches_the_provider_once_and_one_letter_is_not_a_search(): void
    {
        $this->search('Oba');
        $this->search('  oba ');
        $this->search('OBA');
        $this->assertSame(['/search tr Oba'], $this->calls);
        $this->getJson('/api/v1/places/search?q=o')->assertUnprocessable();
        $this->getJson('/api/v1/places/search')->assertUnprocessable();
        $this->assertCount(1, $this->calls);
    }

    public function test_choosing_a_neighbourhood_keeps_the_existing_city_and_alanya_is_a_district_of_antalya(): void
    {
        $alanya = City::where('slug', 'alanya')->firstOrFail();
        $this->assertSame(['tr', 'Antalya', 'tr|antalya||alanya'], [$alanya->country_code, $alanya->admin1, $alanya->area_key]);
        $before = City::count();

        $chosen = $this->choose('Oba');
        $this->assertSame($alanya->id, $chosen['city']['id']);
        $this->assertSame('Oba Mahallesi, Alanya, Antalya', $chosen['place']['label']);
        $this->assertSame($alanya->id, $this->choose('Mahmutlar')['city']['id']);
        $this->assertSame($alanya->id, $this->choose('Alanya')['city']['id']);
        // The old catalogue row is reused as it is: no new city, no provider id forced onto it.
        $this->assertSame($before, City::count());
        $this->assertNull($alanya->fresh()->provider_place_id);
        $this->assertSame(3, Place::count());
        // Choosing the same place again does not duplicate it.
        $this->choose('Oba');
        $this->assertSame(3, Place::count());
        // A whole province still maps to its old row.
        $this->assertSame(City::where('slug', 'istanbul')->value('id'), $this->choose('İstanbul')['city']['id']);
        $this->assertSame($before, City::count());
    }

    public function test_a_turkish_district_joins_its_province_feed_and_a_foreign_city_becomes_its_own_area_once(): void
    {
        $before = City::count();
        // Kadıköy people keep meeting the existing İstanbul people: same area, the place keeps the district.
        $kadikoy = $this->choose('Kadıköy');
        $this->assertSame(City::where('slug', 'istanbul')->value('id'), $kadikoy['city']['id']);
        $this->assertSame('Kadıköy, İstanbul, Türkiye', $kadikoy['place']['label']);
        $this->assertSame($before, City::count());

        // Brooklyn belongs to New York, which is created once as a provider area.
        $brooklyn = $this->choose('New York', 'en', 1);
        $this->assertSame($before + 1, City::count());
        $area = City::findOrFail($brooklyn['city']['id']);
        $this->assertSame(['New York', 'osm', 'us', 'New York', 'us|new-york||new-york', true],
            [$area->getRawOriginal('name'), $area->provider, $area->country_code, $area->admin1, $area->area_key, $area->is_active]);
        $this->assertSame('Brooklyn, New York, United States', $brooklyn['place']['label']);
        $this->assertSame($area->id, $this->choose('New York', 'en')['city']['id']);
        $this->assertSame($before + 1, City::count());
    }

    public function test_one_foreign_city_is_one_area_whatever_the_app_language_and_is_shown_in_that_language(): void
    {
        $turkish = $this->choose('Londra');
        // The area key always comes from the English names, fetched with a single lookup.
        $this->assertContains('/lookup en R175342', $this->calls);
        $this->assertSame('gb|england||london', City::findOrFail($turkish['city']['id'])->area_key);
        $this->assertSame(['Londra', 'Londra, İngiltere, Birleşik Krallık'], [$turkish['city']['name'], $turkish['place']['label']]);

        $english = $this->choose('London', 'en');
        $this->assertSame($turkish['city']['id'], $english['city']['id']);
        $this->assertSame($turkish['place']['id'], $english['place']['id']);
        $this->assertSame(['London', 'London, England, United Kingdom'], [$english['city']['name'], $english['place']['label']]);
        $this->assertSame(1, City::where('country_code', 'gb')->count());
    }

    public function test_a_provider_failure_is_a_readable_localized_message_and_a_forged_choice_is_refused(): void
    {
        $this->withHeader('Accept-Language', 'tr')->getJson('/api/v1/places/search?q=down')->assertStatus(503)
            ->assertJsonPath('message', 'Yer araması şu anda yapılamıyor. Biraz sonra tekrar dene.');
        $this->withHeader('Accept-Language', 'en')->getJson('/api/v1/places/search?q=down')->assertStatus(503)
            ->assertJsonPath('message', 'Place search isn’t available right now. Try again in a moment.');
        $token = $this->search('Oba')[0]['token'];
        $this->postJson('/api/v1/places/resolve', ['token' => 'x'.$token])->assertUnprocessable();
        $this->postJson('/api/v1/places/resolve', ['token' => substr($token, 0, -2).'00'])->assertUnprocessable();
        $this->travel(8)->days();
        $this->withHeader('Accept-Language', 'en')->postJson('/api/v1/places/resolve', ['token' => $token])->assertUnprocessable()
            ->assertJsonPath('errors.place.0', 'This place can no longer be selected. Search again.');
        $this->assertSame(0, Place::count());
    }

    public function test_current_location_is_rounded_before_it_leaves_the_server_and_answers_with_a_place(): void
    {
        $item = $this->withHeader('Accept-Language', 'tr')->getJson('/api/v1/places/reverse?latitude=36.551234&longitude=32.034567')
            ->assertOk()->assertJsonMissingPath('data.item.latitude')->json('data.item');
        $this->assertSame('Oba Mahallesi, Alanya, Antalya', $item['label']);
        // ~550 m grid: the provider never sees the precise device coordinate.
        $this->assertSame(['/reverse tr 36.55,32.035'], $this->calls);
        $this->getJson('/api/v1/places/reverse?latitude=36.5512&longitude=32.0340')->assertOk();
        $this->assertCount(1, $this->calls, 'The same cell is answered from the cache.');
        $this->getJson('/api/v1/places/reverse?latitude=95&longitude=10')->assertUnprocessable();
    }

    public function test_registration_and_profile_carry_a_place_that_stays_private_to_its_owner(): void
    {
        $oba = $this->choose('Oba');
        $this->postJson('/api/v1/auth/register', ['name' => 'Deniz', 'username' => 'deniz', 'email' => 'deniz@example.test',
            'password' => 'Account12345!', 'birth_date' => '1995-01-01', 'accepted_terms' => true])
            ->assertUnprocessable()->assertJsonValidationErrors('city_id');
        $profile = $this->postJson('/api/v1/auth/register', ['name' => 'Deniz', 'username' => 'deniz', 'email' => 'deniz@example.test',
            'password' => 'Account12345!', 'birth_date' => '1995-01-01', 'accepted_terms' => true, 'place_id' => $oba['place']['id']])
            ->assertCreated()->json('data.user');
        $this->assertSame([$oba['city']['id'], 'Alanya', 'Oba Mahallesi, Alanya, Antalya', true],
            [$profile['city_id'], $profile['city']['name'], $profile['place']['label'], $profile['has_password']]);

        $deniz = User::where('username', 'deniz')->firstOrFail();
        $kadikoy = $this->choose('Kadıköy');
        $this->as($deniz)->putJson('/api/v1/profile', ['place_id' => $kadikoy['place']['id']])->assertOk()
            ->assertJsonPath('data.city.id', $kadikoy['city']['id'])->assertJsonPath('data.place.name', 'Kadıköy');
        // An older app that only knows cities still works, and clears the finer place.
        $this->as($deniz)->putJson('/api/v1/profile', ['city_id' => $oba['city']['id']])->assertOk()
            ->assertJsonPath('data.city.name', 'Alanya')->assertJsonPath('data.place', null);
        $this->as($deniz)->putJson('/api/v1/profile', ['place_id' => 999999])->assertUnprocessable();

        $deniz->forceFill(['place_id' => $oba['place']['id']])->save();
        $public = $this->as($this->account('viewer'))->getJson('/api/v1/users/deniz')->assertOk()->json('data');
        $this->assertStringNotContainsString('Oba', json_encode($public, JSON_UNESCAPED_UNICODE), 'The neighbourhood is never on the public profile.');
    }

    public function test_posts_journeys_and_the_active_area_accept_places_and_old_city_requests_keep_working(): void
    {
        $author = $this->account('author');
        $oba = $this->choose('Oba');
        $berlin = $this->choose('Berlin');
        $post = $this->as($author)->postJson('/api/v1/posts', ['body' => 'Sahilde kısa bir an.', 'type' => 'moment', 'visibility' => 'city',
            'is_anonymous' => false, 'request_id' => (string) Str::uuid(), 'place_id' => $oba['place']['id']])->assertCreated()->json('data');
        $this->assertSame(['Alanya', 'Oba Mahallesi, Alanya, Antalya'], [$post['city']['name'], $post['place']['label']]);
        $this->assertArrayNotHasKey('latitude', $post['place']);

        $journey = $this->as($author)->postJson('/api/v1/posts', ['body' => 'Uzun bir yolculuk.', 'type' => 'travel', 'visibility' => 'city',
            'is_anonymous' => false, 'request_id' => (string) Str::uuid(), 'place_id' => $oba['place']['id'],
            'travel' => ['transport_type' => 'plane', 'origin_place_id' => $oba['place']['id'], 'destination_place_id' => $berlin['place']['id']]])
            ->assertCreated()->json('data.travel');
        $this->assertSame(['Alanya', 'Oba Mahallesi, Alanya, Antalya', 'Berlin', 'Berlin, Almanya'],
            [$journey['origin']['name'], $journey['origin']['label'], $journey['destination']['name'], $journey['destination']['label']]);
        $this->as($author)->postJson('/api/v1/posts', ['body' => 'Eksik yolculuk.', 'type' => 'travel', 'visibility' => 'city',
            'is_anonymous' => false, 'request_id' => (string) Str::uuid(), 'place_id' => $oba['place']['id'],
            'travel' => ['transport_type' => 'bus', 'origin_place_id' => $oba['place']['id']]])
            ->assertUnprocessable()->assertJsonValidationErrors('travel.destination_city_id');

        // The old request shape (bare cities) is unchanged.
        $ankara = City::where('slug', 'ankara')->value('id');
        $old = $this->as($author)->postJson('/api/v1/posts', ['body' => 'Otobüsle.', 'type' => 'travel', 'visibility' => 'city',
            'is_anonymous' => false, 'request_id' => (string) Str::uuid(), 'city_id' => $oba['city']['id'],
            'travel' => ['transport_type' => 'bus', 'origin_city_id' => $oba['city']['id'], 'destination_city_id' => $ankara]])
            ->assertCreated()->json('data');
        $this->assertSame([null, 'Ankara', null], [$old['place'], $old['travel']['destination']['name'], $old['travel']['destination']['label']]);

        $this->as($author)->putJson('/api/v1/active-city', ['place_id' => $berlin['place']['id']])->assertOk()->assertJsonPath('data.city.name', 'Berlin');
        $this->assertSame([$berlin['city']['id'], 'manual'], [$author->fresh()->active_city_id, $author->fresh()->active_city_source]);
        $this->as($author)->putJson('/api/v1/active-city', ['city_id' => $ankara])->assertOk()->assertJsonPath('data.city.name', 'Ankara');
        $this->as($author)->putJson('/api/v1/active-city', [])->assertUnprocessable();
    }

    public function test_a_device_outside_the_bundled_boundaries_is_placed_in_a_provider_area_and_inside_them_nothing_changes(): void
    {
        $user = $this->account('traveller');
        $this->as($user)->putJson('/api/v1/location', ['latitude' => 36.54423, 'longitude' => 32.00017, 'accuracy' => 20])
            ->assertOk()->assertJsonPath('data.city.name', 'Alanya');
        $this->assertSame([], $this->calls, 'Coordinates the bundled boundaries know never reach the provider.');

        $this->travel(11)->minutes();
        $this->as($user)->putJson('/api/v1/location', ['latitude' => 52.52001, 'longitude' => 13.40495, 'accuracy' => 20])
            ->assertOk()->assertJsonPath('data.city.name', 'Berlin');
        $this->assertSame(['/reverse en 52.52,13.41'], $this->calls);
        $berlin = City::where('area_key', 'de|berlin||berlin')->firstOrFail();
        $this->assertSame($berlin->id, $user->fresh()->active_city_id);
        // A note may be left in that area, close to its centre; a far away point is still refused.
        $this->assertTrue(\App\Places\Areas::accepts($berlin->id, 52.50, 13.45, City::where('slug', 'alanya')->value('id')));
        $this->assertFalse(\App\Places\Areas::accepts($berlin->id, 36.54, 32.00, City::where('slug', 'alanya')->value('id')));
        $this->assertFalse(\App\Places\Areas::accepts(City::where('slug', 'ankara')->value('id'), 36.54, 32.00, City::where('slug', 'alanya')->value('id')));
    }

    public function test_the_migration_described_every_old_city_without_touching_ids_or_names(): void
    {
        $this->assertSame(0, City::whereNull('area_key')->count());
        $this->assertSame(82, City::whereNull('provider')->where('country_code', 'tr')->count());
        $this->assertSame('tr|istanbul||istanbul', City::where('slug', 'istanbul')->value('area_key'));
        $this->assertSame(0, DB::table('users')->whereNotNull('place_id')->count());
        $this->assertTrue(DB::getSchemaBuilder()->hasColumns('post_travel_details', ['origin_place_id', 'destination_place_id', 'origin_city_id']));
    }
}
