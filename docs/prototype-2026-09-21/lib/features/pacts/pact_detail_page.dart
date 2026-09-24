import 'package:flutter/material.dart';

import '../../models/pact.dart';
import 'pact_controller.dart';

class PactDetailPage extends StatelessWidget {
  const PactDetailPage({
    super.key,
    required this.controller,
    required this.pactId,
  });

  final PactController controller;
  final String pactId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final pact = controller.pactById(pactId);
        final myParty = pact.partyFor(PactController.currentUserId);
        final status = pact.statusFor(PactController.currentUserId);

        return Scaffold(
          appBar: AppBar(title: const Text('Anlaşma detayı')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _PactSummary(pact: pact, status: status),
              const SizedBox(height: 24),
              Text(
                'Maddeler',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (var index = 0; index < pact.clauses.length; index++)
                        _ClauseRow(
                          number: index + 1,
                          text: pact.clauses[index],
                          isLast: index == pact.clauses.length - 1,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tarafların onayı',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    for (var index = 0; index < pact.parties.length; index++)
                      _PartyRow(
                        party: pact.parties[index],
                        isLast: index == pact.parties.length - 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _ApprovalAction(
                status: status,
                currentApproval: myParty.approvalState,
                onApprove: () => _approve(context, pact.id),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _approve(BuildContext context, String pactId) async {
    await controller.approvePact(pactId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Onayın kaydedildi.')),
    );
  }
}

class _PactSummary extends StatelessWidget {
  const _PactSummary({required this.pact, required this.status});

  final Pact pact;
  final PactStatus status;

  @override
  Widget build(BuildContext context) {
    final details = _pactStatusDetails(status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusLabel(details: details),
            const SizedBox(height: 14),
            Text(
              pact.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(pact.description),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.layers_outlined, size: 18),
                const SizedBox(width: 6),
                Text('Sürüm ${pact.version}'),
                const Spacer(),
                const Icon(Icons.event_outlined, size: 18),
                const SizedBox(width: 6),
                Text(_shortDate(pact.dueDate)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClauseRow extends StatelessWidget {
  const _ClauseRow({
    required this.number,
    required this.text,
    required this.isLast,
  });

  final int number;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 14),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFECEFF5))),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: const Color(0xFFE9EEFC),
            foregroundColor: const Color(0xFF2559D6),
            child: Text('$number', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PartyRow extends StatelessWidget {
  const _PartyRow({required this.party, required this.isLast});

  final PactParty party;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final details = _approvalDetails(party.approvalState);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFECEFF5))),
            ),
      child: Row(
        children: [
          CircleAvatar(child: Text(party.name.substring(0, 1).toUpperCase())),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(party.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(party.contact, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(details.icon, color: details.color),
          const SizedBox(width: 6),
          Text(
            details.label,
            style: TextStyle(color: details.color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ApprovalAction extends StatelessWidget {
  const _ApprovalAction({
    required this.status,
    required this.currentApproval,
    required this.onApprove,
  });

  final PactStatus status;
  final ApprovalState currentApproval;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    if (status == PactStatus.active) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE5F5EE),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_outlined, color: Color(0xFF147A59)),
            SizedBox(width: 10),
            Expanded(
              child: Text('Tüm taraflar aynı sürümü onayladı. Anlaşma aktif.'),
            ),
          ],
        ),
      );
    }

    if (currentApproval == ApprovalState.accepted) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('Onayın kaydedildi. Karşı tarafın onayı bekleniyor.'),
      );
    }

    return FilledButton.icon(
      onPressed: onApprove,
      icon: const Icon(Icons.check),
      label: const Text('Bu sürümü onayla'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.details});

  final _PactStatusDetails details;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: details.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(details.icon, size: 14, color: details.color),
          const SizedBox(width: 4),
          Text(
            details.label,
            style: TextStyle(color: details.color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PactStatusDetails {
  const _PactStatusDetails(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

_PactStatusDetails _pactStatusDetails(PactStatus status) {
  switch (status) {
    case PactStatus.awaitingYourApproval:
      return const _PactStatusDetails(
        'Onayın bekleniyor',
        Color(0xFFE08A00),
        Icons.pending_outlined,
      );
    case PactStatus.waitingForOtherParty:
      return const _PactStatusDetails(
        'Karşı taraf bekleniyor',
        Color(0xFF2559D6),
        Icons.schedule_outlined,
      );
    case PactStatus.active:
      return const _PactStatusDetails(
        'Aktif',
        Color(0xFF147A59),
        Icons.verified_outlined,
      );
    case PactStatus.changesRequested:
      return const _PactStatusDetails(
        'Yeni sürüm bekleniyor',
        Color(0xFF8C50C6),
        Icons.edit_note_outlined,
      );
  }
}

class _ApprovalDetails {
  const _ApprovalDetails(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

_ApprovalDetails _approvalDetails(ApprovalState state) {
  switch (state) {
    case ApprovalState.pending:
      return const _ApprovalDetails(
        'Bekliyor',
        Color(0xFFB06D00),
        Icons.schedule_outlined,
      );
    case ApprovalState.accepted:
      return const _ApprovalDetails(
        'Onayladı',
        Color(0xFF147A59),
        Icons.check_circle_outline,
      );
    case ApprovalState.changesRequested:
      return const _ApprovalDetails(
        'Değişiklik istedi',
        Color(0xFF8C50C6),
        Icons.edit_note_outlined,
      );
  }
}

String _shortDate(DateTime date) {
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return '${date.day} ${months[date.month - 1]}';
}
