# Money Tracker

**Versi 1.0.0**  
**Dibuat Oleh: Riky Dwianto**

Aplikasi Money Tracker untuk melacak keuangan pribadi. Dibangun dengan Flutter + Firebase Authentication + Realtime Database. UI berfokus pada pengguna Indonesia: format Rupiah, label berbahasa Indonesia, dan alur cepat untuk dompet, kategori, transaksi, transfer, dan hutang/piutang.

## ✨ Fitur Utama

- 🔐 Login dengan Firebase Auth (Email/Password, Google)
- 🗄️ Penyimpanan data di Firebase Realtime Database (RTDB)
- 👛 Dompet (Wallet) dengan alias unik per pengguna
  - Tambah/Ubah/Hapus dompet
  - Sesuaikan saldo (adjust) — otomatis dicatat sebagai transaksi
  - Transfer antar dompet (satu pengguna)
  - Transfer antar pengguna (pakai UID + alias dompet penerima)
- 🏷️ Kategori dan Subkategori (hierarki 1 level) tampil inline
- 📒 Transaksi income/expense/transfer + format Rupiah (input & tampilan)
- 🔍 Filter transaksi per dompet langsung dari AppBar
- 🧮 Transaksi sistem otomatis:
  - Penyesuaian saldo (adjustment)
  - Transfer (keluar/masuk) untuk kedua dompet yang terlibat
- 🧾 Hutang/Piutang (debt): form khusus dengan pihak terkait dan arah (hutang/piutang)
- 🎉 Acara/Event: kelola event khusus (pernikahan, liburan, arisan)
  - Aktifkan satu acara → transaksi baru otomatis terhubung ke acara tersebut
  - Lihat saldo dan transaksi per acara
  - Budget tracking per acara
- 👤 Profil, Pengaturan (tab label "Profil"), dan halaman Tentang
- 🖼️ Logo kustom (assets/imges/logo.png) muncul di AppBar Transaksi

## 🏗️ Teknologi & Paket

- Flutter 3.8+
- Firebase Core, Firebase Auth, Firebase Realtime Database
- Hive (adapters untuk model lokal)
- intl (format Rupiah), google_fonts
- Material 3 (Tema terang/gelap siap, dapat diaktifkan selanjutnya)

## 📁 Struktur Proyek

```
lib/
├── models/          # Model data: Wallet, Category, Transaction
├── screens/         # Halaman: Home, Wallet, Category, Transaction, Profile, About
├── services/        # Layanan: UserService, WalletService, TransactionService
├── utils/           # Utilitas: IdrFormatters (format & input Rupiah)
├── firebase_options.dart
└── main.dart        # Entry point
```

## 🔧 Setup & Menjalankan

1) Siapkan Firebase Project (Console)
- Buat project di Firebase Console
- Aktifkan Authentication (Email/Password, Google) sesuai kebutuhan
- Aktifkan Realtime Database (mode test untuk dev, produksi butuh rules ketat)

2) Pasang dependensi & konfigurasi
- Pasang Firebase CLI (opsional) dan FlutterFire CLI
- Generate `firebase_options.dart` dengan:

```powershell
flutter pub get
flutterfire configure
```

3) Jalankan aplikasi

```powershell
flutter run
```

4) (Opsional) Build APK

```powershell
flutter build apk --release
```

## 🗃️ Data Model Ringkas

Wallet (`lib/models/wallet.dart`)
- id, name, balance, currency, icon, color, userId
- createdAt, updatedAt
- isShared, sharedWith
- alias (String?, unik per user) — untuk transfer cepat antar pengguna

Category (`lib/models/category.dart`)
- id, name, icon, color
- type: expense | income | transfer | debt
- applies: income | expense | both
- parentId (String?, untuk subkategori satu level)
- Default disediakan dan di-backfill untuk user lama (termasuk subkategori & kategori sistem: transfer, adjustment, debt)

Transaction (`lib/models/transaction.dart`)
- id, title, amount, type (income | expense | transfer | debt)
- categoryId, walletId, toWalletId (transfer)
- date, notes, photoUrl
- userId, createdAt, updatedAt, isSynced
- Debt khusus: counterpartyName (pihak terkait), debtDirection ("hutang" | "piutang")
- Event tracking: eventId (String?, opsional) untuk menghubungkan transaksi ke acara tertentu

Event (`lib/models/event.dart`)
- id, name, isActive (boolean, maksimal 1 acara aktif per user)
- startDate, endDate (DateTime?, opsional)
- budget (double?, opsional)
- notes, userId, createdAt, updatedAt

## 🔌 Realtime Database Paths

```
users/{uid}/
  profile/
  wallets/{walletId}
  categories/{categoryId}
  transactions/{txId}
  events/{eventId}
```

Tips performa: tambahkan index untuk `wallets` pada field `alias` dan `events` pada field `isActive` agar pencarian cepat.

