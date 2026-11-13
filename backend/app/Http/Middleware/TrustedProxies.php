<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Middleware\TrustProxies;
use Illuminate\Http\Request;

class TrustedProxies extends TrustProxies
{
    protected $headers = Request::HEADER_X_FORWARDED_FOR | Request::HEADER_X_FORWARDED_PROTO | Request::HEADER_X_FORWARDED_PORT;

    public function handle(Request $request, Closure $next)
    {
        $this->proxies = config('security.trusted_proxies', []);
        return parent::handle($request, $next);
    }
}
