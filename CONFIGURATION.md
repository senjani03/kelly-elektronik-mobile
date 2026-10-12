# Panduan Konfigurasi Kelly Elektronik

Dokumen ini menjelaskan cara menyiapkan dependency, API Laravel, database,
aplikasi Flutter, dan kredensial untuk pengembangan lokal. Jalankan perintah
dari folder proyek yang disebutkan pada setiap bagian.

> **Penting:** Jangan mengisi kredensial asli di file yang dilacak Git, kode
> Flutter, atau argumen `--dart-define`. Kredensial layanan pembayaran dan
> pengiriman hanya boleh berada di `backend/.env`.

## 1. Struktur konfigurasi

| File/folder | Fungsi | Perlu di-commit? |
| --- | --- | --- |
| `pubspec.yaml` dan `pubspec.lock` | Daftar serta versi dependency Flutter | Ya |
| `backend/composer.json` dan `backend/composer.lock` | Daftar serta versi dependency PHP | Ya |
| `backend/.env.example` | Templat konfigurasi backend tanpa rahasia | Ya |
| `backend/.env` | Konfigurasi lokal, password, dan API key | **Tidak** |
| `build/`, `.dart_tool/`, `backend/vendor/` | Hasil build atau dependency yang dapat dibuat ulang | Tidak |

File `.gitignore` mengabaikan file rahasia umum seperti `.env`, `credentials.json`,
private key, dan direktori dependency besar. File contoh `.env.example` tetap
bisa dilacak. Aturan ignore tidak mengeluarkan file yang sudah telanjur dilacak
Git dari repository; jika kredensial pernah di-commit, cabut/rotasi kredensial
tersebut dan tangani riwayat Git secara terpisah.

## 2. Persiapan perangkat lunak

Pasang perangkat berikut terlebih dahulu:

- Flutter SDK dengan Dart yang memenuhi batas versi di `pubspec.yaml`.
- PHP 8.2 atau lebih baru, Composer, dan ekstensi PHP `pdo_pgsql`.
- PostgreSQL 14 atau lebih baru.
- Chrome untuk menjalankan Flutter Web (opsional).

Pastikan Flutter dan PHP dapat dijalankan dari PowerShell:

```powershell
flutter doctor
php -v
composer --version
```

Jika menggunakan XAMPP, aktifkan `extension=pgsql` dan
`extension=pdo_pgsql` di `C:\xampp\php\php.ini`, kemudian buka terminal baru.

## 3. Menyiapkan API dan database

### 3.1 Buat database PostgreSQL

Buat database kosong bernama `kelly_elektronik` menggunakan pgAdmin atau
perintah `createdb`. Jika nama database, host, port, atau user berbeda,
sesuaikan nilainya pada `backend/.env` di langkah berikutnya.

### 3.2 Buat konfigurasi lokal

Dari root repository:

```powershell
Copy-Item backend/.env.example backend/.env
```

Buka `backend/.env` dan isi setidaknya pengaturan koneksi database berikut:

```dotenv
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=kelly_elektronik
DB_USERNAME=postgres
DB_PASSWORD=password_postgres_anda
```

Gunakan password PostgreSQL lokal Anda sendiri. Jangan menyalin contoh
password di atas sebagai kredensial produksi. Pertahankan `APP_KEY` kosong
sebelum menjalankan perintah pembuatan key pada langkah berikutnya.

### 3.3 Pasang dependency, siapkan aplikasi, dan jalankan API

Dari root repository:

```powershell
Set-Location backend
composer install
php artisan key:generate
php artisan migrate --seed
php artisan serve --host=0.0.0.0 --port=8000
```

API lokal tersedia di `http://localhost:8000`. Opsi `--host=0.0.0.0`
memungkinkan perangkat lain di jaringan lokal mengakses API; gunakan hanya
jaringan tepercaya. Migrasi membuat tabel database, sedangkan seeder
menambahkan data awal dan akun demo. Seeder admin hanya membuat admin bila
kredensial admin disediakan secara eksplisit (lihat bagian berikutnya).

Untuk menjalankan test backend:

```powershell
php artisan test
```

### 3.4 Membuat akun admin lokal

Atur variabel berikut sementara di PowerShell sebelum menjalankan seeder.
Password admin harus memiliki minimal 12 karakter:

