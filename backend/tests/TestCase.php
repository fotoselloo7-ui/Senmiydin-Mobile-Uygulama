<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        // The Symfony test client would otherwise announce "en-us". The Turkish product's reference client speaks Turkish;
        // tests that cover English send their own Accept-Language header or set users.preferred_locale.
        $this->withHeader('Accept-Language', 'tr-TR,tr;q=0.9');
    }
}
