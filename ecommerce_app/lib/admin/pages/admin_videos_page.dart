import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/features/videos/models/storefront_video.dart';
import 'package:ecommerce_app/features/videos/providers/videos_providers.dart';
import 'package:ecommerce_app/features/videos/utils/youtube_url_parser.dart';
import 'package:ecommerce_app/presentation/utils/user_facing_error_message.dart';

import '../widgets/admin_cached_image.dart';

class AdminVideosPage extends ConsumerWidget {
  const AdminVideosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminVideosListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'YouTube URLs only — videos stream from YouTube; nothing is uploaded to storage.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openEditor(context, ref, null),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add video'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No videos yet.'))
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final v = rows[i];
                        final thumb = v.effectiveThumbnailUrl;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: thumb != null
                                      ? AdminCachedImage(
                                          imageUrl: thumb,
                                          width: 120,
                                          height: 68,
                                          borderRadius: BorderRadius.circular(8),
                                        )
                                      : Container(
                                          width: 120,
                                          height: 68,
                                          color: Colors.grey.shade300,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.play_circle_outline),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        v.isActive ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          color: v.isActive ? AppColors.forestGreen : AppColors.warmGray,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (v.category != null && v.category!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Category: ${v.category}',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        v.youtubeUrl,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.warmGray,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _openEditor(context, ref, v),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _confirmDelete(context, ref, v),
                                    ),
                                  ],
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

  static Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    StorefrontVideo? existing,
  ) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final urlCtrl = TextEditingController(text: existing?.youtubeUrl ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    var active = existing?.isActive ?? true;
    String? urlError;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(existing == null ? 'Add video' : 'Edit video'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlCtrl,
                      decoration: InputDecoration(
                        labelText: 'YouTube URL',
                        border: const OutlineInputBorder(),
                        errorText: urlError,
                      ),
                      onChanged: (_) {
                        if (urlError != null) setLocal(() => urlError = null);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: catCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Category (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active (visible in app)'),
                      value: active,
                      onChanged: (v) => setLocal(() => active = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final url = urlCtrl.text.trim();
                    if (!isValidYoutubeUrl(url)) {
                      setLocal(() => urlError = 'Enter a valid YouTube watch or youtu.be link.');
                      return;
                    }
                    if (titleCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Title is required.')),
                      );
                      return;
                    }
                    final svc = ref.read(videosSupabaseServiceProvider);
                    try {
                      if (existing == null) {
                        await svc.insertVideo(
                          title: titleCtrl.text,
                          youtubeUrl: url,
                          description: descCtrl.text,
                          category: catCtrl.text,
                          isActive: active,
                        );
                      } else {
                        await svc.updateVideo(
                          id: existing.id,
                          title: titleCtrl.text,
                          youtubeUrl: url,
                          description: descCtrl.text,
                          category: catCtrl.text,
                          isActive: active,
                        );
                      }
                      if (context.mounted) Navigator.pop(ctx);
                      ref.invalidate(adminVideosListProvider);
                      ref.read(videosStorefrontRevisionProvider.notifier).bump();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(userFacingErrorMessage(e))),
                        );
                      }
                    }
                  },
                  child: Text(existing == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    urlCtrl.dispose();
    descCtrl.dispose();
    catCtrl.dispose();
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    StorefrontVideo v,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete video?'),
        content: Text('Remove "${v.title}" from the catalog?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final svc = ref.read(videosSupabaseServiceProvider);
    try {
      await svc.deleteVideo(v.id);
      ref.invalidate(adminVideosListProvider);
      ref.read(videosStorefrontRevisionProvider.notifier).bump();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingErrorMessage(e))),
        );
      }
    }
  }
}
