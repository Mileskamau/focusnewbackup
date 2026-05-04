// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DashboardDataAdapter extends TypeAdapter<DashboardData> {
  @override
  final int typeId = 4;

  @override
  DashboardData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DashboardData(
      fSessionId: fields[0] as String,
      username: fields[1] as String,
      role: fields[2] as String,
      name: fields[3] as String,
      pendingApprovals: fields[4] as int,
      lowStockItems: fields[5] as int,
      pendingOrders: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DashboardData obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.fSessionId)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.role)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.pendingApprovals)
      ..writeByte(5)
      ..write(obj.lowStockItems)
      ..writeByte(6)
      ..write(obj.pendingOrders);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SalesDataAdapter extends TypeAdapter<SalesData> {
  @override
  final int typeId = 5;

  @override
  SalesData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SalesData(
      voucherNo: fields[0] as String,
      date: fields[1] as DateTime,
      customerCode: fields[2] as String,
      customerName: fields[3] as String,
      cashierCode: fields[4] as String,
      cashierName: fields[5] as String,
      totalAmount: fields[6] as double,
      taxAmount: fields[7] as double,
      netAmount: fields[8] as double,
      paymentMethod: fields[9] as String,
      status: fields[10] as String,
      items: (fields[11] as List).cast<SalesItem>(),
    );
  }

  @override
  void write(BinaryWriter writer, SalesData obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.voucherNo)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.customerCode)
      ..writeByte(3)
      ..write(obj.customerName)
      ..writeByte(4)
      ..write(obj.cashierCode)
      ..writeByte(5)
      ..write(obj.cashierName)
      ..writeByte(6)
      ..write(obj.totalAmount)
      ..writeByte(7)
      ..write(obj.taxAmount)
      ..writeByte(8)
      ..write(obj.netAmount)
      ..writeByte(9)
      ..write(obj.paymentMethod)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.items);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SalesItemAdapter extends TypeAdapter<SalesItem> {
  @override
  final int typeId = 6;

  @override
  SalesItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SalesItem(
      itemCode: fields[0] as String,
      itemName: fields[1] as String,
      qty: fields[2] as double,
      rate: fields[3] as double,
      amount: fields[4] as double,
      taxAmount: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SalesItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.itemCode)
      ..writeByte(1)
      ..write(obj.itemName)
      ..writeByte(2)
      ..write(obj.qty)
      ..writeByte(3)
      ..write(obj.rate)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.taxAmount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SupplierAdapter extends TypeAdapter<Supplier> {
  @override
  final int typeId = 7;

  @override
  Supplier read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Supplier(
      code: fields[0] as String,
      name: fields[1] as String,
      address: fields[2] as String,
      phone: fields[3] as String,
      email: fields[4] as String,
      gstin: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Supplier obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.code)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.email)
      ..writeByte(5)
      ..write(obj.gstin);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AccountAdapter extends TypeAdapter<Account> {
  @override
  final int typeId = 8;

  @override
  Account read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Account(
      code: fields[0] as String,
      name: fields[1] as String,
      accountType: fields[2] as String,
      phone: fields[3] as String,
      email: fields[4] as String,
      address: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Account obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.code)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.accountType)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.email)
      ..writeByte(5)
      ..write(obj.address);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
