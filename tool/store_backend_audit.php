<?php

use App\Administration\Settings;
use App\Deployment\Readiness;
use App\Website\Pages;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

try {
    require __DIR__.'/../backend/vendor/autoload.php';
    $app = require __DIR__.'/../backend/bootstrap/app.php';
    $app->make(Kernel::class)->bootstrap();
} catch (Throwable $error) {
    echo json_encode(['status'=>'FAIL','reason'=>'backend_bootstrap_failed']).PHP_EOL;
    exit(1);
}

$result = ['status'=>'READY', 'environment'=>app()->environment(), 'settings'=>null, 'legal'=>[], 'visible_demo_suffix_free'=>null];
try {
    $result['readiness'] = app(Readiness::class)->checks();
    $database = collect($result['readiness'])->contains(fn ($row) => $row['check']==='Database reachable and migrations installed' && $row['status']==='OK');
    if ($database) {
        $settings = app(Settings::class);
        $support = $settings->get('support_email');
        $result['settings'] = [
            'minimum_age'=>$settings->get('minimum_age'),
            'support_email_real'=>filled($support) && filter_var($support,FILTER_VALIDATE_EMAIL) && !preg_match('/example\.|\.local|\.test/i',$support),
            'banned_words_configured'=>filled($settings->get('moderation_banned_words')),
            'blocked_domains_configured'=>filled($settings->get('moderation_blocked_domains')),
        ];
        foreach (['app_store_url'=>'apps.apple.com','play_store_url'=>'play.google.com'] as $key=>$host) {
            $url=$settings->get($key);
            $valid=!filled($url);
            if (filled($url)) {
                $valid=parse_url($url,PHP_URL_SCHEME)==='https' && parse_url($url,PHP_URL_HOST)===$host
                    && !parse_url($url,PHP_URL_USER) && !parse_url($url,PHP_URL_PASS);
                if ($key==='play_store_url') {
                    parse_str(parse_url($url,PHP_URL_QUERY)??'', $query);
                    $valid=$valid && parse_url($url,PHP_URL_PATH)==='/store/apps/details' && ($query['id']??null)==='com.senmiydin.app';
                } else {
                    $valid=$valid && preg_match('~/id[0-9]+(?:/|$)~',parse_url($url,PHP_URL_PATH)??'');
                }
            }
            $result['settings'][$key]=['configured'=>filled($url),'valid'=>(bool)$valid];
        }
        foreach (Pages::LEGAL as $slug=>$default) {
            $row=DB::table('legal_pages')->where('slug',$slug)->first();
            $body=$row->body??$default[1];
            $result['legal'][$slug]=[
                'uses_default'=>trim($body)===trim($default[1]),
                'placeholder'=>(bool)preg_match('/lorem ipsum|example\.(com|test)|@.*\.local|GERÇEK BİLGİ GEREKLİ/iu',$body),
                'csae_standard'=>(bool)preg_match('/CSAE|CSAM|çocuk.{0,60}(istismar|cinsel)|child sexual/iu',$body),
            ];
        }
        $ids=DB::table('users')->whereIn('email',['demo@senmiydin.local','elif@senmiydin.local'])->pluck('id');
        $result['visible_demo_suffix_free']=true;
        foreach(DB::table('posts')->whereIn('user_id',$ids)->whereNull('deleted_at')->get(['body','story_title']) as $post) {
            foreach([$post->body,$post->story_title] as $value) {
                if(preg_match('/[0-9]{13}\s*$/u',$value??'') || preg_match('/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i',$value??'')) {
                    $result['visible_demo_suffix_free']=false;
                }
            }
        }
    } else {
        $result['status']='MISSING';
        $result['reason']='database_audit_unavailable';
    }
} catch (Throwable $error) {
    $result['status']='MISSING';
    $result['reason']='runtime_audit_unavailable';
}
echo json_encode($result,JSON_PRETTY_PRINT|JSON_THROW_ON_ERROR).PHP_EOL;
