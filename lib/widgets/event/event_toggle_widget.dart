import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../services/event_service.dart';
import '../../services/notification_service.dart';

class EventToggleWidget extends StatefulWidget {
  final Event event;
  final Function()? onToggled;
  final bool showLabel;
  final bool compact;

  const EventToggleWidget({
    super.key,
    required this.event,
    this.onToggled,
    this.showLabel = true,
    this.compact = false,
  });

  @override
  State<EventToggleWidget> createState() => _EventToggleWidgetState();
}

class _EventToggleWidgetState extends State<EventToggleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleEvent() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    try {
      final eventService = EventService();
      final notificationService = NotificationService();

      if (widget.event.isActive) {
        // Deactivate current event
        await eventService.deactivateEvent(
          widget.event.userId,
          widget.event.id,
        );

        // Send notification
        await notificationService.createEventNotification(
          uid: widget.event.userId,
          eventName: widget.event.name,
          action: 'deactivated',
          eventId: widget.event.id,
        );
      } else {
        // Activate this event (will deactivate others automatically)
        await eventService.activateEvent(widget.event.userId, widget.event.id);

        // Send notification
        await notificationService.createEventNotification(
          uid: widget.event.userId,
          eventName: widget.event.name,
          action: 'activated',
          eventId: widget.event.id,
        );
      }

      if (widget.onToggled != null) {
        widget.onToggled!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.event.isActive
                  ? 'Acara "${widget.event.name}" dinonaktifkan'
                  : 'Acara "${widget.event.name}" diaktifkan',
            ),
            backgroundColor: widget.event.isActive
                ? Colors.orange
                : Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status acara: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactToggle();
    }
    return _buildFullToggle();
  }

  Widget _buildCompactToggle() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: InkWell(
            onTap: _isLoading ? null : _toggleEvent,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.event.isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.event.isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.event.isActive
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  else
                    Icon(
                      widget.event.isActive
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: widget.event.isActive
                          ? Colors.white
                          : Theme.of(context).colorScheme.outline,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    widget.event.isActive ? 'Aktif' : 'Tidak Aktif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: widget.event.isActive
                          ? Colors.white
                          : Theme.of(context).colorScheme.outline,
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

  Widget _buildFullToggle() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Card(
            elevation: 2,
            child: InkWell(
              onTap: _isLoading ? null : _toggleEvent,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Event Status Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.event.isActive
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1)
                            : Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: _isLoading
                          ? Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            )
                          : Icon(
                              widget.event.isActive
                                  ? Icons.event_available
                                  : Icons.event_busy,
                              color: widget.event.isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                              size: 24,
                            ),
                    ),

                    const SizedBox(width: 16),

                    // Event Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.showLabel)
                            Text(
                              'Acara Aktif',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                            ),
                          if (widget.showLabel) const SizedBox(height: 4),
                          Text(
                            widget.event.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.event.isActive
                                ? 'Transaksi baru akan terkait dengan acara ini'
                                : 'Klik untuk mengaktifkan acara ini',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                    ),

                    // Toggle Switch
                    Switch.adaptive(
                      value: widget.event.isActive,
                      onChanged: _isLoading ? null : (_) => _toggleEvent(),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
