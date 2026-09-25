import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/errors.dart';
import '../common/confirm_dialog.dart';
import '../common/describe_error.dart';
import '../design/app_button.dart';
import '../design/bottom_action_bar.dart';
import '../design/category_avatar.dart';
import '../design/category_style.dart';
import '../design/style_choosers.dart';
import '../design/tokens.dart';
import '../design/type_switcher.dart';
import '../design/typography.dart';
import 'category_ids.dart';

/// Crea una categoría (o subcategoría de [parentId]) o, con [categoryId], la
/// edita: nombre, ícono y color, y su archivado. En las del sistema el nombre
/// es de solo lectura y no se pueden archivar.
class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({super.key, this.categoryId, this.initialKind, this.parentId});

  final String? categoryId;
  final CategoryKind? initialKind;
  final String? parentId;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _name = TextEditingController();
  late CategoryKind _kind = widget.initialKind ?? CategoryKind.expense;
  String _icon = 'category';
  Color _color = categoryColorChoices[6];

  Category? _existing;
  Category? _parent;
  bool _loading = true;
  bool _saving = false;
  String? _nameError;
  String? _generalError;

  bool get _isEditing => widget.categoryId != null;
  bool get _isSystem => _isEditing && isSystemCategory(widget.categoryId!);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(categoryRepositoryProvider);
    final existing = _isEditing ? await repo.get(widget.categoryId!) : null;
    final parentId = existing?.parentId ?? widget.parentId;
    final parent = parentId == null ? null : await repo.get(parentId);
    if (!mounted) return;
    if ((_isEditing && existing == null) ||
        (widget.parentId != null && (parent == null || isSystemCategory(parent.id)))) {
      context.pop();
      return;
    }
    setState(() {
      _existing = existing;
      _parent = parent;
      if (existing != null) {
        _kind = existing.kind;
        _name.text = existing.name;
        _icon = existing.icon ?? 'category';
        _color = existing.colorValue != null
            ? Color(existing.colorValue!)
            : categoryBaseColor(existing.id);
      } else if (parent != null) {
        _kind = parent.kind;
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _nameError = null;
      _generalError = null;
    });
    try {
      final repo = ref.read(categoryRepositoryProvider);
      if (_isEditing) {
        await repo.update(
          widget.categoryId!,
          name: _isSystem ? null : _name.text,
          icon: _icon,
          colorValue: _color.toARGB32(),
        );
      } else {
        await repo.create(
          CategoryInput(
            name: _name.text,
            kind: _kind,
            parentId: _parent?.id,
            icon: _icon,
            colorValue: _color.toARGB32(),
          ),
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        final message = describeError(e);
        if (errorFieldOf(e) == ErrorField.name) {
          _nameError = message;
        } else {
          _generalError = message;
        }
      });
      if (e is! DomainException) rethrow;
    }
  }

  Future<void> _toggleArchive() async {
    final cat = _existing!;
    final repo = ref.read(categoryRepositoryProvider);
    try {
      if (cat.isArchived) {
        await repo.setArchived(cat.id, false);
      } else {
        final subs = cat.parentId == null
            ? (await repo.list(
                kind: cat.kind,
                includeArchived: true,
              )).where((x) => x.parentId == cat.id && !x.isArchived).toList()
            : <Category>[];
        if (!mounted) return;
        final ok = await confirmAction(
          context,
          title: 'Archivar categoría',
          message:
              '"${cat.name}" dejará de ofrecerse al registrar movimientos'
              '${subs.isEmpty ? '' : ', igual que sus subcategorías'}. '
              'Los movimientos que ya la usan la conservan.',
          confirmLabel: 'Archivar',
        );
        if (!ok) return;
        await repo.setArchived(cat.id, true);
        for (final sub in subs) {
          await repo.setArchived(sub.id, true);
        }
      }
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _generalError = describeError(e));
      if (e is! DomainException) rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final brightness = Theme.of(context).brightness;
    final title = _isEditing
        ? 'Editar categoría'
        : _parent != null
        ? 'Nueva subcategoría'
        : 'Nueva categoría';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isEditing && !_isSystem && !_loading)
            IconButton(
              tooltip: _existing!.isArchived ? 'Restaurar categoría' : 'Archivar categoría',
              icon: Icon(_existing!.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
              onPressed: _toggleArchive,
            ),
        ],
      ),
      bottomNavigationBar: _loading
          ? null
          : BottomActionBar(
              child: AppButton(
                label: _isEditing ? 'Guardar cambios' : 'Crear categoría',
                loading: _saving,
                onPressed: _save,
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xxl),
              children: [
                if (_generalError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: Text(_generalError!, style: t.caption.copyWith(color: c.danger)),
                  ),
                Center(
                  child: CategoryAvatar(
                    icon: categoryIcon(_icon),
                    color: adaptToBrightness(_color, brightness),
                    size: 72,
                  ),
                ),
                const SizedBox(height: Space.xl),
                if (!_isEditing && _parent == null) ...[
                  TypeSwitcher<CategoryKind>(
                    value: _kind,
                    options: const [
                      (CategoryKind.expense, 'Gasto'),
                      (CategoryKind.income, 'Ingreso'),
                    ],
                    colorOf: (k) => k == CategoryKind.income ? c.income : c.expense,
                    onChanged: (k) => setState(() => _kind = k),
                  ),
                  const SizedBox(height: Space.lg),
                ],
                if (_parent != null) ...[
                  Text('Subcategoría de ${_parent!.name}', style: t.caption),
                  const SizedBox(height: Space.sm),
                ],
                TextField(
                  controller: _name,
                  enabled: !_isSystem,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    errorText: _nameError,
                    helperText: _isSystem
                        ? 'Categoría del sistema: no se puede renombrar ni archivar.'
                        : null,
                    helperMaxLines: 2,
                  ),
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
                const SizedBox(height: Space.xl),
                Text('ÍCONO', style: t.label),
                const SizedBox(height: Space.sm),
                IconChooser(
                  icons: categoryIconChoices,
                  selected: _icon,
                  color: adaptToBrightness(_color, brightness),
                  onChanged: (v) => setState(() => _icon = v),
                ),
                const SizedBox(height: Space.xl),
                Text('COLOR', style: t.label),
                const SizedBox(height: Space.sm),
                ColorChooser(
                  colors: categoryColorChoices,
                  selected: _color,
                  onChanged: (v) => setState(() => _color = v),
                ),
              ],
            ),
    );
  }
}
