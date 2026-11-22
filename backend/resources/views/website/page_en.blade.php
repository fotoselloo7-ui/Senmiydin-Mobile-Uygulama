@extends('website.layout')

@if($slug === '')
    @push('head')
        <link rel="preload" as="image" type="image/webp" href="{{ asset('web/hero-istanbul-tram.webp') }}" fetchpriority="high">
        <link rel="stylesheet" href="{{ asset('web/home.css') }}">
    @endpush
@endif

@section('content')
@if($slug === '')
    @include('website.home_en')
@endif

@if($slug === 'nasil-calisir')
<section class="wrap section">
    <div class="section-head">
        <span class="kicker">FROM ENCOUNTER TO STORY</span>
        <h1>How it works</h1>
        <p class="section-sub">Share a real-life moment, discover traces from the same place and time, and verify it with mutual approval.</p>
    </div>
    <div class="steps-flow">
        @foreach([
            ['Leave a moment', 'Write an encounter, memory, thought or confession from your city or your journey. Add photos if you like.'],
            ['Discover what is near you', 'Browse city content or discover location-based posts by approximate distance.'],
            ['Find the person you met', 'If you know the username of someone from an unfinished encounter, tag them, or explore traces on the same route.'],
            ['Confirm together', 'An encounter is verified when the other person accepts. A shared story also needs a separate publishing approval.'],
            ['Leave a letter', 'Cannot find them? Leave a digital letter at an approximate point on the map; it stays for 7 days and others can answer it.'],
        ] as [$heading, $body])
            <div class="step-card">
                <div class="step-left">
                    <div class="step-badge">{{ $loop->iteration }}</div>
                    <div class="step-icon icon-purple">
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                    </div>
                </div>
                <div class="step-right">
                    <h3>{{ $heading }}</h3>
                    <p>{{ $body }}</p>
                </div>
            </div>
        @endforeach
    </div>
</section>
@endif

@if($slug === 'ozellikler')
<section class="surface"><div class="wrap section">
    <div class="section-head">
        <span class="kicker">LOCATION-BASED DISCOVERY</span>
        <h1>Features</h1>
        <p class="section-sub">The city feed, approximate-distance discovery, journey posts and verified encounter stories in one experience.</p>
    </div>
    <div class="feature-grid">
        @foreach([
            ['City content and feed', 'Thoughts, memories, confessions and posts with photos come together in the feed of the city you live in. A separate Following feed gathers the people you follow.'],
            ['Conversations under posts', 'One-level comment threads: reply to a comment, like comments and replies, and keep posts you like in private collections.'],
            ['Journey posts', 'Share unfinished encounters from the same route and trip on a bus, train, plane or ferry.'],
            ['Map Notes and My Letters', 'Leave a digital letter at an approximate point for 7 days, public or anonymous; others can read and answer. Manage active and archived letters and share an expired one again. Get a small notification when a new letter appears near you.'],
            ['Real-life encounters', 'After mutual approval a verified encounter can become a shared story.'],
            ['Location-based discovery', 'Discover nearby posts and profiles that chose to be visible, by approximate distance and without live tracking.'],
            ['Memories', 'Build a collection of the moments you choose on your profile: add a place, a date and photos, and decide who sees them. Nearby Memories on the map and the home screen.'],
            ['Private messages', 'The first message is a request; once accepted, chat continues with photos (gallery or camera), emoji and approximate location messages. Delete a message for yourself or, if you sent it, for everyone, and change bubble colours and the chat background with Chat Theme.'],
            ['Notifications', 'Likes, comments, replies, follows, messages, encounters and Map Note replies reach you in the app and as push notifications, with settings for each.'],
            ['Privacy and age groups', 'Manage location visibility, Places I Passed and message permissions. Accounts aged 16–17 only meet their own age group.'],
        ] as [$heading, $body])
            <article>
                <span class="feature-icon" aria-hidden="true">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
                </span>
                <div>
                    <h3>{{ $heading }}</h3>
                    <p>{{ $body }}</p>
                </div>
            </article>
        @endforeach
    </div>
