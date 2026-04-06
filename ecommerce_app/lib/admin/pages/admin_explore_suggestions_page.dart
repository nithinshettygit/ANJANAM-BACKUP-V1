import 'package:ecommerce_app/features/articles/providers/articles_providers.dart';
import 'package:ecommerce_app/features/explore_suggestions/models/explore_suggestion.dart';
import 'package:ecommerce_app/features/explore_suggestions/providers/explore_suggestions_providers.dart';
import 'package:ecommerce_app/features/videos/providers/videos_providers.dart';
import 'package:ecommerce_app/presentation/utils/user_facing_error_message.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminExploreSuggestionsPage extends ConsumerWidget {
  const AdminExploreSuggestionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminExploreSuggestionsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Manage Explore top "Suggested for you" carousel. Drag to reorder.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(Icons.add),
                      label: const Text('Add item'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No suggested items configured yet.'))
                  : ReorderableListView.builder(
                      itemCount: rows.length,
                      onReorder: (oldIndex, newIndex) async {
                        final updated = [...rows];
                        if (newIndex > oldIndex) newIndex -= 1;
                        final moved = updated.removeAt(oldIndex);
                        updated.insert(newIndex, moved);
                        await ref
                            .read(exploreSuggestionsServiceProvider)
                            .reorderSuggestions(updated.map((e) => e.id).toList());
                        ref.invalidate(adminExploreSuggestionsProvider);
                        ref.invalidate(activeExploreSuggestionsProvider);
                        ref.read(exploreSuggestionsRevisionProvider.notifier).bump();
                      },
                      itemBuilder: (context, i) {
                        final s = rows[i];
                        final label = s.contentType == 'article' ? 'Article' : 'Video';
                        final target = s.contentType == 'article' ? s.articleId : s.videoId;
                        return Card(
                          key: ValueKey(s.id),
                          child: ListTile(
                            leading: const Icon(Icons.drag_indicator),
                            title: Text(
                              s.titleOverride?.isNotEmpty == true ? s.titleOverride! : label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '$label • ${target ?? '-'} • ${s.isActive ? 'Active' : 'Inactive'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              child: const Icon(Icons.more_vert),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await _openEditor(context, ref, s);
                                } else if (value == 'delete') {
                                  try {
                                    await ref.read(exploreSuggestionsServiceProvider).deleteSuggestion(s.id);
                                    ref.invalidate(adminExploreSuggestionsProvider);
                                    ref.invalidate(activeExploreSuggestionsProvider);
                                    ref.read(exploreSuggestionsRevisionProvider.notifier).bump();
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(userFacingErrorMessage(e))),
                                    );
                                  }
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    ExploreSuggestion? existing,
  ) async {
    final articles = await ref.read(adminArticlesListProvider.future);
    final videos = await ref.read(adminVideosListProvider.future);

    var contentType = existing?.contentType ?? 'article';
    String? selectedArticleId = existing?.articleId;
    String? selectedVideoId = existing?.videoId;
    final titleCtrl = TextEditingController(text: existing?.titleOverride ?? '');
    final subtitleCtrl = TextEditingController(text: existing?.subtitleOverride ?? '');
    String? imageUrl = existing?.imageUrl;
    final badgeCtrl = TextEditingController(text: existing?.badgeLabel ?? '');
    var active = existing?.isActive ?? true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add suggestion item' : 'Edit suggestion item'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: contentType,
                    decoration: const InputDecoration(labelText: 'Content type'),
                    items: const [
                      DropdownMenuItem(value: 'article', child: Text('Article')),
                      DropdownMenuItem(value: 'video', child: Text('Video')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => contentType = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  if (contentType == 'article')
                    DropdownMenu<String>(
                      width: 520,
                      enableFilter: true,
                      initialSelection: selectedArticleId,
                      label: const Text('Select article'),
                      dropdownMenuEntries: articles
                          .map((a) => DropdownMenuEntry<String>(value: a.id, label: a.title))
                          .toList(),
                      onSelected: (v) => setLocal(() => selectedArticleId = v),
                    )
                  else
                    DropdownMenu<String>(
                      width: 520,
                      enableFilter: true,
                      initialSelection: selectedVideoId,
                      label: const Text('Select video'),
                      dropdownMenuEntries: videos
                          .map((v) => DropdownMenuEntry<String>(value: v.id, label: v.title))
                          .toList(),
                      onSelected: (v) => setLocal(() => selectedVideoId = v),
                    ),
                  const SizedBox(height: 10),
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title override')),
                  const SizedBox(height: 10),
                  TextField(controller: subtitleCtrl, decoration: const InputDecoration(labelText: 'Subtitle override')),
                  const SizedBox(height: 10),
                  TextField(controller: badgeCtrl, decoration: const InputDecoration(labelText: 'Badge label (ARTICLE / VIDEO)')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          imageUrl == null || imageUrl!.isEmpty ? 'Banner image: not selected' : 'Banner image selected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          try {
                            final picked = await FilePicker.platform.pickFiles(
                              withData: true,
                              type: FileType.custom,
                              allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
                            );
                            if (picked == null || picked.files.isEmpty) return;
                            final f = picked.files.first;
                            final bytes = f.bytes;
                            if (bytes == null || bytes.isEmpty) return;
                            final uploaded = await ref
                                .read(exploreSuggestionsServiceProvider)
                                .uploadSuggestionImage(bytes: bytes, fileName: f.name);
                            setLocal(() => imageUrl = uploaded);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Banner image uploaded.')),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(userFacingErrorMessage(e))),
                            );
                          }
                        },
                        child: const Text('Upload image'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: imageUrl == null || imageUrl!.isEmpty
                            ? null
                            : () => setLocal(() => imageUrl = null),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (contentType == 'article' && (selectedArticleId == null || selectedArticleId!.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select an article.')),
                  );
                  return;
                }
                if (contentType == 'video' && (selectedVideoId == null || selectedVideoId!.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a video.')),
                  );
                  return;
                }
                final row = <String, dynamic>{
                  'content_type': contentType,
                  'article_id': contentType == 'article' ? selectedArticleId : null,
                  'video_id': contentType == 'video' ? selectedVideoId : null,
                  'title_override': titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
                  'subtitle_override': subtitleCtrl.text.trim().isEmpty ? null : subtitleCtrl.text.trim(),
                  'image_url': imageUrl == null || imageUrl!.trim().isEmpty ? null : imageUrl!.trim(),
                  'badge_label': badgeCtrl.text.trim().isEmpty ? null : badgeCtrl.text.trim(),
                  'is_active': active,
                };
                try {
                  if (existing == null) {
                    await ref.read(exploreSuggestionsServiceProvider).insertSuggestion(row);
                  } else {
                    await ref.read(exploreSuggestionsServiceProvider).updateSuggestion(existing.id, row);
                  }
                  if (context.mounted) Navigator.pop(ctx);
                  ref.invalidate(adminExploreSuggestionsProvider);
                  ref.invalidate(activeExploreSuggestionsProvider);
                  ref.read(exploreSuggestionsRevisionProvider.notifier).bump();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(userFacingErrorMessage(e))),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
