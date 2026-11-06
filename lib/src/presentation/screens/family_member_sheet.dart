import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/sources/platform/photos.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/family/family_tree.dart';
import '../brand/tokens.dart';

/// Editing one person in the family tree (#109): a photograph, a role, and
/// who their parents are.
///
/// Returns the edited [Member], or null if nothing was kept. It does **not**
/// save: the screen that opened it does, through `FamilyEditor.updateMember`,
/// which is where the rule about not becoming your own ancestor lives. A
/// sheet that wrote to a repository would be a second place that knows how a
/// family may change.
///
/// Nothing here touches the rota. A role is a word, a parent is an edge, and
/// neither hands anybody a week of prayer — which is the distinction the
/// whole tab exists to keep.
class FamilyMemberSheet extends StatefulWidget {
  const FamilyMemberSheet({
    required this.family,
    required this.member,
    required this.photos,
    super.key,
  });

  final Family family;
  final Member member;
  final Photos photos;

  static const Key roleField = Key('member.role');
  static const Key choosePhoto = Key('member.photo.choose');
  static const Key removePhoto = Key('member.photo.remove');
  static const Key save = Key('member.save');

  static Key parentToggle(String id) => Key('member.parent.$id');

  @override
  State<FamilyMemberSheet> createState() => _FamilyMemberSheetState();
}

class _FamilyMemberSheetState extends State<FamilyMemberSheet> {
  late final TextEditingController _role = TextEditingController(
    text: widget.member.role ?? '',
  );
  late String? _photoPath = widget.member.photoPath;
  late final Set<String> _parents = <String>{...widget.member.parentIds};

  /// A photograph chosen in this sheet and then abandoned.
  ///
  /// Copied into the app's storage the moment it is picked, so dismissing
  /// the sheet would otherwise leave an orphan file nobody references.
  final List<String> _copiedHere = <String>[];

  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _role.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final String? path = await widget.photos.pickFor(widget.member.id);
      if (path != null) {
        _copiedHere.add(path);
        if (mounted) {
          setState(() => _photoPath = path);
        }
      }
    } on Object catch (error) {
      // A picker that will not open, or a copy that fails on a full phone.
      // Said out loud rather than swallowed.
      if (mounted) {
        setState(() => _message = 'That photograph could not be used: $error');
      }
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  void _keep() {
    final String role = _role.text.trim();
    final Member updated = widget.member.copyWith(
      role: role.isEmpty ? null : role,
      clearRole: role.isEmpty,
      photoPath: _photoPath,
      clearPhoto: _photoPath == null,
      parentIds: _parents.toList(),
    );

    // Any photograph picked here and then replaced by another is now
    // referenced by nothing. Tidied on the way out rather than left to
    // accumulate every time somebody changes their mind.
    for (final String path in _copiedHere) {
      if (path != _photoPath) {
        unawaited(widget.photos.remove(path));
      }
    }

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Member> possible = FamilyTree.possibleParentsFor(
      widget.family.members,
      childId: widget.member.id,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.lg,
          Space.lg,
          Space.xl,
        ),
        children: <Widget>[
          Text(widget.member.displayName, style: theme.textTheme.titleLarge),
          const SizedBox(height: Space.xl),

          // ───────────────────────── photograph ─────────────────────────
          Row(
            children: <Widget>[
              if (_photoPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: Image.file(
                    File(_photoPath!),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (
                      BuildContext context,
                      Object e,
                      StackTrace? s,
                    ) => const SizedBox(width: 64, height: 64),
                  ),
                ),
              if (_photoPath != null) const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    OutlinedButton.icon(
                      key: FamilyMemberSheet.choosePhoto,
                      onPressed: _busy ? null : _choosePhoto,
                      icon: const Icon(Icons.photo_outlined),
                      label: Text(
                        _photoPath == null
                            ? 'Choose a photograph'
                            : 'Change the photograph',
                      ),
                    ),
                    if (_photoPath != null)
                      TextButton(
                        key: FamilyMemberSheet.removePhoto,
                        onPressed: _busy
                            ? null
                            : () => setState(() => _photoPath = null),
                        child: const Text('Remove it'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            'It stays on this phone and is never uploaded.',
            style: theme.textTheme.bodySmall,
          ),

          // ──────────────────────────── role ────────────────────────────
          const SizedBox(height: Space.xl),
          TextField(
            key: FamilyMemberSheet.roleField,
            controller: _role,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What they are to the family',
              hintText: 'Mama, eldest sister, born 2019…',
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Your words, not a list the app chose.',
            style: theme.textTheme.bodySmall,
          ),

          // ─────────────────────────── parents ──────────────────────────
          const SizedBox(height: Space.xl),
          Text('Whose child they are', style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.sm),
          if (possible.isEmpty)
            Text(
              'Nobody in the family can be a parent of '
              '${widget.member.displayName} — everyone else is already '
              'below them.',
              style: theme.textTheme.bodySmall,
            )
          else
            // Only names that cannot close a loop are offered, so the
            // refusal is an absence rather than an error afterwards.
            for (final Member candidate in possible)
              CheckboxListTile(
                key: FamilyMemberSheet.parentToggle(candidate.id),
                value: _parents.contains(candidate.id),
                title: Text(candidate.displayName),
                subtitle: candidate.role == null ? null : Text(candidate.role!),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                onChanged: (bool? on) => setState(() {
                  if (on ?? false) {
                    _parents.add(candidate.id);
                  } else {
                    _parents.remove(candidate.id);
                  }
                }),
              ),

          if (_message != null) ...<Widget>[
            const SizedBox(height: Space.lg),
            Text(
              _message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],

          const SizedBox(height: Space.xl),
          FilledButton(
            key: FamilyMemberSheet.save,
            onPressed: _busy ? null : _keep,
            child: const Text('Keep'),
          ),
        ],
      ),
    );
  }
}
