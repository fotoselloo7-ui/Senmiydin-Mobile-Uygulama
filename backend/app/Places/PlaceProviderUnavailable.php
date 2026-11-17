<?php

namespace App\Places;

/** The place provider did not answer (network, timeout, busy). Callers turn this into a readable, localized message. */
final class PlaceProviderUnavailable extends \RuntimeException {}
