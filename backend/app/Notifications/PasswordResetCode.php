<?php

namespace App\Notifications;

use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Notifications\Messages\MailMessage;

class PasswordResetCode extends ResetPassword implements \Illuminate\Contracts\Queue\ShouldQueue, \Illuminate\Contracts\Queue\ShouldBeEncrypted
{
    use \Illuminate\Bus\Queueable;

    public function toMail($notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject('SenMiydin? şifre sıfırlama')
            ->greeting('Merhaba, '.$notifiable->name)
            ->line('Uygulamadaki Şifremi Unuttum ekranında Sıfırlama Kodum Var seçeneğini aç.')
            ->line('Sıfırlama kodun: '.$this->token)
            ->line('Bu kod '.config('auth.passwords.users.expire').' dakika geçerlidir.')
            ->line('Bu isteği sen göndermediysen e-postayı yok sayabilirsin.');
    }
}
