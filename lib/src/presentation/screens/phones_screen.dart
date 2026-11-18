import 'package:flutter/material.dart';

import '../../application/join_a_family.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/sources/platform/identity.dart';
import '../../data/sources/platform/sharing.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/family/codes.dart';
import '../../domain/rota/family_editor.dart';
import '../brand/tokens.dart';
import '../widgets/centred_message.dart';

/// Which of the family's phones are in the family (#143, ADR-027).
///
/// Both directions of the same conversation. Somebody already in the family
/// admits a new phone by name; the new phone then joins with the family's
/// code. There is no code that lets a stranger in, which is why the family
/// code can be sent over WhatsApp without any care.
class PhonesScreen extends StatefulWidget {
  const PhonesScreen({
    required this.familyRepository,
    required this.identity,
    required this.sharing,
    required this.join,
    super.key,
  });

  final FamilyRepository familyRepository;
  final Identity identity;
  final Sharing sharing;

  /// Absent when Firebase did not start, which is also when there is
  /// nothing to join.
  final JoinAFamily? join;

  static const Key myCode = Key('phones.myCode');
  static const Key sendMyCode = Key('phones.myCode.send');
  static const Key familyCodeField = Key('phones.join.field');
  static const Key joinButton = Key('phones.join.confirm');
  static const Key confirmReplace = Key('phones.join.replace');
  static const Key sendFamilyCode = Key('phones.familyCode.send');
  static const Key admitField = Key('phones.admit.field');
  static const Key admitConfirm = Key('phones.admit.confirm');

  static Key admitRow(String memberId) => Key('phones.admit.$memberId');

  @override
  State<PhonesScreen> createState() => _PhonesScreenState();
}

class _PhonesScreenState extends State<PhonesScreen> {
  late final Stream<Family?> _families = widget.familyRepository.watch();
  final TextEditingController _code = TextEditingController();

  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _say(String message) {
    if (mounted) {
      setState(() => _message = message);
    }
  }

  // ───────────────────────────────── joining ─────────────────────────────

  Future<void> _join({bool replacing = false}) async {
    final JoinAFamily? join = widget.join;
    if (join == null) {
      _say('This phone cannot reach the family yet.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    final JoinResult result = await join(_code.text, replacing: replacing);

    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    switch (result) {
      case Joined(family: final Family family):
        _code.clear();
        _say('Joined ${family.name}. Say which one you are on this phone.');
      case WouldReplaceThisRota(mine: final Family mine):
        await _askAboutReplacing(mine);
      case NotAFamilyCode():
        _say(
          'That is not a family code. It is twelve characters beginning '
          'with f — ask them to send it rather than read it out.',
        );
      case NotYourFamilyYet():
        _say(
          'Not yet. Somebody already in that family has to add this '
          'account first — send them your code above, then try again.',
        );
      case NotSignedIn():
        _say('Sign in first, on the settings screen.');
      case CouldNotAsk(error: final Object error):
        _say('Could not reach the family just now: $error');
    }
  }

  /// Two families cannot be merged (ADR-008), so this is a question.
  Future<void> _askAboutReplacing(Family mine) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Put this rota aside?'),
        content: Text(
          'This phone already has ${mine.name}, with '
          '${mine.members.length} people in it. Joining another family '
          'replaces it here — the two cannot be merged.\n\n'
          'Your journal stays. The rota does not.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep this one'),
          ),
          TextButton(
            key: PhonesScreen.confirmReplace,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Join the other'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _join(replacing: true);
    }
  }

  // ──────────────────────────────── admitting ────────────────────────────

  Future<void> _admit(Family family, Member member) async {
    final String? typed = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _AdmitDialog(member: member),
    );
    if (typed == null) {
      return;
    }

