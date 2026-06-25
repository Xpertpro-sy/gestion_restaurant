import 'package:intl/intl.dart';

const String currencyLabel = 'FCFA';

final NumberFormat _fcfaFormatter = NumberFormat('#,##0', 'fr_FR');

String formatFcfa(double amount) => '${_fcfaFormatter.format(amount.round())} $currencyLabel';

String formatFcfaCompact(double amount) => '${amount.round()} $currencyLabel';
