# PRD v2 — DynaNotch (Boring.Notch Fork)

**Proje Adı:** DynaNotch  
**Base:** Boring.Notch fork (GPL v3)  
**Versiyon:** 2.0.0  
**Yazar:** Boğaç  
**Tarih:** Mart 2026  
**Durum:** Aktif Geliştirme  
**Repo:** github.com/bogachanulker/boring.notch

---

## 1. Vizyon ve Özet

DynaNotch, Boring.Notch'un açık kaynak code base'i üzerine inşa edilen, **plugin mimarisi**, **external ekran desteği**, **canlı şarkı sözleri**, **akıllı bildirimler**, **Apple Shortcuts entegrasyonu** ve **AI asistan** gibi özgün özelliklerle genişletilmiş bir macOS notch uygulamasıdır.

Boring.Notch'un olgun medya kontrolleri, file shelf, HUD replacer gibi temel özelliklerini koruyarak, üzerine hiçbir rakibin sunmadığı özellikleri ekleyerek **notch'u bir platforma** dönüştürmeyi hedefliyoruz.

### Temel Fark: Platform Yaklaşımı
Mevcut notch uygulamaları (Boring.Notch, Atoll, Alcove) kapalı sistemler — yalnızca kendi built-in özelliklerini sunarlar. DynaNotch, açık bir plugin protokolü ile üçüncü parti uygulamaların notch'a veri göndermesine ve widget göstermesine olanak tanıyacak. Bu sayede:
- Arkadaşın canlı skor app'i → notch'ta maç widget'ı
- Herhangi bir geliştirici hava durumu app'i yapar → notch'ta hava widget'ı
- Kripto tracker → notch'ta fiyat ticker
- Pomodoro app'i → notch'ta geri sayım

### Hedef Kitle
- MacBook Pro 14"/16" (2021+) ve MacBook Air M3/M4 kullanıcıları
- External ekran kullanan masaüstü Mac kullanıcıları
- Müzik dinlerken lyrics görmek isteyen kullanıcılar
- macOS ekosisteminde üretkenlik araçlarına ilgi duyan geliştiriciler ve tasarımcılar
- Plugin geliştirmek isteyen üçüncü parti geliştiriciler

---

## 2. Boring.Notch'tan Devralınan Özellikler

Fork ile gelen ve korunacak mevcut özellikler:

- Müzik kontrolleri + audio-reactive görselleştirici
- Album art tabanlı renk senkronizasyonu ve dinamik gradient
- AirDrop file shelf (sürükle-bırak dosya paylaşımı)
- Takvim entegrasyonu (EventKit)
- Kamera önizleme (ayna modu)
- Batarya göstergesi
- macOS HUD değiştirici (ses/parlaklık)
- Clipboard monitörü
- Notch'suz Mac'lerde simüle notch desteği

---

## 3. Rekabet Analizi

### 3.1 Boring.Notch (Base — GPL v3)
- **GitHub:** TheBoredTeam/boring.notch
- **Güçlü:** Olgun code base, aktif topluluk, geniş özellik seti, <%2 CPU
- **Eksik:** Plugin sistemi yok, external ekran özel desteği yok, lyrics yok, bildirim yönetimi yok, AI entegrasyonu yok, Shortcuts entegrasyonu yok

### 3.2 Atoll (Boring.Notch Fork — GPL v3)
- **GitHub:** Ebullioscopic/Atoll
- **Güçlü:** Live Activities, lock screen widget, sistem izleme, kullanıcı profilleri
- **Eksik:** Aynı eksikler — plugin yok, lyrics yok, AI yok, platform yaklaşımı yok

### 3.3 Alcove (Ücretli — $16.99)
- **Güçlü:** En cilalı UI, minimum permission, lock screen entegrasyonu
- **Eksik:** Kapalı kaynak, ücretli, tek geliştirici bağımlılığı, genişletilemez

### 3.4 Dynamic Notch by musiclyrics.cn
- **Güçlü:** Gerçek zamanlı lyrics gösterimi — piyasadaki tek notch uygulaması
- **Eksik:** Kapalı kaynak, ücretli (premium), lyrics dışında sınırlı özellik seti

### Piyasa Boşluğu
Hiçbir mevcut çözüm şunları sunmuyor:
1. Açık plugin/extension sistemi (platform yaklaşımı)
2. External ekran için özel floating tab modu
3. Lyrics + medya kontrol birleşimi (açık kaynak olarak)
4. Apple Shortcuts entegrasyonu
5. AI asistan entegrasyonu
6. Akıllı bildirim merkezi (gruplu, swipe yönetimli)
7. Üçüncü parti veri beslemesi (canlı skor, kripto, hava durumu vb.)

---

