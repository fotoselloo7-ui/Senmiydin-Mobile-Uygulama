@php
$icon = \App\Website\Icons::all();
$slides = [
    ['tram', 'Istanbul · İstiklal', 'That moment at the red tram stop', '“Were you the one with a coffee and headphones around your neck, looking at the tram with me?”', 'web/hero-istanbul-tram.webp', 1200, 670, 'A red nostalgic tram on İstiklal Avenue', 'Illustrative post'],
    ['ferry', 'Istanbul · Kadıköy', 'Sunset on the evening ferry', '“Were you the one whose eyes met mine while we tossed simit to the gulls?”', 'web/polaroid-kiz-kulesi.webp', 1024, 1024, 'Maiden’s Tower and the Bosphorus at sunset', 'Illustrative post'],
    ['cafe', 'Istanbul · Moda', 'The coffee at the corner table', '“Were you the one who closed your book, smiled at me and ordered a second coffee?”', 'web/coffee.webp', 900, 600, 'Filter coffee brewing in a café', 'Illustrative post'],
    ['note', 'Alanya · Map Note', 'A digital letter left on the map', '“You looked lovely, girl in the red hood. I will be here again tomorrow at 11:00.” Some time later: “Someone replied to your note.”', null, 0, 0, null, 'Real app screen'],
    ['trip', 'Ankara → Eskişehir · Train', 'A journey by the window', '“Were you the one who handed me your book in the middle of the trip?”', 'web/journey.webp', 1000, 589, 'A train moving along the tracks', 'Illustrative post'],
];
$gallery = [
    ['app-home', 'Home', 'The city feed and people nearby', 540, 1200],
    ['app-notes-letter', 'Map Note', 'An anonymous digital letter', 640, 1422],
    ['app-profile', 'Profile', 'Your posts and encounters', 540, 1200],
    ['app-map', 'Map', 'Approximate places, no live tracking', 540, 1200],
    ['app-encounter', 'Encounter', 'Tag a person, ask for approval', 540, 1200],
    ['app-chat', 'Messages', 'Private, permission-based chat', 540, 1200],
    ['app-memories', 'Memories', 'The memories on your profile, on a map', 540, 1170],
    ['app-chat-theme', 'Chat Theme', 'Bubble and background colours', 540, 1170],
];
@endphp