```powershell
$env:ADMIN_EMAIL = "admin@example.test"
$env:ADMIN_NAME = "Admin Lokal"
$env:ADMIN_PASSWORD = Read-Host "Password admin"
php artisan db:seed
Remove-Item Env:ADMIN_EMAIL, Env:ADMIN_NAME, Env:ADMIN_PASSWORD
```

Gunakan alamat dan password khusus pengembangan lokal. Jangan menuliskan
kredensial admin ke dalam file `.env.example`, dokumentasi publik, atau source
control. Seeder tidak mengubah profil/password akun yang sudah ada.

## 4. Konfigurasi layanan backend

Semua nilai pada bagian ini diatur di `backend/.env`, bukan di aplikasi
Flutter. Variabel yang tidak dipakai boleh dibiarkan kosong.

| Variabel | Kegunaan dan cara mengisi |
| --- | --- |
| `APP_KEY` | Kunci enkripsi Laravel. Biarkan kosong pada awalnya; isi dengan `php artisan key:generate`. Jangan mengganti key setelah aplikasi menyimpan data terenkripsi. |
| `APP_URL` | URL API. Lokal biasanya `http://localhost` dan dapat disesuaikan jika memakai domain lokal. |
| `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` | Koneksi ke PostgreSQL. Harus cocok dengan server/database lokal. |
| `RAJAONGKIR_API_KEY` | API key akun RajaOngkir Komerce. Simpan hanya di sini; kosongkan bila tidak menguji ongkos kirim. |
| `RAJAONGKIR_BASE_URL` | Endpoint RajaOngkir; nilai contoh di `.env.example` menggunakan Komerce API v1. |
| `RAJAONGKIR_ORIGIN_SEARCH` | Pencarian alamat asal gudang. Nilai awalnya `Tanjung Duren Selatan`. |
| `RAJAONGKIR_COURIERS` | Kode kurir dipisahkan koma, misalnya `jne,jnt,sicepat`; sesuaikan dengan layanan akun. |
| `SHOP_BANK_NAME` | Nama bank untuk pembayaran transfer manual. |
| `SHOP_BANK_ACCOUNT_NAME` | Nama pemilik rekening toko. |
| `SHOP_BANK_ACCOUNT_NUMBER` | Nomor rekening toko. Isi rekening yang benar sebelum menerima pembayaran. |
| `MIDTRANS_SERVER_KEY` | Server Key dari Midtrans. Rahasia ini hanya digunakan backend. |
| `MIDTRANS_CLIENT_KEY` | Client Key untuk transaksi Snap; tetap simpan di backend karena integrasi transaksi dilakukan oleh API. |
| `MIDTRANS_IS_PRODUCTION` | Gunakan `false` untuk Sandbox. Gunakan `true` hanya dengan kredensial Production setelah siap bertransaksi sungguhan. |
| `APP_PAYMENT_RETURN_URL` | URL Flutter Web yang dibuka setelah pelanggan kembali dari pembayaran, misalnya `http://localhost:3000/#/payment-return`. |

Untuk mengubah nilai, edit file `backend/.env`, lalu bersihkan cache konfigurasi
Laravel dan mulai ulang server API:

```powershell
php artisan config:clear
```

Detail pengujian RajaOngkir, transfer bank, dan pengaturan dashboard Midtrans
tersedia di [backend/README.md](./backend/README.md).

## 5. Memasang dependency Flutter

Dari root repository (bukan dari `backend/`):

```powershell
flutter pub get
```

Perintah ini mengambil paket yang didefinisikan di `pubspec.yaml`. Setelah
mengubah dependency, jalankan kembali `flutter pub get`; perubahan
`pubspec.lock` perlu ditinjau dan umumnya di-commit bersama perubahan
dependency. Jangan menghapus atau mengabaikan `pubspec.lock` untuk aplikasi.

Folder seperti `.dart_tool/`, `build/`, `.pub-cache/`, dan
`backend/vendor/` merupakan hasil generate atau paket yang dapat dipasang
kembali. Jangan menyalin atau meng-commit folder tersebut.

Jika Anda mengubah atau membangun asset frontend Laravel, pasang Node.js dan
npm lalu jalankan dari `backend/`:

```powershell
npm install
npm run build
```

Folder `backend/node_modules/` juga diabaikan Git. Langkah Node.js ini tidak
diperlukan untuk menjalankan Flutter Web.

## 6. Menghubungkan Flutter ke API

URL API dikonfigurasi melalui `API_BASE_URL`, dan nilainya harus diakhiri
dengan `/api`. URL ini bukan rahasia; jangan meletakkan API key atau password
di dalamnya.

### Flutter Web

Jalankan API pada port `8000`, lalu jalankan aplikasi dari root repository:

```powershell
flutter run -d chrome --web-port 3000
```

Pada Web, aplikasi secara otomatis memakai host halaman yang sedang dibuka dan
port API `8000`. Contohnya, jika Web dibuka dari `http://localhost:3000`,
aplikasi menggunakan `http://localhost:8000/api`. Port `3000` harus sesuai
dengan `APP_PAYMENT_RETURN_URL` untuk alur kembali dari Midtrans Sandbox.

### Android Emulator

Emulator Android standar tidak memakai `localhost` komputer sebagai host.
Jalankan:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

`10.0.2.2` adalah alamat khusus Android Emulator untuk mengakses komputer host.

### Perangkat Android fisik

Hubungkan komputer dan ponsel ke jaringan Wi-Fi yang sama. Cari alamat IPv4
LAN komputer, pastikan server API dijalankan dengan `--host=0.0.0.0`, lalu
berikan alamat tersebut saat menjalankan Flutter:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.17:8000/api
```

Ganti `192.168.1.17` dengan alamat LAN komputer Anda. Periksa izin firewall
untuk port `8000` jika ponsel tidak dapat terhubung. Nilai default non-Web di
`lib/utils/config.dart` adalah alamat jaringan tertentu; gunakan
`--dart-define` di atas jika alamat komputer berbeda.

## 7. Menguji pembayaran lokal

- **Transfer bank:** atur tiga variabel `SHOP_BANK_*` dengan data rekening
  pengembangan. Konfirmasi bukti transfer dilakukan oleh admin.
- **Midtrans:** gunakan Server Key dan Client Key Sandbox serta
  `MIDTRANS_IS_PRODUCTION=false`. Pastikan `APP_PAYMENT_RETURN_URL` cocok
  dengan alamat Flutter Web. URL notifikasi Midtrans membutuhkan API yang
  dapat dijangkau dari internet; Midtrans tidak dapat mengirim notifikasi ke
  `localhost`.
- Jangan mengaktifkan pembayaran produksi atau mengisi kredensial produksi
  sebelum domain HTTPS, konfigurasi notifikasi, dan seluruh alur pembayaran
  diuji.
- Sebelum API dipublikasikan, gunakan HTTPS, batasi origin di
  `backend/config/cors.php`, dan tinjau konfigurasi HTTP cleartext Android
  pada `android/app/src/main/AndroidManifest.xml`.

Langkah dashboard, callback, notifikasi, dan pembatasan konfigurasi produksi
dijelaskan lebih lengkap di [backend/README.md](./backend/README.md#midtrans-snap-sandbox).

## 8. Jika konfigurasi tidak berjalan

1. Periksa bahwa PostgreSQL aktif dan pengaturan `DB_*` cocok dengan database.
2. Jalankan `php artisan config:clear` setelah mengubah `.env`, lalu mulai
   ulang `php artisan serve`.
3. Pastikan API dapat dibuka dari komputer di port `8000`; dari perangkat
   Android gunakan alamat emulator atau IP LAN yang benar.
4. Pastikan URL `API_BASE_URL` berakhir dengan `/api`, tanpa spasi.
5. Jalankan `flutter pub get` dari root proyek atau `composer install` dari
   folder `backend/` jika dependency belum tersedia.
6. Periksa bahwa file lokal seperti `backend/.env` tidak muncul sebagai file
   yang akan di-commit. Contoh pemeriksaan:

   ```powershell
   git check-ignore -v --no-index backend/.env
   ```

Jika suatu file berisi kredensial pernah di-commit, `.gitignore` tidak cukup
untuk melindunginya. Segera cabut/rotasi kredensial tersebut dan pastikan
salinan berisi rahasia tidak dikirim ke remote.
