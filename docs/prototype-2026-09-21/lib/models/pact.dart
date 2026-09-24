enum ApprovalState { pending, accepted, changesRequested }

class PactParty {
  const PactParty({
    required this.id,
    required this.name,
    required this.contact,
    this.approvalState = ApprovalState.pending,
  });

  final String id;
  final String name;
  final String contact;
  final ApprovalState approvalState;

  PactParty copyWith({ApprovalState? approvalState}) => PactParty(
        id: id,
        name: name,
        contact: contact,
        approvalState: approvalState ?? this.approvalState,
      );
}

enum PactStatus {
  awaitingYourApproval,
  waitingForOtherParty,
  active,
  changesRequested,
}

class Pact {
  const Pact({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.dueDate,
    required this.clauses,
    required this.parties,
    this.version = 1,
    this.revisionNote,
  });

  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime dueDate;
  final List<String> clauses;
  final List<PactParty> parties;
  final int version;
  final String? revisionNote;

  PactParty partyFor(String userId) =>
      parties.firstWhere((party) => party.id == userId);

  PactStatus statusFor(String userId) {
    if (parties.any(
      (party) => party.approvalState == ApprovalState.changesRequested,
    )) {
      return PactStatus.changesRequested;
    }
    if (parties.every(
      (party) => party.approvalState == ApprovalState.accepted,
    )) {
      return PactStatus.active;
    }
    if (partyFor(userId).approvalState == ApprovalState.pending) {
      return PactStatus.awaitingYourApproval;
    }
    return PactStatus.waitingForOtherParty;
  }

  Pact copyWith({
    List<PactParty>? parties,
    int? version,
    String? revisionNote,
  }) =>
      Pact(
        id: id,
        title: title,
        description: description,
        createdAt: createdAt,
        dueDate: dueDate,
        clauses: clauses,
        parties: parties ?? this.parties,
        version: version ?? this.version,
        revisionNote: revisionNote ?? this.revisionNote,
      );
}
