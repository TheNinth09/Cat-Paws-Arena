import 'dart:math';

import 'package:flutter/material.dart';

/// Proof that a grown-up answered the parent gate. Only
/// [ParentGateChallenge.answer] can create one, so Google sign-in cannot be
/// reached without passing the gate.
class ParentGateApproval {
  const ParentGateApproval._();
}

/// A multiplication question a young child is unlikely to answer.
class ParentGateChallenge {
  const ParentGateChallenge._(this.a, this.b);

  factory ParentGateChallenge.random([Random? random]) {
    final r = random ?? Random.secure();
    return ParentGateChallenge._(6 + r.nextInt(7), 6 + r.nextInt(7));
  }

  final int a, b;

  String prompt({required bool english}) => english
      ? 'Grown-ups only. What is $a × $b?'
      : 'Doar pentru adulți. Cât face $a × $b?';

  ParentGateApproval? answer(String input) =>
      int.tryParse(input.trim()) == a * b ? const ParentGateApproval._() : null;
}

/// Plain dialog for the gate. Lane 4 places and styles it in settings.
Future<ParentGateApproval?> showParentGate(
  BuildContext context, {
  required bool english,
  Random? random,
}) => showDialog<ParentGateApproval>(
  context: context,
  builder: (_) => _ParentGateDialog(
    challenge: ParentGateChallenge.random(random),
    english: english,
  ),
);

class _ParentGateDialog extends StatefulWidget {
  const _ParentGateDialog({required this.challenge, required this.english});
  final ParentGateChallenge challenge;
  final bool english;

  @override
  State<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<_ParentGateDialog> {
  final _answer = TextEditingController();

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.challenge.prompt(english: widget.english)),
        TextField(
          key: const Key('parentGateAnswer'),
          controller: _answer,
          keyboardType: TextInputType.number,
          maxLength: 3,
          autofocus: true,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.english ? 'Cancel' : 'Renunță'),
      ),
      TextButton(
        key: const Key('parentGateOk'),
        onPressed: () =>
            Navigator.pop(context, widget.challenge.answer(_answer.text)),
        child: const Text('OK'),
      ),
    ],
  );
}
