# CLAUDE.md — DynaNotch (Boring.Notch Fork)

> Bu dosya, Claude Code'un bu fork ile çalışırken takip etmesi gereken kuralları tanımlar.

---

## Proje Özeti

DynaNotch, Boring.Notch'un GPL v3 fork'udur. Mevcut code base'i koruyarak üzerine external ekran desteği, canlı şarkı sözleri, Apple Shortcuts entegrasyonu, akıllı bildirimler, AI asistan ve plugin sistemi ekliyoruz.

## Altın Kural

**Mevcut Boring.Notch özelliklerini bozma.** Her değişiklikten sonra mevcut özelliklerin (medya, file shelf, takvim, batarya, HUD, clipboard) hâlâ çalıştığını doğrula.

## Kod Tabanı Yapısı

Bu bir fork olduğu için önce mevcut yapıyı anla. Değişiklik yapmadan önce ilgili dosyaları oku. Yeni özellikler mümkün olduğunca izole modüller olarak ekle — mevcut dosyalara minimum dokunarak.

### Yeni Kod Nereye Gider

Tüm yeni özellikler şu dizinlere eklenir:
- `boringNotch/Features/Lyrics/` — Şarkı sözleri modülü
- `boringNotch/Features/Shortcuts/` — Apple Shortcuts entegrasyonu
- `boringNotch/Features/Notifications/` — Akıllı bildirimler
- `boringNotch/Features/AIAssistant/` — Claude AI asistan
- `boringNotch/Core/FloatingTab/` — External ekran modu
- `boringNotch/Core/PluginSystem/` — Plugin altyapısı
- `boringNotch/Plugins/` — Örnek plugin'ler

### Mevcut Koda Dokunurken

- Mevcut dosyaları düzenlerken **minimal değişiklik** yap
- Yeni özellik entegrasyonu için mevcut view'lara hook eklerken, mevcut layout'u bozmadığından emin ol
- Mevcut import'lara, class'lara, struct'lara ek yaparken mevcut convention'ı takip et
- Boring.Notch'un kendi kodlama stilini koru (dosya adlandırma, yapı, vs.)

## Teknik Kurallar

### Swift & SwiftUI
- Boring.Notch'un mevcut Swift versiyonunu ve stil convention'ını takip et
- Yeni modüllerde `@Observable` tercih et ama mevcut kodda `@ObservableObject` kullanılıyorsa onu koru (tutarlılık)
- Mevcut kod `ObservableObject` kullanıyorsa, yeni kodda da aynısını kullan — karma yapma
- Force unwrap (`!`) kullanma — guard let / if let

### Logging
- Mevcut logging pattern'ını takip et
- Yeni modüllerde `os.Logger` kullan:
  ```swift
  private let logger = Logger(subsystem: "com.dynanotch", category: "Lyrics")
  ```

### Performans
- Boring.Notch'un <%2 CPU hedefini koru
- Yeni polling interval'ları:
  - Lyrics senkronizasyon: 0.5 saniye (aktif şarkı varken)
  - Shortcuts widget: 5 saniye
  - AI response: async, timeout 10 saniye
  - Plugin polling: Plugin'in kendi interval'ı, minimum 1 saniye
- Background thread'de çalışacak işler: lyrics fetch, AI API çağrıları, plugin veri çekme
- UI güncellemeleri @MainActor üzerinde

### Hata Yönetimi
- Crash yerine graceful degradation: Lyrics bulunamadıysa sessizce "No lyrics" göster
- AI API hatası → "Couldn't reach AI" mesajı, retry butonu
- Plugin crash → Plugin devre dışı bırakılır, diğer özellikler etkilenmez
- Ağ hatası → Cache'ten göster, yoksa placeholder

## Plugin Sistemi Kuralları

### NotchPlugin Protokolü
```swift
protocol NotchPlugin: Identifiable {
    var id: String { get }
    var displayName: String { get }
    var icon: String { get }
    var version: String { get }
    var author: String { get }
    
    func activate()
    func deactivate()
    
    @ViewBuilder var compactView: some View { get }
    @ViewBuilder var expandedView: some View { get }
    @ViewBuilder var settingsView: some View { get }
    
    var updateInterval: TimeInterval { get }
    func fetchData() async throws
}
```

### Plugin İzolasyonu
- Her plugin kendi hata sınırları içinde çalışır
- Bir plugin crash olursa ana uygulama etkilenmez
- Plugin'ler birbirinin verisine doğrudan erişemez — PluginRegistry üzerinden

