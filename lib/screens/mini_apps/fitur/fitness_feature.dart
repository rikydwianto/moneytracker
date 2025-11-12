import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart'; // centralized bootstrap handles init
import '../../../shared/firebase_bootstrap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'fitness_rtdb_service.dart';
import 'fitness_record_editor.dart';

class FitnessFeature extends StatefulWidget {
  final String heroTag;
  final Color color;
  const FitnessFeature({super.key, required this.heroTag, required this.color});

  @override
  State<FitnessFeature> createState() => _FitnessFeatureState();
}

class _FitnessFeatureState extends State<FitnessFeature> {
  bool _loading = true;
  String? _uid;

  String? _goalDesc;
  String _chartRange = 'weekly'; // daily | weekly | monthly | all
  String _chartMetric = 'weight'; // weight | height

  // Map of date (YYYY-MM-DD) to record { weight, height, timestamp }
  final SplayTreeMap<String, Map<String, dynamic>> _records =
      SplayTreeMap<String, Map<String, dynamic>>();

  Map<String, dynamic> _stats = {};
  StreamSubscription<DatabaseEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await FirebaseBootstrap.ensureAll();
      await FitnessRTDBService.ensureFitnessForCurrentUser(
        withSampleRecords: false,
      );
      var user = FirebaseAuth.instance.currentUser;
      user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
      _uid = user?.uid;
      final base = FirebaseDatabase.instance.ref(
        'users/$_uid/miniApps/kebugaran/fitness',
      );

      // Initial fetch
      final snap = await base.get();
      _readSnapshot(snap);