{{-- 1. HERO --}}
<section class="h-hero" aria-labelledby="hero-baslik">
    <div class="wrap h-hero-grid">
        <div class="h-hero-copy">
            <p class="h-eyebrow">{!! $icon['pin'] !!} <span>For the small coincidences of a city</span></p>
            <h1 id="hero-baslik">Maybe the person you are looking for is <span class="h-hl">right here.</span></h1>
            <p class="h-lead">You locked eyes on the tram, stood side by side on the ferry or looked at the same café table, but never got to talk. SenMiydin gives you a way to find that moment again, in the same city, on the same route and in the same place.</p>

            <div class="h-hero-actions">
                @include('website.stores')
                <a class="h-textlink" href="#harita-notlari">Browse the digital letters {!! $icon['arrow'] !!}</a>
            </div>

            <ul class="h-trust" aria-label="In short">
                <li><span class="t-blue">{!! $icon['check'] !!}</span> Mutual approval</li>
                <li><span class="t-blue">{!! $icon['shield'] !!}</span> Exact location is never shared</li>
                <li><span class="t-purple">{!! $icon['pin'] !!}</span> A feed for your own city</li>
            </ul>
            <a class="sr-only" href="#nasil-calisir">See how it works</a>
        </div>

        <div class="hs" data-slider role="region" aria-roledescription="carousel" aria-label="Example encounter stories">
            <div class="hs-glow" aria-hidden="true"></div>
            <div class="hs-stage">
                @foreach($slides as $i => [$key, $loc, $title, $text, $img, $w, $h, $alt, $badge])
                    <figure class="hs-slide hs-{{ $key }} @if($i === 0) is-active @endif" role="group" aria-roledescription="slide" aria-label="{{ $i + 1 }} / {{ count($slides) }}" @if($i !== 0) aria-hidden="true" @endif>
                        @if($img)
                            <img src="{{ asset($img) }}" alt="{{ $alt }}" width="{{ $w }}" height="{{ $h }}" decoding="async" @if($i === 0) fetchpriority="high" @else loading="lazy" @endif>
                        @else
                            <div class="hs-letter">
                                <img class="hs-letter-card" src="{{ asset('web/screens/story-letter-reply.webp') }}" alt="A real app screen: a letter left on the map with an anonymous reply below it" width="900" height="890" loading="lazy" decoding="async">
                                <img class="hs-letter-notice" src="{{ asset('web/screens/story-notification.webp') }}" alt="A real app screen: the notification “Someone replied to your note.”" width="900" height="233" loading="lazy" decoding="async">
                            </div>
                        @endif
                        <figcaption class="hs-caption">
                            <span class="hs-meta">
                                <span class="hs-loc">{!! $icon['pin'] !!} {{ $loc }}</span>
                                <span class="hs-badge">{{ $badge }}</span>
                            </span>
                            <strong>{{ $title }}</strong>
                            <p>{{ $text }}</p>
                        </figcaption>
                    </figure>
                @endforeach
            </div>
            <div class="hs-controls">
                <div class="hs-dots">
                    @foreach($slides as $i => $slide)
                        <button type="button" class="hs-dot @if($i === 0) is-active @endif" data-index="{{ $i }}" aria-label="Story {{ $i + 1 }}: {{ $slide[2] }}" @if($i === 0) aria-current="true" @endif></button>
                    @endforeach
                </div>
                <button type="button" class="hs-pause" data-pause aria-label="Pause automatic slides" aria-pressed="false">
                    <svg class="icon-pause" width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><rect x="6" y="5" width="4" height="14" rx="1"/><rect x="14" y="5" width="4" height="14" rx="1"/></svg>
                    <svg class="icon-play" width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M8 5v14l11-7z"/></svg>
                </button>
            </div>
        </div>
    </div>
</section>

{{-- 2. WHAT IS SENMIYDIN --}}
<section class="h-section h-about" id="nedir" aria-labelledby="nedir-baslik">
    <div class="wrap h-split">
        <div>
            <span class="kicker">WHAT IS SENMIYDIN?</span>
            <h2 id="nedir-baslik">Rediscover the small coincidences inside your city.</h2>
            <p class="h-sub">SenMiydin is not a dating app. It is a city-based social experience for people whose paths crossed in real life, for memories and for stories left unfinished. An encounter only counts once the other person accepts it, and it is yours to decide what to share.</p>
        </div>
        <p class="h-triptych" aria-label="Same city, same route, same moment">
            <span>Same city.</span>
            <span class="p">Same route.</span>
            <span>Same moment.</span>
        </p>
    </div>
</section>

{{-- 3. HOW IT WORKS --}}
<section class="h-section h-soft" id="nasil-calisir" aria-labelledby="nasil-baslik">
    <div class="wrap">
        <div class="h-head">
            <span class="kicker">HOW IT WORKS</span>
            <h2 id="nasil-baslik">Return to an unfinished story in three steps.</h2>
        </div>
        <ol class="h-steps">
            <li>
                <span class="h-num" aria-hidden="true">1</span>
                <h3>Leave a moment</h3>
                <p>A memory, an encounter, a confession, a thought or a journey. Write it, add up to ten photos if you like, stay anonymous if you prefer.</p>
            </li>
            <li>
                <span class="h-num" aria-hidden="true">2</span>
                <h3>Discover in your city</h3>
                <p>Browse the feed across your city; look at approximate areas, people, posts and notes on the map.</p>
            </li>
            <li>
                <span class="h-num" aria-hidden="true">3</span>
                <h3>Confirm together</h3>
                <p>Tag the person you met with @username. If they accept, the encounter is verified; a shared story needs a separate publishing approval.</p>
            </li>
        </ol>
    </div>
