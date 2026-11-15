<?php

namespace Tests\Feature;

use App\Deployment\Readiness;
use App\Models\City;
use App\Models\User;
use Database\Seeders\CitySeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ReleaseOperationsTest extends TestCase
{
    use RefreshDatabase;
    public function test_conversation_and_notification_queries_remain_bounded_and_paginated(): void
    {
        $this->seed();
        $city = City::first();
        $viewer = User::create(['name' => 'Viewer', 'username' => 'viewer', 'email' => 'viewer@example.test',
            'password' => 'ViewerPassword123!', 'birth_date' => '1990-01-01', 'city_id' => $city->id]);
        $this->withToken($viewer->createToken('test')->plainTextToken);
        $add = function (int $number) use ($city, $viewer): void {
            $id = DB::table('users')->insertGetId(['name' => 'Peer '.$number, 'username' => 'peer'.$number,
                'email' => 'peer'.$number.'@example.test', 'password' => $viewer->password,
                'birth_date' => '1990-01-01', 'city_id' => $city->id, 'created_at' => now(), 'updated_at' => now()]);
            $chat = \App\Models\Conversation::create(['first_user_id' => $viewer->id, 'second_user_id' => $id,
                'requester_id' => $viewer->id, 'status' => 'active', 'responded_at' => now()]);
            DB::table('conversation_participants')->insert([
                ['conversation_id' => $chat->id, 'user_id' => $viewer->id],
                ['conversation_id' => $chat->id, 'user_id' => $id]]);
            \App\Models\Message::create(['conversation_id' => $chat->id, 'sender_id' => $id,
                'body' => 'Hello', 'type' => 'text', 'request_id' => (string) \Illuminate\Support\Str::uuid()]);
            \App\Notifications\Inbox::add($viewer->id, $id, 'follow', $id);
        };
        $count = function (string $endpoint): int {
            DB::enableQueryLog(); DB::flushQueryLog();
            $this->getJson('/api/v1/'.$endpoint)->assertOk();
            $result = count(DB::getQueryLog()); DB::disableQueryLog();
            return $result;
        };
        $add(0);
        $small = ['conversations' => $count('conversations'), 'notifications' => $count('notifications')];
        for ($i = 1; $i < 23; $i++) { $add($i); }
        foreach ($small as $endpoint => $queries) {
            $this->assertLessThanOrEqual($queries + 2, $count($endpoint));
            $this->getJson('/api/v1/'.$endpoint)->assertOk()->assertJsonCount(20, 'data.items')->assertJsonPath('data.next_page', 2);
        }
    }

    public function test_readiness_reports_missing_credentials_without_exposing_values(): void
    {
        // Hermetic: whatever real providers a developer machine's .env has configured, this test is about the unconfigured report.
        config(['app.key' => 'base64:'.base64_encode(str_repeat('s', 32)), 'mail.mailers.smtp.password' => 'never-display-this-value',
            'social.google.audiences' => [], 'push.driver' => 'log', 'push.credentials' => null, 'push.project' => null]);
        $this->assertSame(2, Artisan::call('senmiydin:production-check', ['--json' => true]));
        $output = Artisan::output();
        $this->assertStringNotContainsString('never-display-this-value', $output);
        $this->assertStringNotContainsString(config('app.key'), $output);
        $report = json_decode($output, true, flags: JSON_THROW_ON_ERROR);
        $this->assertFalse($report['ready']);
        $rows = collect($report['checks'])->keyBy('check');
        $this->assertSame('MISSING', $rows['Google OAuth audiences']['status']);
        $this->assertSame('MISSING', $rows['Operator identity and reviewed legal CMS']['status']);
        foreach ($report['checks'] as $row) {
            $this->assertContains($row['status'], ['OK', 'WARNING', 'MISSING', 'ERROR']);
            $this->assertSame(['check', 'status', 'category'], array_keys($row));
        }
    }
    public function test_health_is_small_and_does_not_expose_environment(): void
    {
        $this->getJson('/health')->assertOk()->assertExactJson(['status' => 'ok'])->assertHeader('Cache-Control', 'no-store, private');
        DB::partialMock()->shouldReceive('select')->andThrow(new \RuntimeException('secret-host-and-password'));
        $this->getJson('/health')->assertStatus(503)->assertExactJson(['status' => 'unavailable']);
    }
    public function test_catalog_cache_is_shared_only_for_public_catalogs_and_invalidated_by_admin(): void
    {
        $before = City::where('is_active', true)->count();
        $city = City::forceCreate(['name' => 'Cache Audit', 'slug' => 'cache-audit-test', 'is_active' => true]);
        Cache::forget('catalog:cities:v1');
        $this->getJson('/api/v1/cities')->assertOk()->assertJsonCount($before + 1, 'data');
        DB::enableQueryLog();
        $this->getJson('/api/v1/cities')->assertOk();
        $queries = collect(DB::getQueryLog())->filter(fn ($q) => str_contains($q['query'], 'from "cities"'));
        $this->assertCount(0, $queries);
        DB::disableQueryLog();
        $admin = \App\Models\Admin::create(['name' => 'Operator', 'email' => 'operator@example.test', 'password' => 'Operator12345!', 'role' => 'super_admin', 'is_active' => true]);
        $this->actingAs($admin, 'admin')->post('/admin/cities/'.$city->id, ['is_active' => false])->assertRedirect();
        $this->getJson('/api/v1/cities')->assertOk()->assertJsonCount($before, 'data');
    }
}