      // Listen for changes
      _sub = base.onValue.listen((event) {
        _readSnapshot(event.snapshot);
      });
    } catch (_) {
      // ignore; show what we have
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _readSnapshot(DataSnapshot snap) {
    if (!snap.exists) return;
    final m = (snap.value as Map?)?.cast<String, dynamic>() ?? {};
    final profile = (m['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    _goalDesc = (profile['goalDescription'] as String?) ?? '';

    _records.clear();
    final rec = (m['records'] as Map?)?.cast<String, dynamic>() ?? {};
    rec.forEach((k, v) {
      if (v is Map) {
        final vm = v.cast<String, dynamic>();
        _records[k] = vm;
      }
    });

    _stats = _computeStats();
    _saveStatsToRTDB(_stats);
    if (mounted) setState(() {});
  }

  // Compute dynamic stats based on current _records
  Map<String, dynamic> _computeStats() {
    DateTime? parseDate(String s) {
      try {
        final p = s.split('-').map(int.parse).toList();
        if (p.length != 3) return null;
        return DateTime(p[0], p[1], p[2]);
      } catch (_) {
        return null;
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 6));
    final monthAgo = today.subtract(const Duration(days: 29));

    double avg(Iterable<double> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

    final weightsAll = <double>[];
    final heightsAll = <double>[];

    final weightsDaily = <double>[];
    final heightsDaily = <double>[];

    final weightsWeekly = <double>[];
    final heightsWeekly = <double>[];

    final weightsMonthly = <double>[];
    final heightsMonthly = <double>[];

    _records.forEach((date, rec) {
      final w = (rec['weight'] as num?)?.toDouble();
      final h = (rec['height'] as num?)?.toDouble();
      if (w == null || h == null) return;
      weightsAll.add(w);
      heightsAll.add(h);

      final d = parseDate(date);
      if (d == null) return;
      if (d.year == today.year &&
          d.month == today.month &&
          d.day == today.day) {
        weightsDaily.add(w);
        heightsDaily.add(h);
      }
      if (!d.isBefore(weekAgo) && !d.isAfter(today)) {
        weightsWeekly.add(w);
        heightsWeekly.add(h);
      }
      if (!d.isBefore(monthAgo) && !d.isAfter(today)) {
        weightsMonthly.add(w);
        heightsMonthly.add(h);
      }
    });

    return {
      'daily': {
        'averageWeight': double.parse(avg(weightsDaily).toStringAsFixed(2)),
        'averageHeight': double.parse(avg(heightsDaily).toStringAsFixed(2)),
      },
      'weekly': {
        'averageWeight': double.parse(avg(weightsWeekly).toStringAsFixed(2)),
        'averageHeight': double.parse(avg(heightsWeekly).toStringAsFixed(2)),
      },
      'monthly': {
        'averageWeight': double.parse(avg(weightsMonthly).toStringAsFixed(2)),
        'averageHeight': double.parse(avg(heightsMonthly).toStringAsFixed(2)),
      },
      'allTime': {
        'minWeight': weightsAll.isEmpty
            ? 0
            : weightsAll.reduce((a, b) => a < b ? a : b),
        'maxWeight': weightsAll.isEmpty
            ? 0
            : weightsAll.reduce((a, b) => a > b ? a : b),
        'totalRecords': _records.length,
      },
    };
  }

  // Build spots for selected metric ('weight' or 'height') based on range
  List<FlSpot> _spotsForMetric(String metric) {
    DateTime? parseDate(String s) {
      try {
        final p = s.split('-').map(int.parse).toList();
        if (p.length != 3) return null;
        return DateTime(p[0], p[1], p[2]);
      } catch (_) {
        return null;
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 6));
    final monthAgo = today.subtract(const Duration(days: 29));

    final entries = _records.entries.where((e) {
      final d = parseDate(e.key);
      if (d == null) return false;
      switch (_chartRange) {
        case 'daily':
          return d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        case 'weekly':
          return !d.isBefore(weekAgo) && !d.isAfter(today);
        case 'monthly':
          return !d.isBefore(monthAgo) && !d.isAfter(today);
        case 'all':
        default:
          return true;
      }
    }).toList();

    if (entries.isEmpty) return const [];

    // Ensure chronological order (SplayTreeMap already sorted by key string), keep stable
    entries.sort((a, b) => a.key.compareTo(b.key));
    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      final v = (entries[i].value[metric] as num?)?.toDouble();
      if (v != null) {
        spots.add(FlSpot(i.toDouble(), v));
      }
    }
    return spots;
  }

  Widget _metricChart() {
    // Build filtered, sorted labels alongside spots for correct axis titles
    DateTime? parseDate(String s) {
      try {
        final p = s.split('-').map(int.parse).toList();
        if (p.length != 3) return null;
        return DateTime(p[0], p[1], p[2]);
      } catch (_) {
        return null;
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 6));
    final monthAgo = today.subtract(const Duration(days: 29));

    final filteredKeys = _records.keys.where((k) {
      final d = parseDate(k);
      if (d == null) return false;
      switch (_chartRange) {
        case 'daily':
          return d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        case 'weekly':
          return !d.isBefore(weekAgo) && !d.isAfter(today);
        case 'monthly':
          return !d.isBefore(monthAgo) && !d.isAfter(today);
        case 'all':
        default:
          return true;
      }
    }).toList()..sort();

    final spots = _spotsForMetric(_chartMetric);
    if (spots.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: const Text('Belum ada data untuk ditampilkan'),
      );
    }

    final minX = 0.0;
    final maxX = (spots.length - 1).toDouble();
    final weights = spots.map((s) => s.y).toList();
    double minY = weights.reduce((a, b) => a < b ? a : b);
    double maxY = weights.reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      // avoid flat axis
      minY -= 1;
      maxY += 1;
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY.floorToDouble(),
          maxY: maxY.ceilToDouble(),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: spots.length <= 6
                    ? 1
                    : (spots.length / 6).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= filteredKeys.length) {
                    return const SizedBox.shrink();
                  }
                  // Map index back to filtered date label
                  final label = filteredKeys[i];
                  final short = label.length >= 5
                      ? label.substring(5)
                      : label; // MM-DD
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(short, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: ((maxY - minY) / 4).clamp(1, 50).toDouble(),
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: _chartMetric == 'weight'
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color:
                    (_chartMetric == 'weight'
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.secondary)
                        .withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricToggle() {
    return Row(
      children: [
        ChoiceChip(
          label: const Text('BB'),
          selected: _chartMetric == 'weight',
          onSelected: (_) => setState(() => _chartMetric = 'weight'),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('TB'),
          selected: _chartMetric == 'height',
          onSelected: (_) => setState(() => _chartMetric = 'height'),
        ),
        const SizedBox(width: 12),
        Text(
          _chartMetric == 'weight' ? 'Berat badan (kg)' : 'Tinggi badan (cm)',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Future<void> _saveStatsToRTDB(Map<String, dynamic> s) async {
    if (_uid == null) return;
    final ref = FirebaseDatabase.instance.ref(
      'users/$_uid/miniApps/kebugaran/fitness/stats',
    );
    try {
      await ref.set(s);
    } catch (_) {}
  }

  Future<void> _openRecordEditor({String? dateKey}) async {
    if (_uid == null) return;
    final existing = dateKey != null ? _records[dateKey] : null;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FitnessRecordEditor(
          uid: _uid!,
          basePath: 'users/$_uid/miniApps/kebugaran/fitness',
          color: widget.color,
          initialDateKey: dateKey,
          initialWeight: (existing?['weight'] as num?)?.toDouble(),
          initialHeight: (existing?['height'] as num?)?.toDouble(),
          initialNote: existing?['note'] as String?,
        ),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tersimpan')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kebugaran'),
        actions: [
          IconButton(
            onPressed: () => _openRecordEditor(),
            icon: const Icon(Icons.add_chart_outlined),
            tooltip: 'Tambah Catatan',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // Modern header with gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color.withOpacity(0.85),
                        widget.color.withOpacity(0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kebugaran',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (_goalDesc ?? '').isEmpty
                            ? 'Pantau berat & tinggi harian'
                            : _goalDesc!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _headerStat(
                              'BB rata2 minggu ini',
                              (_stats['weekly']?['averageWeight'] ?? 0)
                                  .toString(),
                              'kg',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _headerStat(
                              'TB rata2 minggu ini',
                              (_stats['weekly']?['averageHeight'] ?? 0)
                                  .toString(),
                              'cm',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _headerStat(
                              'BB rata2 hari ini',
                              (_stats['daily']?['averageWeight'] ?? 0)
                                  .toString(),
                              'kg',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _headerStat(
                              'TB rata2 hari ini',
                              (_stats['daily']?['averageHeight'] ?? 0)
                                  .toString(),
                              'cm',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Range selector + stats pills condensed
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: _chartRange,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Harian')),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Mingguan'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Bulanan'),
                        ),
                        DropdownMenuItem(value: 'all', child: Text('Semua')),
                      ],
                      onChanged: (v) =>
                          setState(() => _chartRange = v ?? _chartRange),
                    ),
                    _statsPill(
                      'Harian',
                      _stats['daily'] as Map<String, dynamic>? ?? const {},
                    ),
                    _statsPill(
                      'Mingguan',
                      _stats['weekly'] as Map<String, dynamic>? ?? const {},
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statsPill(
                      'Bulanan',
                      _stats['monthly'] as Map<String, dynamic>? ?? const {},
                    ),
                    _statsPillAllTime(),
                  ],
                ),
                const SizedBox(height: 16),
                // Dynamic chart (BB/TB)
                _metricToggle(),
                const SizedBox(height: 8),
                _metricChart(),
                const SizedBox(height: 24),

                // Records list
                const Text(
                  'Catatan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ..._records.entries.map((e) {
                  final date = e.key;
                  final r = e.value;
                  final w = (r['weight'] as num?)?.toDouble();
                  final h = (r['height'] as num?)?.toDouble();
                  final note = r['note'] as String?;
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: widget.color.withOpacity(0.1),
                        child: const Icon(
                          Icons.monitor_weight,
                          color: Colors.blue,
                        ),
                      ),
                      title: Text(date),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${w?.toStringAsFixed(1) ?? '-'} kg • ${h?.toStringAsFixed(1) ?? '-'} cm',
                          ),
                          if (note != null && note.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                note,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_note_outlined),
                        onPressed: () => _openRecordEditor(dateKey: date),
                        tooltip: 'Edit catatan',
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  // Old widgets removed; replaced with header and pill variants

  Widget _headerStat(String title, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsPill(String title, Map<String, dynamic> m) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Text(
            'BB: ${(m['averageWeight'] ?? 0).toString()} kg',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(
            'TB: ${(m['averageHeight'] ?? 0).toString()} cm',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statsPillAllTime() {
    final m = _stats['allTime'] as Map<String, dynamic>? ?? const {};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        children: [
          const Text('All-time', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Text(
            'Min: ${(m['minWeight'] ?? 0).toString()}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(
            'Max: ${(m['maxWeight'] ?? 0).toString()}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(
            'Total: ${(m['totalRecords'] ?? 0).toString()}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
