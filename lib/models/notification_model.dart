import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  final String id;
  final String title;
  final String message;
  final String
  type; // 'debt_reminder', 'budget_warning', 'transaction_added', 'test', etc.
  final bool isRead;
  final String? relatedId; // ID of related object (transaction, debt, etc.)
  final Map<String, dynamic>? data; // Additional data
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.relatedId,
    this.data,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return NotificationModel(
      id: id,
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      type: map['type']?.toString() ?? 'unknown',
      isRead: map['isRead'] == true,
      relatedId: map['relatedId']?.toString(),
      data: map['data'] != null ? Map<String, dynamic>.from(map['data']) : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'relatedId': relatedId,
      'data': data,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  NotificationModel copyWith({
    String? title,
    String? message,
    String? type,
    bool? isRead,
    String? relatedId,
    Map<String, dynamic>? data,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId ?? this.relatedId,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Get icon based on notification type
  String get iconEmoji {
    switch (type) {
      case 'debt_reminder':
        return '💰';
      case 'budget_warning':
        return '⚠️';
      case 'transaction_added':
        return '💳';
      case 'test':
        return '🎉';
      case 'auto_reminder':
        return '🔔';
      default:
        return '📱';
    }
  }

  // Get color based on notification type
  String get colorHex {
    switch (type) {
      case 'debt_reminder':
        return '#FF5722'; // Orange-red
      case 'budget_warning':
        return '#FFC107'; // Amber
      case 'transaction_added':
        return '#4CAF50'; // Green
      case 'test':
        return '#2196F3'; // Blue
      case 'auto_reminder':
        return '#9C27B0'; // Purple
      default:
        return '#757575'; // Grey
    }
  }

  @override
  List<Object?> get props => [
    id,
    title,
    message,
    type,
    isRead,
    relatedId,
    data,
    createdAt,
  ];
}