Contoh (Rules RTDB – tambahkan index di console Rules):

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid",
        "wallets": {
          ".indexOn": ["alias", "name"]
        },
        "events": {
          ".indexOn": ["isActive"]
        }
      }
    }
  }
}
```

Catatan: Transfer antar pengguna melakukan multi-location update ke dua user. Pastikan rules produksi memperbolehkan skenario terkontrol (atau gunakan Cloud Functions sebagai perantara jika ingin validasi lebih ketat).

## 🧭 Alur & Cara Pakai Singkat

- Dompet
  - Tambah/Ubah dompet; set "Alias" opsional (unik per user). Alias memudahkan transfer antar pengguna (UID + alias).
  - Sesuaikan saldo (adjust) → otomatis tercatat sebagai transaksi (kategori sistem "Penyesuaian").
  - Transfer antar saldo (sesama user) → update saldo kedua dompet + 2 transaksi transfer (keluar/masuk).
  - Transfer antar rekening (lintas user) → masukkan UID penerima + alias dompet penerima → saldo ter-update pada kedua pihak + kedua pihak mendapat transaksi transfer.

  - Tambahkan income/expense/transfer via form.
  - Input jumlah menggunakan formatter Rupiah (tampilan dan parsing konsisten).
  - AppBar Transaksi punya filter dompet; pilih "Semua Dompet" atau dompet spesifik.

- Hutang/Piutang
  - Buka FAB pada tab Transaksi → pilih "Catat Hutang/Piutang".
  - Pilih arah (Hutang — Anda berhutang / Piutang — orang lain berhutang ke Anda), isi pihak terkait, dompet, dan jumlah.
  - Tercatat sebagai transaksi berjenis `debt` (kategori sistem "Hutang/Piutang").

- Acara/Event
  - Buka Pengaturan → "Atur Acara" untuk melihat, membuat, atau mengedit acara.
  - Aktifkan satu acara (toggle "Aktif") → transaksi baru yang dibuat akan otomatis terhubung ke acara tersebut.
  - Lihat detail acara untuk melihat ringkasan saldo (pemasukan/pengeluaran) dan daftar transaksi terkait acara.
  - Opsional: set budget, tanggal mulai/selesai, dan catatan untuk setiap acara.
  - Pada form transaksi/hutang, acara aktif ditampilkan sebagai chip berwarna. Anda bisa melepaskan transaksi dari acara dengan tap tombol X.

## 🖼️ Logo Aplikasi

- Letakkan file logo Anda di: `assets/imges/logo.png` (juga didukung `assets/images/logo.png`).
- Sudah dideklarasikan di `pubspec.yaml` → jalankan `flutter pub get` jika baru menambahkan.
- Logo tampil di AppBar halaman Transaksi (dengan fallback icon bila asset belum ada).

## 📝 Changelog (Ringkas)

Tanggal: 2025-11-01

- Ganti judul aplikasi menjadi "Money Tracker" (AppBar & MaterialApp)
- Rupiah input formatter pada form transaksi & dialog terkait
- Alias dompet: UI + validasi ketersediaan + tampil di list
- Transfer lintas user via UID + alias
- Catat otomatis transaksi untuk adjust & transfer (kategori sistem: transfer, adjustment)
- Subkategori default diperluas (Transport, Belanja, Hiburan, Tagihan, Kesehatan, Income breakdown)
- AppBar Transaksi: filter dompet + logo
- Tambah fitur Hutang/Piutang dengan pihak terkait & arah hutang/piutang
- **Fitur Acara/Event**: kelola event dengan status aktif/nonaktif, auto-link transaksi ke acara aktif, lihat saldo & transaksi per acara, set budget & periode

## 🗺️ Roadmap (Usulan Fitur Lanjutan)

- Anggaran (Budget) per kategori/dompet + notifikasi overspend
- Tagihan berulang (Recurring bills) dengan pengingat
- Laporan/Statistik lanjutan (grafik tren, perbandingan bulan, heatmap)
- Export/Import (CSV/Excel) dan berbagi laporan
- Multi-mata uang + kurs otomatis (sumber publik)
- Pencarian & filter lanjutan (rentang tanggal, kategori, nominal)
- Lampiran struk (foto) + OCR sederhana untuk isi otomatis
- Target tabungan/goal dan progress
- Dompet bersama (shared) dengan peran/izin (admin/viewer)
- Status hutang/piutang (belum/lunas) + catat pelunasan partial
- Kunci aplikasi (PIN/biometrik) dan pengaturan tema (otomatis/gelap)
- Backup/Restore ke Cloud Storage

> Ingin prioritas tertentu? Buka issue atau kirimkan ide Anda.

## ❓ Troubleshooting

- `firebase_options.dart` belum ada → jalankan `flutterfire configure`
- RTDB permission denied → sesuaikan Rules dan pastikan login
- Asset logo tidak tampil → pastikan `assets/imges/logo.png` ada dan sudah menjalankan `flutter pub get`

---

**Money Tracker v1.0.0**  
Dibuat oleh **Riky Dwianto** © 2025
