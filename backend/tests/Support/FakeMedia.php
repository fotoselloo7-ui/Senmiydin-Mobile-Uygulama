<?php

namespace Tests\Support;

/** Builds tiny but structurally valid media files for upload tests. */
final class FakeMedia
{
    /** An M4A (MP4 + AAC) file whose movie header says [$milliseconds]. */
    public static function m4a(int $milliseconds = 12_000, string $brand = 'M4A ', bool $aac = true, int $padding = 0): string
    {
        $box = fn (string $type, string $payload) => pack('N', 8 + strlen($payload)).$type.$payload;
        $ftyp = $box('ftyp', $brand.pack('N', 0).'M4A mp42isom');
        $timescale = 1000;
        $mvhd = $box('mvhd', pack('N', 0).pack('N', 0).pack('N', 0).pack('N', $timescale).pack('N', $milliseconds)
            .pack('N', 0x00010000).pack('n', 0x0100).str_repeat("\0", 10).str_repeat("\0", 36).str_repeat("\0", 24).pack('N', 2));
        $trak = $box('trak', $box('mdia', $box('minf', $box('stbl', $box('stsd', pack('N', 0).pack('N', 1).$box($aac ? 'mp4a' : 'mp3 ', str_repeat("\0", 28)))))));
        $moov = $box('moov', $mvhd.$trak);
        $mdat = $box('mdat', random_bytes(256).str_repeat("\0", $padding));

        return $ftyp.$mdat.$moov;
    }

    /** A real JPEG carrying an EXIF block with GPS-looking data. */
    public static function jpegWithExif(int $width = 64, int $height = 48): string
    {
        $image = imagecreatetruecolor($width, $height);
        imagefill($image, 0, 0, imagecolorallocate($image, 30, 90, 200));
        ob_start();
        imagejpeg($image, null, 90);
        $jpeg = ob_get_clean();
        $tiff = 'II'.pack('v', 42).pack('V', 8).pack('v', 1).pack('v', 0x0112).pack('v', 3).pack('V', 1).pack('v', 1).pack('v', 0).pack('V', 0).'GPSLatitude=36.54463 Make=Pixel';
        $payload = "Exif\0\0".$tiff;

        return substr($jpeg, 0, 2)."\xFF\xE1".pack('n', strlen($payload) + 2).$payload.substr($jpeg, 2);
    }
}