</section>

{{-- 4. CITY FEED --}}
<section class="h-section" id="sehir-akisi" aria-labelledby="sehir-baslik">
    <div class="wrap h-split">
        <div class="h-copy">
            <span class="kicker">CITY-BASED DISCOVERY</span>
            <h2 id="sehir-baslik">The city’s feed first, nearness second.</h2>
            <p>SenMiydin is not only an app that shows people around you. Posts are discovered across the whole city by default; nearness is a hint that helps ordering and does not lock a post into a small circle.</p>
            <ul class="h-chips" aria-label="Content types">
                <li>Memory</li><li>Encounter</li><li>Confession</li><li>Thought</li><li>Journey</li>
            </ul>
            <dl class="h-spec">
                <div><dt>Range</dt><dd>Whole city · 5 km · 10 km · 25 km</dd></div>
                <div><dt>Sorting</dt><dd>Nearby · New · Popular</dd></div>
                <div><dt>Filters</dt><dd>Content type, photos and interests can be combined.</dd></div>
                <div><dt>Following</dt><dd>Posts from the people you follow gather in their own feed, apart from the city feed.</dd></div>
            </dl>
            <p class="h-note">Every post has a one-level comment conversation: reply to a comment, like comments and replies. Posts you like can be kept in optional collections that only you can see.</p>
        </div>
        <figure class="h-shot h-visual">
            <img src="{{ asset('web/screens/app-home.webp') }}" alt="SenMiydin Home: the city feed and encounter stories" loading="lazy" decoding="async" width="540" height="1200">
        </figure>
    </div>
</section>

{{-- 5. ENCOUNTERS --}}
<section class="h-section h-soft" id="karsilasma" aria-labelledby="karsilasma-baslik">
    <div class="wrap h-split rev">
        <figure class="h-shot h-visual">
            <img src="{{ asset('web/screens/app-encounter.webp') }}" alt="SenMiydin encounter post: tagging a person with @username" loading="lazy" decoding="async" width="540" height="1200">
        </figure>
        <div class="h-copy">
            <span class="kicker">ENCOUNTERS</span>
            <h2 id="karsilasma-baslik">A verified encounter is a decision of both people.</h2>
            <ol class="h-list-num">
                <li><strong>Tag.</strong> You find the person you met by @username.</li>
                <li><strong>Let them decide.</strong> The other person accepts or declines. You can also withdraw a pending request.</li>
                <li><strong>Publish your story.</strong> After acceptance you can create a shared story; it is not published until the other side approves.</li>
            </ol>
            <p class="h-note">An encounter is about finding and confirming a specific person. An open letter left at a place is a separate feature: the Map Notes below.</p>
        </div>
    </div>
</section>

{{-- 6. MAP --}}
<section class="h-section" id="harita" aria-labelledby="harita-baslik">
    <div class="wrap h-split">
        <div class="h-copy">
            <span class="kicker">MAP</span>
            <h2 id="harita-baslik">See traces on the map, show yourself only if you wish.</h2>
            <p>The map has three views: People, Posts and Notes. The People list only includes people who turned on “visible near me”; when you turn it off you really leave the list.</p>
            <ul class="h-checks">
                <li>Only approximate locations are shown; exact GPS and street addresses are never shared.</li>
                <li>No real-time route is shown. There is no live tracking of people.</li>
                <li>If you do not allow location you can still pick your city by hand and keep using the app.</li>
            </ul>
        </div>
        <figure class="h-shot h-visual">
            <img src="{{ asset('web/screens/app-map.webp') }}" alt="SenMiydin map: approximate nearby posts" loading="lazy" decoding="async" width="540" height="1200">
        </figure>
    </div>
</section>

