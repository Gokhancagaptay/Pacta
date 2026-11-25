import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/app_constants.dart';
import '../../core/money/asset.dart';
import '../../core/money/money.dart';

// Kişisel veri dışa aktarma (KVKK m.11, "Verilerimi indir").
//
// Okumalar [DataExportSource] arkasındadır (Firestore'lu hâli
// data_export_firestore.dart); toplama [DataExportCollector] ile, dosyanın
// biçimi saf işlevlerle ([buildDataExport]) yapılır. Dosya cihazda
// hazırlanır, sunucuya gönderilmez.

/// Firestore belgesi: kimliği ve saklandığı hâliyle alanları.
typedef RawDoc = ({String id, Map<String, dynamic> data});

/// Giriş yöntemi (Firebase Auth `providerData`).
typedef SignInMethod = ({
  String providerId,
  String? uid,
  String? email,
  String? displayName,
  String? phoneNumber,
});

/// Giriş hizmetindeki hesap bilgisi (FirebaseAuth.currentUser).
class AccountInfo {
  const AccountInfo({
    required this.uid,
    this.email,
    this.emailVerified = false,
    this.displayName,
    this.phoneNumber,
    this.methods = const [],
    this.createdAt,
    this.lastSignInAt,
  });

  final String uid;
  final String? email;
  final bool emailVerified;
  final String? displayName;
  final String? phoneNumber;
  final List<SignInMethod> methods;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
}

/// Kullanıcıya gösterilecek, Türkçe hata.
class DataExportException implements Exception {
  const DataExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Kullanıcı hazırlamayı durdurdu.
class DataExportCancelled implements Exception {
  const DataExportCancelled();
}

const dataExportOfflineMessage =
    'Verileriniz sunucudan okunur ve şu an bağlantı kurulamadı. '
    'İnternet bağlantınız gelince tekrar deneyin.';

/// Kullanıcının güvenlik kurallarına göre okuyabildiği her şey. Liste
/// okumaları kuralların istediği `memberUids` süzgecini taşır; sıralama
/// istemcide yapılır (yeni dizin gerekmez).
abstract interface class DataExportSource {
  /// Oturumdaki hesap; oturum yoksa null.
  AccountInfo? currentAccount();

  Future<RawDoc?> userProfile(String uid);
  Future<RawDoc?> publicProfile(String uid);
  Future<List<RawDoc>> ledgers(String uid);
  Future<List<RawDoc>> entries(String ledgerId, String uid);
  Future<List<RawDoc>> revisions(String ledgerId, String entryId, String uid);
  Future<List<RawDoc>> events(String ledgerId, String uid);
  Future<List<RawDoc>> inbox(String uid);
  Future<List<RawDoc>> notifications(String uid);
}

class ExportedEntry {
  const ExportedEntry(this.doc, this.revisions);

  final RawDoc doc;
  final List<RawDoc> revisions;
}

class ExportedLedger {
  const ExportedLedger(this.doc, this.entries, this.events);

  final RawDoc doc;
  final List<ExportedEntry> entries;
  final List<RawDoc> events;
}

/// Okunan ham veri (henüz biçimlenmemiş).
class CollectedData {
  const CollectedData({
    required this.account,
    required this.profile,
    required this.publicProfile,
    required this.ledgers,
    required this.inbox,
    required this.notifications,
  });

  final AccountInfo? account;
  final RawDoc? profile;
  final RawDoc? publicProfile;
  final List<ExportedLedger> ledgers;
  final List<RawDoc> inbox;
  final List<RawDoc> notifications;

  /// Okunan belge sayısı (dosyada ve ilerlemede).
  int get documentCount =>
      (profile == null ? 0 : 1) +
      (publicProfile == null ? 0 : 1) +
      inbox.length +
      notifications.length +
      ledgers.fold(
        0,
        (total, l) =>
            total +
            1 +
            l.events.length +
            l.entries.fold(0, (s, e) => s + 1 + e.revisions.length),
      );
}

/// Okuma ilerlemesi: kaç defter bitti, kaç belge okundu.
class DataExportProgress {
  const DataExportProgress({
    required this.ledgersDone,
    required this.ledgersTotal,
    required this.documents,
  });

  /// Defter listesi henüz okunmadıysa [ledgersTotal] null.
  final int ledgersDone;
  final int? ledgersTotal;
  final int documents;

