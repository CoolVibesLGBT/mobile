# Coolvibes — Flutter

Flutter uygulaması doğrudan bu dizindedir. React Native kaynak proje değiştirilmedi:
`../coolvibes/mobile/coolvibes` (mutlak kaynak yolu `Design/source-inventory.json` içinde).

[VS Code eklentisini indir](https://marketplace.visualstudio.com/items?itemName=CoolVibes.coolvibes-vscode-extension)

## Çalıştırma

Proje SDK sürümü `.flutter-version` içinde 3.41.9'a sabitlidir. `tool/flutterw`
bu SDK'yı kullanıcı önbelleğine kurar; sistem genelindeki Flutter'ı değiştirmez.
Harita üzerindeki yuvarlak blur sınırları Flutter 3.41'in iOS motor düzeltmesini
gerektirir. VS Code da wrapper'ın oluşturduğu `.flutter-sdk` bağlantısını kullanır.

```sh
./tool/flutterw pub get
./tool/flutterw run
```

Aşağıdaki diğer `flutter` komutları için de `./tool/flutterw` kullanın.

Servis adreslerini kaynak kodu değiştirmeden ayarlamak için:

```sh
flutter run --dart-define=API_URL=https://api.coolvibes.lgbt/api \
  --dart-define=SOCKET_URL=wss://socket.coolvibes.app
```

## Kayıt CAPTCHA bayrağı

`lib/core/constants.dart` içindeki `AppConstants.registrationCaptchaEnabled`
varsayılan olarak `false`. Bu durumda kayıt, React Native istemciyle aynı
`captcha: COOLVIBES` alanını gönderir; backend'in mevcut mobil akışı kullanılır.
Bayrağın `defaultValue` değerini `true` yapıp yeniden derleyerek CAPTCHA'yı
açabilirsiniz. Derleme sırasında da etkinleştirilebilir:

```sh
flutter run --dart-define=REGISTRATION_CAPTCHA_ENABLED=true
```

Açıkken doğrulama tamamlanmadan kayıt isteği gönderilmez; yalnızca alınan
`recaptchaToken` iletilir. Giriş işlemi CAPTCHA istemez. Site anahtarı ve
doğrulama origin'i aynı constants dosyasında bulunur.

iOS simülatörüne kurulacak uygulamayı `--no-codesign` ile derlemeyin.
İmzasız derlemede Keychain erişimi `-34018` hatasıyla engellenir; bu yüzden
sunucu girişe izin verse bile oturum kaydedilemez. `flutter run -d <ios-id>`
veya `flutter build ios --simulator --debug` kullanın. Fiziksel iPhone için
Xcode'daki Runner hedefinin kendi geliştirme takımınızla imzalanması gerekir.

Giriş/kayıt hataları `showErrorSheet` üzerinden ortak `ScreenStatus` ve yerel
`UtyanRestricted` ördek animasyonuyla gösterilir. HTTP kodu ve güvenli hata
kodu açılabilir detay alanındadır; ham yanıt, şifre ve token gösterilmez.
`/debug` kataloğunda bağlantı, HTTP, kayıt ve Keychain hata örnekleri bulunur.

Bilgi, hata ve teyitler aynı `AppInfoSheet` gövdesini kullanır. Ayarlardaki
çıkış ve hesap silme, profil/fotoğraf onayları ve mesaj silme kapsam seçimi
ördek animasyonlu bu panelle açılır. Hesap silme, `user.delete_profile`
başarılı olmadan oturumu temizlemez. Sohbet bildirimleri klavye ve inputun
ölçülen yüksekliğine göre yukarı taşınır; bildirim açıkken input kullanılabilir.

İlet panelindeki **Seç** ile birden fazla kişi/grup işaretlenebilir; arama
seçimleri korur. Ortak yorum, mevcut `chat.forward_messages` sözleşmesiyle her
hedefe iletilir. Onaylanan hedefler seçimden çıkar; kısmi hatada yalnızca kalan
hedefler yeniden denenir. Başarı, sunucunun mesaj yanıtıyla doğrulanır.

Bu değişikliklerin doğrulaması: 320 test geçti, 2 opt-in test atlandı; değişen
20 Dart dosyasında hedefli analiz temiz. iOS simülatör derlemesi başarılı.
Yerel Go servisiyle iOS kayıt → çıkış → giriş ve üretim Keychain ayarlarıyla
geçici anahtar yazma/okuma/silme testi geçti; oluşturulan test hesabı temizlendi.
Çoklu iletme, aramada seçim koruma ve kısmi hata sonrası tekrar gönderim
kontrolleri sahte API ile yapıldı; gerçek kullanıcı sohbetlerine mesaj gönderilmedi.

## Debug ekran kataloğu

```sh
flutter run --dart-define=DEBUG_GALLERY=true
```

Normal debug çalıştırmada giriş ekranındaki geliştirici simgesinden veya
Menü → Ekran kataloğu üzerinden de açılır. Release yapılarında bu giriş bulunmaz.

Katalog üretimdeki ekranları ve form tanımlarını kullanır. Ayrı demo ekranı çizilmez.
`PreviewApi` gerçek HTTP taşıyıcısını çağırmaz; önizlemede değişiklik kaydedilmez.
Katalog üretim ekranlarını, form varyantlarını ve materyal-hareket kontrolünü içerir.
Her ekran için populated / empty / loading / error, açık-koyu tema, Türkçe,
İngilizce, Arapça/RTL, 1x/1.3x/2x metin ve 8pt hizalama ızgarası bulunur.

Belirli bir ekranı doğrudan açmak ve gerçek tam ekran ölçüsünü görmek için:

```sh
flutter run --dart-define=DEBUG_GALLERY=true \
  --dart-define=DEBUG_SCREEN=shell --dart-define=DEBUG_FULLSCREEN=true
```

Radarı kaynakla aynı sekme çubuğuyla açmak için `DEBUG_SCREEN=shell` ile
`--dart-define=DEBUG_TAB=2` kullanın. `DEBUG_SCREEN=radar` aynı üretim ekranını
tek başına açar.

`DEBUG_SCREEN=components.motion` Lottie, basılma ve materyal kontrolünü açar.

## Tek bileşen kuralı

- `lib/components/record_list.dart`: sayfalama, yenileme ve eski yanıt koruması.
- `lib/components/remote_content.dart`: tek kayıt istekleri ve tekrar deneme.
- `lib/components/screen_status.dart`: yükleme, boş ve hata sunumu.
- `lib/components/action_form.dart`: ortak alan, doğrulama, kaydetme ve hata düzeni.
- `lib/screens/app_forms.dart`: üretim ve debug için tek iş kuralı/form tanımı.
- `lib/components/app_pressable.dart`: Telegram buton/satır down/up/cancel ve 200/400 ms dönüşü.
- `lib/components/app_button.dart`, `app_row.dart`: ortak buton, satır ve switch. Kayıt onayı, tercihler, profil gizliliği, kişi seçimi ve düzenlenebilir makale listeleri aynı `AppSwitch` kontrolünü kullanır.
- `lib/components/app_lottie.dart`: tek Lottie oynatıcısı, lifecycle ve Reduce Motion.
- `lib/components/app_tab_bar.dart`, `glass_surface.dart`: ortak Flutter cam yüzeyleri ve platform görünümü desteği.
- `lib/components/person_tile.dart`: kişi satırı ve kişi seçimi.
- `lib/components/avatar.dart`, `app_image.dart`: avatar ve tek ağ görseli yükleyicisi.
- `lib/components/profile_photo_editor.dart`: profil ve düzenleme ekranları için ortak galeri/kamera seçimi, karartılmış kırpma dışı alan, dairesel avatar ve 3:1 kapak kırpması, yakınlaştırma, döndürme, aynalama, onay ve yükleme. Galeri `attachment_sheet.dart` içindeki tek fotoğraf kipidir. Debug girişleri: `profile.photo.avatar`, `profile.photo.cover`.
- `lib/screens/auth.dart`: web ile aynı karşılama, giriş ve kayıt akışı; ortak form kontrolleri ve web çizimleri. Debug girişleri: `auth.welcome`, `auth.login`, `auth.register`.
- `lib/components/brand_mark.dart`: kaynak mobildeki kompakt marka ve navigasyon başlığı.
- `lib/core/mobile_spring.dart`: Radar ve profil için kaynak Reanimated 4 yay fiziği.
- `lib/components/app_header.dart`: bütün ekranların şeffaf ortak başlığı.
- `lib/components/chat_input.dart`, `message_field.dart`: chat ve post için tek yazma alanı.
- `lib/components/chat_bubble.dart`: özel/grup sohbetlerinde tek mesaj balonu.
- `lib/screens/media.dart`: tek fotoğraf/video görüntüleme akışı.
- `lib/design/app_design.dart`: Telegram kaynaklarından alınan ölçüler ve tema.

Yeni bir ekran aynı işi yapan ikinci bir widget üretmez; ilgili ortak bileşeni
parametreleriyle kullanır. Debug kataloğuna gerçek ekranın constructor'ı eklenir.

## Kontroller

`secondary_screens_test.dart` ve `secondary_data_test.dart`; bildirimlerin göndereni,
filtreleri, hedef ekranları ve socket yenilemesini; ilanların çevirilerini,
detay kimliğini, başarısız gönderimde ve canlı yenilemede taslak korumasını;
yasal belgelerin içindekiler menüsünü ve Premium hesap bağlantısını kontrol eder.
Dar ekran, büyük yazı, koyu tema ve Arapça yönü aynı üretim bileşenleriyle denenir.
`secondary_runtime_test.dart`, bu akışları iOS dokunuşlarıyla çalıştırır;
`SECONDARY_SERVICE=true` yerel serviste ilan detaylarını ve mevcut oturumun
bildirimlerini veri değiştirmeden okur.

Premium ekranı mevcut web hesap bağlantısını kullanır; native abonelik satın alma
akışı içermez. Bildirimlerde sunucunun `is_read` durumu gösterilir; backend'de
kayıtlı bir okundu işaretleme endpoint'i olmadığı için istemci sahte bir
okundu durumu üretmez. Yasal belgeler ve çizimler web projesindeki Türkçe,
İngilizce ve Arapça kaynakların kopyalarıdır; web metinleri değişirse bu
paketlenmiş kaynakların da güncellenmesi gerekir.

Profil fotoğrafı akışının widget kontrolleri `test/profile_photo_editor_test.dart`
içindedir: iptal, onay öncesi yüklememe, sürükleme/sıfırlama, kırpılmış dosyanın
oranı ve piksel içeriği, aynalama/döndürme/sıfırlama, başarısız yüklemede seçimi
koruma, yeniden deneme ve RTL/büyük metinde form taslağını koruma.
Bu kontroller gerçek kamera/galeri
izinlerini veya Telegram ile piksel eşitliğini doğrulamaz.

`attachment_photo_selection_test.dart`, profil seçiminde tek fotoğrafı açmayı,
sohbette çoklu seçimin gönder düğmesini beklemesini ve indirme sırasında iptali
kontrol eder. `choice_switch_test.dart`, satır/anahtar dokunuşunu, pasif durumu
ve switch erişilebilirlik bilgisini Türkçe/Arapça büyük metinle doğrular.
`auth_web_parity_test.dart`, giriş/kayıt yerleşimi, doğrulama, klavye alanı ve
oturum akışını kontrol eder. `auth_glass_test.dart` simülatörde gerçek OS
dokunuşları, yerel HTTP ve ayrı Keychain hesabını kullanır; metin girişi test
klavyesiyle yapılır. Üretim hesabına istek göndermez.

`local_login_test.dart`, `RUN_LOCAL_AUTH_MUTATIONS=true` ile açılır ve yalnızca
`localhost:4001` üzerinde geçici bir hesapla kayıt → çıkış → giriş akışını
kontrol eder. Ayrı Keychain hesabı kullanır ve oluşturduğu hesabı test sonunda
kaldırır. CAPTCHA bayrağının kapalı olması gerekir. Bu yerel backend kontrolü
2026-10-26 tarihinde iOS simülatöründe geçti. CAPTCHA'nın açık ve kapalı kayıt
istekleri de `auth_web_parity_test.dart` ile ayrı ayrı doğrulandı.

2026-10-26: 303 test ve simülatörde 2 etkileşim testi geçti; canlı servis
gerektiren 2 test kapalıydı. iOS simülatör ve Android debug derlemeleri başarılı.
Değişen 18 Dart dosyasında hedefli analiz temiz; tüm proje analizinde mevcut
24 bilgi düzeyi lint bildirimi bulunuyor. Fiziksel cihazda kamera/izin akışı
ve Telegram ile piksel karşılaştırması yapılmadı.

```sh
flutter analyze
flutter test
flutter build ios --simulator --debug
flutter build apk --debug
```

Kaynak temelli ölçüler, mevcut doğrulama ve eksikler `Design/verification.md`
içindedir. Katalogda bir ekranın bulunması tam özellik eşitliği veya Telegram ile
piksel karşılaştırmasının tamamlandığı anlamına gelmez.

Native giriş/Keychain ve Radar etkileşim kontrolleri:

```sh
flutter drive --driver=test_driver/auth_glass.dart \
  --target=integration_test/auth_glass_test.dart -d <ios-simulator-id>
```

Bu testler giriş için yerel HTTP servisi ve ayrı Keychain alanı kullanır;
üretim hesabı oluşturmaz veya gerçek servise veri yazmaz.

Konum/yorum/check-in native akışları:

```sh
flutter drive --driver=test_driver/location_composition.dart \
  --target=integration_test/location_composition_test.dart -d <ios-simulator-id>
```

Harita gerçek WKWebView'da yüklenir; gönderimler izole test verileri kullanır.
Son kabul kapsamı ve açık kalanlar `Design/verification.md` içinde tutulur.