    final String? uid = AccountCode.parse(typed);
    if (uid == null) {
      _say(
        'That does not look like a whole code. Ask ${member.displayName} '
        'to send it rather than type it.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final Family? latest = await widget.familyRepository.load();
      if (latest != null) {
        await widget.familyRepository.save(
          FamilyEditor.linkUid(latest, memberId: member.id, uid: uid),
        );
        _say(
          '${member.displayName} is in. Send them the family code so their '
          'phone can find it.',
        );
      }
    } on ArgumentError catch (error) {
      _say(error.message.toString());
    } on Object catch (error) {
      _say('That did not work: $error');
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  // ───────────────────────────────── sending ─────────────────────────────

  Future<void> _send({required String text, required String subject}) async {
    try {
      await widget.sharing.shareText(text: text, subject: subject);
    } on Object catch (error) {
      _say('Nothing on this phone would send that: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('The family\'s phones')),
      body: SafeArea(
        child: StreamBuilder<Family?>(
          stream: _families,
          builder: (BuildContext context, AsyncSnapshot<Family?> stored) {
            final SignedIn? who = widget.identity.current;
            if (who == null) {
              return CentredMessage(
                children: <Widget>[
                  Text(
                    'Sign in first',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'The phones recognise each other by the account signed '
                    'in on them, so there is nothing to do here until this '
                    'one has an account.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              );
            }
            return _body(theme, who, stored.data);
          },
        ),
      ),
    );
  }

  Widget _body(ThemeData theme, SignedIn who, Family? family) => ListView(
    padding: const EdgeInsets.only(bottom: Space.xxl),
    children: <Widget>[
      if (_message case final String message)
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
          child: Text(message, style: theme.textTheme.bodyMedium),
        ),

      const _Heading('This account'),
      ListTile(
        key: PhonesScreen.myCode,
        title: Text(who.displayName ?? who.email ?? 'Signed in'),
        subtitle: Text(who.uid, style: theme.textTheme.bodySmall),
        trailing: IconButton(
          key: PhonesScreen.sendMyCode,
          icon: const Icon(Icons.ios_share_outlined),
          tooltip: 'Send this code',
          onPressed: _busy
              ? null
              : () => _send(
                  text:
                      'Add me to Mashibini Prayer. My code is:\n\n'
                      '${who.uid}',
                  subject: 'My Mashibini Prayer code',
                ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        child: Text(
          'Somebody already in the family has to add this code before this '
          'phone can see the rota. Send it rather than reading it out.',
          style: theme.textTheme.bodySmall,
        ),
      ),

      if (family case final Family mine) ..._inTheFamily(theme, mine),

      // Shown whether or not this phone has a rota. Hiding it while one
      // exists would make `WouldReplaceThisRota` unreachable, which is the
      // "finished in the domain, absent from the product" shape this
      // project has already recorded twice (R1.4, R2.3).
      ..._joining(theme, hasARota: family != null),
    ],
  );

  List<Widget> _joining(ThemeData theme, {required bool hasARota}) => <Widget>[
    _Heading(hasARota ? 'Join a different family' : 'Join the family'),
    Padding(
      padding: Space.gutter,
      child: TextField(
        key: PhonesScreen.familyCodeField,
        controller: _code,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'The family code',
          hintText: 'f…',
          border: OutlineInputBorder(),
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 0),
      child: FilledButton(
        key: PhonesScreen.joinButton,
        onPressed: _busy ? null : () => _join(),
        child: const Text('Join'),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 0),
      child: Text(
        hasARota
            ? 'This phone already has a rota. Joining another replaces it '
                  'here — the two cannot be merged, and it will ask before '
                  'it does anything.'
            : 'They will have sent it to you. It is not a password — '
                  'knowing it is not enough to get in, which is why they '
                  'had to add your code first.',
        style: theme.textTheme.bodySmall,
      ),
    ),
  ];

  List<Widget> _inTheFamily(ThemeData theme, Family family) {
    final List<Member> members = family.members;

    return <Widget>[
      const _Heading('Let somebody in'),
      for (final Member member in members)
        ListTile(
          key: PhonesScreen.admitRow(member.id),
          title: Text(member.displayName),
          subtitle: Text(
            member.uid == null ? 'No phone yet' : 'On a phone of their own',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : () => _admit(family, member),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 0),
        child: Text(
          'Pick whoever has sent you their code. Nobody gets in without '
          'being named here first.',
          style: theme.textTheme.bodySmall,
        ),
      ),

      const _Heading('The family code'),
      ListTile(
        title: Text(family.id, style: theme.textTheme.bodyMedium),
        subtitle: const Text('Send this once you have added somebody'),
        trailing: IconButton(
          key: PhonesScreen.sendFamilyCode,
          icon: const Icon(Icons.ios_share_outlined),
          tooltip: 'Send the family code',
          onPressed: _busy
              ? null
              : () => _send(
                  text:
                      'The Mashibini Prayer family code is:\n\n'
                      '${family.id}',
                  subject: 'Mashibini Prayer family code',
                ),
        ),
      ),
    ];
  }
}

/// Asks for one person's account code.
class _AdmitDialog extends StatefulWidget {
  const _AdmitDialog({required this.member});

  final Member member;

  @override
  State<_AdmitDialog> createState() => _AdmitDialogState();
}

class _AdmitDialogState extends State<_AdmitDialog> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Let ${widget.member.displayName} in'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Paste the code they sent you. It is long and it is not meant to '
          'be typed.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Space.lg),
        TextField(
          key: PhonesScreen.admitField,
          controller: _code,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Their code',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Not now'),
      ),
      TextButton(
        key: PhonesScreen.admitConfirm,
        onPressed: () => Navigator.of(context).pop(_code.text),
        child: const Text('Add them'),
      ),
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.xl,
        Space.lg,
        Space.sm,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.secondary,
        ),
      ),
    );
  }
}
