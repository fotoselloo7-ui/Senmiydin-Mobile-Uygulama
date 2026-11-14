@php($en = ($locale ?? 'tr') === 'en')
@if($legalPage)
<article class="wrap article legal-doc">
    <header class="legal-head">
        <span class="kicker">{{ $en ? 'LEGAL INFORMATION' : 'YASAL BİLGİLENDİRME' }}</span>
        <h1>{{ $legalPage['title'] }}</h1>
        <p class="legal-lead">{{ \App\Website\LegalContent::fill($legalPage['intro'], $operator) }}</p>
        <p class="legal-updated"><small>{{ $en ? 'Last updated' : 'Son güncelleme' }}: {{ \App\Website\LegalContent::UPDATED[$locale] }}</small></p>
        @if($operatorMissing)
            <p class="legal-note" role="note">{{ $en
                ? 'The operator’s identity and contact details have not been completed yet. They are filled in from the administration settings before publication.'
                : 'İşletici kimliği ve iletişim bilgileri henüz tamamlanmadı. Yayından önce yönetim ayarlarından girilir.' }}</p>
        @endif
    </header>
    <div class="legal-layout">
        <nav class="legal-toc" aria-label="{{ $en ? 'On this page' : 'Bu sayfada' }}">
            <strong>{{ $en ? 'On this page' : 'Bu sayfada' }}</strong>
            <ol>
                @foreach($legalPage['sections'] as $section)
                    <li><a href="#{{ $section['id'] }}">{{ $section['h'] }}</a></li>
                @endforeach
            </ol>
        </nav>
        <div class="legal-body">
            @foreach($legalPage['sections'] as $section)
                <section class="legal-section" id="{{ $section['id'] }}" aria-labelledby="{{ $section['id'] }}-h">
                    <h2 id="{{ $section['id'] }}-h">{{ $loop->iteration }}. {{ $section['h'] }}</h2>
                    @foreach($section['p'] ?? [] as $paragraph)
                        <p>{{ \App\Website\LegalContent::fill($paragraph, $operator) }}</p>
                    @endforeach
                    @if(! empty($section['ul']))
                        <ul>
                            @foreach($section['ul'] as $item)
                                <li>{{ \App\Website\LegalContent::fill($item, $operator) }}</li>
                            @endforeach
                        </ul>
                    @endif
                </section>
            @endforeach
            @if(filled($operator['contact_email']))
                <p class="legal-contact">{{ $en ? 'Questions and data requests' : 'Destek ve veri talepleri' }}: <a href="mailto:{{ $operator['contact_email'] }}">{{ $operator['contact_email'] }}</a></p>
            @endif
        </div>
    </div>
</article>
@elseif($legal)
{{-- A page the administrator has edited in the legal CMS: plain, escaped text. --}}
<article class="wrap article"><div class="legal-sheet"><span class="kicker">{{ $en ? 'LEGAL INFORMATION' : 'YASAL BİLGİLENDİRME' }}</span><h1>{{ $legal['title'] }}</h1>
    <div class="legal-copy">{!! nl2br(e($legal['body'])) !!}</div>
    @if(filled($settings['support_email']))<p class="legal-contact">{{ $en ? 'Questions and data requests' : 'Destek ve veri talepleri' }}: <a href="mailto:{{ $settings['support_email'] }}">{{ $settings['support_email'] }}</a></p>@endif
</div></article>
@endif
