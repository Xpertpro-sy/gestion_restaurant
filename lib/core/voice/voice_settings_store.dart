import '../database/database_helper.dart';

class VoiceSettingsStore {
  VoiceSettingsStore._();
  static final VoiceSettingsStore instance = VoiceSettingsStore._();

  static const tablePlaceholder = '{table}';

  static const defaultOrderTemplate =
      'Nouvelle commande enregistrée pour {table}, prise en charge requise.';
  static const defaultWaiterTemplate =
      'Appel serveur pour {table}, intervention requise.';

  static const _orderKey = 'voice_order_template';
  static const _waiterKey = 'voice_waiter_template';

  String orderTemplate = defaultOrderTemplate;
  String waiterTemplate = defaultWaiterTemplate;

  Future<void> load() async {
    try {
      final order = await DatabaseHelper.instance.getAppSetting(_orderKey);
      final waiter = await DatabaseHelper.instance.getAppSetting(_waiterKey);
      orderTemplate = order ?? defaultOrderTemplate;
      waiterTemplate = waiter ?? defaultWaiterTemplate;
    } catch (_) {
      orderTemplate = defaultOrderTemplate;
      waiterTemplate = defaultWaiterTemplate;
    }
  }

  Future<void> save({
    required String orderTemplate,
    required String waiterTemplate,
  }) async {
    this.orderTemplate = _normalize(orderTemplate, defaultOrderTemplate);
    this.waiterTemplate = _normalize(waiterTemplate, defaultWaiterTemplate);
    await DatabaseHelper.instance.setAppSetting(_orderKey, this.orderTemplate);
    await DatabaseHelper.instance.setAppSetting(_waiterKey, this.waiterTemplate);
  }

  Future<void> resetToDefaults() async {
    await save(
      orderTemplate: defaultOrderTemplate,
      waiterTemplate: defaultWaiterTemplate,
    );
  }

  String formatOrder(String tableLabel) =>
      _applyTable(orderTemplate, tableLabel);

  String formatWaiterCall(String tableLabel) =>
      _applyTable(waiterTemplate, tableLabel);

  String _normalize(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _applyTable(String template, String tableLabel) {
    if (template.contains(tablePlaceholder)) {
      return template.replaceAll(tablePlaceholder, tableLabel);
    }
    return template;
  }
}
