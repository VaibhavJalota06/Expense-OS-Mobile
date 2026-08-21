// ============================================================
// Expense OS — Gamification & Health Engine (v3.8.0)
// Financial Health Score, Streaks & Achievement Badges
// ============================================================

(function(window) {
  'use strict';

  const GamificationEngine = {
    /**
     * Compute 0-100 Financial Health Score based on user state
     * @param {number} budget Monthly budget
     * @param {Array} expenses List of expenses
     * @param {Array} subscriptions List of subscriptions
     * @param {number} accountBalance Current account balance
     * @returns {Object} Score details: { score, grade, statusColor, breakdown }
     */
    calculateHealthScore: function(budget, expenses, subscriptions, accountBalance) {
      let score = 50; // base score

      const now = new Date();
      const firstDayMonth = new Date(now.getFullYear(), now.getMonth(), 1);
      const mExpenses = (expenses || []).filter(e => new Date(e.date) >= firstDayMonth);
      const totalMonthExp = mExpenses.reduce((sum, e) => sum + (parseFloat(e.amount) || 0), 0);
      const totalSub = (subscriptions || []).reduce((sum, s) => sum + (parseFloat(s.amount) || 0), 0);

      // 1. Budget Utilization Score (35 points max)
      let budgetScore = 20;
      if (budget > 0) {
        const ratio = totalMonthExp / budget;
        if (ratio <= 0.5) budgetScore = 35;
        else if (ratio <= 0.75) budgetScore = 30;
        else if (ratio <= 0.90) budgetScore = 22;
        else if (ratio <= 1.0) budgetScore = 15;
        else budgetScore = 5;
      }

      // 2. Emergency & Account Buffer Score (25 points max)
      let bufferScore = 10;
      const balance = parseFloat(accountBalance) || 0;
      if (totalMonthExp > 0) {
        const monthsBuffer = balance / totalMonthExp;
        if (monthsBuffer >= 3) bufferScore = 25;
        else if (monthsBuffer >= 1) bufferScore = 18;
        else if (monthsBuffer >= 0.5) bufferScore = 12;
      } else if (balance > 0) {
        bufferScore = 20;
      }

      // 3. Subscription Ratio Burden (20 points max)
      let subScore = 15;
      if (totalMonthExp > 0) {
        const subRatio = totalSub / totalMonthExp;
        if (subRatio <= 0.15) subScore = 20;
        else if (subRatio <= 0.30) subScore = 14;
        else subScore = 8;
      }

      // 4. Activity & Discipline Score (20 points max)
      const streak = GamificationEngine.getNoSpendStreak(expenses);
      let disciplineScore = Math.min(20, 10 + streak.currentStreak * 2);

      score = budgetScore + bufferScore + subScore + disciplineScore;
      score = Math.max(0, Math.min(100, Math.round(score)));

      let grade = 'Fair';
      let statusColor = '#FBBF24'; // Amber
      if (score >= 85) {
        grade = 'Excellent (Financial Fort) 🏰';
        statusColor = '#34D399'; // Emerald
      } else if (score >= 70) {
        grade = 'Good (On Track) 🚀';
        statusColor = '#38BDF8'; // Sky
      } else if (score >= 50) {
        grade = 'Fair (Room for Growth) ⚡';
        statusColor = '#FBBF24'; // Amber
      } else {
        grade = 'Needs Attention 🚨';
        statusColor = '#F87171'; // Red
      }

      return {
        score: score,
        grade: grade,
        statusColor: statusColor,
        breakdown: {
          budget: budgetScore,
          buffer: bufferScore,
          subscriptions: subScore,
          discipline: disciplineScore
        }
      };
    },

    /**
     * Calculate No-Spend Day streak count
     * @param {Array} expenses 
     * @returns {Object} { currentStreak, maxStreak }
     */
    getNoSpendStreak: function(expenses) {
      if (!Array.isArray(expenses) || expenses.length === 0) {
        return { currentStreak: 1, maxStreak: 1 };
      }

      const spendDates = new Set(expenses.map(e => (e.date || '').split('T')[0]));
      let currentStreak = 0;
      let maxStreak = 0;
      let tempStreak = 0;

      const today = new Date();
      for (let i = 0; i < 60; i++) { // check last 60 days
        const d = new Date(today);
        d.setDate(today.getDate() - i);
        const dateStr = d.toISOString().split('T')[0];

        if (!spendDates.has(dateStr)) {
          tempStreak++;
          if (i === 0 || currentStreak === i) {
            currentStreak++;
          }
        } else {
          if (tempStreak > maxStreak) maxStreak = tempStreak;
          tempStreak = 0;
        }
      }

      maxStreak = Math.max(maxStreak, currentStreak);
      return { currentStreak: currentStreak, maxStreak: maxStreak };
    },

    /**
     * Get list of achievements and unlocked badges
     * @param {Array} expenses 
     * @param {number} healthScore 
     * @returns {Array<Object>} Badges list
     */
    getAchievements: function(expenses, healthScore) {
      const streak = GamificationEngine.getNoSpendStreak(expenses);
      const badges = [
        {
          id: 'badge_frugal',
          title: 'Frugal Warrior',
          desc: 'Achieved a 3+ No-Spend Day streak',
          icon: 'fa-shield-halved',
          unlocked: streak.currentStreak >= 3
        },
        {
          id: 'badge_health_pro',
          title: 'Financial Titan',
          desc: 'Reached a Health Score of 80+',
          icon: 'fa-trophy',
          unlocked: healthScore >= 80
        },
        {
          id: 'badge_tracker',
          title: 'Master Logger',
          desc: 'Logged more than 10 transactions',
          icon: 'fa-receipt',
          unlocked: (expenses || []).length >= 10
        },
        {
          id: 'badge_ocr',
          title: 'OCR Pioneer',
          desc: 'Scanned receipt using AI scanner',
          icon: 'fa-camera-retro',
          unlocked: (typeof localStorage !== 'undefined' && localStorage.getItem('expense_cal_used_ocr') === 'true')
        }
      ];
      return badges;
    }
  };

  window.GamificationEngine = GamificationEngine;

})(window);
