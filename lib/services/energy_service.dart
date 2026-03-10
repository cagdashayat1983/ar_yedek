import 'package:shared_preferences/shared_preferences.dart';

class EnergyService {
  static const String _energyKey = 'user_energy_count';
  static const int maxEnergy = 3;

  // Mevcut enerjiyi getir, yoksa 3 yap
  static Future<int> getEnergy() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_energyKey)) {
      await prefs.setInt(_energyKey, maxEnergy);
      return maxEnergy;
    }
    return prefs.getInt(_energyKey) ?? maxEnergy;
  }

  // 1 Enerji harca
  static Future<void> consumeEnergy() async {
    final prefs = await SharedPreferences.getInstance();
    int current = await getEnergy();
    if (current > 0) {
      await prefs.setInt(_energyKey, current - 1);
    }
  }

  // Ödül olarak Enerji ver
  static Future<void> rewardEnergy([int amount = 3]) async {
    final prefs = await SharedPreferences.getInstance();
    int current = await getEnergy();
    int newEnergy = current + amount;
    if (newEnergy > maxEnergy) newEnergy = maxEnergy; // Maksimumu geçmesin
    await prefs.setInt(_energyKey, newEnergy);
  }
}
