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
  static const Key close = Key('member.close');

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.lg,
                Space.lg,
                Space.lg,
              ),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.member.displayName,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: FamilyMemberSheet.close,
                      icon: const Icon(Icons.close),
                      tooltip: 'Close without keeping changes',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),

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
                  for (final Member candidate in possible)
                    CheckboxListTile(
                      key: FamilyMemberSheet.parentToggle(candidate.id),
                      value: _parents.contains(candidate.id),
                      title: Text(candidate.displayName),
                      subtitle: candidate.role == null
                          ? null
                          : Text(candidate.role!),
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
              ],
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                0,
                Space.lg,
                Space.sm,
              ),
              child: Text(
                _message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.sm,
              Space.lg,
              Space.lg,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: FamilyMemberSheet.save,
                onPressed: _busy ? null : _keep,
                child: const Text('Keep'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
