<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A reply in a single-level public thread. Anonymous replies expose no identity at all. On an anonymous
 * note the note owner's replies are always anonymous and merely flagged as coming from the note's author.
 */
class MapNoteReplyResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $note = $this->note;
        $fromNoteAuthor = $note->is_anonymous && $this->user_id === $note->user_id;

        return [
            'id' => $this->id,
            'body' => $this->body,
            'is_anonymous' => $this->is_anonymous || $fromNoteAuthor,
            'mine' => $request->user() !== null && $this->user_id === $request->user()->id,
            'author' => $this->is_anonymous || $fromNoteAuthor ? null : new PublicUserResource($this->author),
            'from_note_author' => $fromNoteAuthor,
            'created_at' => $this->created_at->toISOString(),
        ];
    }
}
