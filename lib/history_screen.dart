import 'package:material_ui/material_ui.dart';

import 'history_db.dart';

/// Maps a raw label from labels.txt to a display name with an emoji.
String friendlySignLabel(String label) {
  switch (label.toLowerCase().trim()) {
    case 'fist':
      return '✊ Fist';
    case 'pointing':
      return '👈 Pointing';
    case 'open_palm':
      return '✋ Open Palm';
    case 'peace':
      return '✌️ Peace';
    case 'thumbs_up':
      return '👍 Thumbs Up';
    case 'i_love_you':
      return '🤟 I Love You';
    case 'ok':
      return '👌 OK';
    default:
      return label;
  }
}

/// Plain text for text-to-speech (no emoji).
String spokenSignLabel(String label) {
  switch (label.toLowerCase().trim()) {
    case 'fist':
      return 'Fist';
    case 'pointing':
      return 'Pointing';
    case 'open_palm':
      return 'Open palm';
    case 'peace':
      return 'Peace';
    case 'thumbs_up':
      return 'Thumbs up';
    case 'i_love_you':
      return 'I love you';
    case 'ok':
      return 'Okay';
    default:
      return label.replaceAll('_', ' ');
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await HistoryDb.instance.all();
      if (!mounted) return;
      setState(() {
        _entries = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This deletes all saved recognitions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await HistoryDb.instance.clear();
      await _load();
    }
  }

  Future<bool> _confirmDelete(HistoryEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this item?'),
        content: Text(
          '${friendlySignLabel(entry.label)} — '
          '${_formatTime(entry.createdAt)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteEntry(HistoryEntry entry) async {
    final id = entry.id;
    if (id == null) return;
    await HistoryDb.instance.delete(id);
    await _load();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatTime(DateTime t) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final ampm = t.hour < 12 ? 'AM' : 'PM';
    return '${months[t.month - 1]} ${t.day}, ${t.year}  '
        '$hour12:${_two(t.minute)}:${_two(t.second)} $ampm';
  }

  /// Count of each sign, most frequent first.
  List<MapEntry<String, int>> _counts() {
    final map = <String, int>{};
    for (final e in _entries) {
      map[e.label] = (map[e.label] ?? 0) + 1;
    }
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load history.\n\n$_error',
              textAlign: TextAlign.center),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No history yet.\nRecognized signs will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final counts = _counts();

    return ListView.builder(
      itemCount: _entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _chartCard(counts);
        }

        final e = _entries[index - 1];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 1) const Divider(height: 1),
            Dismissible(
              key: ValueKey(e.id ?? index),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red.shade400,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) => _confirmDelete(e),
              onDismissed: (_) => _deleteEntry(e),
              child: ListTile(
                title: Text(
                  friendlySignLabel(e.label),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${_formatTime(e.createdAt)}  •  ${e.camera} camera',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(e.confidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red.shade400,
                      ),
                      onPressed: () async {
                        if (await _confirmDelete(e)) {
                          await _deleteEntry(e);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // CHARTS
  // ==========================================================================

  /// Detections per day for the last 7 days, oldest first.
  List<MapEntry<DateTime, int>> _lastSevenDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = <DateTime>[
      for (int i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    return [
      for (final d in days)
        MapEntry(
          d,
          _entries
              .where((e) =>
                  e.createdAt.year == d.year &&
                  e.createdAt.month == d.month &&
                  e.createdAt.day == d.day)
              .length,
        ),
    ];
  }

  Widget _chartCard(List<MapEntry<String, int>> counts) {
    final scheme = Theme.of(context).colorScheme;
    final maxCount = counts.isEmpty ? 1 : counts.first.value;
    final week = _lastSevenDays();
    final weekMax = week.fold<int>(1, (m, d) => d.value > m ? d.value : m);
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Signs detected  (${_entries.length} total)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final c in counts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 118,
                      child: Text(
                        friendlySignLabel(c.key),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: c.value / maxCount,
                          minHeight: 14,
                          color: scheme.primary,
                          backgroundColor: scheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${c.value}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            const Text(
              'Last 7 days',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in week)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            d.value == 0 ? '' : '${d.value}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 22,
                            height: d.value == 0 ? 3 : 80 * d.value / weekMax,
                            decoration: BoxDecoration(
                              color: d.value == 0
                                  ? scheme.primary.withValues(alpha: 0.2)
                                  : scheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            weekdays[d.key.weekday - 1],
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
