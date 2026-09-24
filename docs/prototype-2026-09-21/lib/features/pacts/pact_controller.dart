import 'package:flutter/foundation.dart';

import '../../data/pact_repository.dart';
import '../../models/pact.dart';

class PactController extends ChangeNotifier {
  PactController(this._repository);

  static const currentUserId = 'ayse';
  static const currentUserName = 'Ayşe';

  final PactRepository _repository;
  List<Pact> _pacts = const [];
  bool _isLoading = true;

  List<Pact> get pacts => List.unmodifiable(_pacts);
  bool get isLoading => _isLoading;

  List<Pact> get inboxPacts => _pacts
      .where(
        (pact) =>
            pact.statusFor(currentUserId) == PactStatus.awaitingYourApproval ||
            pact.statusFor(currentUserId) == PactStatus.changesRequested,
      )
      .toList();

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _pacts = await _repository.fetchPacts();
    _isLoading = false;
    notifyListeners();
  }

  Pact pactById(String id) => _pacts.firstWhere((pact) => pact.id == id);

  Future<void> createPact({
    required String title,
    required String description,
    required String invitee,
    required List<String> clauses,
    required DateTime dueDate,
  }) async {
    final pact = Pact(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      description: description,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      clauses: clauses,
      parties: [
        const PactParty(
          id: currentUserId,
          name: currentUserName,
          contact: 'Sen',
          approvalState: ApprovalState.accepted,
        ),
        PactParty(
          id: invitee.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-'),
          name: _nameFromInvitee(invitee),
          contact: invitee,
        ),
      ],
    );
    await _repository.createPact(pact);
    _pacts = [pact, ..._pacts];
    notifyListeners();
  }

  Future<void> approvePact(String pactId) async {
    final pact = pactById(pactId);
    final updated = pact.copyWith(
      parties: pact.parties
          .map(
            (party) => party.id == currentUserId
                ? party.copyWith(approvalState: ApprovalState.accepted)
                : party,
          )
          .toList(),
    );
    await _save(updated);
  }

  /// A revision invalidates every approval, so all parties need to approve
  /// the same version again before an agreement becomes active.
  Future<void> requestChanges(String pactId, String note) async {
    final pact = pactById(pactId);
    final updated = pact.copyWith(
      parties: pact.parties
          .map(
            (party) => party.copyWith(approvalState: ApprovalState.pending),
          )
          .toList(),
      version: pact.version + 1,
      revisionNote: note,
    );
    await _save(updated);
  }

  Future<void> _save(Pact updated) async {
    await _repository.savePact(updated);
    _pacts = _pacts
        .map((pact) => pact.id == updated.id ? updated : pact)
        .toList();
    notifyListeners();
  }

  String _nameFromInvitee(String invitee) {
    final localPart = invitee.split('@').first.trim();
    if (localPart.isEmpty) return 'Davetli';
    return localPart[0].toUpperCase() + localPart.substring(1);
  }
}