{{-- 7. MAP NOTES / DIGITAL LETTERS --}}
<section class="h-notes" id="harita-notlari" aria-labelledby="notlar-baslik">
    <div class="wrap">
        <div class="h-notes-top">
            <div class="h-copy">
                <span class="kicker">MAP NOTES · DIGITAL LETTERS</span>
                <h2 id="notlar-baslik">If you could not find them, leave a note where you passed.</h2>
                <p class="h-sub">Leave a digital letter at an approximate point on the map; it stays for 7 days. Public or anonymous, as you choose. Maybe the person you are looking for sees your note and answers.</p>
                <ul class="h-facts" aria-label="How Map Notes work">
                    <li>{!! $icon['mail'] !!} Stays on the map for 7 days</li>
                    <li>Public or anonymous</li>
                    <li>Can be answered</li>
                    <li>Approximate point</li>
                    <li>My Letters and archive</li>
                </ul>
                <p class="h-note">In My Letters you see your active and archived letters and can share an expired letter again whenever you like. When a new letter is left near you, you get a small notification; the author is not revealed in it.</p>
                <p class="h-note">A Map Note is separate from an encounter confirmed with @username: it is an open letter left at a place that anyone can read.</p>
            </div>
            <figure class="h-shot h-visual h-notes-hero">
                <img src="{{ asset('web/screens/app-notes-map.webp') }}" alt="SenMiydin Map Notes: purple envelope markers on the map; one of three notes holds two letters" loading="lazy" decoding="async" width="640" height="1422">
            </figure>
        </div>

        <div class="h-head h-head-left">
            <h3 class="h-h3-big">Three moments of a letter</h3>
        </div>
        <ol class="h-note-steps" role="list" tabindex="0" aria-label="Map Note steps: scroll to browse">
            <li>
                <figure class="h-shot"><img src="{{ asset('web/screens/app-notes-compose.webp') }}" alt="The note screen: a text field, public or anonymous choice and the approximate point picked on the map" loading="lazy" decoding="async" width="640" height="1422"></figure>
                <span class="h-badge" aria-hidden="true">1</span>
                <h3>Leave a letter at a point.</h3>
                <p>Write your note, choose public or anonymous and mark an approximate place on the map. The note stays for 7 days.</p>
            </li>
            <li>
                <figure class="h-shot"><img src="{{ asset('web/screens/app-notes-list.webp') }}" alt="Notes left at one point: two letters, one anonymous and one public" loading="lazy" decoding="async" width="640" height="1422"></figure>
                <span class="h-badge" aria-hidden="true">2</span>
                <h3>Let people in that area discover it.</h3>
                <p>Notes at the same point are grouped under one marker. Everyone in the city can read them from the Notes view.</p>
            </li>
            <li>
                <figure class="h-shot"><img src="{{ asset('web/screens/app-notes-replies.webp') }}" alt="A Map Note with an anonymous reply below it" loading="lazy" decoding="async" width="640" height="1422"></figure>
                <span class="h-badge" aria-hidden="true">3</span>
                <h3>Maybe that person answers.</h3>
                <p>Replies appear under the note; the person replying can also be public or anonymous. The note’s author gets a notification.</p>
            </li>
        </ol>
    </div>
</section>

{{-- 8. PLACES I PASSED --}}
<section class="h-section" id="gectigim-yerler" aria-labelledby="yerler-baslik">
    <div class="wrap h-split">
        <div class="h-copy">
            <span class="kicker">PLACES I PASSED</span>
            <h2 id="yerler-baslik">The places you pass, only if you want it.</h2>
            <p>Places I Passed is optional. If you turn it on, approximate areas along your way are kept for a short time; if someone was in the same place at the same time, only a discovery suggestion may appear. A suggestion is a guess; nothing is confirmed by itself.</p>
            <p class="h-note">When you turn it off, collection stops and your own history and the suggestions that came from it are deleted.</p>
        </div>
        <dl class="h-facts-big">
            <div><dt>Default</dt><dd>Off</dd></div>
            <div><dt>Location</dt><dd>Approximate areas</dd></div>
            <div><dt>Retention</dt><dd>7 days at most</dd></div>
            <div><dt>Exact route tracking</dt><dd>None</dd></div>
        </dl>
    </div>