## 4. Yeni Özellikler — Phase Planı

### Phase 1 — External Ekran + Stabilizasyon (Hafta 1-3)

#### 4.1.1 External Ekran Floating Tab
Boring.Notch dahil hiçbir uygulamanın düzgün yapmadığı özellik.

- Notch'suz ekranlarda (external monitor, eski MacBook) ekranın üst ortasından aşağı inen pill şeklinde tab
- Collapsed: Ekranın üst ortasında ince (4px yükseklik, ~200px genişlik) çizgi/pill
- Hover → expand: Aşağı doğru spring animasyonla açılır, aynı içeriği gösterir
- Mouse çıkınca yukarı kayarak gizlenir
- `NotchDisplayMode` enum: `.physicalNotch` | `.floatingTab`
- DisplayManager'da otomatik algılama: notch varsa physicalNotch, yoksa floatingTab
- Kullanıcı ayarlardan override edebilir

#### 4.1.2 Boring.Notch Code Base Stabilizasyonu
- Mevcut bug'ları gider (bilinen UI sorunları, hover timing)
- Kod tabanını incele, mimariyi anla
- Kendi CLAUDE.md'yi fork'a ekle
- CI/CD pipeline kur (GitHub Actions)

#### 4.1.3 Plugin Altyapısı (Temel)
- `NotchPlugin` protokolü tanımla
- Plugin kayıt sistemi (PluginRegistry)
- Basit veri modeli: plugin adı, ikon, içerik view, güncelleme intervali
- İlk dahili plugin: mevcut özellikleri plugin formatına refactor et

### Phase 2 — Canlı Şarkı Sözleri + Shortcuts (Hafta 4-7)

#### 4.2.1 Canlı Şarkı Sözleri (Lyrics)
Piyasada açık kaynak notch uygulamalarının hiçbirinde yok.

- **Veri Kaynakları:**
  - LRCLIB (açık kaynak lyrics veritabanı, LRC formatı)
  - Musixmatch API (geniş kütüphane, rate limit var)
  - Apple Music MusicKit (Apple Music aboneleri için native lyrics)
  - Fallback zinciri: MusicKit → LRCLIB → Musixmatch
- **Görüntüleme:**
  - Karaoke modu: Aktif satır vurgulu, önceki/sonraki satırlar soluk
  - Compact modu: Tek satır, şarkı adının altında kayan metin
  - Renk: Album art dominant rengine uyumlu text rengi
  - Senkronizasyon: Zaman damgalı LRC parse, playback pozisyonuyla eşleştirme
- **Medya Modülüne Entegrasyon:**
  - Mevcut MediaPlayerView'a lyrics toggle butonu ekle
  - Expanded modda album art yanında lyrics alanı
  - Full panel modda tam ekran lyrics görünümü
- **Cache:** Şarkı ID bazlı lyrics cache (Core Data veya dosya sistemi)
- **Ayarlar:** Lyrics aç/kapa, font boyutu, varsayılan kaynak seçimi

#### 4.2.2 Apple Shortcuts Entegrasyonu
- `AppIntents` framework ile Shortcuts aksiyonları tanımla
- Notch'a pin'lenebilir shortcut widget'ları
- Örnekler: WiFi toggle, Focus modu aç/kapa, ses kaynağı değiştir, ekran parlaklığı preset
- Expanded notch'ta küçük shortcut butonları satırı
- Kullanıcı ayarlardan hangi shortcut'ların görüneceğini seç

#### 4.2.3 Plugin Altyapısı (Genişletilmiş)
- Plugin'ler arası iletişim protokolü
- Harici veri beslemesi: URL-scheme veya local socket ile üçüncü parti app'ten veri alma
- Plugin ayarları paneli
- Plugin marketplace UI temeli (ayarlarda liste)

### Phase 3 — Bildirimler + AI + Platform (Hafta 8-12)

#### 4.3.1 Akıllı Bildirim Merkezi
macOS bildirimleri dağınık ve yönetimi zor — notch bunu çözebilir.

- `UNUserNotificationCenter` delegate ile gelen bildirimleri yakala
- Notch'tan aşağı akan, gruplanmış bildirim kartları
- Uygulama bazlı gruplama (Slack mesajları, Mail, Calendar hatırlatmaları)
- Swipe gesture ile yönetim: sağa swipe → aç, sola swipe → kapat, yukarı swipe → sessize al
- Bildirim öncelik sistemi: Yüksek (çağrı, alarm) → Orta (mesaj, mail) → Düşük (güncelleme)
- Do Not Disturb entegrasyonu (macOS Focus ile senkron)
- Bildirim geçmişi (son 50 bildirim)

#### 4.3.2 AI Asistan (Claude API)
Notch'ta mini AI asistan — hızlı soru-cevap.

