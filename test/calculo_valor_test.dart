import 'package:flutter_test/flutter_test.dart';

double calcularEstimativa(double valorMedio, double quantidade) {
  return valorMedio * quantidade;
}

void main() {
  group('💰 Cálculo de estimativas', () {
    test('1️⃣ Cálculo simples de orçamento', () {
      final estimativa = calcularEstimativa(50.0, 3.0);
      expect(estimativa, 150.0);
    });

    test('2️⃣ Valor zero retorna zero', () {
      final estimativa = calcularEstimativa(0, 10);
      expect(estimativa, 0);
    });

    test('3️⃣ Quantidade negativa deve retornar negativo', () {
      final estimativa = calcularEstimativa(100, -2);
      expect(estimativa, -200);
    });
  });
}
