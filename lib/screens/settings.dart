import 'package:flutter/material.dart' hide Text;

import '../widgets/translated_text.dart';

import '../core/app_locale.dart';
import '../core/theme.dart';
import '../core/release_info.dart';
import '../core/navigation.dart';
import '../data/app_store.dart';
import '../data/communication_api.dart';
import '../data/models.dart';
import '../widgets/account_action.dart';
import '../widgets/common.dart';
import '../widgets/location_ui.dart';
import '../widgets/social_page.dart';

/// Language picker: "Türkçe" / "English". The choice is saved on the device (and on the account when signed in).
Future<void> _chooseLanguage(BuildContext context, AppStore store) async {
  final text = context.l10n;
  final chosen = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (code, label) in [
            ('tr', text.languageTurkish),
            ('en', text.languageEnglish),
          ])
            ListTile(
              key: ValueKey('language-$code'),
              title: Text(label),
              trailing: AppLocale.code == code
                  ? const Icon(Icons.check_rounded, color: AppColors.blue)
                  : null,
              onTap: () => Navigator.pop(sheet, code),
            ),
        ],
      ),
    ),
  );
  if (chosen != null && chosen != AppLocale.code) {
    await store.setLanguage(chosen);
  }
}

/// The word that confirms account deletion: SİL on a Turkish UI, DELETE on an English one. Either is accepted in
/// either language (and any letter case), the API always receives the same Turkish word.
bool isDeleteConfirmation(String input) {
  const accepted = {'SİL', 'SIL'};
  final word = input.trim();
  return accepted.contains(word.toUpperCase()) ||
      word == 'sil' ||
      word == 'Sil' ||
      word.toLowerCase() == 'delete';
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with AccountAction<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppPage(
      title: tr('Ayarlar'),
      child: ListView(
        padding: Space.page,
        children: [
          UserRow(store.me, onTap: () => openPage(context, '/edit-profile')),
          const SizedBox(height: Space.lg),
          const SectionLabel('HESAP VE PROFİL'),
          SettingsRow(
            'Profil Düzenle',
            Icons.person_outline,
            onTap: () => openPage(context, '/edit-profile'),
          ),
          SettingsRow(
            'İlgi Alanlarım',
            Icons.interests_outlined,
            onTap: () => openPage(context, '/interests', false),
          ),
          if (store.connected)
            SettingsRow(
              'Şifre Değiştir',
              Icons.lock_outline,
              onTap: () => openPage(context, '/change-password'),
            ),
          const SectionLabel('GİZLİLİK VE TERCİHLER'),
          SettingsRow(
            context.l10n.settingsLanguage,
            Icons.language_rounded,
            subtitle: AppLocale.english ? 'English' : 'Türkçe',
            onTap: () => _chooseLanguage(context, store),
          ),
          if (store.ads.privacyOptionsRequired)
            SettingsRow(
              context.l10n.settingsAdPrivacy,
              Icons.ads_click_rounded,
              subtitle: context.l10n.settingsAdPrivacySubtitle,
              onTap: () => store.ads.showPrivacyOptions(),
            ),
          SettingsRow(
            'Gizlilik ve Konum',
            Icons.shield_outlined,
            onTap: () => openPage(context, '/preferences', 'Gizlilik'),
          ),
          SettingsRow(
            'Bildirim Ayarları',
            Icons.notifications_none,
            onTap: () => openPage(context, '/preferences', 'Bildirimler'),
          ),
          SettingsRow(
            'Engellenen Kullanıcılar',
            Icons.block_outlined,
            onTap: () => openPage(context, '/blocked'),
          ),
          const SectionLabel('DESTEK VE HAKKINDA'),
          SettingsRow(
            'Açık Kaynak Lisansları',
            Icons.description_outlined,
            onTap: () async {
              final info = await ReleaseInfo.package;
              if (!context.mounted) return;
              showLicensePage(
                context: context,
                applicationName: 'SenMiydin?',
                applicationVersion: info.version,
              );
            },
          ),
          ...[
            'Topluluk Kuralları',
            'Gizlilik Politikası',
            'KVKK',
            'Kullanım Koşulları',
          ].map(
            (t) => SettingsRow(
              t,
              Icons.article_outlined,
              onTap: () => showLegal(context, t),
            ),
          ),
          SettingsRow(
            'Geri Bildirim / Şikâyet',
            Icons.flag_outlined,
            onTap: () => openPage(context, '/report', 'Uygulama'),
          ),
          const SectionLabel('OTURUM VE HESAP İŞLEMLERİ'),
          SettingsRow(
            busy ? 'Çıkış yapılıyor…' : 'Çıkış Yap',
            Icons.logout,
            onTap: busy
                ? null
                : () => runAccountAction(() async {
                    await store.signOut();
                    if (!store.connected && context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/welcome',
                        (_) => false,
                      );
                    }
                  }),
          ),
          SettingsRow(
            'Hesabımı Sil',
            Icons.delete_outline,
            danger: true,
            onTap: () => openPage(context, '/delete-account'),
          ),
          const SizedBox(height: Space.xl),
          const Center(child: Brand(size: 22)),
          const SizedBox(height: 8),
          const Text(
            'Sürüm 0.1.0',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: Space.xl),
        ],
      ),
    );
  }
}

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key, this.initial = 'Gizlilik'});
  final String initial;
  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage>
    with AccountAction<PreferencesPage> {
  late String tab = widget.initial;

  void setHistory(AppStore store, bool enabled) {
    runAccountAction(() async {
      if (!store.connected) {
        store.setPreference('Geçtiğim yer bildirimleri', enabled);
        return;
      }
      final location = store.location!;
      if (enabled) {
        final confirmed = await confirmAction(
          context,
          title: 'Geçtiğim Yerler açılsın mı?',
          scrollable: true,
          message: location.supportsBackground
              ? 'Geçtiğim Yerler için konumun uygulama arka plandayken de sunucuya gönderilir. Yaklaşık geçmiş bölgeler, sonradan bu bölgelerde paylaşılan hikâyeleri önermek ve bildirim tercihin açıksa haber vermek için saklanır. Kesin konumun diğer kullanıcılara gösterilmez. Android devam eden konum servisini gösterir. Kapattığında kayıt durur, geçmiş ve eşleşmelerin silinir.'
              : 'Uygulama açıkken konumun sunucuya gönderilir. Yaklaşık geçmiş bölgeler, sonradan bu bölgelerde paylaşılan hikâyeleri önermek ve bildirim tercihin açıksa haber vermek için saklanır. Kesin konumun diğer kullanıcılara gösterilmez. Arka planda konum kaydı yapılmaz. Kapattığında kayıt durur, geçmiş ve eşleşmelerin silinir.',
          action: 'Aç',
        );
        if (!confirmed || !mounted) return;
        await location.activateFromUi();
        if (!mounted || !location.allowed) return;
      } else {
        location.configure(active: true, history: false);
      }
      await store.saveAccountProfile({'location_history_enabled': enabled});
    });
  }

  static const messageOptions = {
    'everyone': 'Herkes',
    'following': 'Takip ettiklerim',
    'encounters': 'Karşılaştıklarım',
  };
  static const pushOptions = {
    'message': 'Mesajlar',
    'message_request': 'Mesaj istekleri',
    'encounter': 'Karşılaşmalar',
    'like': 'Beğeniler',
    'comment': 'Yorumlar',
    'follow': 'Takip',
    'location_match': 'Geçtiğim Yerlerden Haber Ver',
    'nearby_activity': 'Yakın bölge aktiviteleri',
    'map_note_nearby': 'Yakınıma bırakılan notlar',
    'map_note_reply': 'Notlarıma gelen cevaplar',
    'system': 'Sistem duyuruları',
  };
  bool? pushAllowed;

  Future<void> messagePrivacy(AppStore store) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in messageOptions.entries)
              ListTile(
                title: Text(option.value),
                trailing: option.key == store.account?.messagePrivacy
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, option.key),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      runAccountAction(
        () => store.saveAccountProfile({'message_privacy': chosen}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppPage(
      title: 'Gizlilik ve Tercihler',
      child: ListView(
        padding: Space.page,
        children: [
          ChoicePills(
            options: const ['Gizlilik', 'Konum', 'Bildirimler'],
            value: tab,
            onChanged: (v) => setState(() => tab = v),
          ),
          const SizedBox(height: Space.lg),
          if (tab == 'Gizlilik') ...[
            const InfoBanner(
              'Görünürlüğün senin kontrolünde.',
              'Kendine uygun deneyimi seç.',
              icon: Icons.shield_outlined,
            ),
            const SizedBox(height: Space.lg),
            PreferenceRow(
              "Yakınındaki İnsanlar'da görün",
              store.me.visible,
              busy
                  ? null
                  : (v) => runAccountAction(() async {
                      if (store.connected) {
                        await store.saveAccountProfile({'nearby_visible': v});
                      } else {
                        store.me.visible = v;
                        store.refresh();
                      }
                    }),
              subtitle: tr(
                'Kapattığında yakın profiller arasında görünmezsin.',
              ),
            ),
            if (store.connected)
              PreferenceRow(
                'Yakınımdaki karşılaşmaları öner',
                store.account?.encounterSuggestions ?? false,
                busy
                    ? null
                    : (v) => runAccountAction(
                        () => store.saveAccountProfile({
                          'encounter_suggestions': v,
                        }),
                      ),
              ),
            if (store.connected) ...[
              SettingsRow(
                'Bana kimler mesaj isteği gönderebilir',
                Icons.chat_bubble_outline,
                subtitle:
                    messageOptions[store.account?.messagePrivacy] ?? 'Herkes',
                onTap: busy ? null : () => messagePrivacy(store),
              ),
              PreferenceRow(
                'Aktiflik durumumu göster',
                store.account?.showActivity ?? false,
                busy
                    ? null
                    : (value) => runAccountAction(
                        () =>
                            store.saveAccountProfile({'show_activity': value}),
                      ),
              ),
            ],
            const InfoNote(
              'Kesin koordinatın, açık adresin ve canlı rotan diğer kullanıcılara gösterilmez.',
            ),
            const SizedBox(height: Space.xl),
            SettingsRow(
              'Engellenen Kullanıcılar',
              Icons.block,
              onTap: () => openPage(context, '/blocked'),
            ),
            SettingsRow(
              'Gizlilik Politikası',
              Icons.article_outlined,
              onTap: () => showLegal(context, 'Gizlilik Politikası'),
            ),
          ] else if (tab == 'Konum') ...[
            if (store.connected) DeviceLocationRow(enabled: !busy),
            SettingsRow(
              'Keşfettiğin şehir',
              Icons.location_on_outlined,
              subtitle: store.city,
              onTap: () async {
                final city = await chooseCity(context, store.city);
                if (city != null) {
                  await runAccountAction(() => store.setCity(city));
                }
              },
            ),
            PreferenceRow(
              'Konum temelli öneriler',
              store.preferences['Konum temelli öneriler']!,
              busy
                  ? null
                  : (v) => runAccountAction(() async {
                      if (store.connected) {
                        await store.saveAccountProfile({'city_discovery': v});
                      } else {
                        store.setPreference('Konum temelli öneriler', v);
                      }
                    }),
            ),
            PreferenceRow(
              'Geçtiğim Yerler',
              store.preferences['Geçtiğim yer bildirimleri']!,
              busy ? null : (v) => setHistory(store, v),
              subtitle: 'Ziyaret ettiğin yaklaşık bölgeleri geçici kaydet. Bu ayar bildirim izninden ayrıdır.',
            ),
            const SizedBox(height: Space.lg),
            SettingsRow(
              'Geçtiğim Yerlerden Haber Ver',
              Icons.notifications_outlined,
              subtitle: 'Geçmişinle ilgili hikâye bildirimlerini yönet.',
              onTap: () => setState(() => tab = 'Bildirimler'),
            ),
            const InfoNote(
              'Haritada paylaşım noktaları yaklaşık gösterilir. Konum geçmişini yalnızca sen yönetebilirsin.',
            ),
          ] else ...[
            if (store.connected) ...[
              if (store.push?.configured == true)
                FutureBuilder<bool>(
                  future: pushAllowed == null ? store.push!.status() : null,
                  builder: (context, snapshot) => PreferenceRow(
                    'Cihaz bildirimlerine izin ver',
                    pushAllowed ?? snapshot.data ?? false,
                    busy
                        ? null
                        : (value) => runAccountAction(() async {
                            final allowed = await store.push!.setEnabled(value);
                            if (mounted) setState(() => pushAllowed = allowed);
                          }),
                  ),
                )
              else
                const InfoNote(
                  'Bu cihazda uygulama içi bildirimler kullanılabilir.',
                ),
              const Divider(),
              for (final option in pushOptions.entries)
                PreferenceRow(
                  option.value,
                  store.account?.pushPreferences[option.key] ??
                      option.key != 'nearby_activity' &&
                          option.key != 'location_match',
                  busy
                      ? null
                      : (value) => runAccountAction(
                          () => store.saveAccountProfile({
                            'push_preferences': {option.key: value},
                          }),
                        ),
                ),
              const InfoNote(
                'Bu seçenekler yeni bildirimlerin oluşturulmasını ve cihaz bildirimlerini yönetir.',
              ),
            ] else
              PreferenceRow(
                'Bildirimlere izin ver',
                store.preferences['Bildirimlere izin ver']!,
                (value) => store.setPreference('Bildirimlere izin ver', value),
              ),
          ],
          const SizedBox(height: Space.xl),
        ],
      ),
    );
  }
}