- Notch'a tıkla veya keyboard shortcut (⌘+Shift+N)
- Küçük text input field açılır (notch'tan aşağı)
- Claude API'ye (claude-haiku-4-5 — hızlı ve ucuz) istek gönder
- Cevap baloncuk şeklinde gösterilir
- Kullanım senaryoları:
  - "Bu dosyayı özetle" (file shelf'teki dosyayı analiz et)
  - "Sonraki toplantım ne zaman" (takvim verisiyle cevapla)
  - "Bu şarkının sözlerini çevir" (lyrics modülüyle entegre)
  - Hızlı hesaplama, çeviri, tanım sorma
- API key ayarlardan girilir
- Token limiti: Mesaj başına max 500 token (hızlı cevap)
- Conversation geçmişi: Son 5 mesaj tutulur (context)

#### 4.3.3 Plugin Platform (Tam)
- Harici plugin yükleme desteği (.dynplugin bundle formatı)
- Plugin API dokümantasyonu
- Örnek plugin template repo'su
- **Canlı skor plugin'i:** Arkadaşın live score app'i ile entegrasyon noktası
  - Plugin, arkadaşın API'sinden maç verisi çeker
  - Notch'ta canlı skor widget'ı: takım logoları, skor, dakika
  - Gol animasyonu
  - Maç durumu (devam ediyor, devre arası, bitti)
- **Hava durumu plugin'i:** Open Meteo API ile örnek plugin
- **Kripto ticker plugin'i:** Örnek plugin template

#### 4.3.4 Diğer Phase 3 Özellikleri
- Lock screen widget'ları
- Gelişmiş gesture kontrolleri
- Kullanıcı profilleri (Developer/Designer/Student)
- *(Opsiyonel)* Word-by-word lyrics animasyonu (Apple Music tarzı)

---

## 5. Teknik Mimari

### 5.1 Fork Üzerine Eklenen Katmanlar

```
boring.notch (mevcut code base)
│
├── Mevcut Özellikler (korunacak)
│   ├── Media Player + Visualizer
│   ├── File Shelf + AirDrop
│   ├── Calendar + Battery + Camera
│   ├── HUD Replacer + Clipboard
│   └── Simulated Notch (notch'suz Mac)
│
└── DynaNotch Eklentileri (yeni)
    ├── Core/
    │   ├── FloatingTab/              # External ekran floating tab modu
    │   │   ├── FloatingTabController.swift
    │   │   ├── FloatingTabGeometry.swift
    │   │   └── FloatingTabAnimator.swift
    │   └── PluginSystem/             # Plugin altyapısı
    │       ├── NotchPlugin.swift     # Plugin protokolü
    │       ├── PluginRegistry.swift  # Plugin kayıt ve yönetim
    │       ├── PluginHost.swift      # Plugin view hosting
    │       └── PluginIPC.swift       # Harici app iletişimi
    │
    ├── Features/
    │   ├── Lyrics/                   # Canlı şarkı sözleri
    │   │   ├── LyricsManager.swift   # Lyrics fetch + sync
    │   │   ├── LyricsParser.swift    # LRC format parser
    │   │   ├── LyricsView.swift      # Karaoke/compact görünüm
    │   │   ├── LRCLibService.swift   # LRCLIB API client
    │   │   └── MusixmatchService.swift
    │   ├── Shortcuts/                # Apple Shortcuts
    │   │   ├── ShortcutsManager.swift
    │   │   ├── ShortcutWidgetView.swift
    │   │   └── Intents/              # AppIntents tanımları
    │   ├── Notifications/            # Akıllı bildirimler
    │   │   ├── NotificationManager.swift
    │   │   ├── NotificationCardView.swift
    │   │   └── NotificationGroupView.swift
    │   └── AIAssistant/              # Claude AI
    │       ├── AIManager.swift       # Claude API client
    │       ├── AIInputView.swift     # Text input
    │       └── AIResponseView.swift  # Cevap baloncuğu
    │
    └── Plugins/                      # Örnek plugin'ler
        ├── LiveScorePlugin/          # Canlı skor (arkadaşın app'i ile)
        ├── WeatherPlugin/            # Hava durumu
        └── PluginTemplate/           # Geliştirici şablonu
```

### 5.2 Plugin Protokolü

```swift
protocol NotchPlugin: Identifiable {
    var id: String { get }
    var displayName: String { get }
    var icon: String { get }                    // SF Symbols
    var version: String { get }
    var author: String { get }
    
    // Yaşam döngüsü
    func activate()
    func deactivate()
    
    // UI
    @ViewBuilder var compactView: some View { get }  // Collapsed notch
    @ViewBuilder var expandedView: some View { get }  // Expanded notch
    @ViewBuilder var settingsView: some View { get }  // Ayarlar paneli
    
    // Veri
    var updateInterval: TimeInterval { get }     // Polling sıklığı
    func fetchData() async throws               // Veri güncelleme
}

// Harici app'lerden veri almak için
protocol ExternalDataProvider {
    var scheme: String { get }                   // URL scheme: "dynanotch://plugin/livescore"
    func handleIncomingData(_ data: Data)
}
```

### 5.3 Harici Uygulama Entegrasyonu (Canlı Skor Örneği)

```
Arkadaşın Live Score App
    │
    ├── URL Scheme: dynanotch://plugin/livescore?data={json}
    │   veya
    ├── Local WebSocket: ws://localhost:9876/livescore
    │   veya
    └── Shared App Group: group.com.dynanotch.plugins
    
    ↓
    
DynaNotch Plugin System
    ├── PluginIPC alır → LiveScorePlugin'e yönlendirir
    └── LiveScorePlugin → NotchWidget'ta gösterir
        ├── Takım logoları (küçük, 24x24)
        ├── Skor: "2 - 1"
        ├── Dakika: "67'"
        └── Gol animasyonu (konfeti efekti)
```

### 5.4 Performans Hedefleri
- Boring.Notch'un mevcut performansını korumak (<%2 CPU)
- Plugin'ler izole: Bir plugin crash olursa ana uygulama etkilenmez
- Lyrics fetch background thread'de, UI güncellemesi @MainActor
- AI API çağrıları async, timeout 10 saniye
- Plugin polling: Her plugin kendi intervalinde, minimum 1 saniye

---

## 6. Geliştirme Yol Haritası

### Phase 1 — External Ekran + Stabilizasyon (Hafta 1-3)
- [ ] Boring.Notch code base analizi ve mimari dokümantasyon
- [ ] CLAUDE.md oluştur (fork'a özel kurallar)
- [ ] External ekran floating tab modu
- [ ] Mevcut bug fix'ler ve stabilizasyon
- [ ] Plugin protokolü temel tanımı
- [ ] CI/CD (GitHub Actions: build + test)

### Phase 2 — Lyrics + Shortcuts (Hafta 4-7)
- [ ] LRC parser ve lyrics fetch servisleri
- [ ] Karaoke + compact lyrics görünümü
- [ ] Medya modülüne lyrics entegrasyonu
- [ ] Apple Shortcuts / AppIntents entegrasyonu
- [ ] Shortcut widget'ları notch'ta
- [ ] Plugin sistemi genişletme (harici veri beslemesi)
- [ ] Lyrics cache sistemi

### Phase 3 — Bildirimler + AI + Platform (Hafta 8-12)
- [ ] Akıllı bildirim merkezi
- [ ] Claude AI asistan entegrasyonu
- [ ] Plugin marketplace UI
- [ ] Harici plugin yükleme (.dynplugin)
- [ ] Canlı skor plugin (arkadaşın app'i ile entegrasyon)
- [ ] Örnek plugin'ler (hava durumu, kripto)
- [ ] Plugin geliştirici dokümantasyonu
- [ ] Lock screen widget'ları
- [ ] Kullanıcı profilleri

---

## 7. Lisans ve Atıf

- **Lisans:** GPL v3 (Boring.Notch ile aynı — zorunlu)
- **README'de kredi:**
  - Boring.Notch — TheBoredTeam (temel code base)
  - Atoll — Ebullioscopic (ilham: Live Activities konsepti)
  - Alcove — Henrik Ruscon (ilham: UI polish standartları)
  - Dynamic Notch by musiclyrics.cn (ilham: lyrics konsepti)
- **Katkıda bulunanlar:** CONTRIBUTORS.md dosyası

---

## 8. Dağıtım

### İlk Aşama
- GitHub Releases üzerinden DMG dağıtımı
- Homebrew Cask desteği
- Gatekeeper bypass talimatları

### Gelecek
- Apple Developer Program ile notarization
- Sparkle framework ile otomatik güncelleme
- Plugin marketplace (community-driven)
- Opsiyonel: Bağış destekli dağıtım (Ko-fi / GitHub Sponsors)

---

## 9. Başarı Metrikleri
- GitHub yıldız sayısı: İlk 3 ayda 1000+ (fork avantajı ile)
- CPU kullanımı: Mevcut Boring.Notch seviyesini koru (<%2)
- Crash-free oranı: >%99
- Plugin ekosistemi: İlk 6 ayda 5+ üçüncü parti plugin
- Topluluk: Discord/GitHub Discussions aktif kullanıcı sayısı
- Fark yaratan özellik: Lyrics ve AI asistan kullanım oranı