</section>

{{-- 9. JOURNEYS --}}
<section class="h-section h-soft" id="yolculuk" aria-labelledby="yolculuk-baslik">
    <div class="wrap h-split">
        <div class="h-copy">
            <span class="kicker">Journey posts</span>
            <h2 id="yolculuk-baslik">The right details for a moment left unfinished on the road.</h2>
            <p>You can add the route and approximate time to a journey post. The same route and time window is only a discovery hint; the system does not know you shared a vehicle.</p>
            <ul class="h-chips" aria-label="Transport types">
                <li>Bus</li><li>Train</li><li>Plane</li><li>Ferry</li><li>Other</li>
            </ul>
            <dl class="h-spec">
                <div><dt>Route</dt><dd>Departure and arrival city, approximate time</dd></div>
                <div><dt>Details</dt><dd>Company, trip code and optional vehicle ID; public or private</dd></div>
                <div><dt>Example</dt><dd>Pamukkale · Ankara → Erzincan · 07 NM 365</dd></div>
            </dl>
            <p class="h-note">There are no journey groups, rooms or join buttons; nobody is claimed to be on the same vehicle.</p>
        </div>
        <figure class="h-shot h-visual">
            <img src="{{ asset('web/screens/app-journey.webp') }}" alt="SenMiydin journey post: route and time details" loading="lazy" decoding="async" width="540" height="1200">
        </figure>
    </div>
</section>

{{-- 9b. MEMORIES --}}
<section class="h-section h-soft" id="anilar" aria-labelledby="anilar-baslik">
    <div class="wrap h-split">
        <figure class="h-shot h-visual">
            <img src="{{ asset('web/screens/app-memories.webp') }}" alt="SenMiydin Memories: the memories on your profile gathered by approximate area on a map" loading="lazy" decoding="async" width="540" height="1170">
        </figure>
        <div class="h-copy">
            <span class="kicker">MEMORIES</span>
            <h2 id="anilar-baslik">The memories on your profile.</h2>
            <p>Memories are a calm collection of the moments you choose to keep on your profile. Turn a post or a map note into a memory, add a place, a date and photos, and decide who gets to see it.</p>
            <ul class="h-checks">
                <li>Up to five photos, cropped together in a 9:16, 4:5 or 16:9 frame</li>
                <li>Visibility: only you, your followers, everyone, or people in a chosen area</li>
                <li>A list and a map view on your profile; Nearby Memories on the home screen and the map</li>
                <li>Hide, show again or delete whenever you like</li>
            </ul>
            <p class="h-note">A memory is not an encounter confirmation; it is simply a moment you tell yourself.</p>
        </div>
    </div>
</section>

{{-- 10. MESSAGING --}}
<section class="h-section" id="mesajlasma" aria-labelledby="mesaj-baslik">
    <div class="wrap h-split rev">
        <figure class="h-shot h-visual">
            <img src="{{ asset('web/screens/app-chat.webp') }}" alt="SenMiydin one-to-one messages: a message request and a photo message" loading="lazy" decoding="async" width="540" height="1200">
        </figure>
        <div class="h-copy">
            <span class="kicker">MESSAGES</span>
            <h2 id="mesaj-baslik">One-to-one, permission-based messaging.</h2>
            <p>The first message is a request; the chat continues once the recipient accepts. After an encounter is confirmed, contact goes on through the same permission-based chat.</p>
            <ul class="h-checks">
                <li>Accept or decline a message request</li>
                <li>Photo messages (from the gallery or the camera), emoji, read receipts and an unread counter</li>
                <li>You can send an approximate area; there is no live location sharing</li>
                <li>Delete a message just for yourself, or delete one you sent for everyone</li>
                <li>Chat Theme: pick the bubble colours and the chat background for your own screen</li>
                <li>Hide a chat, block a user and report</li>
            </ul>
            <p class="h-note">There are no group chats or calls; SenMiydin stays focused on simple one-to-one messaging. Your theme is only visible on your own screen.</p>
        </div>
    </div>