  /// 0..1; defter sayısı bilinmiyorsa null (belirsiz çubuk).
  double? get fraction {
    final total = ledgersTotal;
    if (total == null) return null;
    if (total == 0) return 1;
    return ledgersDone / total;
  }

  String get label {
    final total = ledgersTotal;
    final docs = '$documents belge okundu';
    if (total == null) return 'Hesap bilgileri okunuyor · $docs';
    return 'Defterler: $ledgersDone / $total · $docs';
  }
}

/// Verileri defter defter okur. Bir defterin kayıt sürümleri, aynı anda en
/// fazla [parallel] istekle okunur (her kayıt ayrı bir sorgu).
class DataExportCollector {
  DataExportCollector(this.source, {this.parallel = 8});

  final DataExportSource source;
  final int parallel;

  Future<CollectedData> collect(
    String uid, {
    void Function(DataExportProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (uid.isEmpty) {
      throw const DataExportException(
        'Oturum bulunamadı. Yeniden giriş yapıp tekrar deneyin.',
      );
    }
    var documents = 0;
    int? total;
    var done = 0;
    void report() => onProgress?.call(
      DataExportProgress(
        ledgersDone: done,
        ledgersTotal: total,
        documents: documents,
      ),
    );
    void check() {
      if (isCancelled?.call() ?? false) throw const DataExportCancelled();
    }

    report();
    final account = source.currentAccount();
    final profile = await source.userProfile(uid);
    final public = await source.publicProfile(uid);
    check();
    final inbox = await source.inbox(uid);
    final notifications = await source.notifications(uid);
    check();
    final ledgerDocs = await source.ledgers(uid);
    documents +=
        (profile == null ? 0 : 1) +
        (public == null ? 0 : 1) +
        inbox.length +
        notifications.length +
        ledgerDocs.length;
    total = ledgerDocs.length;
    report();

    final ledgers = <ExportedLedger>[];
    for (final ledger in ledgerDocs) {
      check();
      // Future.wait ilk hatayı olduğu gibi iletir (Türkçe mesaj korunur).
      final read = await Future.wait([
        source.entries(ledger.id, uid),
        source.events(ledger.id, uid),
      ]);
      final entryDocs = read[0];
      final events = read[1];
      documents += entryDocs.length + events.length;
      report();
      final entries = await _inPool(entryDocs, (entry) async {
        check();
        final revisions = await source.revisions(ledger.id, entry.id, uid);
        documents += revisions.length;
        return ExportedEntry(entry, revisions);
      });
      ledgers.add(ExportedLedger(ledger, entries, events));
      done++;
      report();
    }
    return CollectedData(
      account: account,
      profile: profile,
      publicProfile: public,
      ledgers: ledgers,
      inbox: inbox,
      notifications: notifications,
    );
  }

  /// [items] için [run]'ı en fazla [parallel] eşzamanlı çalıştırır; sonuç
  /// sırası girişle aynıdır.
  Future<List<R>> _inPool<T, R>(
    List<T> items,
    Future<R> Function(T item) run,
  ) async {
    final results = <int, R>{};
    var next = 0;
    Future<void> worker() async {
      while (next < items.length) {
        final i = next++;
        results[i] = await run(items[i]);
      }
    }

    final width = parallel < 1 ? 1 : parallel;
    await Future.wait([
      for (var w = 0; w < width && w < items.length; w++) worker(),
    ]);
    return [for (var i = 0; i < items.length; i++) results[i] as R];
  }
}

// --- Dosyanın biçimi (saf işlevler) ----------------------------------------

/// Zaman: ISO 8601, UTC ("2026-11-25T18:30:00.000Z").
String isoTime(DateTime time) => time.toUtc().toIso8601String();

/// Firestore değerini JSON'a çevirir: zaman damgası ISO 8601 metin olur,
/// tamsayılar olduğu gibi kalır (ondalığa çevrilmez). Harita anahtarları
/// sıralanır; dosya her seferinde aynı düzende çıkar.
Object? jsonValue(Object? value) => switch (value) {
  null || bool() || String() || int() => value,
  final double d => d.isFinite ? d : d.toString(),
  final Timestamp t => isoTime(t.toDate()),
  final DateTime d => isoTime(d),
  final GeoPoint g => {'enlem': g.latitude, 'boylam': g.longitude},
  final DocumentReference<Object?> r => r.path,
  final Blob b => base64Encode(b.bytes),
  final Uint8List b => base64Encode(b),
  final Map<Object?, Object?> m => {
    for (final e in _sortedEntries(m)) e.key: jsonValue(e.value),
  },
  final Iterable<Object?> l => [for (final x in l) jsonValue(x)],
  _ => value.toString(),
};

/// Harita alanları, anahtara göre sıralı (anahtar metne çevrilir).
List<MapEntry<String, Object?>> _sortedEntries(Map<Object?, Object?> map) =>
    [for (final e in map.entries) MapEntry('${e.key}', e.value)]
      ..sort((x, y) => x.key.compareTo(y.key));

/// Tutar alanlarının okunur yazımı. Anahtar alanın yoludur
/// ("amountMinor", "dispute.suggestedAmountMinor", "balances.USD",
/// "dueItems[0].openMinor"). Birim aynı haritadaki ya da üstteki `asset`
/// alanından alınır; `balances` haritasında anahtar birimdir. Yalnızca
/// tamsayı değerler yazılır; saklanan değer değişmez.
Map<String, String> readableAmounts(Map<String, dynamic> data) {
  final out = <String, String>{};
  void put(String path, int minor, Object? code) {
    if (code is! String) return;
    final asset = Asset.tryFromCode(code);
    out[path] = asset == null
        ? '$minor (bilinmeyen birim: $code)'
        : Money(minor, asset).format();
  }

  void walk(Object? node, String path, Object? asset) {
    if (node is Map) {
      final own = node['asset'] ?? asset;
      for (final MapEntry(:key, :value) in _sortedEntries(node)) {
        final at = path.isEmpty ? key : '$path.$key';
        if (key == 'balances' && value is Map) {
          for (final b in _sortedEntries(value)) {
            final minor = b.value;
            if (minor is int) put('$at.${b.key}', minor, b.key);
          }
        } else if (key.endsWith('Minor') && value is int) {
          put(at, value, own);
        } else {
          walk(value, at, own);
        }
      }
    } else if (node is List) {
      for (var i = 0; i < node.length; i++) {
        walk(node[i], '$path[$i]', asset);
      }
    }
  }

  walk(data, '', null);
  return out;
}

/// Bir belge: kimlik, saklandığı hâli ve (varsa) okunur tutarlar.
Map<String, Object?> exportDoc(RawDoc doc) => {
  'kimlik': doc.id,
  ..._docBody(doc),
};

Map<String, Object?> _docBody(RawDoc doc) {
  final amounts = readableAmounts(doc.data);
  return {
    'veri': jsonValue(doc.data),
    if (amounts.isNotEmpty) 'okunurTutarlar': amounts,
  };
}

/// Zamana göre eskiden yeniye; zamanı olmayan sona, eşitlikte kimliğe göre.
int compareByTime(RawDoc x, RawDoc y, String field) {
  final a = x.data[field];
  final b = y.data[field];
  if (a is Timestamp && b is Timestamp) {
    final byTime = a.compareTo(b);
    if (byTime != 0) return byTime;
  } else if (a is Timestamp) {
    return -1;
  } else if (b is Timestamp) {
    return 1;
  }
  return x.id.compareTo(y.id);
}

List<RawDoc> sortedByTime(Iterable<RawDoc> docs, String field) =>
    docs.toList()..sort((x, y) => compareByTime(x, y, field));

/// Kayıt sürümleri sürüm numarasına göre.
List<RawDoc> sortedRevisions(Iterable<RawDoc> docs) {
  int version(RawDoc d) {
    final v = d.data['version'];
    return v is int ? v : (int.tryParse(d.id) ?? 0);
  }

  final list = docs.toList();
  list.sort((x, y) {
    final byVersion = version(x).compareTo(version(y));
    return byVersion != 0 ? byVersion : x.id.compareTo(y.id);
  });
  return list;
}

/// Defterin kullanıcının açısından kısa özeti. Defterdeki bakiyeler a
/// tarafına göredir; burada kullanıcının tarafına çevrilir.
Map<String, Object?> ledgerSummary(Map<String, dynamic> data, String uid) {
  final sides = data['sides'] is Map ? data['sides'] as Map : const {};
  final a = sides['a'] is Map ? sides['a'] as Map : const {};
  final b = sides['b'] is Map ? sides['b'] as Map : const {};
  final mySide = b['uid'] == uid && a['uid'] != uid ? 'b' : 'a';
  final other = mySide == 'a' ? b : a;
  final sign = mySide == 'b' ? -1 : 1;
  final balances = data['balances'] is Map ? data['balances'] as Map : const {};
  final lines = <String>[];
  final codes = balances.keys.map((k) => '$k').toList()
    ..sort((x, y) => _assetOrder(x).compareTo(_assetOrder(y)));
  for (final code in codes) {
    final raw = balances[code];
    if (raw is! int || raw == 0) continue;
    final minor = raw * sign;
    final asset = Asset.tryFromCode(code);
    final text = asset == null
        ? '$minor ($code)'
        : Money(minor.abs(), asset).format();
    lines.add(minor > 0 ? '$text alacağınız' : '$text borcunuz');
  }
  return {
    'tur': data['mode'] == 'private'
        ? 'Özel defter (karşı taraf Pacta kullanmıyor)'
        : 'Ortak defter',
    'durum': data['status'] == 'closed' ? 'Kapalı' : 'Açık',
    'sizinTarafiniz': mySide,
    'karsiTaraf': (other['displayName'] as String?) ?? '',
    'bakiyeSizinAcinizdan': lines.isEmpty ? ['Bakiye yok'] : lines,
  };
}

int _assetOrder(String code) {
  final i = Asset.values.indexWhere((a) => a.code == code);
  return i < 0 ? Asset.values.length : i;
}

Map<String, Object?> _account(AccountInfo a) => {
  'kullaniciKimligi': a.uid,
  'eposta': a.email,
  'epostaDogrulandi': a.emailVerified,
  if (a.displayName != null) 'ad': a.displayName,
  if (a.phoneNumber != null) 'telefon': a.phoneNumber,
  'girisYontemleri': [
    for (final m in a.methods)
      {
        'yontem': _methodLabel(m.providerId),
        'saglayici': m.providerId,
        if (m.uid != null) 'saglayicidakiKimlik': m.uid,
        if (m.email != null) 'eposta': m.email,
        if (m.displayName != null) 'ad': m.displayName,
        if (m.phoneNumber != null) 'telefon': m.phoneNumber,
      },
  ],
  'hesapAcilisZamani': a.createdAt == null ? null : isoTime(a.createdAt!),
  'sonGirisZamani': a.lastSignInAt == null ? null : isoTime(a.lastSignInAt!),
};

String _methodLabel(String providerId) => switch (providerId) {
  'password' => 'E-posta ve şifre',
  'google.com' => 'Google',
  'phone' => 'Telefon',
  'apple.com' => 'Apple',
  _ => providerId,
};

/// Dosyanın başındaki açıklama.
const dataExportIntro = [
  'Bu dosya, Pacta\'nın sizinle ilgili sakladığı ve uygulamanın sizin '
      'adınıza okuyabildiği verilerin bir kopyasıdır (KVKK madde 11).',
  'Dosya telefonunuzda hazırlandı; sunucuya gönderilmedi.',
  '"veri" bölümleri veritabanında saklandığı hâliyle verilir; alan adları '
      'veritabanındaki adlardır. Sık geçenlerin anlamı "alanlar" bölümündedir.',
  'Tutarlar tamsayı küçük birimdedir: TL, dolar ve euro için kuruş '
      '(150000 = 1.500,00), gram altın için miligram (1500 = 1,500 gr), '
      'çeyrek için adet. "okunurTutarlar" aynı tutarların okunur yazımıdır.',
  'Defterdeki bakiyeler (balances) defterin a tarafına göredir: pozitif '
      'değer, b tarafının a tarafına borcudur. Her defterin "ozet" bölümü '
      'bakiyeyi sizin açınızdan yazar.',
  'Zamanlar ISO 8601 biçiminde ve UTC\'dir (Türkiye saati UTC+3). Listeler '
      'eskiden yeniye sıralıdır.',
  'Ortak defterlerde karşı tarafın adı ve e-postası, defter kaydınızın '
      'parçası olduğu için dosyada yer alır. Dosyayı paylaşırken bunu göz '
      'önünde bulundurun.',
  'Dosyada olmayan veriler ve nedenleri "dosyadaOlmayanlar" bölümündedir.',
];

/// Sık geçen alanların anlamı.
const dataExportFields = {
  'amountMinor': 'Kaydın tutarı, küçük birimle',
  'asset': 'Birim: TRY, USD, EUR, GAU (gram altın), CEYREK (çeyrek altın)',
  'balances': 'Onaylı bakiyeler, birim başına, a tarafına göre',
  'deltaMinor': 'Kaydın bakiyeye etkisi, a tarafına göre',
  'direction': 'aToB: değer a tarafından b tarafına geçti; bToA: tersi',
  'kind': 'debt: borç, payment: ödeme, reversal: ters kayıt (düzeltme)',
  'state':
      'pending: onay bekliyor, confirmed: onaylandı, disputed: itiraz '
      'edildi, rejected: reddedildi, cancelled: geri çekildi',
  'occurredOn': 'İşlem tarihi',
  'dueOn': 'Vade tarihi',
  'description': 'Açıklama',
  'sides': 'Defterin iki tarafı (a ve b): ad, e-posta, kullanıcı kimliği',
  'memberUids': 'Defteri okuyabilen hesapların kullanıcı kimlikleri',
  'mode': 'shared: ortak defter, private: özel defter',
  'status': 'active: açık, closed: kapalı',
  'version': 'Kaydın sürümü; her düzenlemede artar',
  'contentHash': 'Kaydın içeriğinden hesaplanan özet (değişmediğinin kanıtı)',
  'head': 'Onaylı kayıt zincirinin başı: onay sayısı ve son özet',
  'actorUid': 'Olayı yapan hesabın kullanıcı kimliği',
  'fcmTokens': 'Bildirim gönderilen cihazların bildirim anahtarları',
  'pactaCode': 'Sizi QR ya da davet linkiyle bulmaya yarayan kod',
  'termsVersion': 'Kabul ettiğiniz Kullanım Koşulları sürümü',
};

/// Uygulamanın okuyamadığı, bu yüzden dosyada olmayan veriler. Gizlilik
/// metni (hosting/gizlilik) ve veri beyanlarıyla (docs/magaza) uyumlu
/// tutulur.
const dataExportNotIncluded = <({String veri, String neden})>[
  (
    veri: 'Pacta kodu eşlemesi',
    neden:
        'Kodun hangi hesaba ait olduğunu tutan sunucu kaydıdır. Kodunuz '
        'profil bölümünde (pactaCode) yer alır.',
  ),
  (
    veri: 'Günlük işlem sayaçları',
    neden:
        'Kötüye kullanımı önlemek için sunucuda tutulan sayılardır (ör. gün '
        'içinde kaç kayıt eklendiği). Bir gün geçerlidir, hesapla birlikte '
        'silinir.',
  ),
  (
    veri: 'Bekleyen bildirim kuyruğu',
    neden:
        'Henüz telefonunuza gönderilmemiş bildirimlerdir. Gönderilince '
        'silinir; içerikleri "bildirimler" bölümündekilerle aynıdır.',
  ),
  (
    veri: 'Web onay istekleri',
    neden:
        'Özel defterdeki bir kayıt için oluşturduğunuz onay linklerinin '
        'sunucu kaydıdır. Karşı tarafın tam e-posta adresini, IP adresini ve '
        'tarayıcı bilgisini içerdiği için yalnızca sunucuda tutulur. '
        'Yanıtın özeti (gizlenmiş e-posta, durum, not) kayıtlarınızda '
        '(webConfirmation) yer alır.',
  ),
  (
    veri: 'Web onayı için açılan geçici girişler',
    neden:
        'Karşı tarafın e-postasını doğrulamak için açılan geçici '
        'hesaplardır; yanıttan sonra silinir.',
  ),
  (
    veri: 'Silinen hesap işareti',
    neden: 'Yalnızca hesap silindiğinde oluşur; açık hesapta yoktur.',
  ),
  (
    veri: 'Şifre ve giriş hizmeti kayıtları',
    neden:
        'Şifreniz giriş hizmetinde (Firebase Authentication) geri '
        'çevrilemez bir özet olarak tutulur ve güvenlik gereği verilmez. '
        'Hesap bilgileriniz "hesap" bölümündedir.',
  ),
  (
    veri: 'Çökme raporları',
    neden:
        'Hataları bulmak için toplanır (Firebase Crashlytics). Hesabınızla '
        'eşleştirilmez, 90 gün saklanır.',
  ),
  (
    veri: 'Sunucu kayıtları',
    neden:
        'Kullanıcı kimliği, işlem türü, zaman ve altyapının işlediği IP '
        'adresidir (Cloud Logging). 30 gün saklanır.',
  ),
  (
    veri: 'Bu telefondaki ayarlar',
    neden:
        'Görünüm ve uygulama kilidi gibi ayarlar yalnızca cihazınızda '
        'tutulur; sunucuya gönderilmez.',
  ),
  (
    veri: 'Karşı tarafın kendi verileri',
    neden:
        'Karşı tarafın profili, bildirimleri ve diğer defterleri ona '
        'aittir. Bu dosyada yalnızca ortak defterinizde görünen adı ve '
        'e-postası yer alır.',
  ),
];

/// Dışa aktarma dosyasının tamamı (JSON'a hazır harita).
Map<String, Object?> buildDataExport(
  CollectedData data, {
  required String uid,
  required DateTime now,
  String appVersion = AppConstants.appVersion,
  int buildNumber = AppConstants.buildNumber,
  String termsVersion = AppConstants.termsVersion,
}) {
  final ledgers = data.ledgers.toList()
    ..sort((x, y) => compareByTime(x.doc, y.doc, 'createdAt'));
  var entryCount = 0;
  var revisionCount = 0;
  var eventCount = 0;
  final ledgerList = <Map<String, Object?>>[];
  for (final ledger in ledgers) {
    final entries = ledger.entries.toList()
      ..sort((x, y) => compareByTime(x.doc, y.doc, 'createdAt'));
    final entryList = <Map<String, Object?>>[];
    for (final entry in entries) {
      entryCount++;
      revisionCount += entry.revisions.length;
      entryList.add({
        ...exportDoc(entry.doc),
        'surumler': [
          for (final r in sortedRevisions(entry.revisions)) exportDoc(r),
        ],
      });
    }
    eventCount += ledger.events.length;
    ledgerList.add({
      'kimlik': ledger.doc.id,
      'ozet': ledgerSummary(ledger.doc.data, uid),
      ..._docBody(ledger.doc),
      'kayitlar': entryList,
      'olaylar': [
        for (final e in sortedByTime(ledger.events, 'at')) exportDoc(e),
      ],
    });
  }
  return {
    'aciklama': dataExportIntro,
    'dosyaBilgisi': {
      'olusturmaZamani': isoTime(now),
      'uygulamaSurumu': appVersion,
      'derlemeNumarasi': buildNumber,
      'kosullarSurumu': termsVersion,
      'belgeSayilari': {
        'defter': ledgerList.length,
        'kayit': entryCount,
        'kayitSurumu': revisionCount,
        'olay': eventCount,
        'gelenKutusu': data.inbox.length,
        'bildirim': data.notifications.length,
      },
    },
    'hesap': data.account == null ? null : _account(data.account!),
    'profil': data.profile == null ? null : exportDoc(data.profile!),
    'herkeseAcikProfil': data.publicProfile == null
        ? null
        : exportDoc(data.publicProfile!),
    'defterler': ledgerList,
    'gelenKutusu': [
      for (final d in sortedByTime(data.inbox, 'createdAt')) exportDoc(d),
    ],
    'bildirimler': [
      for (final d in sortedByTime(data.notifications, 'createdAt'))
        exportDoc(d),
    ],
    'alanlar': dataExportFields,
    'dosyadaOlmayanlar': {
      'aciklama':
          'Aşağıdaki veriler uygulamanın okuyamadığı yerlerde tutulur; bu '
          'yüzden dosyada yoktur. Bunları Gizlilik ve KVKK Aydınlatma '
          'Metni\'nin "Haklarınız" bölümündeki iletişim kanalından '
          'isteyebilirsiniz.',
      'liste': [
        for (final item in dataExportNotIncluded)
          {'veri': item.veri, 'neden': item.neden},
      ],
    },
  };
}

/// Girintili, UTF-8 JSON.
Uint8List encodeDataExport(Map<String, Object?> export) => Uint8List.fromList(
  utf8.encode(const JsonEncoder.withIndent('  ').convert(export)),
);

/// "pacta-verilerim-2026-11-25.json" (yerel tarih).
String dataExportFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final d = now.toLocal();
  return 'pacta-verilerim-${d.year}-${two(d.month)}-${two(d.day)}.json';
}
