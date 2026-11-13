<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\User;
use Database\Seeders\DemoDataSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class DemoFixtureTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    public function test_demo_location_fixtures_are_deterministic_and_self_repairing_without_manual_database_edits(): void
    {
        Storage::fake(config('mobile.avatar_disk'));
        Storage::fake(config('mobile.post_media_disk'));
        $this->app['env'] = 'local';
        $this->seed(DemoDataSeeder::class);

        $alanya = City::where('slug', 'alanya')->value('id');
        $antalya = City::where('slug', 'antalya')->value('id');
        $expected = fn (string $handle) => DB::table('user_locations')
            ->where('user_id', User::where('email', DemoDataSeeder::email($handle))->value('id'))->first();

        // Every seeded demo account has an explicit city and its fixture coordinates right after seeding.
        foreach (DemoDataSeeder::PEOPLE as [$handle, , $latitude, $longitude]) {
            $row = $expected($handle);
            $this->assertNotNull($row, "{$handle} has no location row");
            $this->assertSame($handle === 'arda' ? $antalya : $alanya, (int) $row->city_id, "{$handle} city");
            $this->assertEqualsWithDelta($latitude, (float) $row->latitude, 0.00001);
            $this->assertEqualsWithDelta($longitude, (float) $row->longitude, 0.00001);
        }

        // A stale row (the historical demo_ahmet defect: sea coordinate, city_id NULL) is repaired by the helper itself.
        DB::table('user_locations')->where('user_id', User::where('username', 'demo_ahmet')->value('id'))
            ->update(['city_id' => null, 'latitude' => 36.541, 'longitude' => 32.002, 'visibility' => false]);
        $this->artisan('demo:refresh-locations')->assertExitCode(0);
        $ahmet = $expected('ahmet');
        $this->assertSame($alanya, (int) $ahmet->city_id);
        $this->assertEqualsWithDelta(36.544, (float) $ahmet->latitude, 0.00001);
        $this->assertEqualsWithDelta(32.004, (float) $ahmet->longitude, 0.00001);
        $this->assertTrue((bool) $ahmet->visibility);
        $this->assertSame(0, DB::table('user_locations')->whereNull('city_id')->count());

        // The seeded Alanya fixture is reported at the distance the device suite expects (~358 m, public value 400 m).
        $this->assertSame(400, \App\Location\Geo::publicDistance(
            \App\Location\Geo::distance(DemoDataSeeder::LATITUDE, DemoDataSeeder::LONGITUDE, $ahmet->latitude, $ahmet->longitude)));
    }

    public function test_refresh_command_refuses_to_run_outside_development(): void
    {
        $this->app['env'] = 'production';
        $this->artisan('demo:refresh-locations')->assertExitCode(1);
    }
}
