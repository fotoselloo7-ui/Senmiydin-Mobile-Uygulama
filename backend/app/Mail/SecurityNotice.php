<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Contracts\Queue\ShouldBeEncrypted;
use Illuminate\Mail\Mailable;

class SecurityNotice extends Mailable implements ShouldQueue, ShouldBeEncrypted
{
    use Queueable;

    public function __construct(public readonly string $notice) {}

    public function build(): static
    {
        return $this->subject('SenMiydin? hesap güvenliği')->text('mail.security');
    }
}
