// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 1;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionModel(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: fields[2] as double,
      type: fields[3] as TransactionType,
      categoryId: fields[4] as String,
      walletId: fields[5] as String,
      toWalletId: fields[6] as String?,
      date: fields[7] as DateTime,
      notes: fields[8] as String?,
      photoUrl: fields[9] as String?,
      userId: fields[10] as String,
      createdAt: fields[11] as DateTime,
      updatedAt: fields[12] as DateTime,
      isSynced: fields[13] as bool,
      counterpartyName: fields[14] as String?,
      debtDirection: fields[15] as String?,
      eventId: fields[16] as String?,
      dueDate: fields[17] as DateTime?,
      paidAmount: fields[18] as double?,
      withPerson: fields[19] as String?,
      location: fields[20] as String?,
      reminderAt: fields[21] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.categoryId)
      ..writeByte(5)
      ..write(obj.walletId)
      ..writeByte(6)
      ..write(obj.toWalletId)
      ..writeByte(7)
      ..write(obj.date)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.photoUrl)
      ..writeByte(10)
      ..write(obj.userId)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.isSynced)
      ..writeByte(14)
      ..write(obj.counterpartyName)
      ..writeByte(15)
      ..write(obj.debtDirection)
      ..writeByte(16)
      ..write(obj.eventId)
      ..writeByte(17)
      ..write(obj.dueDate)
      ..writeByte(18)
      ..write(obj.paidAmount)
      ..writeByte(19)
      ..write(obj.withPerson)
      ..writeByte(20)
      ..write(obj.location)
      ..writeByte(21)
      ..write(obj.reminderAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
