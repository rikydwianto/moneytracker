import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../models/transaction.dart';
import '../../services/transaction_service.dart';
import '../../utils/date_helpers.dart';
import '../../utils/idr.dart';
import 'debt_detail_screen.dart';

class DebtPage extends StatefulWidget {
  const DebtPage({super.key});

  @override
  State<DebtPage> createState() => _DebtPageState();
}

class _DebtPageState extends State<DebtPage> with TickerProviderStateMixin {
  String _filter = 'semua';
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _sort = 'date_desc';

  late final AnimationController _summaryAnimCtrl;
  late final AnimationController _listAnimCtrl;
  late final AnimationController _fabAnimCtrl;

  final List<Color> _gradientColors = [
    const Color(0xFF6366F1),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    _summaryAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _listAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _summaryAnimCtrl.forward();
    _listAnimCtrl.forward();
    _fabAnimCtrl.forward();

    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _search = _searchCtrl.text.trim());
    });
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 600));
  }

  Future<void> _openAddDebt() async {
    HapticFeedback.mediumImpact();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      _showSnackBar(
        'Silakan login terlebih dahulu',
        Icons.warning_amber_rounded,
      );
      return;
    }
    final result = await Navigator.pushNamed(context, '/add-debt');
    if (result == true && mounted) {
      setState(() {});
      _showSnackBar('Catatan berhasil ditambahkan! 🎉', Icons.check_circle);
    }
  }

  void _showSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.black87,
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _summaryAnimCtrl.dispose();
    _listAnimCtrl.dispose();
    _fabAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _markAsPaid(TransactionModel transaction) async {
    HapticFeedback.mediumImpact();
    try {
      // TODO: await TransactionService().markPaid(transaction.id);
      if (!mounted) return;
      _showSnackBar('Ditandai sebagai dibayar! ✓', Icons.check_circle);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Gagal menandai: $e', Icons.error_outline);
    }
  }

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    HapticFeedback.heavyImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red.shade400),
            ),
            const SizedBox(width: 12),
            const Text('Hapus Catatan?'),
          ],
        ),
        content: const Text(
          'Tindakan ini tidak dapat dibatalkan. Yakin ingin menghapus catatan ini?',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        // TODO: await TransactionService().delete(transaction.id);
        if (!mounted) return;
        _showSnackBar('Catatan berhasil dihapus', Icons.check_circle);
        setState(() {});
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('Gagal menghapus: $e', Icons.error_outline);
      }
    }
  }

  Widget _buildGlassmorphicSummary(double totalHutang, double totalPiutang) {
    final selisih = totalPiutang - totalHutang;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _summaryAnimCtrl,
              curve: Curves.easeOutCubic,
            ),
          ),
      child: FadeTransition(
        opacity: _summaryAnimCtrl,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                _gradientColors[0].withOpacity(0.8),
                _gradientColors[1].withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _gradientColors[0].withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Animated background pattern
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CirclePatternPainter(animation: _summaryAnimCtrl),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ringkasan Keuangan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selisih >= 0
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  IdrFormatters.format(selisih.abs()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Amounts
                      Row(
                        children: [
                          Expanded(
                            child: _buildAmountCard(
                              'Hutang',
                              totalHutang,
                              Icons.arrow_upward_rounded,
                              Colors.red.shade300,
                              0.1,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildAmountCard(
                              'Piutang',
                              totalPiutang,
                              Icons.arrow_downward_rounded,
                              Colors.green.shade300,
                              0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Mini chart
                      _buildMiniChart(totalHutang, totalPiutang),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCard(
    String label,
    double amount,
    IconData icon,
    Color color,
    double delay,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 800 + (delay * 1000).toInt()),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    IdrFormatters.format(amount * value),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniChart(double hutang, double piutang) {
    final total = hutang + piutang;
    final hutangPercent = total > 0 ? hutang / total : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: (hutangPercent * 100 * value).toInt(),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.red.shade300,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: ((1 - hutangPercent) * 100 * value).toInt(),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.green.shade300,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(hutangPercent * 100 * value).toStringAsFixed(0)}% Hutang',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${((1 - hutangPercent) * 100 * value).toStringAsFixed(0)}% Piutang',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildModernEmptyState() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated illustration
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              _gradientColors[0].withOpacity(0.1),
                              _gradientColors[1].withOpacity(0.1),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              _gradientColors[0].withOpacity(0.2),
                              _gradientColors[1].withOpacity(0.2),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          size: 50,
                          color: _gradientColors[0],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _filter == 'hutang'
                        ? 'Belum Ada Hutang'
                        : _filter == 'piutang'
                        ? 'Belum Ada Piutang'
                        : 'Belum Ada Catatan',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'Mulai catat hutang atau piutang Anda untuk mengelola keuangan dengan lebih baik',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _openAddDebt,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Tambah Catatan'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      backgroundColor: _gradientColors[0],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDebtTile(TransactionModel t, int index) {
    final isHutang = t.categoryId == 'loan_received';
    final due = t.dueDate;
    String? dueLabel;
    Color? dueColor;

    if (due != null) {
      final now = DateTime.now();
      final onlyDate = DateTime(due.year, due.month, due.day);
      final today = DateTime(now.year, now.month, now.day);
      final diff = onlyDate.difference(today).inDays;

      if (diff < 0) {
        dueLabel = 'Terlambat ${diff.abs()}h';
        dueColor = Colors.red;
      } else if (diff == 0) {
        dueLabel = 'Hari ini';
        dueColor = Colors.orange;
      } else if (diff <= 7) {
        dueLabel = '$diff hari lagi';
        dueColor = Colors.orange.shade700;
      } else {
        dueLabel = DateHelpers.dateOnly.format(due);
        dueColor = Colors.blueGrey;
      }
    }

    final paid = (t.paidAmount ?? 0).clamp(0, t.amount);
    final progress = t.amount == 0 ? 0.0 : (paid / t.amount).clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Slidable(
                key: ValueKey(t.id ?? t.hashCode),
                endActionPane: ActionPane(
                  motion: const StretchMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (_) => _deleteTransaction(t),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete_rounded,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ],
                ),
                startActionPane: ActionPane(
                  motion: const StretchMotion(),
                  extentRatio: 0.5,
                  children: [
                    SlidableAction(
                      onPressed: (_) => _markAsPaid(t),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      icon: Icons.check_rounded,
                      label: 'Bayar',
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16),
                      ),
                    ),
                    SlidableAction(
                      onPressed: (_) {
                        Navigator.pushNamed(
                          context,
                          '/edit-debt',
                          arguments: t,
                        ).then((_) => setState(() {}));
                      },
                      backgroundColor: _gradientColors[0],
                      foregroundColor: Colors.white,
                      icon: Icons.edit_rounded,
                      label: 'Edit',
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(16),
                      ),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DebtDetailScreen(debt: t),
                        ),
                      ).then((_) => setState(() {}));
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isHutang
                                        ? [
                                            Colors.red.shade300,
                                            Colors.red.shade400,
                                          ]
                                        : [
                                            Colors.green.shade300,
                                            Colors.green.shade400,
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (isHutang ? Colors.red : Colors.green)
                                              .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isHutang
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.counterpartyName ?? 'Tanpa Nama',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateHelpers.dateOnly.format(t.date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                IdrFormatters.format(t.amount),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isHutang
                                      ? Colors.red.shade600
                                      : Colors.green.shade600,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          if (due != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: dueColor?.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      dueColor?.withOpacity(0.3) ?? Colors.grey,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: dueColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    dueLabel ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: dueColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (paid > 0 && paid < t.amount) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: progress),
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation(
                                      isHutang
                                          ? Colors.red.shade400
                                          : Colors.green.shade400,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Terbayar ${(progress * 100).toStringAsFixed(0)}% • Sisa ${IdrFormatters.format(t.amount - paid)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showActionSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildActionItem(
                Icons.add_rounded,
                'Tambah Catatan',
                'Catat hutang atau piutang baru',
                _gradientColors[0],
                () {
                  Navigator.pop(context);
                  _openAddDebt();
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: true,
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabAnimCtrl, curve: Curves.easeOutBack),
        child: FloatingActionButton.extended(
          onPressed: _showActionSheet,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tambah'),
          backgroundColor: _gradientColors[0],
          elevation: 4,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: _gradientColors[0],
        child: user == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Silakan login terlebih dahulu',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Filter Tabs
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'semua', label: Text('Semua')),
                            ButtonSegment(
                              value: 'hutang',
                              label: Text('Hutang'),
                              icon: Icon(Icons.arrow_upward_rounded, size: 16),
                            ),
                            ButtonSegment(
                              value: 'piutang',
                              label: Text('Piutang'),
                              icon: Icon(
                                Icons.arrow_downward_rounded,
                                size: 16,
                              ),
                            ),
                          ],
                          selected: {_filter},
                          onSelectionChanged: (Set<String> selected) {
                            HapticFeedback.selectionClick();
                            setState(() => _filter = selected.first);
                          },
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(MaterialState.selected)) {
                                return _gradientColors[0];
                              }
                              return Colors.transparent;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau catatan...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                },
                              )
                            : PopupMenuButton<String>(
                                icon: const Icon(Icons.sort_rounded),
                                onSelected: (v) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _sort = v);
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'date_desc',
                                    child: Text('Terbaru'),
                                  ),
                                  PopupMenuItem(
                                    value: 'amount_desc',
                                    child: Text('Nominal Terbesar'),
                                  ),
                                  PopupMenuItem(
                                    value: 'due_asc',
                                    child: Text('Jatuh Tempo'),
                                  ),
                                ],
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: _gradientColors[0]),
                        ),
                      ),
                    ),
                  ),
                  // List
                  Expanded(
                    child: StreamBuilder<List<TransactionModel>>(
                      stream: TransactionService().streamTransactions(user.uid),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        var debtList = snapshot.data!
                            .where(
                              (t) =>
                                  t.categoryId == 'loan_received' ||
                                  t.categoryId == 'loan_given',
                            )
                            .toList();

                        if (_filter == 'hutang') {
                          debtList = debtList
                              .where((t) => t.categoryId == 'loan_received')
                              .toList();
                        } else if (_filter == 'piutang') {
                          debtList = debtList
                              .where((t) => t.categoryId == 'loan_given')
                              .toList();
                        }

                        if (_search.isNotEmpty) {
                          final q = _search.toLowerCase();
                          debtList = debtList.where((t) {
                            final name = (t.counterpartyName ?? '')
                                .toLowerCase();
                            final title = t.title.toLowerCase();
                            return name.contains(q) || title.contains(q);
                          }).toList();
                        }

                        debtList.sort((a, b) {
                          switch (_sort) {
                            case 'amount_desc':
                              return b.amount.compareTo(a.amount);
                            case 'due_asc':
                              final ad = a.dueDate;
                              final bd = b.dueDate;
                              if (ad == null && bd == null) return 0;
                              if (ad == null) return 1;
                              if (bd == null) return -1;
                              return ad.compareTo(bd);
                            default:
                              return b.date.compareTo(a.date);
                          }
                        });

                        if (debtList.isEmpty) {
                          return _buildModernEmptyState();
                        }

                        double totalHutang = 0;
                        double totalPiutang = 0;
                        for (final t in debtList) {
                          if (t.categoryId == 'loan_received') {
                            totalHutang += t.amount;
                          } else if (t.categoryId == 'loan_given') {
                            totalPiutang += t.amount;
                          }
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: debtList.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _buildGlassmorphicSummary(
                                totalHutang,
                                totalPiutang,
                              );
                            }
                            return _buildDebtTile(
                              debtList[index - 1],
                              index - 1,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Custom painter untuk background pattern
class _CirclePatternPainter extends CustomPainter {
  final Animation<double> animation;

  _CirclePatternPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final progress = animation.value;

    for (var i = 0; i < 3; i++) {
      final radius = (size.width * 0.3 * (i + 1) * progress);
      canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.3),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CirclePatternPainter oldDelegate) => true;
}
