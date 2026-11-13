<?php

use App\Models\User;
use Illuminate\Contracts\Console\Kernel;
use Senmiydin\Development\PixelFixtures;

require __DIR__.'/../backend/vendor/autoload.php';
$app = require __DIR__.'/../backend/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();
require_once __DIR__.'/PixelFixtures.php';
set_exception_handler(function (Throwable $error): never {
    fwrite(STDERR, 'Fixture operation failed: '.$error->getMessage().PHP_EOL);
    exit(1);
});

PixelFixtures::guard();
$root = realpath(__DIR__.'/..');
$file = $root.'/.local/pixel-fixtures.json';
$defines = $root.'/.local/pixel-fixture-defines.json';
$service = new PixelFixtures;
if (in_array('--cleanup', $argv, true)) {
    if (! is_file($file)) {
        echo "No owned fixtures to clean.\n";
        exit(0);
    }
    $state = json_decode(file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
    // Recover an interrupted sign-up before the device test could print its marker.
    if (! isset($state['accounts']['registration'])) {
        $registered = User::where('email', $state['registration']['email'])->first();
        if ($registered) {
            $service->register($state, $registered->id);
            file_put_contents($file, json_encode($state, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR));
        }
    }
    $report = $service->cleanup($state);
    $service->assertDemoQuality();
    $report['demo_suffix_free'] = true;
    file_put_contents($root.'/.local/pixel-cleanup-audit.json', json_encode($report, JSON_PRETTY_PRINT));
    unlink($file);
    if (is_file($defines)) {
        unlink($defines);
    }
    echo json_encode($report).PHP_EOL;
    exit(0);
}
foreach ($argv as $argument) {
    if (preg_match('/^--register-account=([0-9]+)$/', $argument, $match)) {
        $state = json_decode(file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
        $service->register($state, (int) $match[1]);
        file_put_contents($file, json_encode($state, JSON_PRETTY_PRINT));
        echo "Owned registration ID recorded.\n";
        exit(0);
    }
}
if (is_file($file)) {
    throw new RuntimeException('Owned fixtures remain; run --cleanup first.');
}
$state = $service->create();
file_put_contents($file, json_encode($state, JSON_PRETTY_PRINT));
$data = ['PIXEL_PASSWORD' => $state['password'], 'PIXEL_REGISTRATION_USERNAME' => $state['registration']['username'],
    'PIXEL_REGISTRATION_EMAIL' => $state['registration']['email'],
    'SCENARIO_EVENT_AT' => $state['event_at'], 'SCENARIO_DEPARTURE_AT' => $state['departure_at']];
foreach ($state['accounts'] as $role => $account) {
    $data['PIXEL_'.strtoupper($role)] = $account['username'];
}
$data['SCENARIO_WRITER'] = $state['accounts']['history_writer']['username'];
$data['SCENARIO_READER'] = $state['accounts']['history_reader']['username'];
$data['SCENARIO_PASSWORD'] = $state['password'];
file_put_contents($defines,json_encode($data,JSON_PRETTY_PRINT));
echo "Owned device fixtures prepared; credentials remain in ignored local files.\n";