</div></section>
@endif

@if($slug === 'guvenlik')
<section class="surface"><div class="wrap section safety-section">
    <div>
        <span class="kicker">PRIVACY AND SAFETY</span>
        <h1>Safety</h1>
        <p>You choose your location visibility and who can send you message requests in the app settings.</p>
        <a class="button outline-purple" href="/en/privacy">Read the privacy policy</a>
    </div>
    <ul class="checks">
        <li>There is no live tracking of people; other users only see an approximate distance.</li>
        <li>Shared stories are published with two separate approvals.</li>
        <li>Blocking and reporting are available in the app.</li>
        <li>SenMiydin is for ages 16 and over; accounts aged 16–17 only interact with their own age group, enforced on the server.</li>
        <li>Ads are clearly labelled “Ad”, never use your location and are age-restricted for accounts aged 16–17.</li>
    </ul>
</div></section>
@endif

@include('website.legal')

@if(in_array($slug, ['iletisim', 'hesap-silme'], true))
<div class="wrap article"><span class="kicker">SUPPORT</span><h1>{{ $title }}</h1>
    @if($slug === 'hesap-silme')
        <p>In the app, go to Profile → Settings → Delete My Account, confirm your password and type DELETE to close your account permanently. If you cannot reach the app, you can send a request with the form below.</p>
        <h2>Steps</h2>
        <ol class="delete-steps">
            <li>Open the app and sign in.</li>
            <li>Go to Profile → Settings → Delete My Account.</li>
            <li>Enter your password and type DELETE to confirm.</li>
            <li>No access to the app? Fill in the form below with the email registered to your account.</li>
        </ol>
        <p>The form creates a request record. Writing an email address alone does not delete an account. The support team verifies that the account is yours, then tells you what will be done and its status.</p>
        <h2>What does a request cover?</h2>
        <p>After deletion in the app your profile and content are no longer accessible. Your identity details are anonymized; your sessions, devices, location records and history are erased; the text and images you shared are removed, including private message photos. Records that contain no personal information and the status of moderation actions remain for the integrity of relationships. Other users’ own content and backups are subject to a separate retention policy; the actual retention periods of backups and support records must be stated by the data controller.</p>
    @else
        <p>{{ $description }}</p>
    @endif
    @if(filled($operator['contact_email']))<p><a href="mailto:{{ $operator['contact_email'] }}">{{ $operator['contact_email'] }}</a></p>@endif
    @if(session('status'))<p class="success" role="status">{{ session('status') }}</p>@endif
    @if($errors->any())<div class="form-errors" role="alert"><ul>@foreach($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul></div>@endif
    <form method="post" action="/en/{{ \App\Website\Site::enSlug($slug) }}" class="web-form">
        @csrf
        <div class="form-pair"><label>Your name<input name="name" required maxlength="100" autocomplete="name" value="{{ old('name') }}"></label>
        <label>{{ $slug === 'hesap-silme' ? 'Email registered to your account' : 'Email' }}<input name="email" type="email" required maxlength="254" autocomplete="email" value="{{ old('email') }}"></label></div>
        @if($slug === 'iletisim')<label>Subject<input name="subject" required maxlength="120" value="{{ old('subject') }}"></label>@endif
        <label>{{ $slug === 'hesap-silme' ? 'Additional information (optional)' : 'Message' }}<textarea name="message" maxlength="3000" rows="5" @required($slug === 'iletisim')>{{ old('message') }}</textarea></label>
        <div class="trap" aria-hidden="true"><label>Website<input name="website" tabindex="-1" autocomplete="off"></label></div>
        <p class="muted">Do not send your password or ID documents through the form. <a href="/en/privacy">Privacy Policy</a></p>
        <button class="button" type="submit">{{ $slug === 'hesap-silme' ? 'Send deletion request' : 'Send message' }}</button>
    </form>
</div>
@endif
@endsection
