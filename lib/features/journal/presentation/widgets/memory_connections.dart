import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../gallery/data/services/gallery_service.dart';
import '../../../gallery/domain/models/memory_photo.dart';
import '../../../gallery/presentation/screens/photo_viewer_screen.dart';
import '../../../gallery/presentation/widgets/add_photo_dialog.dart';
import '../../data/models/journal_entry.dart';
import '../../../bucket_list/data/models/bucket_item.dart';
import '../../../bucket_list/data/services/bucket_list_service.dart';
import '../../../bucket_list/presentation/widgets/bucket_item_card.dart';
import '../../../calendar/domain/models/calendar_event.dart';
import '../../../calendar/data/services/calendar_service.dart';
import '../../../calendar/presentation/widgets/day_detail_sheet.dart';
import '../../data/services/journal_service.dart';

class MemoryConnections extends StatefulWidget {
  final JournalEntry entry;
  const MemoryConnections({super.key, required this.entry});

  @override
  State<MemoryConnections> createState() => _MemoryConnectionsState();
}

class _MemoryConnectionsState extends State<MemoryConnections> {
  late final _entryStream = JournalService().watchEntry(widget.entry);
  final _words = TextEditingController();
  bool _saving = false;
  String? _error;
  String? _notice;
  String? _loadedFor;
  String? _lastWords;

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
      if (mounted) setState(() => _notice = "Saved to this memory.");
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save this part of your memory. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _choosePhotos(JournalEntry entry) async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.velvet,
      builder: (_) => _MemoryPhotoPicker(selected: entry.photoIds),
    );
    if (selected == null) return;
    await _run(() => JournalService().setMemoryPhotos(entry.id, selected));
  }

  @override
  Widget build(BuildContext context) {
    final username = context.watch<AuthService?>()?.currentUser;
    if (username == null || !{'khentsgdz', 'clairjassen'}.contains(username)) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<JournalEntry?>(
      stream: _entryStream,
      initialData: widget.entry,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active &&
            snapshot.data == null &&
            !snapshot.hasError) {
          return const Text('This memory was removed from Journal.');
        }
        final entry = snapshot.data ?? widget.entry;
        final incomingWords = entry.perspectives[username] ?? '';
        if (_loadedFor != username ||
            (_words.text == (_lastWords ?? '') &&
                incomingWords != _lastWords)) {
          _loadedFor = username;
          _words.text = incomingWords;
          _lastWords = incomingWords;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Our memory', style: Theme.of(context).textTheme.titleLarge),
            if (entry.bucketItemId != null)
              StreamBuilder<BucketItem?>(
                stream: BucketListService().watchItem(entry.bucketItemId!),
                builder: (context, source) {
                  if (source.hasError) {
                    return const Text('Could not load the original wish.');
                  }
                  final wish = source.data;
                  if (wish == null) {
                    return const Text(
                      'The original wish is no longer available.',
                    );
                  }
                  return TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.roseQuartz,
                    ),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text('Original wish: ${wish.title}'),
                    onPressed: () =>
                        showBucketItemDetail(context, wish, username),
                  );
                },
              ),
            if (entry.calendarEventId != null)
              StreamBuilder<CalendarEvent?>(
                stream: CalendarService().watchEvent(entry.calendarEventId!),
                builder: (context, source) {
                  if (source.hasError) {
                    return const Text('Could not load the calendar plan.');
                  }
                  final event = source.data;
                  if (event == null) {
                    return const Text(
                      'The calendar plan is no longer available.',
                    );
                  }
                  return TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.roseQuartz,
                    ),
                    icon: const Icon(Icons.event_outlined),
                    label: Text('Calendar plan: ${event.title}'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppColors.velvet,
                      builder: (_) =>
                          DayDetailSheet(day: event.date, onEventAdded: () {}),
                    ),
                  );
                },
              ),
            if (snapshot.hasError)
              const Text(
                'Could not refresh this memory. Close and reopen to retry.',
              ),
            const SizedBox(height: 12),
            if (entry.photoIds.isNotEmpty)
              StreamBuilder<List<MemoryPhoto>>(
                stream: GalleryService().watchPhotosByIds(entry.photoIds),
                builder: (context, photosSnapshot) {
                  if (photosSnapshot.hasError) {
                    return const Text(
                      'Photos could not load. Close and reopen to retry.',
                    );
                  }
                  final photos = photosSnapshot.data;
                  if (photos == null) return const LinearProgressIndicator();
                  if (photos.isEmpty) {
                    return const Text(
                      'The linked photos are no longer in the gallery.',
                    );
                  }
                  return SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => Semantics(
                        button: true,
                        label: 'Open memory photo ${index + 1}',
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PhotoViewerScreen(
                                photos: photos,
                                initialIndex: index,
                              ),
                            ),
                          ),
                          child: SizedBox(
                            width: 112,
                            child: AppNetworkImage(
                              imageUrl: GalleryService.displayUrl(
                                photos[index].previewUrl,
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.roseQuartz,
                  ),
                  onPressed: _saving ? null : () => _choosePhotos(entry),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose gallery photos'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.roseQuartz,
                  ),
                  onPressed: _saving || entry.photoIds.length >= 20
                      ? null
                      : () async {
                          final photo = await showDialog<MemoryPhoto>(
                            context: context,
                            builder: (_) => const AddPhotoDialog(),
                          );
                          if (photo != null) {
                            await _run(
                              () => JournalService().addMemoryPhoto(
                                entry.id,
                                photo.id,
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Upload a photo'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final person in ['khentsgdz', 'clairjassen']) ...[
              Text(
                person == 'khentsgdz'
                    ? 'Khent’s favorite part'
                    : 'Clair’s favorite part',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              if (person == username) ...[
                TextField(
                  controller: _words,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    hintText: 'What do you want to remember?',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.roseQuartz,
                  ),
                  onPressed: _saving
                      ? null
                      : () => _run(
                          () => JournalService().savePerspective(
                            entry.id,
                            username,
                            _words.text,
                          ),
                        ),
                  child: Text(_saving ? 'Saving...' : 'Save my words'),
                ),
              ] else
                Text(
                  entry.perspectives[person]?.isNotEmpty == true
                      ? entry.perspectives[person]!
                      : 'A little space for their side of the story.',
                ),
              const SizedBox(height: 16),
            ],
            if (_notice != null)
              Text(
                _notice!,
                style: const TextStyle(color: AppColors.roseQuartz),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
        );
      },
    );
  }
}

class _MemoryPhotoPicker extends StatefulWidget {
  final List<String> selected;
  const _MemoryPhotoPicker({required this.selected});
  @override
  State<_MemoryPhotoPicker> createState() => _MemoryPhotoPickerState();
}

class _MemoryPhotoPickerState extends State<_MemoryPhotoPicker> {
  late final _selected = widget.selected.toSet();
  late final _photos = GalleryService().getPhotosStream(limit: 100);
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(child: Text('Recent gallery photos · up to 20')),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.roseQuartz,
                  ),
                  onPressed: () => Navigator.pop(context, _selected.toList()),
                  child: const Text('Save photos'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MemoryPhoto>>(
              stream: _photos,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load photos. Close and try again.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Upload a photo to Gallery first, or use Upload a photo.',
                    ),
                  );
                }
                return ListView(
                  children: [
                    for (final photo in snapshot.data!)
                      CheckboxListTile(
                        value: _selected.contains(photo.id),
                        title: Text(
                          photo.caption.isEmpty
                              ? 'A photo together'
                              : photo.caption,
                        ),
                        secondary: SizedBox(
                          width: 48,
                          height: 48,
                          child: AppNetworkImage(
                            imageUrl: GalleryService.displayUrl(
                              photo.previewUrl,
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        onChanged:
                            !_selected.contains(photo.id) &&
                                _selected.length >= 20
                            ? null
                            : (checked) => setState(() {
                                if (checked == true) {
                                  _selected.add(photo.id);
                                } else {
                                  _selected.remove(photo.id);
                                }
                              }),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