</section>

{{-- 11. PRIVACY AND SAFETY --}}
<section class="h-section h-privacy" id="guvenlik" aria-labelledby="guvenlik-baslik">
    <div class="wrap">
        <div class="h-head h-head-left">
            <span class="kicker">PRIVACY AND SAFETY</span>
            <h2 id="guvenlik-baslik">A relaxed, respectful and safe experience.</h2>
            <p class="h-sub">You stay in control of your location, visibility and communication.</p>
        </div>
        <ul class="h-safe">
            <li><h3>Approximate location</h3><p>Other users only see an approximate distance and area; exact GPS is never shown.</p></li>
            <li><h3>Anonymous posting</h3><p>Your name and profile stay hidden in posts and Map Notes.</p></li>
            <li><h3>Block and report</h3><p>Block someone you do not want to hear from, and report inappropriate content and behavior.</p></li>
            <li><h3>Moderation</h3><p>Reports are reviewed; inappropriate content can be removed.</p></li>
            <li><h3>Location choices</h3><p>“Visible near me”, Places I Passed and notifications are switched on and off separately.</p></li>
            <li><h3>Age groups</h3><p>SenMiydin is for people aged 16 and over. Accounts aged 16–17 only meet their own age group and accounts aged 18 and over only meet adults; this is enforced on the server.</p></li>
            <li><h3>Account deletion</h3><p>You can close your account in the app or by sending a request from the Delete Account page on the web.</p></li>
        </ul>
        <div class="h-links">
            <a href="/en/safety" class="button button-soft-blue">Read the safety page {!! $icon['arrow'] !!}</a>
            <a href="/en/delete-account" class="h-textlink">Account deletion request</a>
        </div>
        <p class="sr-only">Places I Passed is off by default. There is no live tracking of people; other users only see an approximate distance.</p>
    </div>
</section>

{{-- 12. REAL MOBILE SCREENS --}}
<section class="h-section h-soft" id="ekranlar" aria-labelledby="ekranlar-baslik">
    <div class="wrap">
        <div class="h-head h-head-left">
            <span class="kicker">REAL SCREENS</span>
            <h2 id="ekranlar-baslik">Real images from the app</h2>
            <p class="h-sub">The screens below are real screenshots taken from the Android version of the app.</p>
        </div>
        <ul class="h-gallery" role="list" tabindex="0" aria-label="App screens: scroll to browse">
            @foreach($gallery as [$file, $label, $caption, $w, $h])
                <li>
                    <figure class="h-shot"><img src="{{ asset('web/screens/'.$file.'.webp') }}" alt="SenMiydin {{ $label }} screen" loading="lazy" decoding="async" width="{{ $w }}" height="{{ $h }}"><figcaption><strong>{{ $label }}</strong><span>{{ $caption }}</span></figcaption></figure>
                </li>
            @endforeach
        </ul>
    </div>
</section>

{{-- 13. FINAL CTA --}}
<section class="h-cta" id="indir" aria-labelledby="indir-baslik">
    <div class="wrap h-cta-inner">
        <div>
            <h2 id="indir-baslik">Discover the encounters waiting for you in your city.</h2>
            @if(filled($settings['app_store_url']) || filled($settings['play_store_url']))
                <p>Download the app and start discovering the encounters in your city.</p>
            @else
                <p>Store links will appear here once published. For now they show as “Soon”.</p>
            @endif
        </div>
        <div class="cta-stores-row">
            @include('website.stores')
        </div>
    </div>
</section>
