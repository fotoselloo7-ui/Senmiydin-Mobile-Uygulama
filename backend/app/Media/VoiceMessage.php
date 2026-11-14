<?php

namespace App\Media;

use Illuminate\Http\UploadedFile;
use Illuminate\Validation\ValidationException;

/**
 * Server-side checks for an uploaded voice message. Nothing the client says about the file is trusted: not its name,
 * not its declared type and not its declared duration. The bytes must be an MP4/M4A container with an AAC track, small
 * enough, and its own header (mvhd) tells how long it is.
 */
final class VoiceMessage
{
    /** Validation rules for the multipart "audio" field (size is checked again on the real bytes). */
    public static function rules(): string
    {
        $kilobytes = (int) ceil(config('mobile.voice.max_bytes') / 1024);

        return 'file|max:'.$kilobytes;
    }

    /**
     * @return array{0: string, 1: int} the verified bytes and the duration in milliseconds taken from the file itself
     */
    public static function inspect(UploadedFile $file, string $field = 'audio'): array
    {
        $limits = config('mobile.voice');
        $size = $file->getSize();
        if (! $size || $size > $limits['max_bytes']) {
            throw ValidationException::withMessages([$field => 'Ses kaydı çok büyük.']);
        }
        $bytes = $file->get();
        if (strlen($bytes) < 32 || substr($bytes, 4, 4) !== 'ftyp' || ! in_array(substr($bytes, 8, 4), $limits['brands'], true)) {
            throw ValidationException::withMessages([$field => 'Ses kaydı okunamadı.']);
        }
        // An AAC audio track must be declared inside the container.
        if (! str_contains($bytes, 'mp4a')) {
            throw ValidationException::withMessages([$field => 'Ses kaydı okunamadı.']);
        }
        $finfo = new \finfo(FILEINFO_MIME_TYPE);
        if (! in_array($finfo->buffer($bytes), ['audio/mp4', 'audio/x-m4a', 'video/mp4', 'audio/m4a', 'audio/aac'], true)) {
            throw ValidationException::withMessages([$field => 'Ses kaydı okunamadı.']);
        }
        $duration = self::durationMs($bytes);
        if ($duration === null) {
            throw ValidationException::withMessages([$field => 'Ses kaydı okunamadı.']);
        }
        if ($duration < $limits['min_ms']) {
            throw ValidationException::withMessages([$field => 'Ses kaydı çok kısa.']);
        }
        // A little slack for container rounding; the app stops at the limit itself.
        if ($duration > ($limits['max_seconds'] * 1000) + 1500) {
            throw ValidationException::withMessages([$field => 'Ses kaydı çok uzun.']);
        }

        return [$bytes, min($duration, $limits['max_seconds'] * 1000)];
    }

    /** Duration from the movie header (moov/mvhd) of an MP4/M4A file; null when it cannot be read. */
    public static function durationMs(string $bytes): ?int
    {
        $moov = self::box($bytes, 0, strlen($bytes), 'moov');
        if ($moov === null) {
            return null;
        }
        $mvhd = self::box($bytes, $moov[0], $moov[1], 'mvhd');
        if ($mvhd === null || $mvhd[1] - $mvhd[0] < 20) {
            return null;
        }
        $version = ord($bytes[$mvhd[0]]);
        if ($version === 1) {
            if ($mvhd[1] - $mvhd[0] < 32) {
                return null;
            }
            $timescale = self::uint32($bytes, $mvhd[0] + 20);
            $units = (self::uint32($bytes, $mvhd[0] + 24) << 32) | self::uint32($bytes, $mvhd[0] + 28);
        } else {
            $timescale = self::uint32($bytes, $mvhd[0] + 12);
            $units = self::uint32($bytes, $mvhd[0] + 16);
        }

        return $timescale > 0 ? (int) round($units * 1000 / $timescale) : null;
    }

    /** @return array{0: int, 1: int}|null payload start and end offset of the first box of [$type] inside [$from, $to) */
    private static function box(string $bytes, int $from, int $to, string $type): ?array
    {
        $offset = $from;
        while ($offset + 8 <= $to) {
            $size = self::uint32($bytes, $offset);
            $name = substr($bytes, $offset + 4, 4);
            $header = 8;
            if ($size === 1) {
                if ($offset + 16 > $to) {
                    return null;
                }
                $size = (self::uint32($bytes, $offset + 8) << 32) | self::uint32($bytes, $offset + 12);
                $header = 16;
            } elseif ($size === 0) {
                $size = $to - $offset;
            }
            if ($size < $header || $offset + $size > $to) {
                return null;
            }
            if ($name === $type) {
                return [$offset + $header, $offset + $size];
            }
            $offset += $size;
        }

        return null;
    }

    private static function uint32(string $bytes, int $offset): int
    {
        return (ord($bytes[$offset]) << 24) | (ord($bytes[$offset + 1]) << 16) | (ord($bytes[$offset + 2]) << 8) | ord($bytes[$offset + 3]);
    }
}
