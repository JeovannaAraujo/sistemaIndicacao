import 'package:flutter_test/flutter_test.dart';

bool verificaDisponibilidade(List<Map<String, DateTime>> agendamentos, DateTime inicio, DateTime fim) {
  for (final a in agendamentos) {
    if (inicio.isBefore(a['fim']!) && fim.isAfter(a['inicio']!)) {
      return false; // conflito
    }
  }
  return true;
}

void main() {
  group('📅 Disponibilidade de agenda', () {
    test('1️⃣ Sem conflito de horários', () {
      final agendamentos = [
        {'inicio': DateTime(2025, 10, 10, 8), 'fim': DateTime(2025, 10, 10, 10)},
      ];
      final disponivel = verificaDisponibilidade(agendamentos, DateTime(2025, 10, 10, 10, 30), DateTime(2025, 10, 10, 12));
      expect(disponivel, true);
    });

    test('2️⃣ Com conflito de horários', () {
      final agendamentos = [
        {'inicio': DateTime(2025, 10, 10, 8), 'fim': DateTime(2025, 10, 10, 10)},
      ];
      final disponivel = verificaDisponibilidade(agendamentos, DateTime(2025, 10, 10, 9), DateTime(2025, 10, 10, 11));
      expect(disponivel, false);
    });
  });
}
