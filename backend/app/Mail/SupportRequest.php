<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Contracts\Queue\ShouldBeEncrypted;
use Illuminate\Mail\Mailable;

class SupportRequest extends Mailable implements ShouldQueue, ShouldBeEncrypted
{
    use Queueable;

    public function __construct(public readonly int $requestId) {}

    public function build(): static
    {
        // Personal form content stays in the authenticated panel, outside email logs and queues.
        return $this->subject('SenMiydin? yeni destek talebi')->text('mail.support');
    }
}
