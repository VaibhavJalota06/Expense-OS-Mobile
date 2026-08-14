import 'dart:math';

class ProjectionResult {
  final double monthlySavings;
  final double returnRate; // e.g. 0.09 for 9%
  final double year1Value;
  final double year3Value;
  final double year5Value;
  final double totalInvested5Year;
  final double totalInterest5Year;

  ProjectionResult({
    required this.monthlySavings,
    required this.returnRate,
    required this.year1Value,
    required this.year3Value,
    required this.year5Value,
    required this.totalInvested5Year,
    required this.totalInterest5Year,
  });
}

class WhatIfSimulator {
  static ProjectionResult calculateProjections({
    required double monthlySavings,
    double annualReturnRate = 0.09, // 9% average stock market index return
  }) {
    if (monthlySavings <= 0) {
      return ProjectionResult(
        monthlySavings: 0,
        returnRate: annualReturnRate,
        year1Value: 0,
        year3Value: 0,
        year5Value: 0,
        totalInvested5Year: 0,
        totalInterest5Year: 0,
      );
    }

    final monthlyRate = annualReturnRate / 12.0;

    double calcFutureValue(int months) {
      if (monthlyRate == 0) return monthlySavings * months;
      return monthlySavings * ((pow(1 + monthlyRate, months) - 1) / monthlyRate);
    }

    final y1 = calcFutureValue(12);
    final y3 = calcFutureValue(36);
    final y5 = calcFutureValue(60);

    final totalInvested5Year = monthlySavings * 60;
    final totalInterest5Year = y5 - totalInvested5Year;

    return ProjectionResult(
      monthlySavings: monthlySavings,
      returnRate: annualReturnRate,
      year1Value: y1,
      year3Value: y3,
      year5Value: y5,
      totalInvested5Year: totalInvested5Year,
      totalInterest5Year: max(0, totalInterest5Year),
    );
  }
}