### Harici Veri Beslemesi
```swift
protocol ExternalDataProvider {
    var scheme: String { get }
    func handleIncomingData(_ data: Data)
}
// URL scheme: dynanotch://plugin/{pluginId}?data={json}
// Local WebSocket: ws://localhost:9876/{pluginId}
// Shared App Group: group.com.dynanotch.plugins
```

## Lyrics Modülü Kuralları

### Veri Kaynağı Öncelik Sırası
1. Apple MusicKit (Apple Music abonesi ise)
2. LRCLIB (açık kaynak, ücretsiz)
3. Musixmatch API (rate limit dikkat)

### LRC Format
```
[00:12.00]First line of lyrics
[00:17.50]Second line of lyrics
```
- Zaman damgası: `[mm:ss.xx]` formatı parse et
- Playback pozisyonuyla eşleştir
- 0.5 saniye tolerans ile senkronize et

### Cache
- Şarkı ID + kaynak bazlı cache key
- Cache süresi: 30 gün
- Cache lokasyonu: Application Support dizini

## AI Asistan Kuralları

### API Kullanımı
- Model: `claude-haiku-4-5` (hızlı ve ucuz)
- Max tokens: 500 (hızlı cevap)
- Timeout: 10 saniye
- API key: UserDefaults'ta encrypted şekilde sakla (Keychain tercih edilir)

### Context
- Son 5 mesaj conversation geçmişi
- Opsiyonel context: Şu an çalan şarkı, sonraki takvim etkinliği, file shelf içeriği

## External Ekran (Floating Tab) Kuralları

### Display Mode
```swift
enum NotchDisplayMode {
    case physicalNotch    // MacBook built-in ekran, notch var
    case floatingTab      // External ekran veya notch'suz Mac
}
```

### Floating Tab Davranışı
- Collapsed: Ekranın üst ortası, 4px yükseklik, ~200px genişlik, pill şekli
- Expand animasyon: Yukardan aşağı spring (aynı spring parametreleri)
- Collapse: Yukarı kayarak gizlenme
- İçerik: physicalNotch ile aynı (tüm modüller çalışır)

### Algılama
- `NSScreen.main?.auxiliaryTopLeftArea != nil` → physicalNotch
- Aksi halde → floatingTab
- Ekran değişikliğinde otomatik güncelle

## Git Kuralları

### Branch Stratejisi
```
main                    # Stabil, release-ready
├── develop             # Aktif geliştirme
├── feature/floating-tab
├── feature/lyrics
├── feature/shortcuts
├── feature/notifications
├── feature/ai-assistant
└── feature/plugin-system
```

### Commit Mesajları
```
feat(lyrics): LRC parser ve LRCLIB servis eklendi
feat(floating-tab): external ekran algılama ve pill UI
fix(media): album art renk çıkarma crash düzeltildi
refactor(plugin): NotchPlugin protokolü genişletildi
docs: README atıf bölümü güncellendi
```

### Upstream Senkronizasyon
Boring.Notch ana repo'sundaki güncellemeleri periyodik olarak merge et:
```bash
git remote add upstream https://github.com/TheBoredTeam/boring.notch.git
git fetch upstream
git merge upstream/main
```
Conflict olursa kendi özelliklerimizi koru, mevcut özelliklerde upstream'i tercih et.

## Yasaklar

- ❌ Mevcut Boring.Notch özelliklerini kaldırma veya devre dışı bırakma
- ❌ Boring.Notch'un mevcut dosya yapısını değiştirme (yeniden adlandırma, taşıma)
- ❌ GPL v3 lisansını kaldırma veya değiştirme
- ❌ Kapalı kaynak bağımlılık ekleme
- ❌ Force unwrap (`!`)
- ❌ Thread.sleep
- ❌ print() — os.Logger kullan
- ❌ Plugin'lerin ana uygulama state'ine doğrudan erişmesi

## Test Kuralları

- Her yeni modül için unit test yaz
- Mevcut testleri bozma
- UI test: Yeni özelliğin mevcut akışları bozmadığını doğrula
- Plugin test: Mock plugin ile plugin sistemini test et
- Lyrics test: Mock API response ile parser'ı test et
- Her PR öncesi: `xcodebuild build` başarılı olmalı

## Lisans Hatırlatması

Bu proje GPL v3 lisanslıdır. Her yeni dosyanın başına lisans header'ı ekle. README'de Boring.Notch ve diğer ilham kaynaklarına kredi ver.
