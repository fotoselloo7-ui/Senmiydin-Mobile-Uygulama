<?php

namespace App\Media;

use Illuminate\Http\UploadedFile;
use Illuminate\Validation\ValidationException;

final class PrivateImage
{
    public const RULES = 'required|file|image|mimes:jpg,jpeg,png,webp|extensions:jpg,jpeg,png,webp|max:5120|dimensions:max_width=2048,max_height=2048';

    public static function jpeg(UploadedFile $file, string $field): array
    {
        $image = @imagecreatefromstring($file->get());
        if ($image === false) {
            throw ValidationException::withMessages([$field => 'Fotoğraf okunamadı.']);
        }
        ob_start();
        try {
            $encoded = imagejpeg($image, null, 85);
        } finally {
            $bytes = ob_get_clean();
        }
        abort_unless($encoded && is_string($bytes) && $bytes !== '', 500);
        return [$bytes, imagesx($image), imagesy($image)];
    }
}
