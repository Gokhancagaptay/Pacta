import 'package:flutter/material.dart';

import '../../models/pact.dart';
import 'pact_controller.dart';
import 'pact_detail_page.dart';

class PactaHomePage extends StatelessWidget {
  const PactaHomePage({super.key, required this.controller});

  final PactController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (controller.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final awaitingApproval = controller.pacts
            .where(
              (pact) =>
                  pact.statusFor(PactController.currentUserId) ==
                  PactStatus.awaitingYourApproval,
            )
            .length;
        final activePacts = controller.pacts
            .where(
              (pact) =>
                  pact.statusFor(PactController.currentUserId) ==
                  PactStatus.active,
            )
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Pacta',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16),
                child: CircleAvatar(child: Text('A')),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                'Bugün netleştirelim.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Anlaşmaları oluştur, birlikte onayla ve aynı sayfada kal.',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _MetricCard(
                    value: '$awaitingApproval',
                    label: 'Onayın bekleniyor',
                    color: const Color(0xFFE08A00),
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    value: '$activePacts',
                    label: 'Aktif anlaşma',
                    color: const Color(0xFF147A59),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Anlaşmaların',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              for (final pact in controller.pacts) ...[
                PactCard(
                  pact: pact,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (context) => PactDetailPage(
                        controller: controller,
                        pactId: pact.id,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class PactCard extends StatelessWidget {
  const PactCard({super.key, required this.pact, required this.onTap});

  final Pact pact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = pact.statusFor(PactController.currentUserId);
    final style = _statusStyle(status);
    final otherParty = pact.parties.firstWhere(
      (party) => party.id != PactController.currentUserId,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pact.title,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusChip(style: style),
                ],
              ),
              const SizedBox(height: 8),
              Text(pact.description),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 6),
                  Text('Sen · ${otherParty.name}'),
                  const Spacer(),
                  Text('Sürüm ${pact.version}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.style});

  final _StatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              color: style.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

_StatusStyle _statusStyle(PactStatus status) {
  switch (status) {
    case PactStatus.awaitingYourApproval:
      return const _StatusStyle(
        'Onayın bekleniyor',
        Color(0xFFE08A00),
        Icons.pending_outlined,
      );
    case PactStatus.waitingForOtherParty:
      return const _StatusStyle(
        'Karşı taraf bekleniyor',
        Color(0xFF2559D6),
        Icons.schedule_outlined,
      );
    case PactStatus.active:
      return const _StatusStyle(
        'Aktif',
        Color(0xFF147A59),
        Icons.verified_outlined,
      );
    case PactStatus.changesRequested:
      return const _StatusStyle(
        'Yeni sürüm bekleniyor',
        Color(0xFF8C50C6),
        Icons.edit_note_outlined,
      );
  }
}