class BlockedPage extends StatefulWidget {
  const BlockedPage({super.key});

  @override
  State<BlockedPage> createState() => _BlockedPageState();
}

class _BlockedPageState extends State<BlockedPage>
    with AccountAction<BlockedPage> {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    Widget content(List<Person> people, Widget? footer) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: Space.page,
      children: [
        const InfoNote(
          'Engellediğin kişilerle mesajlaşamazsın. Bu kişilerin paylaşımları ve bildirimleri gizlenir.',
        ),
        const SizedBox(height: Space.lg),
        if (people.isEmpty && footer == null)
          const EmptyState(
            'Engellenen kullanıcı yok.',
            'Gizlilik tercihlerinin kontrolü sende.',
            icon: Icons.shield_outlined,
          ),
        for (final p in people)
          UserRow(
            p,
            trailing: TextButton(
              onPressed: busy
                  ? null
                  : () => runAccountAction(
                      () => store.setRemoteBlock(p.id, false),
                    ),
              child: const Text(
                'Engeli Kaldır',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ?footer,
      ],
    );
    return AppPage(
      title: tr('Engellenen Kullanıcılar'),
      child: store.connected
          ? PagedContent<Person>(
              key: ValueKey(store.communicationVersion),
              fetch: store.communication!.blocks,
              id: (person) => person.id,
              builder: (context, people, footer, refresh) => RefreshIndicator(
                onRefresh: refresh,
                child: content(people, footer),
              ),
            )
          : content(
              store.people.where((p) => store.blocked.contains(p.id)).toList(),
              null,
            ),
    );
  }
}

class ReportPage extends StatefulWidget {
  const ReportPage(this.target, {super.key, this.remoteTarget});
  final String target;
  final ReportTarget? remoteTarget;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage>
    with AccountAction<ReportPage> {
  static const reasons = {
    'inappropriate': 'Uygunsuz içerik',
    'harassment': 'Taciz veya zorbalık',
    'spam': 'Spam veya dolandırıcılık',
    'fake': 'Sahte hesap',
    'hate': 'Nefret veya tehdit',
    'privacy': 'Gizlilik ihlali',
    'other': 'Diğer',
  };
  String reason = 'inappropriate';
  final details = TextEditingController();
  bool sent = false;

  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: tr('Şikâyet'),
    child: sent
        ? ListView(
            padding: Space.page,
            children: [
              const EmptyState(
                'Şikâyetin alındı.',
                'Güvenli bir topluluğa katkı sağladığın için teşekkürler.',
                icon: Icons.check_circle_outline,
              ),
              PrimaryButton(
                'Geri Dön',
                icon: Icons.check,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          )
        : ListView(
            padding: Space.page,
            children: [
              const InfoBanner(
                'Güvenli bir topluluk, birlikte.',
                'Şikâyetinin nedeni karşı tarafa gösterilmez.',
                icon: Icons.shield_outlined,
              ),
              const SizedBox(height: Space.lg),
              Text(
                widget.target,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SectionHeader('Neden şikâyet ediyorsun?'),
              for (final option in reasons.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    reason == option.key
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: reason == option.key
                        ? AppColors.blue
                        : AppColors.muted,
                  ),
                  title: Text(
                    option.value,
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: busy
                      ? null
                      : () => setState(() => reason = option.key),
                ),
              const SizedBox(height: Space.lg),
              if (reason == 'other')
                Field(
                  'Açıklama',
                  Icons.edit_outlined,
                  controller: details,
                  maxLines: 4,
                  maxLength: 500,
                ),
              PrimaryButton(
                'Şikâyeti Gönder',
                icon: Icons.flag_outlined,
                onPressed: busy
                    ? null
                    : () {
                        final store = StoreScope.of(context);
                        final description = reason == 'other'
                            ? details.text.trim()
                            : '';
                        if (reason == 'other' && description.isEmpty) {
                          toast(context, 'Şikâyet nedenini kısaca yaz.');
                          return;
                        }
                        runAccountAction(() async {
                          if (widget.remoteTarget case final target?) {
                            await store.communication!.report(
                              target,
                              reason,
                              description,
                            );
                          }
                          if (mounted) setState(() => sent = true);
                        });
                      },
              ),
            ],
          ),
  );
}

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage>
    with AccountAction<DeleteAccountPage> {
  final password = TextEditingController();
  final text = TextEditingController();
  @override
  void dispose() {
    password.dispose();
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: tr('Hesabımı Sil'),
    child: ListView(
      padding: Space.page,
      children: [
        const SizedBox(height: Space.xl),
        const Icon(
          Icons.heart_broken_outlined,
          color: AppColors.blue,
          size: 65,
        ),
        const SizedBox(height: Space.xl),
        Text(
          'Gitmene üzüldük.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: Space.lg),
        const InfoNote(
          'Hesabın kalıcı olarak kapatılır. Profilin ve içeriklerin görünmez olur; oturumların, kayıtlı cihazların ve konum verilerin temizlenir. Bu işlem geri alınamaz. İlişkilerin bütünlüğü için kimlik bilgisi içermeyen kayıtlar kalabilir.',
        ),
        const SizedBox(height: Space.xl),
        if (StoreScope.of(context).connected) ...[
          Field(
            'Şifre',
            Icons.lock_outline,
            controller: password,
            obscure: true,
            key: const Key('delete-password'),
          ),
          const SizedBox(height: Space.lg),
        ],
        const Text(
          'Devam etmek için aşağıya SİL yaz.',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: Space.md),
        TextField(
          key: const Key('delete-confirmation'),
          controller: text,
          enabled: !busy,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: tr('SİL')),
        ),
        const SizedBox(height: Space.lg),
        FilledButton.icon(
          key: const Key('delete-account'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: busy || !isDeleteConfirmation(text.text)
              ? null
              : () => runAccountAction(() async {
                  final store = StoreScope.of(context);
                  if (store.connected) {
                    await store.eraseAccount(password.text);
                  } else {
                    store.deleteAccount();
                  }
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/welcome',
                    (_) => false,
                  );
                }),
          icon: const Icon(Icons.delete_outline),
          label: Text(busy ? 'İşleniyor…' : 'Hesabımı Sil'),
        ),
        const SizedBox(height: Space.sm),
        SecondaryButton(
          'Vazgeç',
          onPressed: busy ? null : () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

class LegalPage extends StatefulWidget {
  const LegalPage(this.title, {super.key});
  final String title;
  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  Future<Map<String, dynamic>>? document;
  static const slugs = {
    'Gizlilik Politikası': 'gizlilik',
    'KVKK': 'kvkk',
    'Kullanım Koşulları': 'kullanim-kosullari',
    'Topluluk Kuralları': 'topluluk-kurallari',
  };
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = StoreScope.of(context);
    if (store.connected && document == null) {
      document = store.auth!.client
          .send('GET', 'legal/${slugs[widget.title] ?? 'gizlilik'}')
          .then((value) => value as Map<String, dynamic>);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: widget.title,
    child: FutureBuilder<Map<String, dynamic>>(
      future: document,
      builder: (context, snapshot) {
        if (document != null &&
            snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            padding: Space.page,
            children: [
              const InfoNote(
                'Bilgilere ulaşılamadı. Bağlantını kontrol edip tekrar dene.',
              ),
              PrimaryButton(
                'Tekrar Dene',
                onPressed: () => setState(() {
                  document = null;
                  didChangeDependencies();
                }),
              ),
            ],
          );
        }
        return ListView(
          padding: Space.page,
          children: [
            Text(
              snapshot.data?['title'] as String? ?? widget.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: Space.lg),
            Text(
              snapshot.data?['body'] as String? ?? 'SenMiydin? topluluğunda saygı ve güven esastır. Kesin konum ve kişisel bilgileri izinsiz paylaşma. Gizlilik tercihlerini ayarlardan yönetebilirsin.',
              style: const TextStyle(height: 1.7),
            ),
          ],
        );
      },
    ),
  );
}
