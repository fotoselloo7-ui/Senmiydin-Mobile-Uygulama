<?php

namespace App\Http\Controllers;

use App\Administration\Settings;
use App\Http\ApiResponse;
use App\Models\MapNote;
use App\Models\Post;
use App\Sharing\PublicShare;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

/**
 * The public side of "share outside the app": a small preview page for https://<domain>/p/<id> (post) and /n/<id> (Map Note),
 * the deep-link verification files, and the signed-in app's lookup of a link it was opened with.
 * Anything not public right now (private, removed, moderated, expired, teen author, unconfirmed encounter) is a plain 404.
 */
class PublicShareController extends Controller
{
    public function post(Request $request, Settings $settings, string $publicId)
    {
        $post = PublicShare::findPost($publicId);
        abort_if($post === null, 404);
        $locale = $this->locale($request);
        $text = $locale === 'en' ? self::TEXT_EN : self::TEXT_TR;

        $handles = [];
        $badge = null;
        if ($post->is_anonymous) {
            $who = $text['anonymous'];
        } elseif ($post->story_status === Post::STORY_PUBLISHED && $post->jointEncounter) {
            $pair = $post->jointEncounter->invitation;
            $who = $pair->requester->name.' & '.$pair->target->name;
            $badge = $text['encountered'];
        } else {
            $who = $post->author->name;
            $handles[] = '@'.$post->author->username;
        }

        return $this->page($settings, $locale, "p/{$post->public_id}", [
            'kind' => $text['post'],
            'who' => $who,
            'handles' => $handles,
            'badge' => $badge,
            'body' => $post->body,
            'place' => $post->city->name,
            'date' => $post->created_at,
        ]);
    }

    public function note(Request $request, Settings $settings, string $publicId)
    {
        $note = PublicShare::findNote($publicId);
        abort_if($note === null, 404);
        $locale = $this->locale($request);
        $text = $locale === 'en' ? self::TEXT_EN : self::TEXT_TR;

        return $this->page($settings, $locale, "n/{$note->public_id}", [
            'kind' => $text['note'],
            'who' => $note->is_anonymous ? $text['anonymous'] : $note->author->name,
            'handles' => $note->is_anonymous ? [] : ['@'.$note->author->username],
            'badge' => null,
            'body' => $note->body,
            // Only the approximate area label, never a coordinate.
            'place' => $note->place_label ?: $note->city->name,
            'date' => $note->occurred_at ?? $note->created_at,
        ]);
    }

    /** The signed-in app resolves a link it was opened with into its own object (the app's visibility rules apply). */
    public function resolve(Request $request, string $publicId): JsonResponse
    {
        $viewer = $request->user();
        $post = Post::visibleTo($viewer)->where('public_id', $publicId)->first();
        if ($post && PublicShare::postShareable($post->loadMissing('author'))) {
            return ApiResponse::ok(['type' => 'post', 'id' => $post->id]);
        }
        $note = MapNote::visibleTo($viewer)->where('public_id', $publicId)->first();
        if ($note && PublicShare::noteShareable($note->loadMissing('author'))) {
            return ApiResponse::ok(['type' => 'map_note', 'id' => $note->id]);
        }
        abort(404);
    }

    /** Digital Asset Links for Android App Links. Served only once the real signing fingerprints are configured. */
    public function assetLinks()
    {
        $fingerprints = array_values(array_filter(array_map('trim', explode(',', (string) config('deployment.android_app_link_sha256')))));
        abort_if($fingerprints === [], 404);

        return response()->json([[
            'relation' => ['delegate_permission/common.handle_all_urls'],
            'target' => ['namespace' => 'android_app', 'package_name' => 'com.senmiydin.app', 'sha256_cert_fingerprints' => $fingerprints],
        ]]);
    }

    /** apple-app-site-association for Universal Links. Served only once the real Apple Team ID is configured. */
    public function appleAssociation()
    {
        $team = trim((string) config('deployment.apple_team_id'));
        abort_if($team === '', 404);

        return response()->json([
            'applinks' => ['details' => [['appIDs' => [$team.'.com.senmiydin.app'], 'components' => [['/' => '/p/*'], ['/' => '/n/*']]]]],
        ]);
    }

    private function page(Settings $settings, string $locale, string $path, array $content)
    {
        $values = $settings->all();
        $text = $locale === 'en' ? self::TEXT_EN : self::TEXT_TR;
        $flat = preg_replace('/\s+/u', ' ', trim((string) $content['body']));
        $description = Str::limit($flat !== '' && $flat !== null ? $flat : $text['fallback'], 180, '…');

        return response()->view('website.share', [
            'locale' => $locale,
            't' => $text,
            'settings' => $values,
            'content' => $content + ['excerpt' => Str::limit(trim((string) $content['body']), 600, '…')],
            'title' => $content['kind'].' · '.$content['who'].' · '.($values['app_name'] ?? 'SenMiydin?'),
            'description' => $description,
            'canonical' => config('website.url').'/'.$path,
            'deepLink' => config('website.url').'/'.$path,
        ])->header('Cache-Control', 'public, max-age=60')->header('X-Robots-Tag', 'noindex, nofollow');
    }

    private function locale(Request $request): string
    {
        $forced = $request->query('lang');
        if (in_array($forced, ['tr', 'en'], true)) {
            return $forced;
        }

        return str_starts_with(strtolower((string) $request->header('Accept-Language')), 'en') ? 'en' : 'tr';
    }

    private const TEXT_TR = [
        'anonymous' => 'Anonim', 'post' => 'Paylaşım', 'note' => 'Harita Notu', 'encountered' => 'Karşılaşıldı ✓',
        'open' => "SenMiydin?'de Aç", 'play' => 'Google Play', 'app_store' => 'App Store',
        'fallback' => "SenMiydin?'de bir paylaşım.", 'tagline' => 'Şehrindeki hikâyeleri keşfet.',
    ];

    private const TEXT_EN = [
        'anonymous' => 'Anonymous', 'post' => 'Post', 'note' => 'Map Note', 'encountered' => 'Encountered ✓',
        'open' => 'Open in SenMiydin?', 'play' => 'Google Play', 'app_store' => 'App Store',
        'fallback' => 'A post on SenMiydin?.', 'tagline' => 'Discover the stories in your city.',
    ];
}
