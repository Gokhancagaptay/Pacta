import '../models/pact.dart';

abstract class PactRepository {
  Future<List<Pact>> fetchPacts();
  Future<void> createPact(Pact pact);
  Future<void> savePact(Pact pact);
}

/// Temporary local data source. A Firebase implementation can replace this
/// class without changing the controller or screens.
class InMemoryPactRepository implements PactRepository {
  InMemoryPactRepository() : _pacts = _seedPacts();

  final List<Pact> _pacts;

  @override
  Future<List<Pact>> fetchPacts() async => List.unmodifiable(_pacts);

  @override
  Future<void> createPact(Pact pact) async {
    _pacts.insert(0, pact);
  }

  @override
  Future<void> savePact(Pact pact) async {
    final index = _pacts.indexWhere((item) => item.id == pact.id);
    if (index == -1) {
      throw StateError('Anlaşma bulunamadı.');
    }
    _pacts[index] = pact;
  }

  static List<Pact> _seedPacts() {
    final now = DateTime.now();
    return [
      Pact(
        id: 'ev-harcamalari',
        title: 'Eylül ev harcamaları',
        description: 'Eylül ayındaki ortak ev giderlerinin paylaşım planı.',
        createdAt: now.subtract(const Duration(days: 1)),
        dueDate: now.add(const Duration(days: 7)),
        clauses: const [
          'Kira ve faturalar eşit paylaşılır.',
          'Ödemeler her ayın 5. gününe kadar tamamlanır.',
          'Beklenmeyen masraflar önce konuşularak onaylanır.',
        ],
        parties: const [
          PactParty(id: 'ayse', name: 'Ayşe', contact: 'Sen'),
          PactParty(
            id: 'deniz',
            name: 'Deniz',
            contact: 'deniz@example.com',
            approvalState: ApprovalState.accepted,
          ),
        ],
      ),
      Pact(
        id: 'tasarim-teslimi',
        title: 'Landing page teslim planı',
        description: 'Tasarım ve geri bildirim takvimi için iş akışı.',
        createdAt: now.subtract(const Duration(days: 3)),
        dueDate: now.add(const Duration(days: 14)),
        clauses: const [
          'İlk taslak 3 Eylül tarihinde paylaşılır.',
          'İki tur geri bildirim dahildir.',
          'Final dosyalar Figma üzerinden teslim edilir.',
        ],
        parties: const [
          PactParty(
            id: 'ayse',
            name: 'Ayşe',
            contact: 'Sen',
            approvalState: ApprovalState.accepted,
          ),
          PactParty(id: 'mert', name: 'Mert', contact: 'mert@example.com'),
        ],
      ),
      Pact(
        id: 'birikim-hedefi',
        title: 'Ortak birikim hedefi',
        description: 'Yıl sonu tatili için aylık birikim taahhüdü.',
        createdAt: now.subtract(const Duration(days: 11)),
        dueDate: now.add(const Duration(days: 95)),
        clauses: const [
          'Her ay ortak hesaba 5.000 TL aktarılır.',
          'Hedefe ulaşılınca tatil bütçesi birlikte belirlenir.',
        ],
        parties: const [
          PactParty(
            id: 'ayse',
            name: 'Ayşe',
            contact: 'Sen',
            approvalState: ApprovalState.accepted,
          ),
          PactParty(
            id: 'deniz',
            name: 'Deniz',
            contact: 'deniz@example.com',
            approvalState: ApprovalState.accepted,
          ),
        ],
      ),
    ];
  }
}
