<?php



namespace App\Media;



use Illuminate\Http\UploadedFile;

use Illuminate\Validation\ValidationException;



final class PrivateImage

{

    public const RULES = 'required|file|image|mimes:jpg,jpeg,png,webp|extensions:jpg,jpeg,png,webp|max:5120|dimensions:max_width=2048,max_height=2048';



    public static function jpeg(UploadedFile $file, string $field): array

    {

        $source = $file->get();

        $image = @imagecreatefromstring($source);

        if ($image === false) {

            throw ValidationException::withMessages([$field => 'Fotoğraf okunamadı.']);

        }

        // Re-encoding drops every metadata block (GPS, device, time). Camera photos keep their upright position in the

        // EXIF "orientation" tag though, so apply it to the pixels first or portrait photos would end up sideways.

        $image = self::upright($image, self::orientation($source));

        ob_start();

        try {

            $encoded = imagejpeg($image, null, 85);

        } finally {

            $bytes = ob_get_clean();

        }

        abort_unless($encoded && is_string($bytes) && $bytes !== '', 500);

        return [$bytes, imagesx($image), imagesy($image)];

    }



    /** EXIF orientation (1–8) of a JPEG, 1 when absent or unreadable. Parsed by hand: no extension needed. */

    public static function orientation(string $bytes): int

    {

        if (strlen($bytes) < 12 || substr($bytes, 0, 2) !== "\xFF\xD8") {

            return 1;

        }

        $offset = 2;

        $length = strlen($bytes);

        while ($offset + 4 <= $length && $bytes[$offset] === "\xFF") {

            $marker = ord($bytes[$offset + 1]);

            $size = (ord($bytes[$offset + 2]) << 8) | ord($bytes[$offset + 3]);

            if ($marker === 0xE1 && substr($bytes, $offset + 4, 6) === "Exif\0\0") {

                $tiff = $offset + 10;

                $little = substr($bytes, $tiff, 2) === 'II';

                $u16 = fn (int $at): int => $little ? (ord($bytes[$at]) | (ord($bytes[$at + 1]) << 8)) : ((ord($bytes[$at]) << 8) | ord($bytes[$at + 1]));

                $u32 = fn (int $at): int => $little

                    ? (ord($bytes[$at]) | (ord($bytes[$at + 1]) << 8) | (ord($bytes[$at + 2]) << 16) | (ord($bytes[$at + 3]) << 24))

                    : ((ord($bytes[$at]) << 24) | (ord($bytes[$at + 1]) << 16) | (ord($bytes[$at + 2]) << 8) | ord($bytes[$at + 3]));

                if ($tiff + 8 > $length) {

                    return 1;

                }

                $ifd = $tiff + $u32($tiff + 4);

                if ($ifd + 2 > $length) {

                    return 1;

                }

                $entries = $u16($ifd);

                for ($i = 0; $i < $entries && $ifd + 2 + ($i + 1) * 12 <= $length; $i++) {

                    $entry = $ifd + 2 + $i * 12;

                    if ($u16($entry) === 0x0112) {

                        $value = $u16($entry + 8);



                        return $value >= 1 && $value <= 8 ? $value : 1;

                    }

                }



                return 1;

            }

            if ($marker === 0xDA || $size < 2) {

                break;

            }

            $offset += 2 + $size;

        }



        return 1;

    }



    /** @return \GdImage the image turned/mirrored the way its orientation tag says. */

    public static function upright(\GdImage $image, int $orientation): \GdImage

    {

        if ($orientation === 1) {

            return $image;

        }

        if (in_array($orientation, [2, 5, 7], true)) {

            imageflip($image, IMG_FLIP_HORIZONTAL);

        }

        if ($orientation === 4) {

            imageflip($image, IMG_FLIP_VERTICAL);

        }

        $counterClockwise = match ($orientation) {

            3 => 180, 6, 7 => 270, 5, 8 => 90, default => 0,

        };

        if ($counterClockwise === 0) {

            return $image;

        }

        $rotated = imagerotate($image, $counterClockwise, 0);



        return $rotated === false ? $image : $rotated;

    }

}

