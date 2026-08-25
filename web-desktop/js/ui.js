// ────────────────────────────────────────────────────────────
// Production Console Guard — suppress logs on live deployments
// ────────────────────────────────────────────────────────────
(function() {
  const IS_DEV = location.hostname === 'localhost' || location.hostname === '127.0.0.1';
  if (!IS_DEV) {
    const noop = function() {};
    console.log = noop;
    console.debug = noop;
    // Keep console.warn and console.error for critical runtime issues
  }
})();

// ────────────────────────────────────────────────────────────
// Input Validation & Sanitization Utilities
// ────────────────────────────────────────────────────────────
window.ExpenseValidator = {
  sanitizeHTML: function(str) {
    if (!str || typeof str !== 'string') return '';
    const div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  },

  validateAmount: function(amount) {
    const num = parseFloat(amount);
    if (isNaN(num) || num <= 0) return { valid: false, error: 'Amount must be a positive number' };
    if (num > 999999.99) return { valid: false, error: 'Amount cannot exceed 999,999.99' };
    return { valid: true, value: Math.round(num * 100) / 100 };
  },

  validateTitle: function(title) {
    if (!title || typeof title !== 'string') return { valid: false, error: 'Title is required' };
    const trimmed = title.trim();
    if (trimmed.length === 0) return { valid: false, error: 'Title cannot be empty' };
    if (trimmed.length > 100) return { valid: false, error: 'Title must be 100 characters or less' };
    return { valid: true, value: trimmed };
  },

  validateCategory: function(category) {
    if (!category || typeof category !== 'string') return { valid: false, error: 'Category is required' };
    const trimmed = category.trim();
    if (trimmed.length === 0) return { valid: false, error: 'Category cannot be empty' };
    if (trimmed.length > 50) return { valid: false, error: 'Category must be 50 characters or less' };
    return { valid: true, value: trimmed };
  },

  validateDate: function(dateStr) {
    if (!dateStr) return { valid: false, error: 'Date is required' };
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return { valid: false, error: 'Invalid date format' };
    return { valid: true, value: dateStr };
  },

  validateExpense: function(expense) {
    const errors = [];
    const titleResult = this.validateTitle(expense.title || expense.name);
    if (!titleResult.valid) errors.push(titleResult.error);
    const amountResult = this.validateAmount(expense.amount);
    if (!amountResult.valid) errors.push(amountResult.error);
    const categoryResult = this.validateCategory(expense.category);
    if (!categoryResult.valid) errors.push(categoryResult.error);
    const dateResult = this.validateDate(expense.date);
    if (!dateResult.valid) errors.push(dateResult.error);

    if (errors.length > 0) return { valid: false, errors: errors };
    return {
      valid: true,
      sanitized: {
        title: this.sanitizeHTML(titleResult.value),
        amount: amountResult.value,
        category: this.sanitizeHTML(categoryResult.value),
        date: dateResult.value
      }
    };
  }
};


// Helper to trigger Native Windows OS & Web Toast Notifications for 80% and 100% budget caps (Once per day)
function triggerDesktopBudgetNotification(title, body, notificationKey) {
  try {
    const todayStr = getLocalDateString();
    const storageKey = 'budget_notif_sent_' + notificationKey + '_' + todayStr;
    const lastTrigger = localStorage.getItem(storageKey);
    if (lastTrigger) return;
    localStorage.setItem(storageKey, 'true');

    if (window.electronAPI && window.electronAPI.showNativeNotification) {
      window.electronAPI.showNativeNotification(title, body);
    }

    if ('Notification' in window) {
      if (Notification.permission === 'granted') {
        new Notification(title, { body, icon: 'icon.png' });
      } else if (Notification.permission !== 'denied') {
        Notification.requestPermission().then(permission => {
          if (permission === 'granted') {
            new Notification(title, { body, icon: 'icon.png' });
          }
        });
      }
    }
  } catch (e) {
    console.error('Desktop notification error:', e);
  }
}

// ────────────────────────────────────────────────────────────
// Accessible Global Toast Notification Engine
// ────────────────────────────────────────────────────────────
window.showToast = function(message, type = 'info', duration = 3500) {
  try {
    let container = document.getElementById('toast-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'toast-container';
      container.className = 'toast-container';
      container.setAttribute('role', 'region');
      container.setAttribute('aria-label', 'Notifications');
      container.setAttribute('aria-live', 'polite');
      document.body.appendChild(container);
    }

    const toast = document.createElement('div');
    toast.className = 'toast-item toast-' + type;
    toast.setAttribute('role', 'status');

    let iconHtml = '<i class="fa-solid fa-circle-info text-sky"></i>';
    if (type === 'success') iconHtml = '<i class="fa-solid fa-circle-check text-emerald"></i>';
    else if (type === 'error') iconHtml = '<i class="fa-solid fa-circle-exclamation text-rose"></i>';
    else if (type === 'warning') iconHtml = '<i class="fa-solid fa-triangle-exclamation text-amber"></i>';

    toast.innerHTML = [
      '<div style="display:flex; align-items:center; gap:0.6rem;">',
      iconHtml,
      '<span>' + message + '</span>',
      '</div>',
      '<button type="button" class="toast-close-btn" aria-label="Dismiss">&times;</button>'
    ].join('');

    const closeBtn = toast.querySelector('.toast-close-btn');
    const dismiss = () => {
      toast.classList.add('toast-exit');
      setTimeout(() => {
        if (toast.parentNode) toast.parentNode.removeChild(toast);
      }, 300);
    };

    if (closeBtn) closeBtn.onclick = dismiss;
    container.appendChild(toast);

    if (duration > 0) {
      setTimeout(dismiss, duration);
    }
  } catch (err) {
    console.warn('Toast display notice:', err);
  }
};

// ────────────────────────────────────────────────────────────
// Recurring Bills & Subscriptions Dashboard Reminder Banner
// ────────────────────────────────────────────────────────────
function renderDashboardBillReminders() {
  const banner = document.getElementById('dashboard-bill-reminder-banner');
  if (!banner) return;

  const currentYM = typeof getCurrentYearMonth === 'function' ? getCurrentYearMonth() : new Date().toISOString().slice(0, 7);
  const currentDay = new Date().getDate();

  // Find unpaid bills due in <= 2 days (today, tomorrow, or in 2 days) or overdue in active month
  const alertBills = (subscriptions || []).filter(sub => {
    if (sub.startMonth && currentYM < sub.startMonth) return false;
    if (sub.lastPaidMonth === currentYM) return false;
    const dueDay = Number(sub.dueDay || 1);
    const diff = dueDay - currentDay;
    return diff <= 2;
  });

  if (alertBills.length === 0) {
    banner.classList.add('hidden');
    banner.innerHTML = '';
    return;
  }

  const overdueCount = alertBills.filter(s => currentDay > s.dueDay).length;
  const isUrgent = overdueCount > 0;

  let title = '';
  let subtext = '';

  if (alertBills.length === 1) {
    const bill = alertBills[0];
    const diff = bill.dueDay - currentDay;
    let dueTag = diff < 0 ? ('Overdue by ' + Math.abs(diff) + ' day(s)') : (diff === 0 ? 'Due Today!' : ('Due in ' + diff + ' day(s)'));
    title = '⚠️ Recurring Bill Alert: ' + bill.name + ' (' + formatCurrency(bill.amount) + ')';
    subtext = dueTag + ' • Avoid late fees by clearing it today.';
  } else {
    const totalDue = alertBills.reduce((acc, b) => acc + Number(b.amount || 0), 0);
    title = '⚠️ ' + alertBills.length + ' Recurring Bills Due Soon (' + formatCurrency(totalDue) + ')';
    subtext = (overdueCount > 0 ? (overdueCount + ' bill(s) are overdue! ') : '') + 'Next bills: ' + alertBills.map(b => b.name).slice(0, 3).join(', ');
  }

  banner.className = 'bill-reminder-banner ' + (isUrgent ? 'urgent' : '');
  banner.classList.remove('hidden');
  banner.innerHTML = [
    '<div class="bill-reminder-left">',
    '  <div class="bill-reminder-icon">',
    '    <i class="fa-solid ' + (isUrgent ? 'fa-triangle-exclamation text-rose' : 'fa-bell text-amber') + '"></i>',
    '  </div>',
    '  <div>',
    '    <div class="bill-reminder-title">' + title + '</div>',
    '    <div class="bill-reminder-sub">' + subtext + '</div>',
    '  </div>',
    '</div>',
    '<div style="display:flex; align-items:center; gap:0.5rem;">',
    '  <button type="button" class="bill-reminder-btn" onclick="if(window.switchView)window.switchView(\'bills\');">',
    '    Manage Bills <i class="fa-solid fa-arrow-right" style="margin-left:4px;"></i>',
    '  </button>',
    '</div>'
  ].join('');
}

// Request Desktop Notification Permission on Startup
if ('Notification' in window && Notification.permission !== 'granted' && Notification.permission !== 'denied') {
  try { Notification.requestPermission(); } catch(e) {}
}

// ---------- DOM Elements ----------
const viewTitleEl = document.getElementById('view-title');
const viewSubtitleEl = document.getElementById('view-subtitle');

const statBudgetEl = document.getElementById('stat-budget');
const statSpentEl = document.getElementById('stat-spent');
const statCountEl = document.getElementById('stat-count');
const statRemainingEl = document.getElementById('stat-remaining');
const statPercentEl = document.getElementById('stat-percent');
const statusIconEl = document.getElementById('status-icon');
const activeMonthLabelEl = document.getElementById('active-month-label');

const statSubsTotalEl = document.getElementById('stat-subs-total');
const statSubsCountEl = document.getElementById('stat-subs-count');

const progressBarFillEl = document.getElementById('progress-bar-fill');
const progressPercentLabelEl = document.getElementById('progress-percent-label');
const gaugeLimitLabelEl = document.getElementById('gauge-limit-label');
const statPercentDetailEl = document.getElementById('stat-percent-detail');

const radialGaugeContainer = document.getElementById('radial-gauge-container');

// Month Picker Elements
const monthPickerSelect = document.getElementById('month-picker');
const btnPrevMonth = document.getElementById('btn-prev-month');
const btnNextMonth = document.getElementById('btn-next-month');

// Forms & Inputs
const expenseForm = document.getElementById('expense-form');
const expAmountInput = document.getElementById('exp-amount');
const expCategorySelect = document.getElementById('exp-category');
const expDescriptionInput = document.getElementById('exp-description');
const expPaymentSelect = document.getElementById('exp-payment');
const expDateInput = document.getElementById('exp-date');

// Lists & Tables
const subsGridContainer = document.getElementById('subs-grid-container');
const dashSubsPreviewContainer = document.getElementById('dash-subs-preview');
const breakdownChartContainer = document.getElementById('breakdown-chart-container');
const breakdownListEl = document.getElementById('category-breakdown-list');
const fullAnalyticsChartContainer = document.getElementById('full-analytics-chart-container');
const fullAnalyticsListEl = document.getElementById('full-analytics-list');
const monthlyTrendChartContainer = document.getElementById('monthly-trend-chart-container');

const transactionsTbody = document.getElementById('transactions-tbody');
const emptyTableMsg = document.getElementById('empty-table-msg');

// Filters & Controls
const filterSearchInput = document.getElementById('filter-search');
const filterCategorySelect = document.getElementById('filter-category');

// Action Buttons
const btnExportCsv = document.getElementById('btn-export-csv');
const btnResetAll = document.getElementById('btn-reset-all');
const btnEditBudget = document.getElementById('btn-edit-budget');
const btnSidebarBudgetEdit = document.getElementById('btn-sidebar-budget-edit');
const btnAddSub = document.getElementById('btn-add-sub');
const btnAddSubInline = document.getElementById('btn-add-sub-inline');

// Modals
const budgetModal = document.getElementById('budget-modal');
const budgetForm = document.getElementById('budget-form');
const modalBudgetInput = document.getElementById('modal-budget-input');
const modalSaveBtn = document.getElementById('modal-save-btn');
const modalCancelBtn = document.getElementById('modal-cancel-btn');
const modalCloseBtn = document.getElementById('modal-close-btn');
const modalTitleText = document.getElementById('modal-title-text');
const statBudgetCard = document.getElementById('stat-budget-card');

const subModal = document.getElementById('sub-modal');
const subModalTitle = document.getElementById('sub-modal-title');
const subSubmitBtn = document.getElementById('sub-submit-btn');
const subForm = document.getElementById('sub-form');
const subNameInput = document.getElementById('sub-name');
const subAmountInput = document.getElementById('sub-amount');
const subStartMonthInput = document.getElementById('sub-start-month');
const subDueDayInput = document.getElementById('sub-due-day');
const subCategorySelect = document.getElementById('sub-category');
const subModalCloseBtn = document.getElementById('sub-modal-close');
const subModalCancelBtn = document.getElementById('sub-modal-cancel');
let editingSubId = null;

let activeCurrency = 'INR';
let incomes = [];

const currencyRates = {
  INR: { rate: 1, symbol: '₹', locale: 'en-IN', currency: 'INR' },
  USD: { rate: 0.012, symbol: '$', locale: 'en-US', currency: 'USD' },
  EUR: { rate: 0.011, symbol: '€', locale: 'de-DE', currency: 'EUR' },
  GBP: { rate: 0.0094, symbol: '£', locale: 'en-GB', currency: 'GBP' }
};

// ---------- Month-Wise Selection & Navigation ----------
function getAvailableMonths() {
  const monthSet = new Set();
  monthSet.add(getCurrentYearMonth()); // Always include current month

  expenses.forEach(item => {
    if (item.date && item.date.length >= 7) {
      monthSet.add(item.date.substring(0, 7));
    }
  });

  const sorted = Array.from(monthSet).sort().reverse();
  return sorted;
}

window.handleMonthSelectChange = function(newMonth) {
  selectedMonth = newMonth;
  updateMonthPickerOptions();
  updateUI();
};

function updateMonthPickerOptions() {
  const months = getAvailableMonths();
  const selectors = [monthPickerSelect, document.getElementById('reports-month-select')].filter(Boolean);

  selectors.forEach(sel => {
    sel.innerHTML = '';
    
    // Option for All Time
    const allOpt = document.createElement('option');
    allOpt.value = 'ALL';
    allOpt.textContent = '📅 All Time';
    if (selectedMonth === 'ALL') allOpt.selected = true;
    sel.appendChild(allOpt);

    months.forEach(ym => {
      const opt = document.createElement('option');
      opt.value = ym;
      opt.textContent = `📅 ${formatMonthLabel(ym)}`;
      if (selectedMonth === ym) opt.selected = true;
      sel.appendChild(opt);
    });
  });
}

if (monthPickerSelect) {
  monthPickerSelect.addEventListener('change', (e) => {
    selectedMonth = e.target.value;
    updateUI();
  });
}

if (btnPrevMonth && btnNextMonth) {
  btnPrevMonth.addEventListener('click', () => {
    const months = getAvailableMonths();
    if (selectedMonth === 'ALL') {
      selectedMonth = months[0] || getCurrentYearMonth();
    } else {
      const idx = months.indexOf(selectedMonth);
      if (idx !== -1 && idx < months.length - 1) {
        selectedMonth = months[idx + 1];
      }
    }
    updateMonthPickerOptions();
    updateUI();
  });

  btnNextMonth.addEventListener('click', () => {
    const months = getAvailableMonths();
    if (selectedMonth === 'ALL') {
      selectedMonth = months[0] || getCurrentYearMonth();
    } else {
      const idx = months.indexOf(selectedMonth);
      if (idx > 0) {
        selectedMonth = months[idx - 1];
      }
    }
    updateMonthPickerOptions();
    updateUI();
  });
}

// ---------- Tab / View Switching with History & Mouse Back/Forward Support ----------
window.switchView = function switchView(viewName, updateHash = true) {
  if (!viewName || !viewHeadings[viewName]) return;
  currentView = viewName;
  window.currentView = viewName;
  try { localStorage.setItem('expense_cal_current_view', viewName); } catch(e){}

  // Force close any lingering welcome modal overlay
  const welcomeModal = document.getElementById('welcome-modal');
  if (welcomeModal) {
    welcomeModal.classList.add('hidden');
    welcomeModal.style.setProperty('display', 'none', 'important');
    welcomeModal.style.setProperty('pointer-events', 'none', 'important');
  }

  document.querySelectorAll('.nav-item').forEach(nav => {
    if (nav.dataset.view === viewName) {
      nav.classList.add('active');
    } else {
      nav.classList.remove('active');
    }
  });

  if (viewHeadings[viewName]) {
    if (viewTitleEl) viewTitleEl.textContent = viewHeadings[viewName].title;
    if (viewSubtitleEl) viewSubtitleEl.textContent = viewHeadings[viewName].subtitle;
  }

  document.querySelectorAll('.view-panel').forEach(panel => {
    panel.classList.remove('active', 'view-exit');
    panel.style.setProperty('display', 'none', 'important');
  });

  const targetPanel = document.getElementById(`view-${viewName}`);
  if (targetPanel) {
    targetPanel.classList.add('active');
    targetPanel.style.setProperty('display', 'flex', 'important');
    targetPanel.style.setProperty('opacity', '1', 'important');
    targetPanel.style.setProperty('visibility', 'visible', 'important');
  }

  // Keep URL Hash in sync for direct links, browser history & mouse side buttons
  if (updateHash && window.location.hash !== `#${viewName}`) {
    try {
      history.pushState({ view: viewName }, '', `#${viewName}`);
    } catch(err) {
      window.location.hash = viewName;
    }
  }

  try { updateUI(); } catch(err) { console.warn('UI Update notice:', err); }
};

// URL Hash & PopState Change Handlers for mouse side buttons & browser back/forward
window.addEventListener('popstate', (e) => {
  const hash = window.location.hash.replace('#', '');
  const stateView = e.state && e.state.view;
  const targetView = stateView || hash || 'dashboard';
  if (targetView && viewHeadings[targetView] && targetView !== currentView) {
    window.switchView(targetView, false);
  }
});

window.addEventListener('hashchange', () => {
  const hash = window.location.hash.replace('#', '');
  if (hash && viewHeadings[hash] && hash !== currentView) {
    window.switchView(hash, false);
  }
});

// Explicit mouse side button listener (Button 3 = Thumb Back, Button 4 = Thumb Forward)
const handleMouseSideButtons = (e) => {
  if (e.button === 3) {
    e.preventDefault();
    history.back();
  } else if (e.button === 4) {
    e.preventDefault();
    history.forward();
  }
};
window.addEventListener('auxclick', handleMouseSideButtons);
window.addEventListener('mouseup', handleMouseSideButtons);

// Restore saved active view on load or refresh (e.g. #savings-goals)
function initSavedViewNavigation() {
  const hash = window.location.hash.replace('#', '');
  const savedView = localStorage.getItem('expense_cal_current_view');
  const targetView = (hash && viewHeadings[hash]) ? hash : ((savedView && viewHeadings[savedView]) ? savedView : 'dashboard');
  if (targetView && viewHeadings[targetView]) {
    window.switchView(targetView, true);
  }
}
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initSavedViewNavigation);
} else {
  initSavedViewNavigation();
}

document.querySelectorAll('.nav-item').forEach(nav => {
  nav.addEventListener('click', (e) => {
    e.preventDefault();
    const view = nav.dataset.view;
    if (view) window.switchView(view);
  });
});

document.querySelectorAll('.view-all-link[data-view]').forEach(control => {
  control.addEventListener('click', (e) => {
    e.preventDefault();
    switchView(control.dataset.view);
  });
});

// ---------- UI Render & Update ----------
function updateUI() {

  // Filter Expenses by Selected Month
  const filteredMonthExpenses = expenses.filter(item => {
    if (selectedMonth === 'ALL') return true;
    return item.date && item.date.startsWith(selectedMonth);
  });

  const totalSpent = filteredMonthExpenses.reduce((sum, item) => sum + Number(item.amount), 0);

  // Filter Incomes by Selected Month
  const filteredMonthIncomes = incomes.filter(item => {
    if (selectedMonth === 'ALL') return true;
    return item.date && item.date.startsWith(selectedMonth);
  });

  const totalIncome = filteredMonthIncomes.reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const totalAllTimeIncome = incomes.reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const totalAllTimeSpent = expenses.reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const totalAccountMoney = accountBalance + totalAllTimeIncome;

  // Dynamic Budgeting: Effective Monthly Budget = Base Set Budget + Active Month's Extra Income
  const effectiveMonthlyBudget = (budget > 0 || totalIncome > 0) ? (budget + totalIncome) : 0;
  const remaining = effectiveMonthlyBudget - totalSpent;
  const spentRatio = effectiveMonthlyBudget > 0 ? (totalSpent / effectiveMonthlyBudget) * 100 : 0;
  const remainingPercent = Math.max(0, 100 - spentRatio);
  const availableMoney = effectiveMonthlyBudget > 0 ? Math.max(0, totalAccountMoney - effectiveMonthlyBudget) : totalAccountMoney;

  if (activeMonthLabelEl) {
    activeMonthLabelEl.textContent = selectedMonth === 'ALL' ? 'All Time' : formatMonthLabel(selectedMonth);
  }

  // Update Stat Cards & Topbar Budget Edit Button Label
  if (btnEditBudget) {
    btnEditBudget.innerHTML = budget > 0 
      ? '<i class="fa-solid fa-pen-to-square"></i> Edit Budget' 
      : '<i class="fa-solid fa-sliders"></i> Set Budget';
  }

  const statAccountBalanceEl = document.getElementById('stat-account-balance');
  const statIncomeEl = document.getElementById('stat-income');
  const statIncomeCountEl = document.getElementById('stat-income-count');

  if (statAccountBalanceEl) {
    statAccountBalanceEl.textContent = formatCurrency(availableMoney, 'stat-account-balance');
    statAccountBalanceEl.className = availableMoney >= 0 ? 'stat-value text-emerald mono' : 'stat-value text-rose mono';
  }

  const statAccountSubtextEl = document.getElementById('stat-account-subtext');
  if (statAccountSubtextEl) {
    const totalGoalSaved = savingsGoals.reduce((sum, g) => sum + Number(g.savedAmount || 0), 0);
    if (effectiveMonthlyBudget > 0) {
      statAccountSubtextEl.innerHTML = `Gross Total: <strong>${formatCurrency(totalAccountMoney, 'stat-account-balance')}</strong> (${formatCurrency(effectiveMonthlyBudget)} budgeted) <span class="edit-hint">(Edit ✏️)</span>`;
    } else if (totalGoalSaved > 0) {
      statAccountSubtextEl.innerHTML = `Allocated to Goals: <strong>${formatCurrency(totalGoalSaved, 'stat-account-balance')}</strong> <span class="edit-hint">(Edit ✏️)</span>`;
    } else {
      statAccountSubtextEl.innerHTML = `Total Account Cash + Extra Incomes <span class="edit-hint">(Edit ✏️)</span>`;
    }
  }

  const statLeftoverEl = document.getElementById('stat-leftover');
  const statLeftoverSubtextEl = document.getElementById('stat-leftover-subtext');
  if (statLeftoverSubtextEl) {
    statLeftoverSubtextEl.textContent = `Budget Cap − Expenses`;
  }

  if (statRemainingEl) {
    statRemainingEl.textContent = effectiveMonthlyBudget > 0 ? formatCurrency(remaining, 'stat-remaining') : (isCardMasked('stat-remaining') ? '••••••' : '₹0.00');
    statRemainingEl.className = (effectiveMonthlyBudget > 0 && remaining < 0) ? 'stat-value text-rose mono' : 'stat-value text-emerald mono';
  }

  if (statPercentEl) {
    if (effectiveMonthlyBudget === 0) {
      statPercentEl.textContent = 'Budget Limit Not Set (Click to Set ✏️)';
    } else {
      statPercentEl.textContent = `${spentRatio.toFixed(1)}% Spent of Cap (${remainingPercent.toFixed(1)}% Left)`;
    }
  }

  // Trigger Windows OS Toast Notification & Web Notification for 80% and 100% Budget Thresholds (Once per day)
  if (effectiveMonthlyBudget > 0) {
    if (spentRatio >= 100) {
      triggerDesktopBudgetNotification(
        '⚠️ Monthly Budget Exceeded!',
        `You have spent ${formatCurrency(totalSpent)} of your ${formatCurrency(effectiveMonthlyBudget)} limit (${spentRatio.toFixed(1)}%).`,
        `budget_exceeded_${selectedMonth}`
      );
    } else if (spentRatio >= 80) {
      triggerDesktopBudgetNotification(
        '🔔 80% Budget Threshold Reached',
        `You have used ${spentRatio.toFixed(1)}% of your monthly budget limit (${formatCurrency(totalSpent)} / ${formatCurrency(effectiveMonthlyBudget)}).`,
        `budget_80_${selectedMonth}`
      );
    }
  }

  const leftoverIconEl = document.getElementById('status-icon');
  if (leftoverIconEl) {
    leftoverIconEl.className = 'fa-solid stat-icon';
    if (effectiveMonthlyBudget > 0) {
      if (remaining < 0) {
        leftoverIconEl.classList.add('fa-circle-exclamation', 'text-rose');
      } else if (spentRatio >= 80) {
        leftoverIconEl.classList.add('fa-triangle-exclamation', 'text-amber');
      } else {
        leftoverIconEl.classList.add('fa-piggy-bank', 'text-emerald');
      }
    } else {
      leftoverIconEl.classList.add('fa-piggy-bank', 'text-emerald');
    }
  }

  if (statIncomeEl) statIncomeEl.textContent = formatCurrency(totalIncome, 'stat-income');
  if (statIncomeCountEl) {
    statIncomeCountEl.innerHTML = `${filteredMonthIncomes.length} extra source${filteredMonthIncomes.length === 1 ? '' : 's'} <span class="edit-hint">(+Add)</span>`;
  }

  if (statBudgetEl) statBudgetEl.textContent = formatCurrency(effectiveMonthlyBudget, 'stat-budget');
  const statBudgetSubtextEl = document.getElementById('stat-budget-subtext');
  if (statBudgetSubtextEl) {
    if (totalIncome > 0) {
      statBudgetSubtextEl.innerHTML = `Base: ${formatCurrency(budget)} + Extra: ${formatCurrency(totalIncome)} <span class="edit-hint">(Edit ✏️)</span>`;
    } else {
      statBudgetSubtextEl.innerHTML = `Monthly Spending Limit <span class="edit-hint">(Edit ✏️)</span>`;
    }
  }

  if (statSpentEl) statSpentEl.textContent = formatCurrency(totalSpent, 'stat-spent');
  if (statCountEl) statCountEl.textContent = `${filteredMonthExpenses.length} transaction${filteredMonthExpenses.length === 1 ? '' : 's'}`;

  const sidebarBudgetVal = document.getElementById('sidebar-budget-val');
  if (sidebarBudgetVal) sidebarBudgetVal.textContent = formatCurrency(effectiveMonthlyBudget, 'sb-budget-val');

  // Balance Indicator Colors
  if (statRemainingEl && statusIconEl) {
    statRemainingEl.classList.remove('text-rose', 'text-amber', 'text-emerald', 'text-muted');
    statusIconEl.className = 'fa-solid stat-icon';

    if (budget === 0) {
      statRemainingEl.classList.add('text-muted');
      statusIconEl.classList.add('fa-circle-info', 'text-muted');
    } else if (remaining < 0) {
      statRemainingEl.classList.add('text-rose');
      statusIconEl.classList.add('fa-circle-exclamation', 'text-rose');
    } else if (spentRatio >= 80) {
      statRemainingEl.classList.add('text-amber');
      statusIconEl.classList.add('fa-triangle-exclamation', 'text-amber');
    } else {
      statRemainingEl.classList.add('text-emerald');
      statusIconEl.classList.add('fa-shield-halved', 'text-emerald');
    }
  }

  // Progress Bar & Gauge Labels
  const clampPercent = Math.min(100, Math.max(0, spentRatio));
  if (progressBarFillEl) progressBarFillEl.style.width = `${clampPercent}%`;
  if (progressPercentLabelEl) progressPercentLabelEl.textContent = budget > 0 ? `${clampPercent.toFixed(1)}% Used` : '0% Used';
  if (gaugeLimitLabelEl) gaugeLimitLabelEl.textContent = `${formatCurrency(budget)} Limit`;
  if (statPercentDetailEl) statPercentDetailEl.textContent = budget > 0 ? `${clampPercent.toFixed(1)}% Used` : '0% Used';

  if (progressBarFillEl) {
    if (spentRatio > 100) {
      progressBarFillEl.style.background = 'linear-gradient(90deg, #f59e0b, #f43f5e)';
    } else if (spentRatio >= 80) {
      progressBarFillEl.style.background = 'linear-gradient(90deg, #10b981, #f59e0b)';
    } else {
      progressBarFillEl.style.background = 'linear-gradient(90deg, #10b981, #6366f1)';
    }
  }

  updateFinancialHealthScore(totalIncome, totalSpent, budget);
  syncPrivacyBtnUI();
  if (typeof window.syncProfileUI === 'function') window.syncProfileUI();

  window.requestAnimationFrame(() => {
    const activeView = currentView || 'dashboard';

    if (activeView === 'dashboard') {
      renderRadialGauge(spentRatio, totalSpent, budget);
      renderSubscriptions();
      renderDashboardBillReminders();
      renderCategoryBreakdown(filteredMonthExpenses, totalSpent);
      renderMonthlyTrendChart();
      renderTransactionsTable(filteredMonthExpenses);
    } else if (activeView === 'transactions' || activeView === 'reports') {
      renderTransactionsTable(filteredMonthExpenses);
    } else if (activeView === 'bills') {
      renderSubscriptions();
    } else if (activeView === 'analytics') {
      renderCategoryBreakdown(filteredMonthExpenses, totalSpent);
      renderMonthlyTrendChart();
    } else if (activeView === 'savings-goals') {
      renderSavingsGoals();
    } else {
      renderRadialGauge(spentRatio, totalSpent, budget);
      renderSubscriptions();
      renderCategoryBreakdown(filteredMonthExpenses, totalSpent);
      renderMonthlyTrendChart();
      renderTransactionsTable(filteredMonthExpenses);
    }

    checkAndSendSubscriptionReminders();
  });
}

// Automated Email Reminder Engine for Subscriptions Due Soon
function checkAndSendSubscriptionReminders() {
  if (!subscriptions || subscriptions.length === 0) return;
  const now = new Date();
  const currentYM = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  const currentDay = now.getDate();

  // Get current user email from Supabase session (Firebase auth was removed in v2.4.0)
  let userEmail = null;
  try {
    const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : null);
    if (supaClient && supaClient.auth) {
      supaClient.auth.getSession().then(({ data }) => {
        if (data && data.session && data.session.user) {
          userEmail = data.session.user.email;
        }
      }).catch(() => {});
    }
  } catch(e) {}

  subscriptions.forEach(sub => {
    const isPaidThisMonth = sub.lastPaidMonth === currentYM;
    if (isPaidThisMonth) return;

    const daysLeft = sub.dueDay - currentDay;
    if (daysLeft >= 0 && daysLeft <= 3) {
      const reminderKey = `expense_cal_sub_reminded_${sub.id}_${currentYM}_${daysLeft}d`;
      if (!localStorage.getItem(reminderKey)) {
        localStorage.setItem(reminderKey, 'true');

        // EmailJS Live Email Delivery to Gmail
        if (typeof emailjs !== 'undefined' && emailjsConfig && 
            typeof emailjsConfig.serviceId !== 'undefined' && 
            typeof emailjsConfig.templateId !== 'undefined' && 
            typeof emailjsConfig.publicKey !== 'undefined' && 
            userEmail) {
          try {
            emailjs.send(
              emailjsConfig.serviceId,
              emailjsConfig.templateId,
              {
                to_email: userEmail,
                email: userEmail,
                name: sub.name,
                user_name: sub.name,
                subject: `⏰ Subscription Due Reminder: ${sub.name} is due ${daysLeft === 0 ? 'today' : 'in ' + daysLeft + ' days'}!`,
                message: `Reminder: ${sub.name} (₹${sub.amount.toFixed(2)}) renewal payment is due ${daysLeft === 0 ? 'today' : 'in ' + daysLeft + ' days'}.`,
                web_app_url: window.location.origin + window.location.pathname,
                app_url: window.location.origin + window.location.pathname,
                action_url: window.location.origin + window.location.pathname,
                url: window.location.origin + window.location.pathname,
                link: window.location.origin + window.location.pathname
              },
              emailjsConfig.publicKey
            );
            console.log('Live EmailJS Subscription Reminder sent to:', userEmail);
          } catch (err) {
            console.warn('EmailJS reminder notice:', err);
          }
        }


      }
    }
  });
  if (window.renderIncomeList) window.renderIncomeList();
}

// Render Radial SVG Budget Gauge Ring
function renderRadialGauge(spentRatio, totalSpent, budgetLimit) {
  if (!radialGaugeContainer) return;

  const size = 200;
  const strokeWidth = 12;
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const clampPercent = Math.min(100, Math.max(0, spentRatio));
  const strokeDashoffset = circumference - (clampPercent / 100) * circumference;

  let strokeColor = '#10B981';
  let statusText = 'Healthy';
  let badgeClass = 'gauge-success';

  if (budgetLimit === 0) {
    statusText = 'Set Limit';
    strokeColor = '#71717A';
    badgeClass = 'gauge-muted';
  } else if (spentRatio > 100) {
    statusText = 'Over Budget';
    strokeColor = '#FB7185';
    badgeClass = 'gauge-danger';
  } else if (spentRatio >= 80) {
    statusText = 'High Spending';
    strokeColor = '#F59E0B';
    badgeClass = 'gauge-warning';
  } else {
    statusText = 'Healthy';
    strokeColor = '#10B981';
    badgeClass = 'gauge-success';
  }

  radialGaugeContainer.innerHTML = `
    <div class="radial-gauge-wrapper">
      <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" class="radial-gauge-svg">
        <circle cx="${size / 2}" cy="${size / 2}" r="${radius}"
          fill="transparent"
          stroke="rgba(255, 255, 255, 0.08)"
          stroke-width="${strokeWidth}"
        />
        <circle cx="${size / 2}" cy="${size / 2}" r="${radius}"
          fill="transparent"
          stroke="${strokeColor}"
          stroke-width="${strokeWidth}"
          stroke-dasharray="${circumference}"
          stroke-dashoffset="${strokeDashoffset}"
          stroke-linecap="round"
          class="radial-gauge-progress"
          transform="rotate(-90 ${size / 2} ${size / 2})"
        />
      </svg>
      <div class="radial-gauge-center">
        <span class="radial-percent-val">${budgetLimit > 0 ? clampPercent.toFixed(1) + '%' : '0%'}</span>
        <span class="radial-percent-label">Budget Used</span>
        <span class="gauge-status-badge ${badgeClass}">${statusText}</span>
      </div>
    </div>
  `;
}

function renderSubscriptions() {
  const now = new Date();
  const currentYM = getCurrentYearMonth();
  const currentDay = now.getDate();

  let totalMonthlySubs = 0;
  let dueSoonCount = 0;
  let paidCount = 0;

  subscriptions.forEach(sub => {
    totalMonthlySubs += Number(sub.amount || 0);
    const isPaidThisMonth = sub.lastPaidMonth === currentYM;
    if (isPaidThisMonth) {
      paidCount++;
    } else if (currentDay > sub.dueDay || sub.dueDay - currentDay <= 7) {
      dueSoonCount++;
    }
  });

  if (statSubsTotalEl) statSubsTotalEl.textContent = formatCurrency(totalMonthlySubs);
  if (statSubsCountEl) statSubsCountEl.textContent = `${subscriptions.length} active subscription${subscriptions.length === 1 ? '' : 's'}`;

  // Update Bills Progress Strip
  const billsProgressText = document.getElementById('bills-progress-text');
  const billsProgressFillBar = document.getElementById('bills-progress-fill-bar');
  const totalCount = subscriptions.length;
  const percentPaid = totalCount > 0 ? Math.round((paidCount / totalCount) * 100) : 0;

  if (billsProgressText) {
    billsProgressText.textContent = `${paidCount} of ${totalCount} Paid (${percentPaid}%)`;
  }
  if (billsProgressFillBar) {
    billsProgressFillBar.style.width = `${percentPaid}%`;
  }

  // Dedicated Bills View Grid
  if (subsGridContainer) {
    if (typeof deduplicateSubscriptions === 'function') {
      subscriptions = deduplicateSubscriptions(subscriptions);
    } else if (window.deduplicateSubscriptions) {
      subscriptions = window.deduplicateSubscriptions(subscriptions);
    }
    subsGridContainer.innerHTML = '';

    if (subscriptions.length === 0) {
      subsGridContainer.classList.add('empty-grid');
      subsGridContainer.innerHTML = `
        <div class="empty-state-card">
          <i class="fa-solid fa-calendar-check empty-state-icon"></i>
          <p class="empty-state-title">No Recurring Bills Added</p>
          <p class="empty-state-sub">Click "+ Add Bill" to manage monthly rent, wifi, or utility reminders.</p>
        </div>
      `;
    } else {
      subsGridContainer.classList.remove('empty-grid');
      const todayDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

      subscriptions.forEach(sub => {
        const isPaidThisMonth = sub.lastPaidMonth === currentYM;
        let urgencyBadge = '';

        // Calculate exact target due date
        let targetDueDate;
        const sDay = Number(sub.dueDay || sub.due_day || 15);
        if (sub.startMonth && currentYM < sub.startMonth) {
          const [y, m] = sub.startMonth.split('-').map(Number);
          targetDueDate = new Date(y, m - 1, sDay);
        } else if (sub.dueDate || sub.due_date) {
          const raw = sub.dueDate || sub.due_date;
          if (raw.includes('-')) {
            const [y, m, d] = raw.split('-').map(Number);
            targetDueDate = new Date(y, m - 1, d || sDay);
          } else {
            targetDueDate = new Date(now.getFullYear(), now.getMonth(), sDay);
          }
        } else {
          targetDueDate = new Date(now.getFullYear(), now.getMonth(), sDay);
        }

        const diffTime = targetDueDate - todayDate;
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        const dayNum = targetDueDate.getDate();
        const formattedTargetDate = `${String(dayNum).padStart(2, '0')} ${monthNames[targetDueDate.getMonth()]}`;

        if (isPaidThisMonth) {
          urgencyBadge = `<span class="bill-urgency-badge paid"><i class="fa-solid fa-circle-check"></i> Paid for ${monthNames[now.getMonth()]}</span>`;
        } else if (diffDays < 0) {
          urgencyBadge = `<span class="bill-urgency-badge overdue"><i class="fa-solid fa-triangle-exclamation"></i> Overdue (${formattedTargetDate})</span>`;
        } else if (diffDays === 0) {
          urgencyBadge = `<span class="bill-urgency-badge due-soon"><i class="fa-solid fa-clock"></i> Due Today ⚠️</span>`;
        } else if (diffDays === 1) {
          urgencyBadge = `<span class="bill-urgency-badge due-soon"><i class="fa-solid fa-clock"></i> Due in 1 day (${formattedTargetDate})</span>`;
        } else if (diffDays <= 2) {
          urgencyBadge = `<span class="bill-urgency-badge due-soon"><i class="fa-solid fa-clock"></i> Due in 2 days (${formattedTargetDate})</span>`;
        } else {
          urgencyBadge = `<span class="bill-urgency-badge normal"><i class="fa-regular fa-calendar-days"></i> Due in ${diffDays} days (${formattedTargetDate})</span>`;
        }

        // Auto-Pay pill badge if enabled
        const autoPayBadge = (sub.autoPay || sub.auto_pay) 
          ? `<span style="display: inline-flex; align-items: center; gap: 3px; font-size: 0.68rem; font-weight: 700; color: #a855f7; background: rgba(168, 85, 247, 0.12); border: 1px solid rgba(168, 85, 247, 0.25); padding: 1px 6px; border-radius: 6px; margin-left: 6px;">⚡ Auto-Pay</span>`
          : '';

        const card = document.createElement('div');
        card.className = 'sub-card-item';
        card.innerHTML = `
          <div class="sub-card-header">
            <div style="cursor: pointer;" onclick="if(window.editSubscription){window.editSubscription('${sub.id}');}">
              <div class="sub-title" style="display: flex; align-items: center;">${escapeHtml(sub.name || sub.title || 'Subscription')} ${autoPayBadge}</div>
              <div class="sub-due">${escapeHtml(sub.category || 'Services & Subscriptions')}</div>
            </div>
            <div style="display: flex; align-items: center; gap: 0.35rem;">
              <button type="button" class="icon-btn action-btn-edit" data-edit-sub="${sub.id}" title="Edit Subscription" onclick="if(window.editSubscription){event.preventDefault();event.stopPropagation();window.editSubscription('${sub.id}');}">
                <i class="fa-solid fa-pen-to-square"></i>
              </button>
              <button type="button" class="icon-btn action-btn-del" data-delete-sub="${sub.id}" title="Delete Subscription" onclick="if(window.deleteSubscription){event.preventDefault();event.stopPropagation();window.deleteSubscription('${sub.id}');}">
                <i class="fa-solid fa-xmark"></i>
              </button>
            </div>
          </div>
          <div class="sub-amount">${formatCurrency(sub.amount)} <span class="per-mo">/ mo</span></div>
          <div class="sub-actions">
            ${urgencyBadge}
            ${
              !isPaidThisMonth
                ? `<button type="button" class="btn btn-secondary btn-sm" data-pay-sub="${sub.id}" onclick="if(window.markSubAsPaid){event.preventDefault();event.stopPropagation();window.markSubAsPaid('${sub.id}');}">
                    <i class="fa-solid fa-check"></i> Mark Paid
                   </button>`
                : `<span class="paid-check-badge"><i class="fa-solid fa-circle-check"></i> Paid</span>`
            }
          </div>
        `;
        subsGridContainer.appendChild(card);
      });
    }
  }

  // Dashboard Overview Bills Preview
  if (dashSubsPreviewContainer) {
    dashSubsPreviewContainer.innerHTML = '';
    if (subscriptions.length === 0) {
      dashSubsPreviewContainer.innerHTML = '<p class="empty-state-sub">No active recurring bills.</p>';
    } else {
      const topSubs = subscriptions.slice(0, 3);
      topSubs.forEach(sub => {
        const isPaidThisMonth = sub.lastPaidMonth === currentYM;
        const item = document.createElement('div');
        item.className = 'dash-sub-item';
        item.innerHTML = `
          <div class="dash-sub-info">
            <span class="dash-sub-name">${escapeHtml(sub.name)}</span>
            <span class="dash-sub-due">Due Day ${sub.dueDay}</span>
          </div>
          <div class="dash-sub-right">
            <span class="dash-sub-amount">${formatCurrency(sub.amount)}</span>
            ${isPaidThisMonth
              ? '<span class="status-badge paid"><i class="fa-solid fa-check"></i> Paid</span>'
              : `<button type="button" class="btn btn-secondary btn-xs" data-pay-sub="${sub.id}" onclick="if(window.markSubAsPaid){event.preventDefault();event.stopPropagation();window.markSubAsPaid('${sub.id}');}">Pay</button>`
            }
          </div>
        `;
        dashSubsPreviewContainer.appendChild(item);
      });
    }
  }
}

window.markAllDueBillsAsPaid = function() {
  const currentYM = getCurrentYearMonth();
  const unpaidBills = subscriptions.filter(s => s.lastPaidMonth !== currentYM);
  if (unpaidBills.length === 0) {
    if (typeof showToast === 'function') showToast('All monthly bills are already paid for this month! 🎉');
    return;
  }

  unpaidBills.forEach(sub => {
    sub.lastPaidMonth = currentYM;
    const today = getLocalDateString();
    expenses.push({
      id: Date.now().toString(36) + Math.random().toString(36).substring(2, 6),
      amount: sub.amount,
      category: sub.category || 'Services & Subscriptions',
      description: `Bill Payment: ${sub.name}`,
      payment: 'Auto-Pay',
      date: today
    });
  });

  saveState();
  updateMonthPickerOptions();
  updateUI();
  if (typeof showToast === 'function') showToast(`⚡ Successfully marked ${unpaidBills.length} bills as paid & logged to ledger!`);
};

function markSubAsPaid(subId) {
  const sub = subscriptions.find(s => String(s.id) === String(subId));
  if (!sub) return;

  const currentYM = getCurrentYearMonth();
  sub.lastPaidMonth = currentYM;

  const today = getLocalDateString();
  const newExpense = {
    id: Date.now().toString(36) + Math.random().toString(36).slice(2, 7),
    amount: sub.amount,
    category: sub.category || 'Services & Subscriptions',
    description: `Bill Payment: ${sub.name}`,
    payment: 'Auto-Pay',
    date: today
  };

  expenses.push(newExpense);
  saveState();
  updateMonthPickerOptions();
  updateUI();
}

window.markSubAsPaid = markSubAsPaid;

async function deleteSubscription(subId) {
  if (!subId) return;
  const ok = await showConfirm('Delete Recurring Bill', 'Are you sure you want to delete this recurring subscription/bill?', true);
  if (ok) {
    subscriptions = subscriptions.filter(s => String(s.id) !== String(subId));
    saveState();
    updateUI();
  }
}

window.deleteSubscription = deleteSubscription;

// Chart.js Category Donut Breakdown - Stable Zero-Animation Engine
function renderCategoryBreakdown(filteredList, totalSpent) {
  const containers = [
    { chart: breakdownChartContainer, list: breakdownListEl, getInstance: () => breakdownChartInstance, setInstance: (inst) => { breakdownChartInstance = inst; } },
    { chart: fullAnalyticsChartContainer, list: fullAnalyticsListEl, getInstance: () => fullAnalyticsChartInstance, setInstance: (inst) => { fullAnalyticsChartInstance = inst; } }
  ];

  containers.forEach(({ chart, list, getInstance, setInstance }) => {
    if (list) list.innerHTML = '';

    if (filteredList.length === 0 || totalSpent === 0) {
      if (getInstance()) {
        try { getInstance().destroy(); } catch(e) {}
        setInstance(null);
      }
      if (chart) {
        chart.innerHTML = `
          <div class="empty-state-small">
            <i class="fa-solid fa-chart-pie empty-state-icon"></i>
            <p>No expense data for ${selectedMonth === 'ALL' ? 'All Time' : formatMonthLabel(selectedMonth)}</p>
          </div>
        `;
      }
      if (list) list.innerHTML = `<p class="empty-state-sub text-center">No expenses logged in ${selectedMonth === 'ALL' ? 'all time' : formatMonthLabel(selectedMonth)}.</p>`;
      return;
    }

    const categoryTotals = {};
    filteredList.forEach(item => {
      categoryTotals[item.category] = (categoryTotals[item.category] || 0) + Number(item.amount);
    });

    const sortedCategories = Object.entries(categoryTotals).sort((a, b) => b[1] - a[1]);
    const labels = sortedCategories.map(c => c[0]);
    const data = sortedCategories.map(c => c[1]);
    const bgColors = sortedCategories.map(c => categoryColors[c[0]] || '#34D399');

    // Chart.js or SVG Donut Chart Fallback
    if (chart) {
      const existingInst = getInstance();
      const existingCanvas = chart.querySelector('canvas');
      const existingCenterVal = chart.querySelector('.donut-total-val');

      if (existingInst && existingCanvas) {
        // Fast instant update without recreating canvas or triggering re-animation
        existingInst.data.labels = labels;
        existingInst.data.datasets[0].data = data;
        existingInst.data.datasets[0].backgroundColor = bgColors;
        existingInst.update('none');
        if (existingCenterVal) existingCenterVal.textContent = formatCurrency(totalSpent);
      } else {
        if (existingInst) {
          try { existingInst.destroy(); } catch(e) {}
        }
        chart.innerHTML = '';

        const wrapper = document.createElement('div');
        wrapper.className = 'donut-chart-wrapper';

        if (typeof Chart !== 'undefined') {
          const canvas = document.createElement('canvas');
          wrapper.appendChild(canvas);

          const centerText = document.createElement('div');
          centerText.className = 'donut-center-text';
          centerText.innerHTML = `
            <span class="donut-total-title">Total Spent</span>
            <span class="donut-total-val mono">${formatCurrency(totalSpent)}</span>
          `;
          wrapper.appendChild(centerText);
          chart.appendChild(wrapper);

          const inst = new Chart(canvas, {
            type: 'doughnut',
            data: {
              labels: labels,
              datasets: [{
                data: data,
                backgroundColor: bgColors,
                borderColor: '#0E131A',
                borderWidth: 2,
                hoverOffset: 4
              }]
            },
            options: {
              responsive: true,
              maintainAspectRatio: false,
              animation: false,
              animations: {
                colors: false,
                x: false,
                y: false
              },
              transitions: {
                active: { animation: { duration: 0 } },
                resize: { animation: { duration: 0 } }
              },
              plugins: {
                legend: { display: false },
                tooltip: {
                  backgroundColor: 'rgba(14, 19, 26, 0.95)',
                  titleColor: '#F2F5FA',
                  bodyColor: '#A6B0C3',
                  borderColor: 'rgba(255, 255, 255, 0.1)',
                  borderWidth: 1,
                  callbacks: {
                    label: function(context) {
                      const val = context.raw || 0;
                      const pct = ((val / totalSpent) * 100).toFixed(1);
                      return `${context.label}: ${formatCurrency(val)} (${pct}%)`;
                    }
                  }
                }
              },
              cutout: '74%'
            }
          });
          setInstance(inst);
        } else {
          // Instant SVG Donut Ring Fallback
          let cumulativePercent = 0;
          const svgSegments = sortedCategories.map(([catName, catAmount]) => {
            const pct = (catAmount / totalSpent);
            const dashArray = `${pct * 283} ${283 - (pct * 283)}`;
            const dashOffset = -(cumulativePercent * 283);
            cumulativePercent += pct;
            const color = categoryColors[catName] || '#34D399';
            return `<circle cx="50" cy="50" r="45" fill="none" stroke="${color}" stroke-width="9" stroke-dasharray="${dashArray}" stroke-dashoffset="${dashOffset}" transform="rotate(-90 50 50)"></circle>`;
          }).join('');

          wrapper.innerHTML = `
            <svg viewBox="0 0 100 100" class="donut-svg-fallback" style="width: 100%; height: 100%;">
              <circle cx="50" cy="50" r="45" fill="none" stroke="rgba(255,255,255,0.06)" stroke-width="9"></circle>
              ${svgSegments}
            </svg>
            <div class="donut-center-text">
              <span class="donut-total-title">Total Spent</span>
              <span class="donut-total-val mono">${formatCurrency(totalSpent)}</span>
            </div>
          `;
          chart.appendChild(wrapper);
        }
      }
    }

    // List Breakdown items with Category Distribution Progress Bars & Pills
    if (list) {
      sortedCategories.forEach(([catName, catAmount]) => {
        const percent = ((catAmount / totalSpent) * 100).toFixed(1);
        const color = categoryColors[catName] || '#34D399';

        const itemEl = document.createElement('div');
        itemEl.className = 'category-distribution-item';
        itemEl.innerHTML = `
          <div class="category-distribution-header">
            <div class="category-name-group">
              <span class="cat-dot" style="background: ${color}; width: 8px; height: 8px; border-radius: 50%; display: inline-block;"></span>
              <span>${escapeHtml(catName)}</span>
            </div>
            <div class="distribution-pill-group">
              <span class="distribution-percent-pill">${percent}%</span>
              <span class="distribution-amount-pill">${formatCurrency(catAmount)}</span>
            </div>
          </div>
          <div class="category-distribution-bar">
            <div class="distribution-progress-fill" style="width: ${percent}%; background: ${color};"></div>
          </div>
        `;
        list.appendChild(itemEl);
      });
    }
  });
}

// Interactive Time-Range Analytics Filter State
let activeAnalyticsRange = '6M';

window.switchAnalyticsRange = function(range) {
  activeAnalyticsRange = range;
  document.querySelectorAll('#analytics-range-selector .chart-range-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.range === range);
  });
  renderMonthlyTrendChart();
};

// Chart.js Expenditure Trend Multi-Range Chart Engine
function renderMonthlyTrendChart() {
  if (!monthlyTrendChartContainer) return;
  if (trendChartInstance) { trendChartInstance.destroy(); trendChartInstance = null; }
  monthlyTrendChartContainer.innerHTML = '';

  const titleEl = document.getElementById('trend-chart-title');

  if (expenses.length === 0) {
    monthlyTrendChartContainer.innerHTML = `
      <div class="empty-state-small">
        <i class="fa-solid fa-chart-column empty-state-icon"></i>
        <p>No historical data recorded yet.</p>
      </div>
    `;
    return;
  }

  let labels = [];
  let dataPoints = [];
  let isDaily = false;
  const today = new Date();

  if (activeAnalyticsRange === '7D') {
    isDaily = true;
    if (titleEl) titleEl.textContent = '7-Day Expenditure Trend';
    for (let i = 6; i >= 0; i--) {
      const d = new Date(today);
      d.setDate(today.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      const dayLabel = d.toLocaleDateString('en-US', { weekday: 'short', month: 'numeric', day: 'numeric' });
      const dayTotal = expenses.filter(e => e.date === dateStr).reduce((sum, e) => sum + Number(e.amount || 0), 0);
      labels.push(dayLabel);
      dataPoints.push(dayTotal);
    }
  } else if (activeAnalyticsRange === '30D') {
    isDaily = true;
    if (titleEl) titleEl.textContent = '30-Day Expenditure Trend';
    for (let i = 29; i >= 0; i--) {
      const d = new Date(today);
      d.setDate(today.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      const dayLabel = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      const dayTotal = expenses.filter(e => e.date === dateStr).reduce((sum, e) => sum + Number(e.amount || 0), 0);
      labels.push(dayLabel);
      dataPoints.push(dayTotal);
    }
  } else {
    // Monthly View (6M, 1Y, ALL)
    const monthlyTotals = {};
    expenses.forEach(item => {
      if (item.date && item.date.length >= 7) {
        const ym = item.date.substring(0, 7);
        monthlyTotals[ym] = (monthlyTotals[ym] || 0) + Number(item.amount || 0);
      }
    });

    let allMonths = Object.keys(monthlyTotals).sort();
    if (activeAnalyticsRange === '6M') {
      if (titleEl) titleEl.textContent = '6-Month Expenditure Trend';
      allMonths = allMonths.slice(-6);
    } else if (activeAnalyticsRange === '1Y') {
      if (titleEl) titleEl.textContent = '12-Month Expenditure Trend';
      allMonths = allMonths.slice(-12);
    } else {
      if (titleEl) titleEl.textContent = 'All-Time Spending History';
    }

    labels = allMonths.map(ym => formatMonthLabel(ym).split(' ')[0]);
    dataPoints = allMonths.map(ym => monthlyTotals[ym] || 0);
  }

  const canvas = document.createElement('canvas');
  canvas.style.height = '180px';
  monthlyTrendChartContainer.appendChild(canvas);

  if (typeof Chart !== 'undefined') {
    const ctx = canvas.getContext('2d');
    let gradient = null;
    if (ctx) {
      gradient = ctx.createLinearGradient(0, 0, 0, 180);
      gradient.addColorStop(0, 'rgba(52, 211, 153, 0.4)');
      gradient.addColorStop(1, 'rgba(52, 211, 153, 0.01)');
    }

    trendChartInstance = new Chart(canvas, {
      type: isDaily ? 'line' : 'bar',
      data: {
        labels: labels,
        datasets: [{
          data: dataPoints,
          backgroundColor: isDaily ? (gradient || 'rgba(52, 211, 153, 0.2)') : labels.map((_, idx) => (selectedMonth !== 'ALL' && labels[idx] === formatMonthLabel(selectedMonth).split(' ')[0]) ? '#34D399' : 'rgba(56, 189, 248, 0.35)'),
          hoverBackgroundColor: isDaily ? undefined : labels.map((_, idx) => (selectedMonth !== 'ALL' && labels[idx] === formatMonthLabel(selectedMonth).split(' ')[0]) ? '#34D399' : 'rgba(56, 189, 248, 0.75)'),
          borderColor: isDaily ? '#34D399' : undefined,
          borderWidth: isDaily ? 2.5 : 0,
          pointBackgroundColor: '#34D399',
          pointBorderColor: '#0E131A',
          pointBorderWidth: 2,
          pointRadius: isDaily ? (activeAnalyticsRange === '7D' ? 4 : 2.5) : 0,
          pointHoverRadius: 6,
          fill: isDaily,
          tension: 0.35,
          borderRadius: isDaily ? 0 : 6,
          borderSkipped: false
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        onClick: (e, elements) => {
          if (!isDaily && elements && elements.length > 0) {
            const idx = elements[0].index;
            selectMonthFromChart(labels[idx]);
          }
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: 'rgba(14, 19, 26, 0.95)',
            titleColor: '#F2F5FA',
            bodyColor: '#A6B0C3',
            borderColor: 'rgba(255, 255, 255, 0.1)',
            borderWidth: 1,
            callbacks: {
              label: function(context) {
                return `${context.label}: ${formatCurrency(context.raw)}`;
              }
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: '#A6B0C3', font: { family: 'Poppins', size: 11, weight: '600' } }
          },
          y: {
            grid: { color: 'rgba(255, 255, 255, 0.05)' },
            ticks: {
              color: '#5F6A80',
              font: { family: 'IBM Plex Mono', size: 10 },
              callback: function(val) { return '₹' + val; }
            }
          }
        }
      }
    });
  }
}

function selectMonthFromChart(ym) {
  selectedMonth = ym;
  updateMonthPickerOptions();
  updateUI();
}

window.switchTxLogTab = function(tab) {
  currentTxLogTab = tab;
  const btnExpense = document.getElementById('btn-tx-tab-expense');
  const btnIncome = document.getElementById('btn-tx-tab-income');
  const titleEl = document.getElementById('tx-view-title');

  if (btnExpense) btnExpense.classList.toggle('active', tab === 'expense');
  if (btnIncome) btnIncome.classList.toggle('active', tab === 'income');
  if (titleEl) titleEl.textContent = tab === 'income' ? 'Extra Income Logs' : 'Expense Logs';

  updateUI();
};

window.openAccountBalanceModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const modal = document.getElementById('account-balance-modal');
  const input = document.getElementById('account-balance-input');
  if (input) input.value = accountBalance > 0 ? accountBalance : '';
  if (modal) {
    modal.classList.remove('hidden');
    modal.style.setProperty('display', 'flex', 'important');
    modal.style.setProperty('opacity', '1', 'important');
    modal.style.setProperty('visibility', 'visible', 'important');
    modal.style.setProperty('z-index', '100000', 'important');
    modal.style.setProperty('pointer-events', 'auto', 'important');
    setTimeout(() => { if (input) input.focus(); }, 50);
  }
};

window.closeAccountBalanceModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const modal = document.getElementById('account-balance-modal');
  if (modal) {
    modal.classList.add('hidden');
    modal.style.setProperty('display', 'none', 'important');
  }
};

window.handleSaveAccountBalance = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const input = document.getElementById('account-balance-input');
  const val = input ? parseFloat(input.value) : 0;
  if (!isNaN(val) && val >= 0) {
    accountBalance = val;
    saveState();
    updateUI();
    window.closeAccountBalanceModal();
    if (typeof showToast === 'function') showToast('Total Account Money updated successfully!');
  }
};

function renderTransactionsTable(monthFilteredExpenses) {
  if (!transactionsTbody) return;

  let searchTerm = filterSearchInput ? filterSearchInput.value.toLowerCase().trim() : '';
  const selectedCat = filterCategorySelect ? filterCategorySelect.value : 'ALL';
  const todayStr = getLocalDateString();

  if (currentTxLogTab === 'income') {
    const filteredIncomes = incomes.filter(inc => {
      if (selectedMonth !== 'ALL' && inc.date && !inc.date.startsWith(selectedMonth)) return false;
      if (searchTerm && !(inc.source || '').toLowerCase().includes(searchTerm)) return false;
      return true;
    });

    transactionsTbody.innerHTML = '';
    if (filteredIncomes.length === 0) {
      if (emptyTableMsg) emptyTableMsg.classList.remove('hidden');
      return;
    }
    if (emptyTableMsg) emptyTableMsg.classList.add('hidden');

    filteredIncomes.forEach(inc => {
      const tr = document.createElement('tr');
      tr.className = 'tx-table-row';
      tr.innerHTML = `
        <td data-label="Date" class="font-medium mono">${escapeHtml(inc.date || 'Active')}</td>
        <td data-label="Category"><span class="category-badge-pill" style="border-left: 3px solid var(--sky); background: rgba(56, 189, 248, 0.08); color: #38bdf8;"><i class="fa-solid fa-coins" style="margin-right: 4px;"></i> Extra Income</span></td>
        <td data-label="Description" class="description-cell">${escapeHtml(inc.source || 'Income Source')}</td>
        <td data-label="Payment"><span class="payment-badge-pill"><i class="fa-solid fa-hand-holding-dollar text-sky"></i> Freelance / Extra</span></td>
        <td data-label="Amount" class="text-right font-bold text-amount text-sky">+${formatCurrency(inc.amount || 0)}</td>
        <td class="text-center td-action">
          <button type="button" class="icon-btn action-btn-del" title="Delete Income Record" onclick="if(window.deleteIncome){event.preventDefault();event.stopPropagation();window.deleteIncome('${inc.id}');}">
            <i class="fa-solid fa-trash-can"></i>
          </button>
        </td>
      `;
      transactionsTbody.appendChild(tr);
    });
    return;
  }

  const filtered = monthFilteredExpenses.filter(item => {
    let matchesSearch = true;
    if (searchTerm) {
      const descMatch = (item.description || '').toLowerCase().includes(searchTerm);
      const catMatch = (item.category || '').toLowerCase().includes(searchTerm);
      const payMatch = (item.payment || '').toLowerCase().includes(searchTerm);
      const dateMatch = (item.date || '').toLowerCase().includes(searchTerm);
      const amtMatch = String(item.amount || '').includes(searchTerm);

      let rangeMatch = false;
      if (searchTerm.startsWith('>') && !isNaN(parseFloat(searchTerm.slice(1)))) {
        rangeMatch = Number(item.amount || 0) >= parseFloat(searchTerm.slice(1));
      } else if (searchTerm.startsWith('<') && !isNaN(parseFloat(searchTerm.slice(1)))) {
        rangeMatch = Number(item.amount || 0) <= parseFloat(searchTerm.slice(1));
      }

      matchesSearch = descMatch || catMatch || payMatch || dateMatch || amtMatch || rangeMatch;
    }
    const matchesCat = selectedCat === 'ALL' || item.category === selectedCat;

    let matchesTime = true;
    if (activeTimeFilter === 'TODAY') {
      matchesTime = item.date === todayStr;
    }

    return matchesSearch && matchesCat && matchesTime;
  });

  transactionsTbody.innerHTML = '';

  if (filtered.length === 0) {
    if (emptyTableMsg) emptyTableMsg.classList.remove('hidden');
    return;
  }

  if (emptyTableMsg) emptyTableMsg.classList.add('hidden');
  const sorted = [...filtered].sort((a, b) => new Date(b.date) - new Date(a.date));

  const catIcons = {
    'Food & Dining': '🍔',
    'Transportation': '🚗',
    'Shopping': '🛍️',
    'Bills & Utilities': '⚡',
    'Entertainment': '🎬',
    'Health & Fitness': '💊',
    'Services & Subscriptions': '📱',
    'Miscellaneous': '📦'
  };

  const paymentIcons = {
    'UPI': '<i class="fa-solid fa-mobile-screen-button text-emerald"></i>',
    'Credit Card': '<i class="fa-solid fa-credit-card text-sky"></i>',
    'Debit Card': '<i class="fa-solid fa-building-columns text-violet"></i>',
    'Cash': '<i class="fa-solid fa-money-bill-wave text-amber"></i>',
    'Net Banking': '<i class="fa-solid fa-globe text-rose"></i>',
    'Auto-Pay': '<i class="fa-solid fa-arrows-rotate text-purple"></i>'
  };

  sorted.forEach(item => {
    const tr = document.createElement('tr');
    tr.className = 'tx-table-row';
    const color = categoryColors[item.category] || '#3b82f6';
    const icon = catIcons[item.category] || '🏷️';
    const payIcon = paymentIcons[item.payment] || '<i class="fa-solid fa-credit-card"></i>';

    tr.innerHTML = `
      <td data-label="Date" class="font-medium mono">${escapeHtml(item.date)}</td>
      <td data-label="Category"><span class="category-badge-pill" style="border-left: 3px solid ${color}; background: rgba(255,255,255,0.03);"><span class="cat-emoji">${icon}</span> ${escapeHtml(item.category)}</span></td>
      <td data-label="Description" class="description-cell">${escapeHtml(item.description)} ${item.receipt ? '<i class="fa-solid fa-paperclip text-emerald ml-1" title="Receipt Attached"></i>' : ''}</td>
      <td data-label="Payment"><span class="payment-badge-pill">${payIcon} <span>${escapeHtml(item.payment)}</span></span></td>
      <td data-label="Amount" class="text-right font-bold text-amount text-rose">-${formatCurrency(item.amount)}</td>
      <td class="text-center td-action">
        ${item.receipt ? `<button type="button" class="btn-receipt-view mr-1" title="View Attached Receipt" onclick="if(window.openReceiptModal)window.openReceiptModal('${item.id}')"><i class="fa-solid fa-paperclip"></i></button>` : ''}
        <button type="button" class="icon-btn action-btn-edit mr-1" title="Edit Transaction" onclick="if(window.openEditTransactionModal)window.openEditTransactionModal('${escapeHtml(item.id)}')">
          <i class="fa-solid fa-pen-to-square"></i>
        </button>
        <button type="button" class="icon-btn action-btn-del" data-delete-tx="${escapeHtml(item.id)}" title="Delete Transaction">
          <i class="fa-solid fa-trash-can"></i>
        </button>
      </td>
    `;
    transactionsTbody.appendChild(tr);
  });
}

function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str).replace(/[&<>"']/g, function(m) {
    return {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;'
    }[m];
  });
}

// ---------- Event Handlers ----------
if (expenseForm) {
  expenseForm.addEventListener('submit', (e) => {
    e.preventDefault();

    const amount = parseFloat(expAmountInput ? expAmountInput.value : 0);
    const category = expCategorySelect ? expCategorySelect.value : 'Miscellaneous';
    const description = expDescriptionInput ? expDescriptionInput.value.trim() : '';
    const payment = expPaymentSelect ? expPaymentSelect.value : 'UPI';
    const date = expDateInput ? expDateInput.value : getLocalDateString();

    if (isNaN(amount) || amount <= 0 || amount > 99999999) {
      showAlert('Invalid Input', 'Please enter a valid expense amount (max ₹99,999,999).');
      return;
    }
    if (description.length > 200) {
      showAlert('Invalid Input', 'Description is too long (max 200 characters).');
      return;
    }

    const newExpense = {
      id: Date.now().toString(36) + Math.random().toString(36).slice(2, 7),
      amount,
      category,
      description,
      payment,
      date,
      receipt: pendingReceiptDataUrl || null
    };

    expenses.push(newExpense);
    saveState();
    try { if (window.dispatchExpenseLoggedEmail) window.dispatchExpenseLoggedEmail(newExpense); } catch(err){}
    
    // Automatically switch month to the added expense month if different
    if (date && date.length >= 7) {
      selectedMonth = date.substring(0, 7);
    }

    updateMonthPickerOptions();
    updateUI();

    expAmountInput.value = '';
    expDescriptionInput.value = '';
    setTodayDateDefault();
    expAmountInput.focus();
  });
}

async function deleteTransaction(id) {
  if (!id) return;
  const ok = await showConfirm('Delete Transaction', 'Are you sure you want to delete this expense transaction record?', true);
  if (ok) {
    expenses = expenses.filter(item => String(item.id) !== String(id));
    saveState();

    // Dual-delete from relational expenses table in Supabase
    const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
    if (supaClient) {
      supaClient.from('expenses').delete().eq('id', String(id)).catch(() => {});
    }

    updateMonthPickerOptions();
    updateUI();
    if (typeof showToast === 'function') showToast('Transaction deleted & synced');
  }
}
window.deleteTransaction = deleteTransaction;

window.openEditTransactionModal = function(id) {
  const tx = expenses.find(e => String(e.id) === String(id));
  if (!tx) return;
  const modal = document.getElementById('edit-transaction-modal');
  const idInput = document.getElementById('edit-tx-id');
  const descInput = document.getElementById('edit-tx-description');
  const amountInput = document.getElementById('edit-tx-amount');
  const dateInput = document.getElementById('edit-tx-date');
  const catSelect = document.getElementById('edit-tx-category');
  const paySelect = document.getElementById('edit-tx-payment');

  if (idInput) idInput.value = tx.id;
  if (descInput) descInput.value = tx.description || tx.title || '';
  if (amountInput) amountInput.value = tx.amount || 0;
  if (dateInput) dateInput.value = tx.date || getLocalDateString();
  if (catSelect) catSelect.value = tx.category || 'Food & Dining';
  if (paySelect) paySelect.value = tx.payment || tx.payment_method || 'Credit Card';

  if (modal) {
    modal.classList.remove('hidden');
    modal.style.setProperty('display', 'flex', 'important');
    modal.style.setProperty('opacity', '1', 'important');
    modal.style.setProperty('visibility', 'visible', 'important');
    modal.style.setProperty('z-index', '100000', 'important');
    modal.style.setProperty('pointer-events', 'auto', 'important');
  }
};

window.closeEditTransactionModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const modal = document.getElementById('edit-transaction-modal');
  if (modal) {
    modal.classList.add('hidden');
    modal.style.setProperty('display', 'none', 'important');
  }
};

window.handleSaveEditTransaction = async function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const idInput = document.getElementById('edit-tx-id');
  const descInput = document.getElementById('edit-tx-description');
  const amountInput = document.getElementById('edit-tx-amount');
  const dateInput = document.getElementById('edit-tx-date');
  const catSelect = document.getElementById('edit-tx-category');
  const paySelect = document.getElementById('edit-tx-payment');

  const id = idInput ? idInput.value : '';
  const amount = parseFloat(amountInput ? amountInput.value : 0);
  const description = descInput ? descInput.value.trim() : '';
  const date = dateInput ? dateInput.value : getLocalDateString();
  const category = catSelect ? catSelect.value : 'Food & Dining';
  const payment = paySelect ? paySelect.value : 'Credit Card';

  if (!id || isNaN(amount) || amount <= 0 || !description) {
    showAlert('Invalid Input', 'Please enter a valid description and amount.');
    return;
  }

  const idx = expenses.findIndex(exp => String(exp.id) === String(id));
  if (idx !== -1) {
    expenses[idx] = {
      ...expenses[idx],
      amount,
      description,
      title: description,
      date,
      category,
      payment
    };
    saveState();

    // Direct dual-write update to relational expenses table in Supabase
    const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
    if (supaClient) {
      let userId = currentUserId;
      if (!userId && supaClient.auth) {
        try {
          const sess = await supaClient.auth.getSession();
          userId = sess?.data?.session?.user?.id;
        } catch (_) {}
      }
      if (userId) {
        supaClient.from('expenses').upsert({
          id: String(id),
          user_id: userId,
          amount,
          title: description,
          category,
          payment_method: payment,
          date,
          type: 'expense',
          updated_at: new Date().toISOString()
        }, { onConflict: 'id' }).catch(() => {});
      }
    }

    window.closeEditTransactionModal();
    updateMonthPickerOptions();
    updateUI();
    if (typeof showToast === 'function') showToast('Transaction updated successfully & synced to mobile!');
  }
};

if (filterSearchInput) filterSearchInput.addEventListener('input', updateUI);
if (filterCategorySelect) filterCategorySelect.addEventListener('change', updateUI);

document.querySelectorAll('.filter-chip').forEach(chip => {
  chip.addEventListener('click', () => {
    document.querySelectorAll('.filter-chip').forEach(c => c.classList.remove('active'));
    chip.classList.add('active');
    activeTimeFilter = chip.dataset.filter || 'ALL';
    updateUI();
  });
});

// Budget Modal Handlers
function openBudgetModal() {
  if (!modalBudgetInput || !budgetModal) return;
  if (modalTitleText) {
    modalTitleText.textContent = budget > 0 ? 'Edit Monthly Budget Cap' : 'Set Monthly Budget Cap';
  }
  modalBudgetInput.value = budget > 0 ? budget : '';
  budgetModal.classList.remove('hidden');
  setTimeout(() => {
    try {
      modalBudgetInput.focus();
      if (typeof modalBudgetInput.select === 'function') {
        modalBudgetInput.select();
      }
    } catch (err) {
      // Ignore selection errors on unsupported platforms
    }
  }, 50);
}

if (btnEditBudget) btnEditBudget.addEventListener('click', openBudgetModal);
if (btnSidebarBudgetEdit) btnSidebarBudgetEdit.addEventListener('click', openBudgetModal);
if (statBudgetCard) statBudgetCard.addEventListener('click', openBudgetModal);

function closeModal(targetModal) {
  const hideElement = (el) => {
    if (!el) return;
    el.classList.add('hidden');
    el.style.setProperty('display', 'none', 'important');
    el.style.setProperty('opacity', '0', 'important');
    el.style.setProperty('visibility', 'hidden', 'important');
    el.style.setProperty('pointer-events', 'none', 'important');
  };

  if (targetModal) {
    hideElement(targetModal);
  } else {
    // Close all modals if no specific target
    [budgetModal, subModal, document.getElementById('confirm-modal'), document.getElementById('alert-modal'), document.getElementById('welcome-modal'), document.getElementById('edit-profile-modal'), document.getElementById('signout-modal')].forEach(hideElement);
  }
}

if (modalCancelBtn) modalCancelBtn.addEventListener('click', () => closeModal(budgetModal));
if (modalCloseBtn) modalCloseBtn.addEventListener('click', () => closeModal(budgetModal));
if (subModalCloseBtn) subModalCloseBtn.addEventListener('click', () => closeModal(subModal));
if (subModalCancelBtn) subModalCancelBtn.addEventListener('click', () => closeModal(subModal));

// Backdrop Click to Dismiss Modals
if (budgetModal) {
  budgetModal.addEventListener('click', (e) => {
    if (e.target === budgetModal) closeModal(budgetModal);
  });
}
if (subModal) {
  subModal.addEventListener('click', (e) => {
    if (e.target === subModal) closeModal(subModal);
  });
}

function handleSaveBudget(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const raw = modalBudgetInput ? modalBudgetInput.value : '';
  // Clean commas, currency symbols, spaces, keeping digits and decimal point
  const cleaned = raw.toString().replace(/[^0-9.]/g, '').trim();
  const newBudget = parseFloat(cleaned);

  if (cleaned === '' || isNaN(newBudget) || newBudget <= 0) {
    showAlert('Invalid Budget', 'Please enter a valid budget amount.');
    return;
  }

  // Strict Validation: Total Account Money must be set first & Budget cannot exceed Total Account Money
  const totalAllTimeIncome = incomes.reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const currentTotalAccountMoney = accountBalance + totalAllTimeIncome;

  if (currentTotalAccountMoney <= 0) {
    showAlert('Total Account Money Required', 'Please enter your Total Account Money first before setting a Monthly Budget! Your budget is allocated directly from your available account funds.');
    closeModal(budgetModal);
    if (typeof openAccountBalanceModal === 'function') openAccountBalanceModal();
    return;
  }

  if (newBudget > currentTotalAccountMoney) {
    showAlert('Budget Exceeds Account Balance', `Your Monthly Budget (${formatCurrency(newBudget)}) cannot exceed your Total Account Money (${formatCurrency(currentTotalAccountMoney)}). You cannot set a spending budget higher than your total account balance!`);
    return;
  }

  budget = newBudget;
  saveState();
  updateUI();
  closeModal(budgetModal);
}

window.handleSaveBudget = handleSaveBudget;

if (modalBudgetInput) {
  modalBudgetInput.addEventListener('input', (e) => {
    // Restrict input to digits and an optional single decimal point only
    let val = e.target.value.replace(/[^0-9.]/g, '');
    const parts = val.split('.');
    if (parts.length > 2) {
      val = parts[0] + '.' + parts.slice(1).join('');
    }
    e.target.value = val;
  });
}

if (budgetForm) {
  budgetForm.addEventListener('submit', handleSaveBudget);
} else if (modalSaveBtn) {
  modalSaveBtn.addEventListener('click', handleSaveBudget);
}

window.renderIncomeList = function() {
  const container = document.getElementById('income-list-container');
  const badge = document.getElementById('income-total-badge');
  if (!container) return;

  const targetIncomes = (Array.isArray(incomes) && incomes.length > 0) ? incomes : [];
  const total = targetIncomes.reduce((sum, item) => sum + Number(item.amount || 0), 0);
  if (badge) badge.textContent = formatCurrency(total);

  if (targetIncomes.length === 0) {
    container.innerHTML = `
      <div style="text-align:center; padding:1.2rem; color:var(--text-muted); font-size:0.85rem;">
        <i class="fa-solid fa-circle-info" style="margin-right:4px;"></i> No active income sources logged yet. Add one above!
      </div>`;
    return;
  }

  container.innerHTML = targetIncomes.map(inc => `
    <div class="glass-panel" style="display:flex; align-items:center; justify-content:space-between; padding:0.65rem 0.9rem; background:rgba(255,255,255,0.03); border:1px solid rgba(255,255,255,0.06); border-radius:var(--radius-md); margin-bottom:0.4rem;">
      <div>
        <div style="font-weight:600; font-size:0.9rem; color:var(--text-hi);">${typeof escapeHtml === 'function' ? escapeHtml(inc.source || 'Income Source') : (inc.source || 'Income Source')}</div>
        <div style="font-size:0.75rem; color:var(--text-muted);">${inc.date || 'Active Record'}</div>
      </div>
      <div style="display:flex; align-items:center; gap:0.8rem;">
        <span class="mono text-sky" style="font-weight:700; font-size:0.95rem;">${formatCurrency(inc.amount || 0)}</span>
        <button type="button" class="icon-btn action-btn-del" title="Delete Income Record" onclick="if(window.deleteIncome){event.preventDefault();event.stopPropagation();window.deleteIncome('${inc.id}');}" style="color:var(--rose); background:rgba(244,63,94,0.12); border:1px solid rgba(244,63,94,0.25); border-radius:var(--radius-sm); width:32px; height:32px; display:inline-flex; align-items:center; justify-content:center; cursor:pointer;">
          <i class="fa-solid fa-trash-can" style="font-size:0.85rem;"></i>
        </button>
      </div>
    </div>
  `).join('');
};

window.deleteIncome = function(incomeId) {
  if (!incomeId) return;

  incomes = incomes.filter(inc => String(inc.id) !== String(incomeId));

  saveState();
  updateUI();
  if (window.renderIncomeList) window.renderIncomeList();
  showToast('Income record removed successfully');
};

// ---------- Income Modal Logic ----------
window.openIncomeModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const incomeModal = document.getElementById('income-modal');
  const sourceInput = document.getElementById('income-source-input');
  const amountInput = document.getElementById('income-amount-input');
  const addToBudgetCheck = document.getElementById('income-add-to-budget');
  if (sourceInput) sourceInput.value = '';
  if (amountInput) amountInput.value = '';
  if (addToBudgetCheck) addToBudgetCheck.checked = true;
  if (window.renderIncomeList) window.renderIncomeList();
  if (incomeModal) {
    incomeModal.classList.remove('hidden');
    incomeModal.style.setProperty('display', 'flex', 'important');
    incomeModal.style.setProperty('opacity', '1', 'important');
    incomeModal.style.setProperty('visibility', 'visible', 'important');
    incomeModal.style.setProperty('z-index', '100000', 'important');
    incomeModal.style.setProperty('pointer-events', 'auto', 'important');
  }
  if (sourceInput) sourceInput.focus();
};

window.closeIncomeModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const incomeModal = document.getElementById('income-modal');
  if (incomeModal) {
    incomeModal.classList.add('hidden');
    incomeModal.style.setProperty('display', 'none', 'important');
    incomeModal.style.setProperty('pointer-events', 'none', 'important');
  }
};

window.handleSaveIncome = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const sourceInput = document.getElementById('income-source-input');
  const amountInput = document.getElementById('income-amount-input');
  const addToBudgetCheck = document.getElementById('income-add-to-budget');
  const source = sourceInput ? sourceInput.value.trim() : '';
  const amount = amountInput ? parseFloat(amountInput.value) : 0;
  const addToBudget = addToBudgetCheck ? addToBudgetCheck.checked : true;

  if (!source || isNaN(amount) || amount <= 0) {
    showAlert('Invalid Income Details', 'Please enter a valid income source description and positive amount.');
    return;
  }

  const newIncome = {
    id: 'inc_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
    source: source,
    amount: amount,
    date: getLocalDateString(),
    addedToBudget: addToBudget
  };

  incomes.push(newIncome);

  saveState();
  updateUI();
  if (window.renderIncomeList) window.renderIncomeList();
  showToast('✓ Income logged successfully!');
  if (sourceInput) sourceInput.value = '';
  if (amountInput) amountInput.value = '';
};

// Add Subscription Modal
function openSubscriptionModal() {
  if (!subModal) return;
  editingSubId = null;
  if (subModalTitle) subModalTitle.innerHTML = '<i class="fa-solid fa-calendar-plus"></i> Add Recurring Bill';
  if (subSubmitBtn) subSubmitBtn.textContent = 'Add Subscription';
  if (subNameInput) subNameInput.value = '';
  if (subAmountInput) subAmountInput.value = '';
  if (subDueDayInput) subDueDayInput.value = '';
  if (subStartMonthInput) {
    const currentYM = typeof getCurrentYearMonth === 'function' ? getCurrentYearMonth() : new Date().toISOString().slice(0, 7);
    subStartMonthInput.value = currentYM;
  }
  const autoPayEl = document.getElementById('sub-autopay');
  if (autoPayEl) autoPayEl.checked = false;

  subModal.classList.remove('hidden');
  subModal.style.removeProperty('display');
  subModal.style.removeProperty('opacity');
  subModal.style.removeProperty('visibility');
  subModal.style.removeProperty('pointer-events');
  if (subNameInput) subNameInput.focus();
}

function editSubscription(subId) {
  if (!subId || !subModal) return;
  const sub = subscriptions.find(s => String(s.id) === String(subId));
  if (!sub) return;

  editingSubId = sub.id;
  if (subModalTitle) subModalTitle.innerHTML = '<i class="fa-solid fa-pen-to-square"></i> Edit Recurring Bill';
  if (subSubmitBtn) subSubmitBtn.textContent = 'Save Changes';

  if (subNameInput) subNameInput.value = sub.name || sub.title || '';
  if (subAmountInput) subAmountInput.value = sub.amount || '';
  if (subCategorySelect) subCategorySelect.value = sub.category || 'Services & Subscriptions';
  if (subStartMonthInput) {
    const currentYM = typeof getCurrentYearMonth === 'function' ? getCurrentYearMonth() : new Date().toISOString().slice(0, 7);
    subStartMonthInput.value = sub.startMonth || sub.start_month || currentYM;
  }
  if (subDueDayInput) subDueDayInput.value = sub.dueDay || sub.due_day || (sub.due_date ? new Date(sub.due_date).getDate() : 1);
  const autoPayEl = document.getElementById('sub-autopay');
  if (autoPayEl) autoPayEl.checked = Boolean(sub.autoPay || sub.auto_pay);

  subModal.classList.remove('hidden');
  subModal.style.removeProperty('display');
  subModal.style.removeProperty('opacity');
  subModal.style.removeProperty('visibility');
  subModal.style.removeProperty('pointer-events');
  if (subNameInput) subNameInput.focus();
}

window.editSubscription = editSubscription;

function handleSubFormSubmit(e) {
  if (e && e.preventDefault) e.preventDefault();
  if (e && e.stopPropagation) e.stopPropagation();

  const name = subNameInput ? subNameInput.value.trim() : '';
  const amount = subAmountInput ? parseFloat(subAmountInput.value) : NaN;
  const dueDay = subDueDayInput ? parseInt(subDueDayInput.value, 10) : NaN;
  const category = subCategorySelect ? subCategorySelect.value : 'Services & Subscriptions';
  const currentYM = typeof getCurrentYearMonth === 'function' ? getCurrentYearMonth() : new Date().toISOString().slice(0, 7);
  const startMonth = subStartMonthInput && subStartMonthInput.value ? subStartMonthInput.value : currentYM;
  const autoPayEl = document.getElementById('sub-autopay');
  const autoPay = autoPayEl ? autoPayEl.checked : false;

  if (!name || isNaN(amount) || amount <= 0 || isNaN(dueDay) || dueDay < 1 || dueDay > 31) {
    showAlert('Invalid Details', 'Please enter a valid subscription name, positive amount, and due day (1–31).');
    return false;
  }

  const [yr, mo] = startMonth.split('-');
  const padDay = String(dueDay).padStart(2, '0');
  const computedDueDate = `${yr}-${mo}-${padDay}`;

  if (editingSubId) {
    const existing = subscriptions.find(s => String(s.id) === String(editingSubId));
    if (existing) {
      existing.name = name;
      existing.title = name;
      existing.amount = amount;
      existing.dueDay = dueDay;
      existing.due_day = dueDay;
      existing.category = category;
      existing.startMonth = startMonth;
      existing.start_month = startMonth;
      existing.dueDate = computedDueDate;
      existing.due_date = computedDueDate;
      existing.autoPay = autoPay;
      existing.auto_pay = autoPay;
      existing.updated_at = new Date().toISOString();
    }
    editingSubId = null;
    showToast('Recurring bill updated successfully');
  } else {
    const newSub = {
      id: 'sub_' + Date.now().toString(36),
      name,
      title: name,
      amount,
      dueDay,
      due_day: dueDay,
      category,
      startMonth,
      start_month: startMonth,
      dueDate: computedDueDate,
      due_date: computedDueDate,
      autoPay,
      auto_pay: autoPay,
      lastPaidMonth: '',
      is_active: true
    };
    subscriptions.push(newSub);
    try { if (window.dispatchSubscriptionAddedEmail) window.dispatchSubscriptionAddedEmail(newSub); } catch(err){}
    showToast('Recurring bill added successfully');
  }

  saveState();
  updateUI();
  closeModal(subModal);
  return false;
}

window.handleSubFormSubmit = handleSubFormSubmit;

if (btnAddSub) btnAddSub.addEventListener('click', openSubscriptionModal);
if (btnAddSubInline) btnAddSubInline.addEventListener('click', openSubscriptionModal);
if (subForm) subForm.addEventListener('submit', handleSubFormSubmit);

// Export CSV
if (btnExportCsv) {
  btnExportCsv.addEventListener('click', () => {
    const exportList = selectedMonth === 'ALL'
      ? expenses
      : expenses.filter(item => item.date && item.date.startsWith(selectedMonth));

    if (exportList.length === 0) {
      showAlert('No Data to Export', 'No expense records found for ' + (selectedMonth === 'ALL' ? 'All Time' : formatMonthLabel(selectedMonth)) + '.');
      return;
    }

    let csvContent = '\uFEFFDate,Category,Description,Payment Method,Amount (INR)\n';
    exportList.forEach(item => {
      const safeDate = (item.date || '').replace(/"/g, '""');
      const safeCat = (item.category || '').replace(/"/g, '""');
      const safeDesc = (item.description || '').replace(/"/g, '""').replace(/[\r\n]+/g, ' ');
      const safePay = (item.payment || '').replace(/"/g, '""');
      const row = `"${safeDate}","${safeCat}","${safeDesc}","${safePay}",${item.amount}`;
      csvContent += row + '\n';
    });

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    const monthLabel = selectedMonth === 'ALL' ? 'AllTime' : selectedMonth;
    link.download = `Expense_Report_${monthLabel}_${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(link);
    link.click();
    setTimeout(() => {
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
    }, 100);
  });
}

// Reset All Data
async function resetAllData(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }

  const ok = await showConfirm(
    'Reset All Financial Data',
    'This will permanently wipe all your local and cloud data. Continue?',
    true
  );
  if (!ok) return;

  budget = 0;
  accountBalance = 0;
  expenses = [];
  subscriptions = [];
  incomes = [];
  savingsGoals = [];
  selectedMonth = getCurrentYearMonth();

  // Reset all LocalStorage keys cleanly
  try {
    localStorage.setItem('expense_cal_web_budget', '0');
    localStorage.setItem('expense_cal_web_account_balance', '0');
    localStorage.setItem('expense_cal_web_expenses', '[]');
    localStorage.setItem('expense_cal_expenses', '[]');
    localStorage.setItem('expense_cal_web_subscriptions', '[]');
    localStorage.setItem('expense_cal_subscriptions', '[]');
    localStorage.setItem('expense_cal_web_incomes', '[]');
    localStorage.setItem('expense_cal_incomes', '[]');
    localStorage.setItem('expense_cal_savings_goals', '[]');
    localStorage.setItem('expense_cal_web_savings_goals', '[]');
    localStorage.removeItem('expense_cal_user_emeralds_v3');
  } catch (err) {
    console.warn('LocalStorage reset notice:', err);
  }

  // Ensure state persistence adapter is updated
  if (typeof saveState === 'function') {
    try { await saveState(); } catch(err) {}
  }

  updateMonthPickerOptions();
  updateUI();
  if (typeof renderSavingsGoals === 'function') renderSavingsGoals();
  if (typeof renderTransactionsTable === 'function') renderTransactionsTable([]);

  if (typeof setSyncStatus === 'function') setSyncStatus('syncing');

  let cloudSuccess = false;

  // 1. Reset Supabase Cloud Database Data with schema-valid columns & clear relational tables
  const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
  if (supaClient) {
    try {
      let uId = currentUserId;
      if (!uId && supaClient.auth) {
        const { data: sessData } = await supaClient.auth.getSession();
        if (sessData && sessData.session && sessData.session.user) {
          uId = sessData.session.user.id;
        }
      }
      if (uId) {
        const payload = {
          user_id: uId,
          budget: 0,
          starting_balance: 0.0,
          account_balance: 0.0,
          expenses: [],
          subscriptions: [],
          incomes: [],
          savings_goals: [],
          updated_at: new Date().toISOString()
        };
        const { error } = await supaClient.from('user_data').upsert(payload, { onConflict: 'user_id' });
        if (!error) {
          cloudSuccess = true;
        } else {
          // Fallback basic payload if some columns are absent
          const basicPayload = {
            user_id: uId,
            budget: 0,
            expenses: [],
            subscriptions: [],
            updated_at: new Date().toISOString()
          };
          const { error: basicErr } = await supaClient.from('user_data').upsert(basicPayload, { onConflict: 'user_id' });
          if (!basicErr) cloudSuccess = true;
        }

        // Delete relational database table rows cleanly so cross-platform sync stays at 0
        try { await supaClient.from('expenses').delete().eq('user_id', uId); } catch (_) {}
        try { await supaClient.from('subscriptions').delete().eq('user_id', uId); } catch (_) {}
        try { await supaClient.from('split_bills').delete().eq('user_id', uId); } catch (_) {}
        try { await supaClient.from('budgets').delete().eq('user_id', uId); } catch (_) {}
        try { await supaClient.from('user_emerald_rewards').delete().eq('user_id', uId); } catch (_) {}
      }
    } catch(err) {
      console.warn('Supabase reset notice:', err);
    }
  }

  if (typeof setSyncStatus === 'function') setSyncStatus('synced');
  if (cloudSuccess) {
    await showAlert('Cloud & Local Data Reset Complete', 'All expense records, bank balances, budget limits, and cloud database records have been reset cleanly.');
  } else {
    await showAlert('Data Reset Complete', 'Your local device expense records, bank balance, and budget limits have been reset.');
  }
}

// Global Action Handlers for Buttons
window.openBudgetModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }

  const totalAllTimeIncome = incomes.reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const currentTotalAccountMoney = accountBalance + totalAllTimeIncome;

  if (currentTotalAccountMoney <= 0) {
    showAlert('Total Account Money Required', 'Please enter your Total Account Money first before setting a Monthly Budget! Your budget is allocated directly from your available account funds.');
    if (typeof openAccountBalanceModal === 'function') openAccountBalanceModal();
    return;
  }

  const welcomeModal = document.getElementById('welcome-modal');
  if (welcomeModal) {
    welcomeModal.classList.add('hidden');
    welcomeModal.style.setProperty('display', 'none', 'important');
    welcomeModal.style.setProperty('pointer-events', 'none', 'important');
  }
  const budgetModal = document.getElementById('budget-modal');
  const modalBudgetInput = document.getElementById('modal-budget-input');
  if (budgetModal) {
    if (modalBudgetInput) modalBudgetInput.value = (typeof budget !== 'undefined' && budget > 0) ? budget : '';
    budgetModal.classList.remove('hidden');
    budgetModal.style.setProperty('display', 'flex', 'important');
    budgetModal.style.setProperty('opacity', '1', 'important');
    budgetModal.style.setProperty('visibility', 'visible', 'important');
    budgetModal.style.setProperty('z-index', '100000', 'important');
    budgetModal.style.setProperty('pointer-events', 'auto', 'important');
    setTimeout(() => {
      if (modalBudgetInput) {
        modalBudgetInput.focus();
        if (typeof modalBudgetInput.select === 'function') modalBudgetInput.select();
      }
    }, 50);
  }
};

window.closeBudgetModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const budgetModal = document.getElementById('budget-modal');
  if (budgetModal) {
    budgetModal.classList.add('hidden');
    budgetModal.style.setProperty('display', 'none', 'important');
  }
};

window.openIncomeModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const incomeModal = document.getElementById('income-modal');
  const sourceInput = document.getElementById('income-source-input');
  if (window.renderIncomeList) window.renderIncomeList();
  if (incomeModal) {
    incomeModal.classList.remove('hidden');
    incomeModal.style.setProperty('display', 'flex', 'important');
    incomeModal.style.setProperty('opacity', '1', 'important');
    incomeModal.style.setProperty('visibility', 'visible', 'important');
    incomeModal.style.setProperty('z-index', '100000', 'important');
    incomeModal.style.setProperty('pointer-events', 'auto', 'important');
    setTimeout(() => { if (sourceInput) sourceInput.focus(); }, 50);
  }
};

window.closeIncomeModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const incomeModal = document.getElementById('income-modal');
  if (incomeModal) {
    incomeModal.classList.add('hidden');
    incomeModal.style.setProperty('display', 'none', 'important');
  }
};

window.handleSaveIncome = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const sourceInput = document.getElementById('income-source-input');
  const amountInput = document.getElementById('income-amount-input');
  const source = sourceInput ? sourceInput.value.trim() : '';
  const amount = amountInput ? parseFloat(amountInput.value) : 0;

  if (source && amount > 0) {
    incomes.unshift({
      id: 'inc_' + Date.now() + '_' + Math.random().toString(36).substr(2, 4),
      source: source,
      amount: amount,
      date: getLocalDateString()
    });
    saveState();
    updateUI();
    if (window.renderIncomeList) window.renderIncomeList();
    if (typeof showToast === 'function') showToast('Income source added successfully!');
    if (sourceInput) sourceInput.value = '';
    if (amountInput) amountInput.value = '';
  } else {
    if (typeof showAlert === 'function') showAlert('Invalid Income Details', 'Please enter a valid description and positive amount.');
  }
};

window.openSubModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const welcomeModal = document.getElementById('welcome-modal');
  if (welcomeModal) {
    welcomeModal.classList.add('hidden');
    welcomeModal.style.setProperty('display', 'none', 'important');
    welcomeModal.style.setProperty('pointer-events', 'none', 'important');
  }
  const subModal = document.getElementById('sub-modal');
  const subNameInput = document.getElementById('sub-name');
  if (subModal) {
    subModal.classList.remove('hidden');
    subModal.style.setProperty('display', 'flex', 'important');
    subModal.style.setProperty('opacity', '1', 'important');
    subModal.style.setProperty('visibility', 'visible', 'important');
    subModal.style.setProperty('z-index', '100000', 'important');
    subModal.style.setProperty('pointer-events', 'auto', 'important');
    setTimeout(() => {
      if (subNameInput) subNameInput.focus();
    }, 50);
  }
};

window.closeSubModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const subModal = document.getElementById('sub-modal');
  if (subModal) {
    subModal.classList.add('hidden');
    subModal.style.setProperty('display', 'none', 'important');
  }
};

function getActiveCurrencySymbol() {
  const curr = typeof activeCurrency !== 'undefined' ? activeCurrency : 'INR';
  return (typeof currencyRates !== 'undefined' && currencyRates[curr]?.symbol) || (curr === 'USD' ? '$' : curr === 'EUR' ? '€' : curr === 'GBP' ? '£' : '₹');
}

function getUserDisplayName() {
  try {
    const user = (typeof currentUserId !== 'undefined' && currentUserId) || localStorage.getItem('expense_cal_user');
    if (user) {
      const match = String(user).match(/([a-zA-Z0-9._-]+)@/);
      return (match ? match[1] : String(user)).replace(/[^a-zA-Z0-9]/g, '_').substring(0, 20);
    }
  } catch(e) {}
  return 'User';
}

function generateFormattedCSVContent(selectedMonthFilter) {
  const currentSymbol = getActiveCurrencySymbol();
  const exportExpenses = selectedMonthFilter === 'ALL'
    ? (expenses || [])
    : (expenses || []).filter(item => item.date && item.date.startsWith(selectedMonthFilter));

  const exportIncomes = selectedMonthFilter === 'ALL'
    ? (incomes || [])
    : (incomes || []).filter(item => item.date && item.date.startsWith(selectedMonthFilter));

  const exportSubs = subscriptions || [];

  const totalExpenseAmt = exportExpenses.reduce((sum, item) => sum + (parseFloat(item.amount) || 0), 0);
  const totalIncomeAmt = exportIncomes.reduce((sum, item) => sum + (parseFloat(item.amount) || 0), 0);
  const totalSubsAmt = exportSubs.reduce((sum, item) => sum + (parseFloat(item.amount) || 0), 0);
  const netBalance = totalIncomeAmt - totalExpenseAmt;
  const monthTitle = selectedMonthFilter === 'ALL' ? 'All Time Overview' : (typeof formatMonthLabel === 'function' ? formatMonthLabel(selectedMonthFilter) : selectedMonthFilter);
  const formattedDate = new Date().toLocaleString();

  let csv = '\uFEFF'; // UTF-8 BOM for Excel compatibility

  // Title Banner
  csv += '================================================================================\n';
  csv += 'EXPENSE OS - OFFICIAL FINANCIAL STATEMENT & REPORT\n';
  csv += '================================================================================\n';
  csv += `Report Generated Date,"${formattedDate}"\n`;
  csv += `Selected Period,"${monthTitle}"\n`;
  csv += `Currency,"${typeof activeCurrency !== 'undefined' ? activeCurrency : 'INR'} (${currentSymbol})"\n`;
  csv += `Account User ID,"${typeof currentUserId !== 'undefined' && currentUserId ? currentUserId : 'Registered User'}"\n\n`;

  // 1. Executive Summary
  csv += '--------------------------------------------------------------------------------\n';
  csv += '1. FINANCIAL EXECUTIVE SUMMARY\n';
  csv += '--------------------------------------------------------------------------------\n';
  csv += `Metric,Amount (${typeof activeCurrency !== 'undefined' ? activeCurrency : 'INR'})\n`;
  csv += `Monthly Budget,${(parseFloat(budget) || 0).toFixed(2)}\n`;
  csv += `Total Incomes,${totalIncomeAmt.toFixed(2)}\n`;
  csv += `Total Expenses,${totalExpenseAmt.toFixed(2)}\n`;
  csv += `Total Subscriptions (Monthly),${totalSubsAmt.toFixed(2)}\n`;
  csv += `Net Balance / Cash Flow,${netBalance.toFixed(2)}\n\n`;

  // 2. Expenses Ledger
  csv += '--------------------------------------------------------------------------------\n';
  csv += '2. ITEMIZATION: EXPENSES LEDGER\n';
  csv += '--------------------------------------------------------------------------------\n';
  csv += `Date,Category,Description,Payment Method,Amount (${typeof activeCurrency !== 'undefined' ? activeCurrency : 'INR'})\n`;

  if (exportExpenses.length === 0) {
    csv += 'No expense records found for this period.\n';
  } else {
    exportExpenses.forEach(item => {
      const safeDate = (item.date || '').replace(/"/g, '""');
      const safeCat = (item.category || '').replace(/"/g, '""');
      const safeDesc = (item.description || '').replace(/"/g, '""').replace(/[\r\n]+/g, ' ');
      const safePay = (item.payment || '').replace(/"/g, '""');
      const safeAmt = (parseFloat(item.amount) || 0).toFixed(2);
      csv += `"${safeDate}","${safeCat}","${safeDesc}","${safePay}",${safeAmt}\n`;
    });
  }
  csv += `--------------------------------------------------------------------------------\n`;
  csv += `TOTAL EXPENSES,,,,${totalExpenseAmt.toFixed(2)}\n\n`;

  // 3. Subscriptions
  csv += '--------------------------------------------------------------------------------\n';
  csv += '3. ITEMIZATION: RECURRING BILLS & SUBSCRIPTIONS\n';
  csv += '--------------------------------------------------------------------------------\n';
  csv += `Subscription Name,Billing Cycle,Billing Day,Category,Amount (${typeof activeCurrency !== 'undefined' ? activeCurrency : 'INR'})\n`;

  if (exportSubs.length === 0) {
    csv += 'No active subscription records found.\n';
  } else {
    exportSubs.forEach(sub => {
      const safeName = (sub.name || '').replace(/"/g, '""');
      const safeCycle = (sub.cycle || 'Monthly').replace(/"/g, '""');
      const safeDay = (sub.day || '1st').replace(/"/g, '""');
      const safeCat = (sub.category || 'General').replace(/"/g, '""');
      const safeAmt = (parseFloat(sub.amount) || 0).toFixed(2);
      csv += `"${safeName}","${safeCycle}","${safeDay}","${safeCat}",${safeAmt}\n`;
    });
  }
  csv += `--------------------------------------------------------------------------------\n`;
  csv += `TOTAL SUBSCRIPTIONS,,,,${totalSubsAmt.toFixed(2)}\n\n`;

  // 4. Incomes
  csv += '--------------------------------------------------------------------------------\n';
  csv += '4. ITEMIZATION: INCOMES & DEPOSITS\n';
  csv += '--------------------------------------------------------------------------------\n';
  csv += `Income Source,Date Received,Category,Frequency,Amount (${typeof activeCurrency !== 'undefined' ? activeCurrency : 'INR'})\n`;

  if (exportIncomes.length === 0) {
    csv += 'No income records found for this period.\n';
  } else {
    exportIncomes.forEach(inc => {
      const safeSource = (inc.source || inc.description || 'Income').replace(/"/g, '""');
      const safeDate = (inc.date || '').replace(/"/g, '""');
      const safeCat = (inc.category || 'Salary').replace(/"/g, '""');
      const safeFreq = (inc.frequency || 'Monthly').replace(/"/g, '""');
      const safeAmt = (parseFloat(inc.amount) || 0).toFixed(2);
      csv += `"${safeSource}","${safeDate}","${safeCat}","${safeFreq}",${safeAmt}\n`;
    });
  }
  csv += `--------------------------------------------------------------------------------\n`;
  csv += `TOTAL INCOMES,,,,${totalIncomeAmt.toFixed(2)}\n\n`;

  csv += '================================================================================\n';
  csv += 'END OF FINANCIAL STATEMENT - EXPENSE OS\n';
  csv += '================================================================================\n';

  return csv;
}

function generateFormattedPDFHTML(selectedMonthFilter) {
  const currentSymbol = getActiveCurrencySymbol();
  const exportExpenses = selectedMonthFilter === 'ALL'
    ? (expenses || [])
    : (expenses || []).filter(item => item.date && item.date.startsWith(selectedMonthFilter));

  const exportIncomes = selectedMonthFilter === 'ALL'
    ? (incomes || [])
    : (incomes || []).filter(item => item.date && item.date.startsWith(selectedMonthFilter));

  const exportSubs = subscriptions || [];

  const totalExpenseAmt = exportExpenses.reduce((sum, item) => sum + (parseFloat(item.amount) || 0), 0);
  const totalIncomeAmt = exportIncomes.reduce((sum, item) => sum + (parseFloat(item.amount) || 0), 0);
  const totalSubsAmt = exportSubs.reduce((sum, item) => sum + (parseFloat(item.amount) || 0), 0);
  const netBalance = totalIncomeAmt - totalExpenseAmt;
  const monthTitle = selectedMonthFilter === 'ALL' ? 'All Time Overview' : (typeof formatMonthLabel === 'function' ? formatMonthLabel(selectedMonthFilter) : selectedMonthFilter);
  const formattedDate = new Date().toLocaleString();
  const userName = getUserDisplayName();
  const titleDoc = `${userName}_Expense_OS_Statement_${selectedMonthFilter === 'ALL' ? 'AllTime' : selectedMonthFilter}`;

  let html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>${titleDoc}</title>
  <style>
    @page { size: A4; margin: 15mm; }
    body { font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #0f172a; margin: 0; padding: 24px; background: #ffffff; line-height: 1.5; }
    .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 3px solid #10b981; padding-bottom: 16px; margin-bottom: 24px; }
    .brand-title { font-size: 26px; font-weight: 800; color: #0f172a; margin: 0; letter-spacing: -0.02em; }
    .brand-title span { color: #10b981; }
    .report-meta { text-align: right; font-size: 13px; color: #64748b; }
    .user-badge { font-size: 14px; font-weight: 700; color: #0f172a; margin-top: 4px; background: #f1f5f9; padding: 3px 8px; border-radius: 6px; display: inline-block; }
    
    .section-header { font-size: 14px; font-weight: 700; color: #0f172a; text-transform: uppercase; letter-spacing: 0.05em; background: #f8fafc; border-left: 4px solid #10b981; padding: 8px 12px; margin: 24px 0 14px 0; border-radius: 0 6px 6px 0; }
    
    .summary-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 24px; }
    .summary-card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px; }
    .summary-card .label { font-size: 11px; text-transform: uppercase; color: #64748b; font-weight: 600; }
    .summary-card .value { font-size: 18px; font-weight: 800; color: #0f172a; margin-top: 4px; }
    .summary-card.positive .value { color: #10b981; }
    .summary-card.negative .value { color: #ef4444; }

    table { width: 100%; border-collapse: collapse; margin-bottom: 20px; font-size: 13px; }
    th { background: #0f172a; color: #ffffff; text-align: left; padding: 10px 12px; font-weight: 600; border: none; }
    td { padding: 10px 12px; border-bottom: 1px solid #e2e8f0; }
    tr:nth-child(even) td { background: #f8fafc; }
    .text-right { text-align: right; }
    .font-bold { font-weight: 700; }
    .footer-total td { background: #e2e8f0; font-weight: 700; color: #0f172a; border-top: 2px solid #cbd5e1; }
    
    .footer { text-align: center; font-size: 11px; color: #94a3b8; border-top: 1px solid #e2e8f0; padding-top: 16px; margin-top: 40px; }
  </style>
</head>
<body>
  <div class="header">
    <div>
      <h1 class="brand-title">EXPENSE <span>OS</span></h1>
      <div style="font-size: 13px; color: #64748b; margin-top: 2px;">Executive Financial Statement & Analysis</div>
    </div>
    <div class="report-meta">
      <div><strong>Date Generated:</strong> ${formattedDate}</div>
      <div><strong>Period Overview:</strong> ${monthTitle}</div>
      <div class="user-badge">Account: ${userName}</div>
    </div>
  </div>

  <div class="section-header">1. Executive Summary</div>
  <div class="summary-grid">
    <div class="summary-card">
      <div class="label">Monthly Budget</div>
      <div class="value">${currentSymbol}${(parseFloat(budget) || 0).toFixed(2)}</div>
    </div>
    <div class="summary-card">
      <div class="label">Total Incomes</div>
      <div class="value">${currentSymbol}${totalIncomeAmt.toFixed(2)}</div>
    </div>
    <div class="summary-card">
      <div class="label">Total Expenses</div>
      <div class="value">${currentSymbol}${totalExpenseAmt.toFixed(2)}</div>
    </div>
    <div class="summary-card ${netBalance >= 0 ? 'positive' : 'negative'}">
      <div class="label">Net Cash Flow</div>
      <div class="value">${netBalance >= 0 ? '+' : ''}${currentSymbol}${netBalance.toFixed(2)}</div>
    </div>
  </div>

  <div class="section-header">2. Expense Transactions Ledger</div>
  <table>
    <thead>
      <tr>
        <th>Date</th>
        <th>Category</th>
        <th>Description</th>
        <th>Payment Method</th>
        <th class="text-right">Amount (${activeCurrency || 'INR'})</th>
      </tr>
    </thead>
    <tbody>`;

  if (exportExpenses.length === 0) {
    html += `<tr><td colspan="5" style="text-align:center; color:#94a3b8;">No expense records found for this period.</td></tr>`;
  } else {
    exportExpenses.forEach(item => {
      html += `<tr>
        <td>${item.date || ''}</td>
        <td><strong>${item.category || ''}</strong></td>
        <td>${item.description || '-'}</td>
        <td>${item.payment || '-'}</td>
        <td class="text-right font-bold">${currentSymbol}${(parseFloat(item.amount) || 0).toFixed(2)}</td>
      </tr>`;
    });
  }

  html += `</tbody>
    <tfoot>
      <tr class="footer-total">
        <td colspan="4">TOTAL EXPENSES</td>
        <td class="text-right">${currentSymbol}${totalExpenseAmt.toFixed(2)}</td>
      </tr>
    </tfoot>
  </table>`;

  if (exportSubs.length > 0) {
    html += `<div class="section-header">3. Recurring Bills & Subscriptions</div>
    <table>
      <thead>
        <tr>
          <th>Subscription</th>
          <th>Cycle</th>
          <th>Billing Day</th>
          <th>Category</th>
          <th class="text-right">Amount (${activeCurrency || 'INR'})</th>
        </tr>
      </thead>
      <tbody>`;
    exportSubs.forEach(sub => {
      html += `<tr>
        <td><strong>${sub.name || ''}</strong></td>
        <td>${sub.cycle || 'Monthly'}</td>
        <td>${sub.day || '1st'}</td>
        <td>${sub.category || 'General'}</td>
        <td class="text-right font-bold">${currentSymbol}${(parseFloat(sub.amount) || 0).toFixed(2)}</td>
      </tr>`;
    });
    html += `</tbody>
      <tfoot>
        <tr class="footer-total">
          <td colspan="4">TOTAL SUBSCRIPTIONS (MONTHLY)</td>
          <td class="text-right">${currentSymbol}${totalSubsAmt.toFixed(2)}</td>
        </tr>
      </tfoot>
    </table>`;
  }

  if (exportIncomes.length > 0) {
    html += `<div class="section-header">4. Income Deposits & Streams</div>
    <table>
      <thead>
        <tr>
          <th>Source</th>
          <th>Date</th>
          <th>Category</th>
          <th>Frequency</th>
          <th class="text-right">Amount (${activeCurrency || 'INR'})</th>
        </tr>
      </thead>
      <tbody>`;
    exportIncomes.forEach(inc => {
      html += `<tr>
        <td><strong>${inc.source || inc.description || 'Income'}</strong></td>
        <td>${inc.date || ''}</td>
        <td>${inc.category || 'Salary'}</td>
        <td>${inc.frequency || 'Monthly'}</td>
        <td class="text-right font-bold">${currentSymbol}${(parseFloat(inc.amount) || 0).toFixed(2)}</td>
      </tr>`;
    });
    html += `</tbody>
      <tfoot>
        <tr class="footer-total">
          <td colspan="4">TOTAL INCOMES</td>
          <td class="text-right">${currentSymbol}${totalIncomeAmt.toFixed(2)}</td>
        </tr>
      </tfoot>
    </table>`;
  }

  html += `
  <div class="footer">
    Expense OS Statement • Account: ${userName} • Confidential Personal Financial Record
  </div>
</body>
</html>`;

  return html;
}

window.exportFormattedFinancialReportPDF = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  try {
    const htmlContent = generateFormattedPDFHTML(selectedMonth);
    const userName = getUserDisplayName();
    const monthLabel = selectedMonth === 'ALL' ? 'AllTime' : selectedMonth;
    const dateStr = new Date().toISOString().split('T')[0];
    const docTitle = `${userName}_Expense_OS_Statement_${monthLabel}_${dateStr}`;

    // Remove any existing print frame
    const oldFrame = document.getElementById('pdf-print-iframe');
    if (oldFrame) oldFrame.remove();

    // Create a hidden iframe for seamless print-to-PDF without popup blocking
    const iframe = document.createElement('iframe');
    iframe.id = 'pdf-print-iframe';
    iframe.style.position = 'fixed';
    iframe.style.right = '0';
    iframe.style.bottom = '0';
    iframe.style.width = '0';
    iframe.style.height = '0';
    iframe.style.border = '0';
    document.body.appendChild(iframe);

    const pri = iframe.contentWindow || iframe.contentDocument;
    const doc = pri.document || pri;
    doc.open();
    doc.write(htmlContent);
    doc.title = docTitle;
    doc.close();

    // Trigger print
    setTimeout(() => {
      try {
        pri.focus();
        pri.print();
      } catch (printErr) {
        const win = window.open('', '_blank');
        if (win) {
          win.document.write(htmlContent);
          win.document.title = docTitle;
          win.document.close();
          win.print();
        }
      }
    }, 250);
  } catch (err) {
    console.error('PDF Export Error:', err);
    if (typeof showAlert === 'function') {
      showAlert('PDF Generation Error', 'Failed to generate PDF statement: ' + (err.message || err));
    }
  }
};

window.exportFormattedFinancialReportCSV = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  try {
    const csvContent = generateFormattedCSVContent(selectedMonth);
    const userName = getUserDisplayName();
    const monthLabel = selectedMonth === 'ALL' ? 'AllTime' : selectedMonth;
    const dateStr = new Date().toISOString().split('T')[0];
    const fileName = `${userName}_Expense_OS_Statement_${monthLabel}_${dateStr}.csv`;

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = fileName;
    document.body.appendChild(link);
    link.click();
    setTimeout(() => {
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
    }, 100);
  } catch (err) {
    console.error('CSV Export Error:', err);
    if (typeof showAlert === 'function') {
      showAlert('CSV Generation Error', 'Failed to generate CSV statement: ' + (err.message || err));
    }
  }
};

window.promptResetAllData = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  resetAllData(e);
};

window.handlePrevMonth = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const months = getAvailableMonths();
  if (selectedMonth === 'ALL') {
    selectedMonth = months[0] || getCurrentYearMonth();
  } else {
    const idx = months.indexOf(selectedMonth);
    if (idx >= 0 && idx < months.length - 1) {
      selectedMonth = months[idx + 1];
    }
  }
  updateMonthPickerOptions();
  updateUI();
};

window.handleNextMonth = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const months = getAvailableMonths();
  if (selectedMonth === 'ALL') {
    selectedMonth = months[0] || getCurrentYearMonth();
  } else {
    const idx = months.indexOf(selectedMonth);
    if (idx > 0) {
      selectedMonth = months[idx - 1];
    }
  }
  updateMonthPickerOptions();
  updateUI();
};

window.toggleSidebar = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const appLayout = document.querySelector('.app-layout');
  const sidebar = document.querySelector('.sidebar');
  const overlay = document.getElementById('sidebar-overlay');

  if (window.innerWidth <= 992) {
    if (sidebar) {
      sidebar.classList.toggle('sidebar-open');
      sidebar.classList.toggle('active');
    }
    if (overlay) {
      overlay.classList.toggle('active');
    }
  } else {
    if (sidebar) sidebar.classList.toggle('active');
    if (overlay) overlay.classList.toggle('active');
    if (appLayout) {
      appLayout.classList.toggle('sidebar-collapsed');
      const isCollapsed = appLayout.classList.contains('sidebar-collapsed');
      try { localStorage.setItem('expense_cal_sidebar_collapsed', isCollapsed ? 'true' : 'false'); } catch(err){}
    }
  }
};

// Restore saved sidebar collapsed state on load (Desktop only)
document.addEventListener('DOMContentLoaded', function() {
  try {
    if (window.innerWidth > 992 && localStorage.getItem('expense_cal_sidebar_collapsed') === 'true') {
      const appLayout = document.querySelector('.app-layout');
      if (appLayout) appLayout.classList.add('sidebar-collapsed');
    }
  } catch(err){}
});

if (btnResetAll) btnResetAll.addEventListener('click', resetAllData);
// Keyboard Shortcuts
document.addEventListener('keydown', (e) => {
  if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
    e.preventDefault();
    if (expAmountInput) expAmountInput.focus();
  }
  if ((e.ctrlKey || e.metaKey) && e.key === 'f') {
    e.preventDefault();
    if (filterSearchInput) filterSearchInput.focus();
  }
  if (e.key === 'Escape') {
    closeModal();
  }
});

// ---------- Delegated Event Listeners ----------
document.addEventListener('click', (e) => {
  const resetBtn = e.target.closest('#btn-reset-all');
  if (resetBtn) {
    if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
    if (typeof window.promptResetAllData === 'function') {
      window.promptResetAllData(e);
    } else if (typeof resetAllData === 'function') {
      resetAllData(e);
    }
    return;
  }

  const editProfileBtn = e.target.closest('#btn-dropdown-edit-profile, #sidebar-profile-card');
  if (editProfileBtn) {
    if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
    if (typeof window.handleEditProfileClick === 'function') {
      window.handleEditProfileClick(e);
    } else if (typeof window.openEditProfileModal === 'function') {
      window.openEditProfileModal(e);
    }
    return;
  }

  const checkUpdateBtn = e.target.closest('#btn-dropdown-check-update');
  if (checkUpdateBtn) {
    if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
    if (typeof window.handleCheckUpdateClick === 'function') {
      window.handleCheckUpdateClick(e);
    } else if (typeof window.checkAppUpdates === 'function') {
      window.checkAppUpdates(true);
    }
    return;
  }

  const authBtn = e.target.closest('#btn-dropdown-auth, #btn-dropdown-logout');
  if (authBtn) {
    if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
    if (typeof window.promptSignOut === 'function') {
      window.promptSignOut(e);
    } else if (typeof window.handleSignOut === 'function') {
      window.handleSignOut(e);
    }
    return;
  }

  const target = e.target.closest('[data-delete-sub]');
  if (target) {
    const id = target.dataset.deleteSub || target.getAttribute('data-delete-sub');
    if (id) deleteSubscription(id);
    return;
  }

  const payBtn = e.target.closest('[data-pay-sub]');
  if (payBtn) {
    const id = payBtn.dataset.paySub || payBtn.getAttribute('data-pay-sub');
    if (id) markSubAsPaid(id);
    return;
  }

  const txDel = e.target.closest('[data-delete-tx]');
  if (txDel) {
    const id = txDel.dataset.deleteTx || txDel.getAttribute('data-delete-tx');
    if (id) deleteTransaction(id);
    return;
  }

  const monthBar = e.target.closest('[data-select-month]');
  if (monthBar) {
    const m = monthBar.dataset.selectMonth || monthBar.getAttribute('data-select-month');
    if (m) selectMonthFromChart(m);
    return;
  }
});

// ---------- Sidebar Toggle for Small Screens ----------
function toggleSidebar(e) {
  if (typeof window.toggleSidebar === 'function') {
    window.toggleSidebar(e);
  } else {
    if (e) { e.preventDefault(); e.stopPropagation(); }
    const sidebar = document.querySelector('.sidebar');
    const overlay = document.getElementById('sidebar-overlay');
    if (sidebar) {
      sidebar.classList.toggle('sidebar-open');
      sidebar.classList.toggle('active');
    }
    if (overlay) {
      overlay.classList.toggle('active');
    }
  }
}

function closeSidebar() {
  const sidebar = document.querySelector('.sidebar');
  const overlay = document.getElementById('sidebar-overlay');
  if (sidebar) {
    sidebar.classList.remove('sidebar-open', 'active');
  }
  if (overlay) {
    overlay.classList.remove('active');
  }
}

document.addEventListener('click', (e) => {
  const overlay = e.target.closest('#sidebar-overlay');
  if (overlay) {
    closeSidebar();
    return;
  }
  if (e.target.closest('.nav-item') && window.innerWidth <= 992) {
    closeSidebar();
  }
});

// Initialization
document.addEventListener('DOMContentLoaded', () => {
  setTodayDateDefault();
  // Load state from localStorage immediately on startup so expenses render without waiting
  loadStateFromLocal();
  syncPrivacyBtnUI();

  const expDesc = document.getElementById('exp-description');
  const expCat = document.getElementById('exp-category');
  if (expDesc && expCat) {
    expDesc.addEventListener('input', (e) => {
      const matchedCategory = autoCategorizeExpense(e.target.value);
      const aiBadge = document.getElementById('ai-cat-badge');
      if (matchedCategory) {
        expCat.value = matchedCategory;
        if (aiBadge) {
          aiBadge.classList.remove('hidden');
          aiBadge.innerHTML = `<i class="fa-solid fa-wand-magic-sparkles"></i> AI: ${matchedCategory}`;
        }
      } else {
        if (aiBadge) aiBadge.classList.add('hidden');
      }
    });
  }
});

// ---------- Interactive Onboarding & Feature Tour ----------
const tourSteps = [
  {
    view: 'dashboard',
    target: '.stats-grid',
    title: '📊 Step 1: Financial Command Center & Health Score',
    msg: 'Monitor your real-time budget status, net account balance, financial health score, and monthly spending progress at a glance.'
  },
  {
    view: 'dashboard',
    target: '#expense-form',
    title: '💸 Step 2: Log Daily Expenses',
    msg: 'Quickly log daily purchases, groceries, and bills with category tags, payment methods, and optional receipt image attachments.'
  },
  {
    view: 'transactions',
    target: '[data-view="transactions"]',
    title: '📜 Step 3: Transaction Manager & Search',
    msg: 'Switch to the Transaction Manager tab to view your complete expense history, search items, filter by category, or export your records.'
  },
  {
    view: 'bills',
    target: '[data-view="bills"]',
    title: '🔄 Step 4: Recurring Bills & Subscriptions',
    msg: 'Never miss a payment! Track monthly subscriptions (Netflix, Spotify, Rent, Utilities) with automated due-date reminders.'
  },
  {
    view: 'dashboard',
    target: '#breakdown-chart-container',
    title: '🥧 Step 5: Category Breakdown & Spending Charts',
    msg: 'View interactive spending charts, expenditure trends, and visual category breakdowns of where your money goes each month.'
  },
  {
    view: 'reports',
    target: '[data-view="reports"]',
    title: '📑 Step 6: Reports & Financial Statement Exports',
    msg: 'Generate formatted PDF statements, export CSV spreadsheets, or back up your entire financial database anytime.'
  },
  {
    view: 'fx-rates',
    target: '[data-view="fx-rates"]',
    title: '🌐 Step 7: Multi-Currency & FX Exchange Rates',
    msg: 'Track real-time foreign currency exchange rates (USD, EUR, GBP, INR) and easily convert your financial statements across currencies.'
  }
];

let currentTourStep = 0;

function renderTourStep(stepIdx) {
  if (stepIdx < 0 || stepIdx >= tourSteps.length) {
    endGuidedTour();
    return;
  }

  currentTourStep = stepIdx;
  const step = tourSteps[stepIdx];

  // Auto-switch to target tab/view if specified
  if (step.view && typeof switchView === 'function') {
    switchView(step.view);
  }

  document.querySelectorAll('.tour-highlight').forEach(el => el.classList.remove('tour-highlight'));

  const tourOverlay = document.getElementById('tour-overlay');
  const tourCard = document.getElementById('tour-card');
  const stepBadge = document.getElementById('tour-step-badge');
  const titleEl = document.getElementById('tour-title');
  const msgEl = document.getElementById('tour-msg');
  const prevBtn = document.getElementById('btn-tour-prev');
  const nextBtn = document.getElementById('btn-tour-next');

  if (!tourOverlay || !tourCard) return;

  tourOverlay.classList.remove('hidden');
  if (stepBadge) stepBadge.textContent = `Step ${stepIdx + 1} of ${tourSteps.length}`;
  if (titleEl) titleEl.textContent = step.title;
  if (msgEl) msgEl.textContent = step.msg;

  if (prevBtn) prevBtn.style.display = stepIdx === 0 ? 'none' : 'inline-flex';
  if (nextBtn) nextBtn.innerHTML = stepIdx === tourSteps.length - 1 ? 'Finish 🎉' : 'Next <i class="fa-solid fa-arrow-right"></i>';

  setTimeout(() => {
    const targetEl = document.querySelector(step.target);
    if (targetEl) {
      targetEl.classList.add('tour-highlight');
      try { targetEl.scrollIntoView({ behavior: 'smooth', block: 'nearest' }); } catch(e) {}

      const rect = targetEl.getBoundingClientRect();
      const cardWidth = Math.min(340, window.innerWidth - 32);
      const cardHeight = tourCard.offsetHeight || 220;
      const vpWidth = window.innerWidth;
      const vpHeight = window.innerHeight;

      let top = 0;
      let left = 0;

      // 1. Prefer placing card below target
      if (rect.bottom + cardHeight + 16 <= vpHeight) {
        top = rect.bottom + 12;
        left = rect.left + (rect.width / 2) - (cardWidth / 2);
      }
      // 2. Otherwise place card above target
      else if (rect.top - cardHeight - 16 >= 0) {
        top = rect.top - cardHeight - 12;
        left = rect.left + (rect.width / 2) - (cardWidth / 2);
      }
      // 3. Otherwise place card to the right of target
      else if (rect.right + cardWidth + 16 <= vpWidth) {
        top = rect.top + (rect.height / 2) - (cardHeight / 2);
        left = rect.right + 12;
      }
      // 4. Otherwise place card to the left of target
      else if (rect.left - cardWidth - 16 >= 0) {
        top = rect.top + (rect.height / 2) - (cardHeight / 2);
        left = rect.left - cardWidth - 12;
      }
      // 5. Fallback: Position with safe margin
      else {
        top = rect.top > vpHeight / 2 ? Math.max(16, rect.top - cardHeight - 12) : rect.bottom + 12;
        left = rect.left + (rect.width / 2) - (cardWidth / 2);
      }

      // Clamp within viewport boundaries
      left = Math.max(16, Math.min(vpWidth - cardWidth - 16, left));
      top = Math.max(16, Math.min(vpHeight - cardHeight - 16, top));

      tourCard.style.top = `${top}px`;
      tourCard.style.left = `${left}px`;
    } else {
      tourCard.style.top = '30%';
      tourCard.style.left = '50%';
    }
  }, 60);
}

function startGuidedTour() {
  const welcomeModal = document.getElementById('welcome-modal');
  if (welcomeModal) welcomeModal.classList.add('hidden');
  renderTourStep(0);
}

function endGuidedTour() {
  document.querySelectorAll('.tour-highlight').forEach(el => el.classList.remove('tour-highlight'));
  const tourOverlay = document.getElementById('tour-overlay');
  if (tourOverlay) tourOverlay.classList.add('hidden');
  localStorage.setItem('expense_cal_seen_welcome_global', 'true');
  if (typeof switchView === 'function') switchView('dashboard');
}

const isElectronApp = /Electron/i.test(navigator.userAgent) || Boolean(window.process && window.process.type) || Boolean(window.electronAPI && window.electronAPI.isElectron);

function applyEnvironmentAdjustments() {
  const skipTourBtn = document.getElementById('btn-skip-tour');
  if (skipTourBtn) {
    if (!isElectronApp) {
      skipTourBtn.style.display = 'none';
    } else {
      skipTourBtn.style.display = 'block';
    }
  }
}

// Event Listeners for Welcome Modal & Guided Tour
document.addEventListener('click', (e) => {
  if (e.target.closest('#btn-start-tour')) {
    startGuidedTour();
    return;
  }
  if (e.target.closest('#btn-skip-tour')) {
    const welcomeModal = document.getElementById('welcome-modal');
    if (welcomeModal) welcomeModal.classList.add('hidden');
    return;
  }
  if (e.target.closest('#btn-sidebar-tour')) {
    startGuidedTour();
    return;
  }
  if (e.target.closest('#btn-tour-next')) {
    renderTourStep(currentTourStep + 1);
    return;
  }
  if (e.target.closest('#btn-tour-prev')) {
    renderTourStep(currentTourStep - 1);
    return;
  }
  if (e.target.closest('#btn-tour-skip, #btn-tour-close')) {
    endGuidedTour();
    return;
  }
});

document.addEventListener('DOMContentLoaded', applyEnvironmentAdjustments);

// ---------- Live Update Manager & GitHub Checker ----------
const CURRENT_APP_VERSION = 'v3.3.11';

window.showUpdateToast = function(title, message, showActions = false) {
  const toast = document.getElementById('update-notification');
  const titleEl = document.getElementById('update-toast-title');
  const msgEl = document.getElementById('update-toast-msg');
  const actionsEl = document.getElementById('update-toast-actions');

  if (!toast) return;

  if (titleEl) titleEl.textContent = title;
  if (msgEl) msgEl.textContent = message;

  if (actionsEl) {
    if (showActions) actionsEl.classList.remove('hidden');
    else actionsEl.classList.add('hidden');
  }

  toast.classList.remove('hidden');
  toast.style.cssText = 'display: block !important; position: fixed !important; bottom: 24px !important; right: 24px !important; z-index: 9999999 !important; width: 340px !important; max-width: calc(100vw - 32px) !important;';
};

window.hideUpdateToast = function() {
  const toast = document.getElementById('update-notification');
  if (toast) {
    toast.classList.add('hidden');
    toast.style.cssText = 'display: none !important;';
  }
};

window.checkAppUpdates = async function checkAppUpdates(manual = false) {
  window.lastManualCheck = manual;
  const dropdown = document.getElementById('user-dropdown-menu');
  if (dropdown) dropdown.classList.add('hidden');

  const isElectron = !!(window.electronAPI && window.electronAPI.isElectron);
  if (!isElectron) {
    if (manual) {
      window.showUpdateToast('✓ Web Version', 'You are using the Expense OS Web App.', false);
      setTimeout(() => { window.hideUpdateToast(); }, 3500);
    } else {
      window.hideUpdateToast();
    }
    return;
  }

  if (window.electronAPI && typeof window.electronAPI.checkForUpdates === 'function') {
    if (manual) {
      window.showUpdateToast('Checking for Updates...', 'Connecting to release server...', false);
    }
    window.electronAPI.checkForUpdates();
    return;
  }

  if (manual) {
    window.showUpdateToast('Checking for Updates...', 'Connecting to release server...', false);
  } else {
    window.hideUpdateToast();
  }

  try {
    let latestTag = '';
    const res = await fetch('https://api.github.com/repos/VaibhavJalota06/Expense-OS-Mobile/releases/latest');
    if (res.ok) {
      const data = await res.json();
      latestTag = (data.tag_name || '').trim();
    } else {
      const tagsRes = await fetch('https://api.github.com/repos/VaibhavJalota06/Expense-OS-Mobile/tags');
      if (tagsRes.ok) {
        const tagsData = await tagsRes.json();
        if (Array.isArray(tagsData) && tagsData.length > 0) {
          latestTag = (tagsData[0].name || '').trim();
        }
      }
    }

    function isNewerVersion(latest, current) {
      if (!latest || !current) return false;
      const clean = v => v.replace(/^v/i, '').split('.').map(n => parseInt(n, 10) || 0);
      const l = clean(latest);
      const c = clean(current);
      for (let i = 0; i < Math.max(l.length, c.length); i++) {
        const numL = l[i] || 0;
        const numC = c[i] || 0;
        if (numL > numC) return true;
        if (numL < numC) return false;
      }
      return false;
    }

    if (latestTag && isNewerVersion(latestTag, CURRENT_APP_VERSION)) {
      window.showUpdateToast('🎉 Update Available (' + latestTag + ')', `A new version (${latestTag}) of Expense OS is available!`, true);
    } else if (manual) {
      window.showUpdateToast('✓ Up to Date', `Expense OS ${CURRENT_APP_VERSION} is currently up to date.`, false);
      setTimeout(() => {
        window.hideUpdateToast();
      }, 4500);
    } else {
      window.hideUpdateToast();
    }
  } catch (err) {
    console.warn('Update check notice:', err);
    if (manual) {
      window.showUpdateToast('✓ Up to Date', `Expense OS ${CURRENT_APP_VERSION} is currently up to date.`, false);
      setTimeout(() => {
        window.hideUpdateToast();
      }, 4500);
    } else {
      window.hideUpdateToast();
    }
  }
};

if (window.electronAPI && typeof window.electronAPI.onUpdateStatus === 'function') {
  window.electronAPI.onUpdateStatus((data) => {
    const restartBtn = document.getElementById('btn-restart-update');
    const downloadBtn = document.getElementById('btn-download-update');

    if (data.status === 'checking') {
      window.showUpdateToast('Checking for Updates...', 'Connecting to release server...', false);
    } else if (data.status === 'available') {
      window.showUpdateToast('🎉 Update Available', `New version (v${data.version || ''}) detected. Downloading in background...`, false);
    } else if (data.status === 'downloading') {
      window.showUpdateToast('⏬ Downloading Update...', `Progress: ${data.percent || 0}%`, false);
    } else if (data.status === 'downloaded') {
      if (restartBtn) restartBtn.classList.remove('hidden');
      if (downloadBtn) downloadBtn.classList.add('hidden');
      window.showUpdateToast('✅ Update Ready!', `Expense OS v${data.version || ''} downloaded. Click below to restart & update now.`, true);
    } else if (data.status === 'not-available') {
      if (restartBtn) restartBtn.classList.add('hidden');
      if (downloadBtn) downloadBtn.classList.remove('hidden');
      window.showUpdateToast('✓ Up to Date', `Expense OS ${CURRENT_APP_VERSION} is currently up to date.`, false);
      setTimeout(() => { window.hideUpdateToast(); }, 4500);
    } else if (data.status === 'dev-mode') {
      window.showUpdateToast('✓ Development Mode', `App is running in development mode (${CURRENT_APP_VERSION}).`, false);
      setTimeout(() => { window.hideUpdateToast(); }, 3000);
    } else if (data.status === 'error') {
      if (window.lastManualCheck) {
        window.showUpdateToast('✓ Up to Date', `Expense OS ${CURRENT_APP_VERSION} is currently up to date.`, false);
        setTimeout(() => { window.hideUpdateToast(); }, 4500);
      } else {
        window.hideUpdateToast();
      }
    }
  });
}

window.handleCheckUpdateClick = function(e) {
  if (e) {
    try { e.preventDefault(); e.stopPropagation(); } catch(err){}
  }
  if (typeof window.checkAppUpdates === 'function') {
    window.checkAppUpdates(true);
  }
};

document.addEventListener('click', (e) => {
  const toggleBtn = e.target.closest('.btn-toggle-password');
  if (toggleBtn) {
    e.preventDefault();
    const targetId = toggleBtn.getAttribute('data-target');
    const input = targetId ? document.getElementById(targetId) : null;
    if (input) {
      const isPassword = input.type === 'password';
      input.type = isPassword ? 'text' : 'password';
      const icon = toggleBtn.querySelector('i');
      if (icon) {
        icon.className = isPassword ? 'fa-solid fa-eye-slash text-emerald' : 'fa-solid fa-eye';
      }
    }
    return;
  }

  if (e.target.closest('#btn-restart-update')) {
    e.preventDefault();
    if (window.electronAPI && typeof window.electronAPI.restartAndInstall === 'function') {
      window.electronAPI.restartAndInstall();
    }
    return;
  }

  if (e.target.closest('#btn-dropdown-check-update, .btn-check-update-link')) {
    e.preventDefault();
    checkAppUpdates(true);
    return;
  }
  if (e.target.closest('#btn-close-update-toast, #btn-dismiss-update')) {
    const toast = document.getElementById('update-notification');
    if (toast) {
      toast.classList.add('hidden');
      toast.style.setProperty('display', 'none', 'important');
    }
    return;
  }
});

// ============================================================
// SAVINGS GOALS & TARGET TRACKERS LOGIC
// ============================================================
const escapeHTML = (str) => {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
};

function saveSavingsGoalsToStorage() {
  try {
    localStorage.setItem('expense_cal_web_savings_goals', JSON.stringify(savingsGoals));
    localStorage.setItem('expense_cal_savings_goals', JSON.stringify(savingsGoals));
    if (typeof saveState === 'function') {
      saveState();
    }
  } catch(e) { console.error('Error saving goals:', e); }
}

function openGoalModal(goalId = null) {
  const modal = document.getElementById('goal-modal');
  const titleEl = document.getElementById('goal-modal-title');
  const editIdEl = document.getElementById('goal-edit-id');
  const titleInput = document.getElementById('goal-title-input');
  const targetInput = document.getElementById('goal-target-input');
  const savedInput = document.getElementById('goal-saved-input');
  const dateInput = document.getElementById('goal-date-input');
  const iconInput = document.getElementById('goal-icon-input');
  const notesInput = document.getElementById('goal-notes-input');

  if (!modal) return;

  if (goalId) {
    const goal = savingsGoals.find(g => g.id === goalId);
    if (goal) {
      if (titleEl) titleEl.textContent = 'Edit Savings Goal';
      if (editIdEl) editIdEl.value = goal.id;
      if (titleInput) titleInput.value = goal.title || '';
      if (targetInput) targetInput.value = goal.targetAmount || '';
      if (savedInput) savedInput.value = goal.savedAmount || 0;
      if (dateInput) dateInput.value = goal.targetDate || '';
      if (iconInput) iconInput.value = goal.icon || '🏦';
      if (notesInput) notesInput.value = goal.notes || '';
    }
  } else {
    if (titleEl) titleEl.textContent = 'Create Savings Goal';
    if (editIdEl) editIdEl.value = '';
    if (titleInput) titleInput.value = '';
    if (targetInput) targetInput.value = '';
    if (savedInput) savedInput.value = '0';
    if (dateInput) {
      const future = new Date();
      future.setMonth(future.getMonth() + 6);
      dateInput.value = future.toISOString().split('T')[0];
    }
    if (iconInput) iconInput.value = '🏦';
    if (notesInput) notesInput.value = '';
  }

  modal.classList.remove('hidden');
  modal.style.setProperty('display', 'flex', 'important');
  modal.style.setProperty('opacity', '1', 'important');
  modal.style.setProperty('visibility', 'visible', 'important');
  modal.style.setProperty('pointer-events', 'auto', 'important');
}
window.openGoalModal = openGoalModal;

function closeGoalModal() {
  const modal = document.getElementById('goal-modal');
  if (modal) {
    modal.classList.add('hidden');
    modal.style.setProperty('display', 'none', 'important');
    modal.style.setProperty('opacity', '0', 'important');
    modal.style.setProperty('visibility', 'hidden', 'important');
    modal.style.setProperty('pointer-events', 'none', 'important');
  }
}
window.closeGoalModal = closeGoalModal;

// Backdrop click handlers for Goal Modals
const goalModalEl = document.getElementById('goal-modal');
if (goalModalEl) {
  goalModalEl.addEventListener('click', (e) => {
    if (e.target === goalModalEl) closeGoalModal();
  });
}
const goalDepositModalEl = document.getElementById('goal-deposit-modal');
if (goalDepositModalEl) {
  goalDepositModalEl.addEventListener('click', (e) => {
    if (e.target === goalDepositModalEl) closeGoalDepositModal();
  });
}

function handleGoalSubmit(e) {
  if (e) e.preventDefault();
  const editId = document.getElementById('goal-edit-id')?.value;
  const title = document.getElementById('goal-title-input')?.value.trim();
  const targetAmount = parseFloat(document.getElementById('goal-target-input')?.value || '0');
  const savedAmount = parseFloat(document.getElementById('goal-saved-input')?.value || '0');
  const targetDate = document.getElementById('goal-date-input')?.value;
  const icon = document.getElementById('goal-icon-input')?.value || '🏦';
  const notes = document.getElementById('goal-notes-input')?.value.trim();

  if (!title || !targetAmount || targetAmount <= 0) {
    alert('Please enter a valid goal title and target amount.');
    return;
  }

  const todayStr = new Date().toISOString().split('T')[0];

  if (editId) {
    const index = savingsGoals.findIndex(g => g.id === editId);
    if (index !== -1) {
      const oldSaved = Number(savingsGoals[index].savedAmount || 0);
      savingsGoals[index] = {
        ...savingsGoals[index],
        title,
        targetAmount,
        savedAmount: Math.max(0, savedAmount),
        targetDate,
        icon,
        notes,
        updatedAt: new Date().toISOString()
      };
      const added = savedAmount - oldSaved;
      if (added > 0) {
        const goalExpense = {
          id: `goal_dep_${editId}_${Date.now()}`,
          amount: added,
          category: 'Savings & Goals',
          description: `Goal Deposit: ${title}`,
          title: `Goal Deposit: ${title}`,
          date: todayStr,
          type: 'expense',
          paymentMethod: 'Bank Account',
          notes: `Additional savings deposit for ${title}`,
          createdAt: new Date().toISOString()
        };
        expenses.unshift(goalExpense);
        try { localStorage.setItem('expense_cal_web_expenses', JSON.stringify(expenses)); } catch(err){}
      }
    }
  } else {
    const newGoalId = 'goal_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5);
    const newGoal = {
      id: newGoalId,
      title,
      targetAmount,
      savedAmount: Math.max(0, savedAmount),
      targetDate,
      icon,
      notes,
      createdAt: new Date().toISOString()
    };
    savingsGoals.push(newGoal);

    if (savedAmount > 0) {
      const goalExpense = {
        id: `goal_dep_${newGoalId}_${Date.now()}`,
        amount: savedAmount,
        category: 'Savings & Goals',
        description: `Goal Deposit: ${title}`,
        title: `Goal Deposit: ${title}`,
        date: todayStr,
        type: 'expense',
        paymentMethod: 'Bank Account',
        notes: `Initial savings allocation for ${title}`,
        createdAt: new Date().toISOString()
      };
      expenses.unshift(goalExpense);
      try { localStorage.setItem('expense_cal_web_expenses', JSON.stringify(expenses)); } catch(err){}
    }

    try { if (window.dispatchGoalCreatedEmail) window.dispatchGoalCreatedEmail(newGoal); } catch(err){}
  }

  saveSavingsGoalsToStorage();
  closeGoalModal();
  renderSavingsGoals();
  if (typeof updateUI === 'function') updateUI();
}
window.handleGoalSubmit = handleGoalSubmit;

function deleteGoal(goalId) {
  if (!confirm('Are you sure you want to delete this savings goal? All saved funds will be returned to your budget.')) return;
  const targetGoal = savingsGoals.find(g => g.id === goalId);
  const targetTitle = (targetGoal?.title || '').trim().toLowerCase();

  // 1. Remove goal
  savingsGoals = savingsGoals.filter(g => g.id !== goalId);

  // 2. Cascade delete all deposit expenses associated with this goal to restore budget
  expenses = expenses.filter(e => {
    if (e.id && (e.id === `goal_dep_${goalId}` || e.id.startsWith(`goal_dep_${goalId}_`))) return false;
    const t = (e.description || e.title || '').trim().toLowerCase();
    if ((e.category === 'Savings & Goals' || t.startsWith('goal deposit:')) && targetTitle && t.includes(targetTitle)) {
      return false;
    }
    return true;
  });
  try { localStorage.setItem('expense_cal_web_expenses', JSON.stringify(expenses)); } catch(err){}

  saveSavingsGoalsToStorage();
  renderSavingsGoals();
  if (typeof updateUI === 'function') updateUI();
}
window.deleteGoal = deleteGoal;

function openGoalDepositModal(goalId, actionType = 'deposit') {
  const modal = document.getElementById('goal-deposit-modal');
  const goal = savingsGoals.find(g => g.id === goalId);
  if (!modal || !goal) return;

  const goalIdInput = document.getElementById('deposit-goal-id');
  const actionTypeInput = document.getElementById('deposit-action-type');
  const titleEl = document.getElementById('deposit-modal-title');
  const infoEl = document.getElementById('deposit-goal-info');
  const amountInput = document.getElementById('deposit-amount-input');
  const submitBtn = document.getElementById('btn-submit-deposit');
  const deductLabelEl = document.getElementById('deposit-deduct-label');
  const deductCheckbox = document.getElementById('deposit-deduct-account');

  if (goalIdInput) goalIdInput.value = goalId;
  if (actionTypeInput) actionTypeInput.value = actionType;
  if (amountInput) amountInput.value = '';
  if (deductCheckbox) deductCheckbox.checked = true;

  if (actionType === 'deposit') {
    if (titleEl) titleEl.innerHTML = `<i class="fa-solid fa-plus-circle text-emerald"></i> Deposit into ${goal.icon} ${escapeHTML(goal.title)}`;
    if (deductLabelEl) deductLabelEl.textContent = 'Deduct from Monthly Budget (Log Expense)';
    if (submitBtn) {
      submitBtn.className = 'btn btn-emerald';
      submitBtn.innerHTML = '<i class="fa-solid fa-plus-circle"></i> Confirm Deposit';
    }
  } else {
    if (titleEl) titleEl.innerHTML = `<i class="fa-solid fa-minus-circle text-rose"></i> Withdraw from ${goal.icon} ${escapeHTML(goal.title)}`;
    if (deductLabelEl) deductLabelEl.textContent = 'Credit back to Monthly Budget (Log Income)';
    if (submitBtn) {
      submitBtn.className = 'btn btn-rose';
      submitBtn.innerHTML = '<i class="fa-solid fa-minus-circle"></i> Confirm Withdrawal';
    }
  }

  if (infoEl) {
    infoEl.innerHTML = `Current Balance: <strong>${formatCurrency(goal.savedAmount)}</strong> / Target: <strong>${formatCurrency(goal.targetAmount)}</strong>`;
  }

  modal.classList.remove('hidden');
  modal.style.setProperty('display', 'flex', 'important');
  modal.style.setProperty('opacity', '1', 'important');
  modal.style.setProperty('visibility', 'visible', 'important');
  modal.style.setProperty('pointer-events', 'auto', 'important');
}
window.openGoalDepositModal = openGoalDepositModal;

function closeGoalDepositModal() {
  const modal = document.getElementById('goal-deposit-modal');
  if (modal) {
    modal.classList.add('hidden');
    modal.style.setProperty('display', 'none', 'important');
    modal.style.setProperty('opacity', '0', 'important');
    modal.style.setProperty('visibility', 'hidden', 'important');
    modal.style.setProperty('pointer-events', 'none', 'important');
  }
}
window.closeGoalDepositModal = closeGoalDepositModal;

function handleGoalDepositSubmit(e) {
  if (e) e.preventDefault();
  const goalId = document.getElementById('deposit-goal-id')?.value;
  const actionType = document.getElementById('deposit-action-type')?.value || 'deposit';
  const amount = parseFloat(document.getElementById('deposit-amount-input')?.value || '0');

  if (!goalId || isNaN(amount) || amount <= 0) {
    alert('Please enter a valid amount.');
    return;
  }

  const goal = savingsGoals.find(g => g.id === goalId);
  if (!goal) return;

  const todayStr = new Date().toISOString().split('T')[0];

  if (actionType === 'deposit') {
    goal.savedAmount += amount;
    const goalExpense = {
      id: `goal_dep_${goal.id}_${Date.now()}`,
      amount: amount,
      category: 'Savings & Goals',
      description: `Goal Deposit: ${goal.title}`,
      title: `Goal Deposit: ${goal.title}`,
      date: todayStr,
      type: 'expense',
      paymentMethod: 'Bank Account',
      notes: `Quick savings deposit towards ${goal.title}`,
      createdAt: new Date().toISOString()
    };
    expenses.unshift(goalExpense);
    try { localStorage.setItem('expense_cal_web_expenses', JSON.stringify(expenses)); } catch(err){}
  } else {
    if (amount > goal.savedAmount) {
      alert(`Cannot withdraw more than current balance (${formatCurrency(goal.savedAmount)}).`);
      return;
    }
    goal.savedAmount -= amount;
    const goalIncome = {
      id: `goal_with_${goal.id}_${Date.now()}`,
      amount: amount,
      source: `Savings Withdrawal: ${goal.title}`,
      description: `Savings Withdrawal: ${goal.title}`,
      date: todayStr,
      type: 'income',
      createdAt: new Date().toISOString()
    };
    incomes.unshift(goalIncome);
    try { localStorage.setItem('expense_cal_web_incomes', JSON.stringify(incomes)); } catch(err){}
  }

  goal.updatedAt = new Date().toISOString();
  saveSavingsGoalsToStorage();
  closeGoalDepositModal();
  renderSavingsGoals();
  if (typeof updateUI === 'function') updateUI();
}
window.handleGoalDepositSubmit = handleGoalDepositSubmit;

function renderSavingsGoals() {
  const gridEl = document.getElementById('savings-goals-grid');
  const statSavedEl = document.getElementById('goals-stat-saved');
  const statTargetEl = document.getElementById('goals-stat-target');
  const statPercentEl = document.getElementById('goals-stat-percent');
  const statCountSubtextEl = document.getElementById('goals-stat-count-subtext');

  const totalSaved = savingsGoals.reduce((sum, g) => sum + Number(g.savedAmount || 0), 0);
  const totalTarget = savingsGoals.reduce((sum, g) => sum + Number(g.targetAmount || 0), 0);
  const overallPercent = totalTarget > 0 ? Math.min(100, Math.round((totalSaved / totalTarget) * 100)) : 0;

  if (statSavedEl) statSavedEl.textContent = formatCurrency(totalSaved);
  if (statTargetEl) statTargetEl.textContent = formatCurrency(totalTarget);
  if (statPercentEl) statPercentEl.textContent = `${overallPercent}%`;
  if (statCountSubtextEl) statCountSubtextEl.textContent = `${savingsGoals.length} active goal${savingsGoals.length === 1 ? '' : 's'}`;

  if (!gridEl) return;

  if (savingsGoals.length === 0) {
    gridEl.innerHTML = `
      <div class="empty-goals-state">
        <i class="fa-solid fa-bullseye empty-goals-icon"></i>
        <h4>No Savings Goals Created Yet</h4>
        <p style="margin-top: 0.5rem; margin-bottom: 1.25rem;">Start setting financial milestones like Emergency Fund, Gadgets, or Vacations!</p>
        <button class="btn btn-emerald" onclick="if(window.openGoalModal)window.openGoalModal();">
          <i class="fa-solid fa-plus"></i> Create Your First Goal
        </button>
      </div>
    `;
    return;
  }

  const today = new Date();
  gridEl.innerHTML = savingsGoals.map(goal => {
    const saved = Number(goal.savedAmount || 0);
    const target = Number(goal.targetAmount || 1);
    const pct = Math.min(100, Math.round((saved / target) * 100));
    const isCompleted = pct >= 100;
    
    let daysText = 'No deadline';
    if (goal.targetDate) {
      const targetDt = new Date(goal.targetDate);
      const diffTime = targetDt - today;
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
      if (diffDays < 0) {
        daysText = '⚠️ Overdue';
      } else if (diffDays === 0) {
        daysText = '⏱️ Due Today';
      } else {
        daysText = `📅 ${diffDays} day${diffDays === 1 ? '' : 's'} left`;
      }
    }

    return `
      <div class="goal-card glass-panel">
        <div>
          <div class="goal-card-header">
            <div class="goal-icon-badge">${goal.icon || '🏦'}</div>
            <div class="goal-card-actions">
              <button class="icon-btn" title="Edit Goal" onclick="if(window.openGoalModal)window.openGoalModal('${goal.id}');"><i class="fa-solid fa-pen"></i></button>
              <button class="icon-btn text-rose" title="Delete Goal" onclick="if(window.deleteGoal)window.deleteGoal('${goal.id}');"><i class="fa-solid fa-trash"></i></button>
            </div>
          </div>
          <div class="goal-title-text">${escapeHTML(goal.title)}</div>
          ${goal.notes ? `<div class="goal-notes-text">${escapeHTML(goal.notes)}</div>` : ''}
          <div class="goal-amounts-row">
            <span class="goal-saved-val">${formatCurrency(saved)}</span>
            <span class="goal-target-val">Target: ${formatCurrency(target)}</span>
          </div>
          <div class="goal-progress-track">
            <div class="goal-progress-fill ${isCompleted ? 'completed' : ''}" style="width: ${pct}%;"></div>
          </div>
          <div class="goal-footer-meta">
            <span>Progress: <strong>${pct}%</strong></span>
            <span>${daysText}</span>
          </div>
        </div>
        <div class="goal-card-btns">
          <button class="btn btn-emerald" onclick="if(window.openGoalDepositModal)window.openGoalDepositModal('${goal.id}', 'deposit');">
            <i class="fa-solid fa-plus-circle"></i> Deposit
          </button>
          <button class="btn btn-secondary" onclick="if(window.openGoalDepositModal)window.openGoalDepositModal('${goal.id}', 'withdraw');">
            <i class="fa-solid fa-minus-circle"></i> Withdraw
          </button>
        </div>
      </div>
    `;
  }).join('');
}
window.renderSavingsGoals = renderSavingsGoals;

// --- Receipt Attachment, WebP Compression & OCR Engine ---
let pendingReceiptDataUrl = null;
let currentReceiptZoom = 1;
let currentReceiptRotation = 0;
let currentReceiptId = null;

// 1. Canvas Grayscale & WebP Image Compression (~60KB)
function compressReceiptImage(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error('Failed to read image file'));
    reader.onload = (e) => {
      const img = new Image();
      img.onerror = () => reject(new Error('Failed to load image element'));
      img.onload = () => {
        const MAX_WIDTH = 1000;
        let width = img.width;
        let height = img.height;

        if (width > MAX_WIDTH) {
          height = Math.round((height * MAX_WIDTH) / width);
          width = MAX_WIDTH;
        }

        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d');

        ctx.drawImage(img, 0, 0, width, height);

        // High contrast grayscale filter for OCR boost
        const imageData = ctx.getImageData(0, 0, width, height);
        const data = imageData.data;
        for (let i = 0; i < data.length; i += 4) {
          const avg = (data[i] + data[i + 1] + data[i + 2]) / 3;
          const contrastAvg = avg > 128 ? Math.min(255, avg * 1.12) : Math.max(0, avg * 0.88);
          data[i] = contrastAvg;
          data[i + 1] = contrastAvg;
          data[i + 2] = contrastAvg;
        }
        ctx.putImageData(imageData, 0, 0);

        const compressedDataUrl = canvas.toDataURL('image/webp', 0.75);
        resolve(compressedDataUrl);
      };
      img.src = e.target.result;
    };
    reader.readAsDataURL(file);
  });
}

// 2. High-Contrast Receipt Image Preprocessing for Thermal Paper OCR
function preprocessReceiptForOcr(imageSource) {
  return new Promise((resolve) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      try {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        const scale = Math.max(1, Math.min(2.5, 1400 / (img.width || 800)));
        canvas.width = Math.round(img.width * scale);
        canvas.height = Math.round(img.height * scale);

        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const data = imgData.data;

        // Adaptive high-contrast greyscale
        for (let i = 0; i < data.length; i += 4) {
          const avg = 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];
          const enhanced = avg < 145 ? Math.max(0, avg * 0.65) : Math.min(255, avg * 1.3);
          data[i] = enhanced;
          data[i + 1] = enhanced;
          data[i + 2] = enhanced;
        }
        ctx.putImageData(imgData, 0, 0);
        resolve(canvas.toDataURL('image/png'));
      } catch (e) {
        resolve(imageSource);
      }
    };
    img.onerror = () => resolve(imageSource);
    img.src = imageSource;
  });
}

// 3. Multi-Tier OCR Text Scanning (Electron Native -> Server Engine -> Browser Fallback)
async function scanReceiptOCR(file, compressedDataUrl) {
  const ocrBadge = document.getElementById('ocr-status-badge');
  if (ocrBadge) {
    ocrBadge.classList.remove('hidden');
    ocrBadge.className = 'ocr-status-badge text-emerald';
    ocrBadge.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> ⚡ Scanning receipt items & totals via OCR...';
  }

  let extractedText = '';

  // Tier 1: Electron Native IPC (100% offline Node OCR)
  if (window.electronAPI && typeof window.electronAPI.scanReceiptOcr === 'function') {
    try {
      const res = await window.electronAPI.scanReceiptOcr(compressedDataUrl);
      if (res && res.success && res.text) {
        extractedText = res.text;
      }
    } catch (e) {
      console.warn('Electron OCR IPC notice:', e);
    }
  }

  // Tier 2: Server API endpoint /api/scan-receipt
  if (!extractedText) {
    try {
      const resp = await fetch('/api/scan-receipt', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ image: compressedDataUrl })
      });
      if (resp.ok) {
        const data = await resp.json();
        if (data && data.success && data.text) {
          extractedText = data.text;
        }
      }
    } catch (e) {
      console.warn('Server OCR endpoint notice:', e);
    }
  }

  // Tier 3: Client-side Tesseract.js fallback
  if (!extractedText) {
    try {
      if (typeof Tesseract === 'undefined') {
        await loadExternalScript('https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js');
      }
      if (typeof Tesseract !== 'undefined') {
        const processedUrl = await preprocessReceiptForOcr(compressedDataUrl);
        const result = await Tesseract.recognize(processedUrl, 'eng');
        if (result && result.data && result.data.text) {
          extractedText = result.data.text;
        }
      }
    } catch (e) {
      console.warn('Client-side Tesseract fallback notice:', e);
    }
  }

  if (extractedText && extractedText.trim().length > 0) {
    parseReceiptText(extractedText);
    if (ocrBadge) {
      ocrBadge.className = 'ocr-status-badge text-emerald';
      ocrBadge.innerHTML = '<i class="fa-solid fa-circle-check"></i> OCR Scan & Item Breakdown Complete!';
      setTimeout(() => ocrBadge.classList.add('hidden'), 3500);
    }
  } else {
    if (ocrBadge) {
      ocrBadge.className = 'ocr-status-badge text-amber';
      ocrBadge.innerHTML = '<i class="fa-solid fa-paperclip"></i> Receipt attached! (Fill amount manually)';
      setTimeout(() => ocrBadge.classList.add('hidden'), 3500);
    }
  }
}

function loadExternalScript(src) {
  return new Promise((resolve, reject) => {
    if (document.querySelector(`script[src="${src}"]`)) return resolve();
    const script = document.createElement('script');
    script.src = src;
    script.onload = resolve;
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

let lastParsedReceiptData = null;

function parseReceiptText(text) {
  if (!text) return;
  const structured = parseReceiptStructured(text);
  lastParsedReceiptData = structured;
  renderOcrBreakdown(structured);
  applyOcrToForm(structured);
}

function parseReceiptStructured(text) {
  const lines = text.split(/\r?\n/).map(l => l.trim()).filter(l => l.length > 0);
  const structured = {
    merchant: '',
    date: '',
    items: [],
    subtotal: 0,
    tax: 0,
    total: 0,
    paymentMethod: 'Card / UPI',
    category: 'Food & Dining',
    rawText: text
  };

  // 1. Merchant Detection & Brand Matching
  const brandKeywords = [
    { name: "McDonald's", match: /mcdonald|hardcastle|mcspicy|mcafee|mcd/i, cat: 'Food & Dining' },
    { name: "Starbucks", match: /starbucks|frappuccino|espresso/i, cat: 'Food & Dining' },
    { name: "Subway", match: /subway/i, cat: 'Food & Dining' },
    { name: "Domino's Pizza", match: /domino|jubilant\s*food/i, cat: 'Food & Dining' },
    { name: "KFC", match: /kfc|yum\s*restaurants/i, cat: 'Food & Dining' },
    { name: "Burger King", match: /burger\s*king/i, cat: 'Food & Dining' },
    { name: "Pizza Hut", match: /pizza\s*hut/i, cat: 'Food & Dining' },
    { name: "Swiggy", match: /swiggy|bundl/i, cat: 'Food & Dining' },
    { name: "Zomato", match: /zomato/i, cat: 'Food & Dining' },
    { name: "DMart", match: /dmart|avenue\s*supermarts/i, cat: 'Groceries' },
    { name: "Reliance Fresh / Smart", match: /reliance\s*(fresh|smart|retail)/i, cat: 'Groceries' },
    { name: "Zepto / Blinkit", match: /zepto|blinkit|grofers/i, cat: 'Groceries' },
    { name: "Amazon", match: /amazon/i, cat: 'Shopping' },
    { name: "Flipkart", match: /flipkart/i, cat: 'Shopping' },
    { name: "Apple Store", match: /apple\s*store|apple\s*india/i, cat: 'Technology' },
    { name: "Uber / Ola", match: /uber|ola\s*cabs|ani\s*technologies/i, cat: 'Transportation' }
  ];

  for (const b of brandKeywords) {
    if (b.match.test(text)) {
      structured.merchant = b.name;
      structured.category = b.cat;
      break;
    }
  }

  if (!structured.merchant) {
    const topLines = lines.slice(0, 4).filter(l => !/order|tax|invoice|table|token|bill|welcome|tel|ph|gst/i.test(l));
    if (topLines.length > 0) {
      structured.merchant = topLines[0].replace(/[^a-zA-Z0-9\s&'-]/g, '').trim().slice(0, 45);
    } else {
      structured.merchant = 'Receipt Expense';
    }
  }

  // 2. Date Extraction
  const dateRegex = /(\d{1,2}[\/\.-]\d{1,2}[\/\.-]\d{2,4}|\d{4}[\/\.-]\d{1,2}[\/\.-]\d{1,2})/;
  const dateMatch = dateRegex.exec(text);
  if (dateMatch) {
    try {
      const parts = dateMatch[1].split(/[\/\.-]/);
      let dObj = null;
      if (parts[0].length === 4) {
        dObj = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
      } else if (parts[2].length === 4) {
        dObj = new Date(parseInt(parts[2], 10), parseInt(parts[1], 10) - 1, parseInt(parts[0], 10));
      }
      if (dObj && !isNaN(dObj.getTime())) {
        structured.date = dObj.toISOString().split('T')[0];
      }
    } catch(e) {}
  }
  if (!structured.date) {
    structured.date = new Date().toISOString().split('T')[0];
  }

  // 3. Tabular Item & Financial Summary Extraction
  const parsedItems = [];
  const itemRowRegex = /^(?:(\d+)\s+)?(.+?)\s+([₹$€£]?\s*[\d,]+\.\d{2})$/i;

  lines.forEach((line) => {
    const subMatch = /(?:sub[\s-]?total|subtotal|net\s*amount)\s*[:=]?\s*([₹$€£]?\s*[\d,]+\.\d{2})/i.exec(line);
    if (subMatch) {
      const val = parseFloat(subMatch[1].replace(/[^0-9.]/g, ''));
      if (!isNaN(val)) structured.subtotal = val;
      return;
    }

    const taxMatch = /(?:cgst|sgst|gst|vat|tax)\s*(?:@\s*[\d.]+%)?\s*[:=]?\s*([₹$€£]?\s*[\d,]+\.\d{2})/i.exec(line);
    if (taxMatch) {
      const val = parseFloat(taxMatch[1].replace(/[^0-9.]/g, ''));
      if (!isNaN(val)) structured.tax += val;
      return;
    }

    const totalMatch = /(?:eat-in\s*total|grand\s*total|total|amount\s*paid|net\s*payable|paid)\s*[:=]?\s*([₹$€£]?\s*[\d,]+\.\d{2})/i.exec(line);
    if (totalMatch) {
      const val = parseFloat(totalMatch[1].replace(/[^0-9.]/g, ''));
      if (!isNaN(val) && val > structured.total) structured.total = val;
      return;
    }

    if (/card|visa|mastercard|amex|pos|debit|credit/i.test(line)) {
      structured.paymentMethod = 'Card / UPI';
    } else if (/upi|gpay|phonepe|paytm|qr/i.test(line)) {
      structured.paymentMethod = 'UPI / GPay';
    } else if (/cash/i.test(line)) {
      structured.paymentMethod = 'Cash';
    }

    if (!/invoice|gstin|fssai|phone|reg|qty|table|counter|welcome|visit|feedback|card|change|cash|balance|tax/i.test(line)) {
      const m = itemRowRegex.exec(line);
      if (m) {
        const qty = parseInt(m[1], 10) || 1;
        let name = m[2].trim().replace(/^[-*•\s]+/, '');
        const price = parseFloat(m[3].replace(/[^0-9.]/g, ''));
        if (name.length >= 3 && !isNaN(price) && price > 0 && price < 100000) {
          parsedItems.push({ name, qty, price });
        }
      }
    }
  });

  structured.items = parsedItems;

  if (structured.total === 0) {
    if (structured.subtotal > 0) {
      structured.total = structured.subtotal + (structured.tax || 0);
    } else if (parsedItems.length > 0) {
      const itemsSum = parsedItems.reduce((s, i) => s + i.price, 0);
      structured.total = itemsSum + (structured.tax || 0);
    } else {
      const allNums = (text.match(/[\d,]+\.\d{2}/g) || []).map(n => parseFloat(n.replace(/,/g, ''))).filter(n => !isNaN(n) && n < 500000);
      if (allNums.length > 0) structured.total = Math.max(...allNums);
    }
  }

  structured.total = Math.round(structured.total * 100) / 100;
  structured.subtotal = Math.round((structured.subtotal || (structured.total - structured.tax)) * 100) / 100;
  structured.tax = Math.round(structured.tax * 100) / 100;

  return structured;
}

function renderOcrBreakdown(structured) {
  const container = document.getElementById('ocr-itemized-breakdown');
  const storeEl = document.getElementById('ocr-detected-store');
  const itemsList = document.getElementById('ocr-items-list');
  const subtotalVal = document.getElementById('ocr-subtotal-val');
  const taxVal = document.getElementById('ocr-tax-val');
  const totalVal = document.getElementById('ocr-total-val');

  if (!container || !itemsList) return;

  if (storeEl) storeEl.textContent = structured.merchant || 'Store Receipt';

  itemsList.innerHTML = '';
  if (structured.items && structured.items.length > 0) {
    structured.items.forEach(item => {
      const row = document.createElement('div');
      row.className = 'ocr-item-row';
      row.innerHTML = `
        <span class="ocr-item-name">${escapeHtml(item.name)} ${item.qty > 1 ? '<span class="text-muted">(' + item.qty + 'x)</span>' : ''}</span>
        <span class="ocr-item-price">${formatCurrency(item.price)}</span>
      `;
      itemsList.appendChild(row);
    });
  } else {
    itemsList.innerHTML = '<div class="text-muted" style="padding: 0.25rem 0.5rem; font-style: italic;">No individual item rows detected — full amount captured.</div>';
  }

  if (subtotalVal) subtotalVal.textContent = formatCurrency(structured.subtotal || structured.total);
  if (taxVal) taxVal.textContent = formatCurrency(structured.tax || 0);
  if (totalVal) totalVal.textContent = formatCurrency(structured.total);

  container.classList.remove('hidden');
}

function applyOcrToForm(structured) {
  if (!structured) return;

  const amountInput = document.getElementById('exp-amount');
  const descInput = document.getElementById('exp-description');
  const dateInput = document.getElementById('exp-date');
  const catSelect = document.getElementById('exp-category');
  const paymentSelect = document.getElementById('exp-payment');
  const aiBadge = document.getElementById('ai-cat-badge');

  if (amountInput && structured.total > 0) {
    amountInput.value = structured.total.toFixed(2);
  }

  if (descInput) {
    if (structured.items && structured.items.length > 0) {
      const itemsSummary = structured.items.map(i => i.name).join(', ');
      descInput.value = `${structured.merchant}: ${itemsSummary}`.slice(0, 70);
    } else {
      descInput.value = structured.merchant || 'Receipt Expense';
    }
  }

  if (dateInput && structured.date) {
    dateInput.value = structured.date;
  }

  if (catSelect && structured.category) {
    catSelect.value = structured.category;
    if (aiBadge) {
      aiBadge.classList.remove('hidden');
      aiBadge.innerHTML = `<i class="fa-solid fa-wand-magic-sparkles"></i> AI: ${structured.category}`;
    }
  }

  if (paymentSelect && structured.paymentMethod) {
    paymentSelect.value = structured.paymentMethod;
  }
}

window.applyOcrSingleExpense = function() {
  if (lastParsedReceiptData) {
    applyOcrToForm(lastParsedReceiptData);
    if (typeof showToast === 'function') {
      showToast('✓ Form filled with receipt details!', 'success');
    }
  }
};

window.logOcrSplitTransactions = function() {
  if (!lastParsedReceiptData || !lastParsedReceiptData.items || lastParsedReceiptData.items.length === 0) {
    if (typeof showAlert === 'function') {
      showAlert('Notice', 'No individual line items to split. Use "Add Expense Record" to log the total amount.');
    }
    return;
  }

  const items = lastParsedReceiptData.items;
  const merchant = lastParsedReceiptData.merchant || 'Store';
  const date = lastParsedReceiptData.date || new Date().toISOString().split('T')[0];
  const payment = lastParsedReceiptData.paymentMethod || 'Card / UPI';
  const category = lastParsedReceiptData.category || 'Food & Dining';
  const receipt = pendingReceiptDataUrl || '';

  let count = 0;
  items.forEach(item => {
    const expenseRecord = {
      id: 'exp_' + Date.now() + '_' + Math.random().toString(36).substr(2, 6),
      description: `${merchant} - ${item.name}`,
      amount: item.price,
      category: category,
      payment: payment,
      date: date,
      receipt: receipt,
      receiptUrl: receipt,
      created_at: new Date().toISOString()
    };
    if (typeof addExpense === 'function') {
      addExpense(expenseRecord);
      count++;
    }
  });

  // Also log tax as a separate line if present and > 0
  if (lastParsedReceiptData.tax && lastParsedReceiptData.tax > 0) {
    const taxRecord = {
      id: 'exp_' + Date.now() + '_tax',
      description: `${merchant} - GST / Tax`,
      amount: lastParsedReceiptData.tax,
      category: category,
      payment: payment,
      date: date,
      receipt: receipt,
      receiptUrl: receipt,
      created_at: new Date().toISOString()
    };
    if (typeof addExpense === 'function') {
      addExpense(taxRecord);
      count++;
    }
  }

  // Clear inputs & hide OCR breakdown
  const form = document.getElementById('add-expense-form');
  if (form) form.reset();
  const breakdown = document.getElementById('ocr-itemized-breakdown');
  if (breakdown) breakdown.classList.add('hidden');
  const pill = document.getElementById('receipt-preview-pill');
  if (pill) pill.classList.add('hidden');
  pendingReceiptDataUrl = null;

  if (typeof updateUI === 'function') updateUI();

  if (typeof showToast === 'function') {
    showToast(`🎉 Logged ${count} itemized transactions from receipt!`, 'success');
  }
};

// 3. File Selection & Drag-and-Drop Handlers
window.handleReceiptSelect = async function(e) {
  const file = e.target.files ? e.target.files[0] : null;
  if (!file) return;
  await processReceiptFile(file);
};

async function processReceiptFile(file) {
  try {
    const compressedDataUrl = await compressReceiptImage(file);
    pendingReceiptDataUrl = compressedDataUrl;
    showReceiptPreviewPill(file.name, compressedDataUrl);
    scanReceiptOCR(file, compressedDataUrl);
  } catch (err) {
    console.error('Error processing receipt:', err);
    if (typeof showAlert === 'function') {
      showAlert('Receipt Upload Error', 'Could not process receipt file. Please upload a valid image (JPG, PNG, WebP).');
    }
  }
}

function showReceiptPreviewPill(fileName, dataUrl) {
  const pill = document.getElementById('receipt-preview-pill');
  const thumb = document.getElementById('receipt-preview-thumb');
  const nameEl = document.getElementById('receipt-preview-name');
  if (pill && thumb && nameEl) {
    thumb.src = dataUrl;
    nameEl.textContent = fileName || 'receipt.webp';
    pill.classList.remove('hidden');
  }
}

window.clearReceiptAttachment = function(e) {
  if (e) e.stopPropagation();
  pendingReceiptDataUrl = null;
  const fileInput = document.getElementById('exp-receipt-input');
  const pill = document.getElementById('receipt-preview-pill');
  if (fileInput) fileInput.value = '';
  if (pill) pill.classList.add('hidden');
};

// 4. Modal Viewer Controls (Zoom & Rotate)
window.openReceiptModal = function(expenseId) {
  const exp = expenses.find(e => String(e.id) === String(expenseId));
  if (!exp || !exp.receipt) return;

  currentReceiptId = expenseId;
  currentReceiptZoom = 1;
  currentReceiptRotation = 0;

  const modal = document.getElementById('receipt-modal');
  const img = document.getElementById('receipt-modal-img');
  if (img) {
    img.src = exp.receipt;
    img.style.transform = `scale(1) rotate(0deg)`;
  }
  if (modal) {
    modal.classList.remove('hidden');
    modal.style.display = 'flex';
  }
};

window.closeReceiptModal = function(e) {
  if (e && e.preventDefault) e.preventDefault();
  const modal = document.getElementById('receipt-modal');
  if (modal) {
    modal.classList.add('hidden');
    modal.style.display = 'none';
  }
};

window.zoomReceipt = function(delta) {
  currentReceiptZoom = Math.min(3, Math.max(0.5, currentReceiptZoom + delta));
  applyReceiptTransform();
};

window.rotateReceipt = function(deg) {
  currentReceiptRotation = (currentReceiptRotation + deg) % 360;
  applyReceiptTransform();
};

window.resetReceiptTransform = function() {
  currentReceiptZoom = 1;
  currentReceiptRotation = 0;
  applyReceiptTransform();
};

function applyReceiptTransform() {
  const img = document.getElementById('receipt-modal-img');
  if (img) {
    img.style.transform = `scale(${currentReceiptZoom}) rotate(${currentReceiptRotation}deg)`;
  }
}

window.downloadReceiptAttachment = function() {
  const img = document.getElementById('receipt-modal-img');
  if (!img || !img.src) return;
  const a = document.createElement('a');
  a.href = img.src;
  a.download = `receipt_${currentReceiptId || 'attachment'}.webp`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
};

// ============================================================
// SMART BULK BANK CSV IMPORTER ENGINE (Native Platform / Ponytail First)
// ============================================================
let parsedCsvRecords = [];

window.openCsvImportModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  parsedCsvRecords = [];
  const modal = document.getElementById('csv-import-modal');
  const previewContainer = document.getElementById('csv-preview-container');
  const confirmBtn = document.getElementById('btn-confirm-csv-import');
  const fileInput = document.getElementById('csv-file-input');

  if (fileInput) fileInput.value = '';
  if (previewContainer) previewContainer.classList.add('hidden');
  if (confirmBtn) confirmBtn.classList.add('hidden');

  if (modal) {
    modal.classList.remove('hidden');
    modal.style.setProperty('display', 'flex', 'important');
    modal.style.setProperty('opacity', '1', 'important');
    modal.style.setProperty('visibility', 'visible', 'important');
    modal.style.setProperty('pointer-events', 'auto', 'important');
    modal.style.setProperty('z-index', '100000', 'important');
  }
};

window.closeCsvImportModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  parsedCsvRecords = [];
  const modal = document.getElementById('csv-import-modal');
  if (modal) {
    modal.classList.add('hidden');
    modal.style.setProperty('display', 'none', 'important');
    modal.style.setProperty('pointer-events', 'none', 'important');
  }
};

function autoCategorizeDescription(desc) {
  const s = String(desc || '').toLowerCase();
  if (/swiggy|zomato|starbucks|dunkin|mcdonald|kfc|pizza|domino|restaurant|food|dine|cafe|grocery|blinkit|zepto|instamart|supermarket/i.test(s)) return 'Food & Dining';
  if (/uber|ola|lyft|fuel|petrol|diesel|shell|hpcl|bpcl|metro|rail|train|flight|airline|parking|toll/i.test(s)) return 'Transportation';
  if (/amazon|flipkart|myntra|zara|nike|adidas|target|walmart|apple store|mall|shopping|apparel/i.test(s)) return 'Shopping';
  if (/netflix|spotify|youtube|prime|disney|apple|google|hulu|hbo|membership|subscription/i.test(s)) return 'Services & Subscriptions';
  if (/electricity|water|gas|wifi|airtel|jio|broadband|utility|bill|mobile|recharge/i.test(s)) return 'Bills & Utilities';
  if (/cinema|pvr|inox|movie|game|steam|playstation|xbox|event|ticket/i.test(s)) return 'Entertainment';
  if (/hospital|pharmacy|doctor|apollo|cvs|health|gym|fitness|medical/i.test(s)) return 'Health & Fitness';
  return 'Miscellaneous';
}

window.handleCsvFileSelect = function(e) {
  const file = e.target.files && e.target.files[0];
  if (!file) return;

  const fileName = (file.name || '').toLowerCase();
  const isExcel = fileName.endsWith('.xlsx') || fileName.endsWith('.xls');
  const isPdf = fileName.endsWith('.pdf');

  if (isPdf) {
    loadAndParsePdfFile(file);
  } else if (isExcel) {
    loadAndParseExcelFile(file);
  } else {
    const reader = new FileReader();
    reader.onload = function(evt) {
      const text = evt.target.result || '';
      if (text.startsWith('%PDF')) {
        loadAndParsePdfFile(file);
        return;
      }
      if (text.startsWith('PK\x03\x04') || text.includes('\x00\x00') || /[\x00-\x08\x0E-\x1F]/.test(text.substring(0, 100))) {
        loadAndParseExcelFile(file);
        return;
      }
      parseBankCsvText(text);
    };
    reader.readAsText(file);
  }
};

function loadAndParsePdfFile(file) {
  function processFile() {
    if (typeof pdfjsLib === 'undefined') {
      if (typeof showAlert === 'function') {
        showAlert('PDF Parser Unavailable', 'Unable to load PDF parser library. Please convert your PDF statement to CSV or Excel and try again.');
      } else {
        alert('Unable to load PDF parser library. Please convert your PDF statement to CSV or Excel and try again.');
      }
      return;
    }

    try {
      if (pdfjsLib.GlobalWorkerOptions && !pdfjsLib.GlobalWorkerOptions.workerSrc) {
        pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdn.jsdelivr.net/npm/pdfjs-dist@3.11.174/build/pdf.worker.min.js';
      }
    } catch(e) {}

    const reader = new FileReader();
    reader.onload = function(evt) {
      const typedArray = new Uint8Array(evt.target.result);
      pdfjsLib.getDocument({ data: typedArray }).promise.then(function(pdf) {
        let maxPages = pdf.numPages;
        let pagePromises = [];

        for (let p = 1; p <= maxPages; p++) {
          pagePromises.push(pdf.getPage(p).then(function(page) {
            return page.getTextContent().then(function(textContent) {
              let linesMap = {};
              textContent.items.forEach(function(item) {
                if (!item.str || !item.str.trim()) return;
                let y = Math.round(item.transform[5]);
                if (!linesMap[y]) linesMap[y] = [];
                linesMap[y].push({ x: item.transform[4], str: item.str.trim() });
              });

              let sortedYs = Object.keys(linesMap).map(Number).sort((a, b) => b - a);
              let pageLines = [];

              sortedYs.forEach(function(y) {
                let lineItems = linesMap[y].sort((a, b) => a.x - b.x);
                pageLines.push(lineItems.map(i => i.str).join(' , '));
              });

              return pageLines.join('\n');
            });
          }));
        }

        Promise.all(pagePromises).then(function(pagesTexts) {
          const fullPdfText = pagesTexts.join('\n');
          if (!fullPdfText || !fullPdfText.trim()) {
            if (typeof showAlert === 'function') {
              showAlert('Empty PDF File', 'Could not extract text from this PDF file. It might be a scanned image or password-protected.');
            } else {
              alert('Could not extract text from this PDF file. It might be a scanned image or password-protected.');
            }
            return;
          }
          parseBankCsvText(fullPdfText);
        }).catch(function(err) {
          console.error('PDF text extraction error:', err);
          if (typeof showAlert === 'function') {
            showAlert('PDF Parse Error', 'Failed to extract text from PDF file. Please ensure it is a text-based bank statement.');
          } else {
            alert('Failed to extract text from PDF file. Please ensure it is a text-based bank statement.');
          }
        });
      }).catch(function(err) {
        console.error('PDF document load error:', err);
        if (typeof showAlert === 'function') {
          showAlert('PDF Read Error', 'Could not open PDF file. If it is password protected, please remove the password or convert to CSV/Excel first.');
        } else {
          alert('Could not open PDF file. If it is password protected, please remove the password or convert to CSV/Excel first.');
        }
      });
    };
    reader.readAsArrayBuffer(file);
  }

  if (typeof pdfjsLib === 'undefined') {
    const script = document.createElement('script');
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js';
    script.onload = processFile;
    script.onerror = function() {
      if (typeof showAlert === 'function') {
        showAlert('PDF Import Error', 'Could not load PDF parser library from CDN. Please save your file as CSV or Excel format.');
      } else {
        alert('Could not load PDF parser library from CDN. Please save your file as CSV or Excel format.');
      }
    };
    document.head.appendChild(script);
  } else {
    processFile();
  }
}

function loadAndParseExcelFile(file) {
  function processFile() {
    if (typeof XLSX === 'undefined') {
      if (typeof showAlert === 'function') {
        showAlert('Excel Parser Unavailable', 'Unable to parse Excel file. Please save your Excel sheet as CSV (.csv) in Excel or Google Sheets.');
      } else {
        alert('Unable to parse Excel file. Please save your Excel sheet as CSV (.csv) in Excel or Google Sheets.');
      }
      return;
    }
    const reader = new FileReader();
    reader.onload = function(evt) {
      try {
        const data = new Uint8Array(evt.target.result);
        const workbook = XLSX.read(data, { type: 'array' });
        if (!workbook || !workbook.SheetNames || workbook.SheetNames.length === 0) {
          if (typeof showAlert === 'function') showAlert('Invalid Excel File', 'The selected Excel file contains no readable sheets.');
          return;
        }

        // Scan all sheets and pick the sheet with the most data rows
        let bestCsvText = '';
        let maxRowsFound = -1;

        for (let s = 0; s < workbook.SheetNames.length; s++) {
          const sheetName = workbook.SheetNames[s];
          const ws = workbook.Sheets[sheetName];
          if (!ws) continue;
          const csv = XLSX.utils.sheet_to_csv(ws);
          const nonCols = csv.split(/\r\n|\n/).filter(l => l.trim().length > 0);
          if (nonCols.length > maxRowsFound) {
            maxRowsFound = nonCols.length;
            bestCsvText = csv;
          }
        }

        if (!bestCsvText || !bestCsvText.trim()) {
          if (typeof showAlert === 'function') showAlert('Empty Excel Sheet', 'The selected Excel sheet contains no data rows.');
          return;
        }
        parseBankCsvText(bestCsvText);
      } catch(err) {
        console.error('XLSX parse error:', err);
        if (typeof showAlert === 'function') {
          showAlert('Excel Parse Error', 'Failed to read Excel workbook. Please save your sheet as CSV format (.csv) and try again.');
        } else {
          alert('Failed to read Excel workbook. Please save your sheet as CSV format (.csv) and try again.');
        }
      }
    };
    reader.readAsArrayBuffer(file);
  }

  if (typeof XLSX === 'undefined') {
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js';
    script.onload = processFile;
    script.onerror = function() {
      if (typeof showAlert === 'function') {
        showAlert('XLSX Import Error', 'Could not load Excel parser. Please save your file as CSV (.csv) in Excel or Google Sheets before uploading.');
      } else {
        alert('Could not load Excel parser. Please save your file as CSV (.csv) in Excel or Google Sheets before uploading.');
      }
    };
    document.head.appendChild(script);
  } else {
    processFile();
  }
}

function parseBankCsvText(csvText) {
  if (!csvText || !csvText.trim()) {
    if (typeof showAlert === 'function') showAlert('Empty File', 'The selected file contains no readable text or rows.');
    return;
  }

  const lines = csvText.split(/\r\n|\n/).map(l => l.trim()).filter(l => l.length > 0);
  if (lines.length < 1) {
    if (typeof showAlert === 'function') showAlert('Invalid File', 'File contains no transaction data rows.');
    return;
  }

  // 1. Smart Header Scanner: Scan up to 50 lines for the true table header row
  let headerRowIndex = -1;
  let bestHeaderScore = 0;
  let headers = [];

  for (let r = 0; r < Math.min(lines.length, 50); r++) {
    const candidateHeaders = parseCsvRow(lines[r]).map(h => h.toLowerCase().trim());
    let score = 0;
    candidateHeaders.forEach(h => {
      if (/date|time|timestamp|txn_date|value_date|booking_date|post_date|tran_date|date\/time/i.test(h)) score += 3;
      if (/desc|description|payee|narrative|particulars|details|vendor|name|remarks|narration|notes|ref|statement/i.test(h)) score += 3;
      if (/(^|\b)amount|debit|credit|withdrawal|deposit|spent|received|val|cost|total|price|amt(\b|$)/i.test(h) && !/balance/i.test(h)) score += 3;
      if (/category|type|tag|cr\/dr|dr\/cr/i.test(h)) score += 1;
      if (/payment|method|mode|channel/i.test(h)) score += 1;
    });
    if (score > bestHeaderScore && score >= 2) {
      bestHeaderScore = score;
      headerRowIndex = r;
      headers = candidateHeaders;
    }
  }

  let dateIdx = -1;
  let descIdx = -1;
  let debitIdx = -1;
  let creditIdx = -1;
  let amountIdx = -1;
  let crDrIdx = -1;
  let categoryIdx = -1;
  let paymentIdx = -1;

  if (headerRowIndex !== -1) {
    dateIdx = headers.findIndex(h => /date|time|timestamp|txn_date|value_date|booking_date|post_date|tran_date/i.test(h));
    descIdx = headers.findIndex(h => {
      if (/cheque|chq|ref|reference|sl\.no|s\.no|txn id|transaction id/i.test(h)) return false;
      return /particulars|narration|transaction details|desc|description|payee|narrative|details|remarks|vendor|name|notes/i.test(h);
    });
    debitIdx = headers.findIndex(h => /debit|withdrawal|outflow|spent|amt_debited|money_out/i.test(h));
    creditIdx = headers.findIndex(h => /credit|deposit|inflow|received|amt_credited|money_in/i.test(h));
    amountIdx = headers.findIndex(h => /(^|\b)amount|net|sum|total|val|cost|price|amt(\b|$)/i.test(h) && !/balance/i.test(h));
    crDrIdx = headers.findIndex(h => /cr\/dr|dr\/cr|type/i.test(h));
    categoryIdx = headers.findIndex(h => /category|tag/i.test(h));
    paymentIdx = headers.findIndex(h => /payment|method|mode|channel/i.test(h));
  }

  parsedCsvRecords = [];
  const startIndex = headerRowIndex !== -1 ? headerRowIndex + 1 : 0;

  // 3. Process Data Rows
  for (let i = startIndex; i < lines.length; i++) {
    const cols = parseCsvRow(lines[i]);
    if (!cols || cols.length === 0) continue;

    // Skip summary / total rows & balance rows
    const rowTextAll = cols.join(' ').toLowerCase();
    if (rowTextAll.includes('total amount') || rowTextAll.includes('closing balance') || rowTextAll.includes('opening balance') || rowTextAll.includes('balance b/f') || rowTextAll.includes('balance c/f') || rowTextAll.includes('end of statement') || rowTextAll.includes('page ') || rowTextAll.includes('account statement')) {
      continue;
    }

    // Universal Cell Extractor
    let rawDate = (dateIdx !== -1 && cols[dateIdx]) ? cols[dateIdx] : '';
    let rawDesc = (descIdx !== -1 && cols[descIdx]) ? cols[descIdx].trim() : '';
    
    let numDebit = (debitIdx !== -1 && cols[debitIdx]) ? Math.abs(parseFloat(String(cols[debitIdx]).replace(/[^0-9.-]/g, '')) || 0) : 0;
    let numCredit = (creditIdx !== -1 && cols[creditIdx]) ? Math.abs(parseFloat(String(cols[creditIdx]).replace(/[^0-9.-]/g, '')) || 0) : 0;
    let numAmount = (amountIdx !== -1 && cols[amountIdx]) ? Math.abs(parseFloat(String(cols[amountIdx]).replace(/[^0-9.-]/g, '')) || 0) : 0;

    // Universal Fallback if column matching failed
    if (!rawDate || (!numDebit && !numCredit && !numAmount)) {
      for (let c = 0; c < cols.length; c++) {
        const val = (cols[c] || '').trim();
        if (!val) continue;

        // Auto-detect Date cell
        if (!rawDate && /(\d{1,4}[-/\.]\d{1,2}[-/\.]\d{1,4}|\d{1,2}\s+[A-Za-z]{3}\s+\d{2,4})/.test(val)) {
          rawDate = val;
        } else {
          // Auto-detect Numeric Amount cell
          const cleanNum = Math.abs(parseFloat(val.replace(/[^0-9.-]/g, '')) || 0);
          if (cleanNum > 0 && !numAmount && !numDebit && !numCredit && !/balance/i.test(headers[c] || '')) {
            numAmount = cleanNum;
          } else if (!rawDesc && val.length > 2 && isNaN(cleanNum) && !/^\d+$/.test(val)) {
            rawDesc = val;
          }
        }
      }
    }

    if (/opening balance|closing balance|balance b\/f|balance c\/f/i.test(rawDesc)) continue;
    if (!rawDesc) rawDesc = 'Bank Transaction';

    let finalAmount = 0;
    if (numDebit > 0) finalAmount = numDebit;
    else if (numCredit > 0) finalAmount = numCredit;
    else if (numAmount > 0) finalAmount = numAmount;

    if (finalAmount <= 0) continue;

    const rawCategory = (categoryIdx !== -1 && cols[categoryIdx]) ? cols[categoryIdx] : null;
    const rawPayment = (paymentIdx !== -1 && cols[paymentIdx]) ? cols[paymentIdx] : 'UPI';

    const formattedDate = parseAndFormatDate(rawDate);
    const category = rawCategory && rawCategory.trim() ? rawCategory.trim() : autoCategorizeDescription(rawDesc);
    const payment = rawPayment && rawPayment.trim() ? rawPayment.trim() : 'UPI';

    parsedCsvRecords.push({
      selected: true,
      id: Date.now().toString(36) + Math.random().toString(36).slice(2, 7) + i,
      date: formattedDate,
      description: rawDesc,
      category: category,
      payment: payment,
      amount: finalAmount
    });
  }

  if (parsedCsvRecords.length === 0) {
    if (typeof showAlert === 'function') {
      showAlert('No Valid Transactions Found', 'Could not parse any valid numeric transactions. Please check if your bank statement file has empty data rows.');
    }
    return;
  }

  renderCsvPreviewTable();
}

function parseCsvRow(rowText) {
  const result = [];
  let insideQuotes = false;
  let entry = '';
  for (let i = 0; i < rowText.length; i++) {
    const c = rowText[i];
    if (c === '"') {
      insideQuotes = !insideQuotes;
    } else if (c === ',' && !insideQuotes) {
      result.push(entry.trim());
      entry = '';
    } else {
      entry += c;
    }
  }
  result.push(entry.trim());
  return result;
}

function parseAndFormatDate(dStr) {
  if (!dStr || !String(dStr).trim()) return getLocalDateString();
  const str = String(dStr).trim();

  const monthsMap = {
    jan: '01', feb: '02', mar: '03', apr: '04', may: '05', jun: '06',
    jul: '07', aug: '08', sep: '09', oct: '10', nov: '11', dec: '12'
  };

  // 1. DD-MMM-YYYY or DD/MMM/YYYY or DD MMM YYYY (e.g. 01-Apr-2026)
  const ddMmmYyyyMatch = str.match(/^(\d{1,2})[-\/\s\.]+([A-Za-z]{3})[-\/\s\.]+(\d{2,4})/);
  if (ddMmmYyyyMatch) {
    let day = ddMmmYyyyMatch[1].padStart(2, '0');
    let mStr = ddMmmYyyyMatch[2].toLowerCase();
    let month = monthsMap[mStr] || '01';
    let yr = ddMmmYyyyMatch[3];
    if (yr.length === 2) yr = '20' + yr;
    return `${yr}-${month}-${day}`;
  }

  // 2. ISO / Standard YYYY-MM-DD
  const isoMatch = str.match(/^(\d{4})[-\/\.](\d{1,2})[-\/\.](\d{1,2})/);
  if (isoMatch) {
    return `${isoMatch[1]}-${isoMatch[2].padStart(2, '0')}-${isoMatch[3].padStart(2, '0')}`;
  }

  // 3. DD/MM/YYYY or DD-MM-YYYY or MM/DD/YYYY
  const ddmmyyyyMatch = str.match(/^(\d{1,2})[-\/\.](\d{1,2})[-\/\.](\d{2,4})/);
  if (ddmmyyyyMatch) {
    let p1 = parseInt(ddmmyyyyMatch[1], 10);
    let p2 = parseInt(ddmmyyyyMatch[2], 10);
    let yr = ddmmyyyyMatch[3];
    if (yr.length === 2) yr = '20' + yr;
    
    if (p1 > 12) {
      return `${yr}-${String(p2).padStart(2, '0')}-${String(p1).padStart(2, '0')}`;
    }
    return `${yr}-${String(p2).padStart(2, '0')}-${String(p1).padStart(2, '0')}`;
  }

  // 4. Fallback JS Date
  const parsedTS = Date.parse(str);
  if (!isNaN(parsedTS)) {
    const dt = new Date(parsedTS);
    return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}-${String(dt.getDate()).padStart(2, '0')}`;
  }

  return getLocalDateString();
}

function renderCsvPreviewTable() {
  const previewContainer = document.getElementById('csv-preview-container');
  const tbody = document.getElementById('csv-preview-tbody');
  const confirmBtn = document.getElementById('btn-confirm-csv-import');

  if (!previewContainer || !tbody) return;

  if (parsedCsvRecords.length === 0) {
    showAlert('No Valid Transactions', 'Could not parse any valid transactions from the CSV file.');
    return;
  }

  tbody.innerHTML = parsedCsvRecords.map((item, idx) => `
    <tr>
      <td>
        <input type="checkbox" ${item.selected ? 'checked' : ''} onchange="window.toggleCsvRecordSelection(${idx}, this.checked)" />
      </td>
      <td class="mono" style="font-size:0.82rem;">${escapeHTML(item.date)}</td>
      <td style="font-weight:500;">${escapeHTML(item.description)}</td>
      <td><span class="badge badge-emerald" style="font-size:0.78rem;">${escapeHTML(item.category)}</span></td>
      <td style="font-size:0.82rem;">${escapeHTML(item.payment)}</td>
      <td class="text-right mono text-emerald" style="font-weight:700;">₹${item.amount.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
    </tr>
  `).join('');

  previewContainer.classList.remove('hidden');
  if (confirmBtn) confirmBtn.classList.remove('hidden');

  updateCsvSelectedCount();
}

window.toggleCsvRecordSelection = function(idx, checked) {
  if (parsedCsvRecords[idx]) {
    parsedCsvRecords[idx].selected = !!checked;
  }
  updateCsvSelectedCount();
};

window.toggleAllCsvCheckboxes = function(checked) {
  parsedCsvRecords.forEach(r => r.selected = !!checked);
  renderCsvPreviewTable();
};

function updateCsvSelectedCount() {
  const selectedCount = parsedCsvRecords.filter(r => r.selected).length;
  const countBadge = document.getElementById('csv-count-badge');
  const btnCount = document.getElementById('csv-btn-count');
  if (countBadge) countBadge.textContent = `${selectedCount} transactions`;
  if (btnCount) btnCount.textContent = selectedCount;
}

window.confirmBulkCsvImport = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const toImport = parsedCsvRecords.filter(r => r.selected);
  if (toImport.length === 0) {
    showAlert('Selection Required', 'Please select at least one transaction to import.');
    return;
  }

  toImport.forEach(item => {
    expenses.push({
      id: item.id,
      amount: item.amount,
      category: item.category,
      description: item.description,
      payment: item.payment,
      date: item.date,
      receipt: null
    });
  });

  saveState();
  updateMonthPickerOptions();
  updateUI();
  window.closeCsvImportModal(e);

  showAlert('Bulk Import Complete! 🎉', `Successfully imported ${toImport.length} transactions into your Expense OS ledger.`);
};

window.loadSampleDemoData = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }

  const today = getLocalDateString();
  const sampleExpenses = [
    { id: 'demo1', date: today, category: 'Food & Dining', description: 'Swiggy Food Order', payment: 'UPI', amount: 485.00 },
    { id: 'demo2', date: today, category: 'Shopping', description: 'Amazon Electronics Purchase', payment: 'Credit Card', amount: 2499.00 },
    { id: 'demo3', date: today, category: 'Transportation', description: 'Uber Ride to Office', payment: 'UPI', amount: 320.00 },
    { id: 'demo4', date: today, category: 'Bills & Utilities', description: 'Airtel Broadband Wifi Bill', payment: 'Net Banking', amount: 999.00 },
    { id: 'demo5', date: today, category: 'Food & Dining', description: 'Starbucks Coffee & Snacks', payment: 'Credit Card', amount: 650.00 },
    { id: 'demo6', date: today, category: 'Services & Subscriptions', description: 'Netflix Monthly Premium HD', payment: 'Auto Debit', amount: 649.00 },
    { id: 'demo7', date: today, category: 'Health & Fitness', description: 'Apollo Pharmacy Medicines', payment: 'UPI', amount: 890.00 },
    { id: 'demo8', date: today, category: 'Entertainment', description: 'PVR Cinema Movie Tickets', payment: 'UPI', amount: 1200.00 }
  ];

  sampleExpenses.forEach(sample => {
    if (!expenses.some(exp => exp.id === sample.id || exp.description === sample.description)) {
      expenses.push(sample);
    }
  });

  saveState();
  updateMonthPickerOptions();
  updateUI();

  if (typeof showAlert === 'function') {
    showAlert('Sample Data Loaded! 🎉', 'Populated 8 clean sample transactions into your Expense OS ledger.');
  }
};

window.downloadBankStatementTemplate = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }

  const templateCsv = `Transaction Date,Value Date,Particulars,Cheque No,Debit,Credit,Balance
01-Apr-2026,01-Apr-2026,Opening Balance,,,67554.25
01-Apr-2026,01-Apr-2026,IMPS-OPM/609108923120/VAIBHAV JALOTA/PUNB0116000/6094/,,1393.00,,66161.25
05-Apr-2026,05-Apr-2026,IMPS/609516719401/NATIONALSKILLDE/ICIC0000007/1266/IMPSTransaction,,,1.00,66162.25
06-Apr-2026,06-Apr-2026,UPI/DR/609618413564/RELIANCE/CITI/jio@cit/JIO20BR,,349.00,,65813.25
07-Apr-2026,07-Apr-2026,NEFT/IN22609710361273/NATIONAL SKILL DEVELOPMENT,,,19355.00,85168.25`;

  const blob = new Blob([templateCsv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.setAttribute('href', url);
  link.setAttribute('download', 'IDFC_Bank_Statement_Template.csv');
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);

  if (typeof showToast === 'function') {
    showToast('Bank Statement Template downloaded! 📄');
  }
};

// ============================================================
// EXECUTIVE FORMATTED CSV STATEMENT EXPORTER ENGINE
// ============================================================
window.exportFormattedCsvStatement = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }

  const u = currentUser || { email: 'user@expenseos.local' };
  const currencySymbol = getCurrencySymbol();
  const todayStr = getLocalDateString();
  
  let csvLines = [];
  
  csvLines.push(`"=== EXPENSE OS — EXECUTIVE FINANCIAL STATEMENT & AUDIT REPORT ==="`);
  csvLines.push(`"User Account:","${escapeCsvVal(u.email || u.user_id || 'User')}"`);
  csvLines.push(`"Base Currency:","${escapeCsvVal(activeCurrency)} (${currencySymbol})"` );
  csvLines.push(`"Monthly Budget Cap:","${currencySymbol}${budget.toLocaleString('en-IN')}"`);
  csvLines.push(`"Export Date:","${todayStr}"`);
  csvLines.push(`""`);
  
  csvLines.push(`"=== DETAILED TRANSACTIONS LEDGER ==="`);
  csvLines.push(`"Date","Category","Description","Payment Method","Amount (${currentCurrency})"` );
  
  if (expenses.length === 0) {
    csvLines.push(`"No transactions logged","","","","0.00"`);
  } else {
    expenses.forEach(item => {
      csvLines.push(`"${escapeCsvVal(item.date)}","${escapeCsvVal(item.category)}","${escapeCsvVal(item.description)}","${escapeCsvVal(item.payment || 'UPI')}","${item.amount.toFixed(2)}"` );
    });
  }
  
  csvLines.push(`""`);
  
  csvLines.push(`"=== RECURRING BILLS & SUBSCRIPTIONS ==="`);
  csvLines.push(`"Bill Name","Category","Monthly Cost (${currentCurrency})","Next Billing Date"` );
  if (subscriptions.length === 0) {
    csvLines.push(`"No subscriptions logged","","0.00",""` );
  } else {
    subscriptions.forEach(sub => {
      csvLines.push(`"${escapeCsvVal(sub.name)}","${escapeCsvVal(sub.category || 'Subscription')}","${sub.amount.toFixed(2)}","${escapeCsvVal(sub.date || todayStr)}"` );
    });
  }
  
  csvLines.push(`""`);
  
  csvLines.push(`"=== EXTRA INCOME STREAMS ==="`);
  csvLines.push(`"Income Source","Category","Amount (${currentCurrency})","Date Received"` );
  if (incomes.length === 0) {
    csvLines.push(`"No income streams logged","","0.00",""` );
  } else {
    incomes.forEach(inc => {
      csvLines.push(`"${escapeCsvVal(inc.description || inc.source)}","${escapeCsvVal(inc.category || 'Income')}","${inc.amount.toFixed(2)}","${escapeCsvVal(inc.date || todayStr)}"` );
    });
  }

  const blob = new Blob([csvLines.join('\n')], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.setAttribute('href', url);
  link.setAttribute('download', `Expense_OS_Executive_Statement_${todayStr}.csv`);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);

  showAlert('Formatted CSV Downloaded! 📊', 'Your executive financial statement CSV has been exported into clean Excel rows.');
};

function escapeCsvVal(val) {
  return String(val || '').replace(/"/g, '""');
}

// ============================================================
// SUPER ADMIN MASTER EXPORTER (Export All Users' Ledger Data)
// ============================================================
// ============================================================
// USER PROFILE & CUSTOM AVATAR MANAGER ENGINE
// ============================================================
let currentCustomAvatarData = null;

const PROFILE_COUNTRY_PHONE_FORMATS = {
  'United States': '+1 (555) 000-0000',
  'United Kingdom': '+44 7000 000000',
  'India': '+91 98765 43210',
  'Canada': '+1 (555) 000-0000',
  'Australia': '+61 400 000 000',
  'Germany': '+49 151 1234567',
  'France': '+33 6 12 34 56 78',
  'Japan': '+81 90 1234 5678',
  'Brazil': '+55 11 98765-4321',
  'Other': '+00 000000000'
};

const PROFILE_COUNTRY_DIAL_CODES = {
  'United States': '+1',
  'United Kingdom': '+44',
  'India': '+91',
  'Canada': '+1',
  'Australia': '+61',
  'Germany': '+49',
  'France': '+33',
  'Japan': '+81',
  'Brazil': '+55',
  'Other': '+'
};

window.handleProfileCountryChange = function(e) {
  const countrySelect = document.getElementById('profile-edit-country-select');
  const phoneInput = document.getElementById('profile-edit-phone-input');
  if (!countrySelect || !phoneInput) return;

  const country = countrySelect.value || 'United States';
  const dialCode = PROFILE_COUNTRY_DIAL_CODES[country] || '+1';
  const format = PROFILE_COUNTRY_PHONE_FORMATS[country] || '+1 (555) 000-0000';

  phoneInput.placeholder = format;

  const currentVal = phoneInput.value.trim();
  if (!currentVal) {
    phoneInput.value = dialCode + ' ';
  } else {
    // If the phone input only has a previous dial code, update it to the new dial code
    const isJustDialCode = Object.values(PROFILE_COUNTRY_DIAL_CODES).some(code => currentVal === code || currentVal === code + ' ');
    if (isJustDialCode) {
      phoneInput.value = dialCode + ' ';
    }
  }
};

window.handleEditProfileClick = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }

  const modal = document.getElementById('edit-profile-modal');
  const nameInput = document.getElementById('profile-edit-name-input');
  const emailInput = document.getElementById('profile-edit-email-input');
  const phoneInput = document.getElementById('profile-edit-phone-input');
  const jobInput = document.getElementById('profile-edit-job-input');
  const countrySelect = document.getElementById('profile-edit-country-select');
  const currencySelect = document.getElementById('profile-edit-currency-select');
  const bioInput = document.getElementById('profile-edit-bio-input');

  const initialSpan = document.getElementById('profile-avatar-initial-preview');
  const imgPreview = document.getElementById('profile-avatar-img-preview');

  let sessionUser = (typeof currentUser !== 'undefined' && currentUser) ? currentUser : null;
  if (!sessionUser) {
    try { sessionUser = JSON.parse(localStorage.getItem('expense_cal_user_session') || 'null'); } catch(e) {}
  }
  const userMeta = sessionUser ? (sessionUser.user_metadata || sessionUser.raw_user_meta_data || {}) : {};
  const identities = (sessionUser && Array.isArray(sessionUser.identities) && sessionUser.identities.length) ? sessionUser.identities[0].identity_data || {} : {};
  const storedProfile = JSON.parse(localStorage.getItem('expense_cal_user_profile') || '{}');

  const defaultSessionName = (sessionUser && (sessionUser.displayName || userMeta.full_name || userMeta.name || userMeta.display_name || identities.full_name || identities.name || (sessionUser.email ? sessionUser.email.split('@')[0] : ''))) || 'User';
  const defaultSessionAvatar = (sessionUser && (sessionUser.photoURL || userMeta.avatar_url || userMeta.picture || userMeta.avatar || identities.avatar_url || identities.picture)) || null;

  const name = storedProfile.name || defaultSessionName;
  const email = storedProfile.email || (sessionUser && sessionUser.email) || '';
  currentCustomAvatarData = storedProfile.avatar || defaultSessionAvatar || null;

  if (nameInput) nameInput.value = name;
  if (emailInput) emailInput.value = email;
  if (phoneInput) phoneInput.value = storedProfile.phone || '';
  if (jobInput) jobInput.value = storedProfile.job || '';
  if (countrySelect) countrySelect.value = storedProfile.country || 'United States';
  if (currencySelect) currencySelect.value = localStorage.getItem('expense_cal_currency') || storedProfile.currency || 'INR';
  if (bioInput) bioInput.value = storedProfile.bio || '';

  if (typeof window.handleProfileCountryChange === 'function') {
    window.handleProfileCountryChange();
    if (storedProfile.phone) phoneInput.value = storedProfile.phone;
  }

  if (currentCustomAvatarData) {
    if (currentCustomAvatarData.startsWith('data:image/') || currentCustomAvatarData.startsWith('http')) {
      if (imgPreview) { 
        imgPreview.src = currentCustomAvatarData; 
        imgPreview.setAttribute('referrerpolicy', 'no-referrer');
        imgPreview.classList.remove('hidden'); 
      }
      if (initialSpan) initialSpan.classList.add('hidden');
    } else {
      if (initialSpan) { initialSpan.textContent = currentCustomAvatarData; initialSpan.classList.remove('hidden'); }
      if (imgPreview) imgPreview.classList.add('hidden');
    }
  } else {
    const initial = (name && name.trim()) ? name.trim().charAt(0).toUpperCase() : 'U';
    if (initialSpan) { initialSpan.textContent = initial; initialSpan.classList.remove('hidden'); }
    if (imgPreview) imgPreview.classList.add('hidden');
  }

  const dropdown = document.getElementById('user-dropdown-menu');
  if (dropdown) dropdown.classList.add('hidden');

  if (modal) {
    modal.classList.remove('hidden');
    modal.style.display = 'flex';
  }
};

window.isMandatoryProfileSetup = false;

window.openEditProfileModal = function(isMandatory = false) {
  window.isMandatoryProfileSetup = !!isMandatory;

  const titleEl = document.getElementById('profile-modal-title');
  const closeBtn = document.getElementById('profile-modal-close-btn');
  const cancelBtn = document.getElementById('profile-modal-cancel-btn');
  const saveBtn = document.getElementById('profile-modal-save-btn');

  if (titleEl) {
    titleEl.innerHTML = isMandatory
      ? '<i class="fa-solid fa-user-gear text-emerald"></i> Complete Profile Setup'
      : '<i class="fa-solid fa-user-pen text-emerald"></i> Edit User Profile';
  }

  if (closeBtn) closeBtn.style.display = isMandatory ? 'none' : 'block';
  if (cancelBtn) cancelBtn.style.display = isMandatory ? 'none' : 'inline-block';
  if (saveBtn) {
    saveBtn.innerHTML = isMandatory
      ? '<i class="fa-solid fa-rocket"></i> Complete Setup & Continue'
      : '<i class="fa-solid fa-check"></i> Save Changes';
  }

  window.handleEditProfileClick();
};

window.closeEditProfileModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  if (window.isMandatoryProfileSetup) {
    alert('Profile setup is required for first-time account setup. Please complete and save your profile to continue.');
    return;
  }
  const modal = document.getElementById('edit-profile-modal');
  if (modal) {
    modal.classList.add('hidden');
    modal.style.display = 'none';
  }
};

window.handleProfileAvatarFileSelect = function(e) {
  if (!e || !e.target || !e.target.files || e.target.files.length === 0) return;
  const file = e.target.files[0];
  if (!file.type.startsWith('image/')) {
    alert('Please select a valid image file (PNG, JPG, WebP).');
    return;
  }

  const reader = new FileReader();
  reader.onload = function(evt) {
    currentCustomAvatarData = evt.target.result;
    const initialSpan = document.getElementById('profile-avatar-initial-preview');
    const imgPreview = document.getElementById('profile-avatar-img-preview');

    if (imgPreview) {
      imgPreview.src = currentCustomAvatarData;
      imgPreview.setAttribute('referrerpolicy', 'no-referrer');
      imgPreview.classList.remove('hidden');
    }
    if (initialSpan) initialSpan.classList.add('hidden');
  };
  reader.readAsDataURL(file);
};

window.selectPresetAvatar = function(emoji) {
  currentCustomAvatarData = emoji;
  const initialSpan = document.getElementById('profile-avatar-initial-preview');
  const imgPreview = document.getElementById('profile-avatar-img-preview');

  if (initialSpan) {
    initialSpan.textContent = emoji;
    initialSpan.classList.remove('hidden');
  }
  if (imgPreview) {
    imgPreview.classList.add('hidden');
  }
};

window.saveUserProfileChanges = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }

  const nameInput = document.getElementById('profile-edit-name-input');
  const emailInput = document.getElementById('profile-edit-email-input');
  const phoneInput = document.getElementById('profile-edit-phone-input');
  const jobInput = document.getElementById('profile-edit-job-input');
  const countrySelect = document.getElementById('profile-edit-country-select');
  const currencySelect = document.getElementById('profile-edit-currency-select');
  const bioInput = document.getElementById('profile-edit-bio-input');

  const storedProfile = JSON.parse(localStorage.getItem('expense_cal_user_profile') || '{}');
  let sessionUser = (typeof currentUser !== 'undefined' && currentUser) ? currentUser : null;
  if (!sessionUser) {
    try { sessionUser = JSON.parse(localStorage.getItem('expense_cal_user_session') || 'null'); } catch(err) {}
  }
  const userMeta = sessionUser ? (sessionUser.user_metadata || sessionUser.raw_user_meta_data || {}) : {};
  const identities = (sessionUser && Array.isArray(sessionUser.identities) && sessionUser.identities.length) ? sessionUser.identities[0].identity_data || {} : {};

  let newName = nameInput ? nameInput.value.trim() : '';
  if (!newName) {
    newName = storedProfile.name || (sessionUser && (sessionUser.displayName || userMeta.full_name || userMeta.name || userMeta.display_name || identities.full_name || identities.name || (sessionUser.email ? sessionUser.email.split('@')[0] : ''))) || 'User';
  }

  const newEmail = (emailInput && emailInput.value.trim()) ? emailInput.value.trim() : (storedProfile.email || (sessionUser && sessionUser.email) || 'admin@expenseos.com');
  const newPhone = phoneInput ? phoneInput.value.trim() : (storedProfile.phone || '');
  const newJob = jobInput ? jobInput.value.trim() : (storedProfile.job || '');
  const newCountry = countrySelect ? countrySelect.value : (storedProfile.country || 'United States');
  const newCurrency = currencySelect ? currencySelect.value : (storedProfile.currency || 'INR');
  const newBio = bioInput ? bioInput.value.trim() : (storedProfile.bio || '');

  const defaultSessionAvatar = (sessionUser && (sessionUser.photoURL || userMeta.avatar_url || userMeta.picture || userMeta.avatar || identities.avatar_url || identities.picture)) || null;

  const profileObj = {
    name: newName,
    email: newEmail,
    phone: newPhone,
    job: newJob,
    country: newCountry,
    currency: newCurrency,
    bio: newBio,
    avatar: currentCustomAvatarData || storedProfile.avatar || defaultSessionAvatar || null,
    completed: true
  };

  localStorage.setItem('expense_cal_user_profile', JSON.stringify(profileObj));
  localStorage.setItem('expense_cal_profile_completed', 'true');

  if (typeof window.syncProfileToSupabase === 'function') {
    window.syncProfileToSupabase(profileObj);
  }

  if (newCurrency) {
    if (typeof window.changeCurrency === 'function') {
      window.changeCurrency(newCurrency);
    } else {
      localStorage.setItem('expense_cal_currency', newCurrency);
    }
  }

  const userNameEl = document.getElementById('user-name');
  if (userNameEl) userNameEl.textContent = newName;

  const dropdownName = document.getElementById('dropdown-user-name');
  const dropdownEmail = document.getElementById('dropdown-user-email');
  if (dropdownName) dropdownName.textContent = newName;
  if (dropdownEmail) dropdownEmail.textContent = newEmail;

  window.syncProfileUI();

  window.isMandatoryProfileSetup = false;
  const modal = document.getElementById('edit-profile-modal');
  if (modal) {
    modal.classList.add('hidden');
    modal.style.display = 'none';
  }

  if (typeof updateUI === 'function') updateUI();
  if (typeof renderLeaderboard === 'function') renderLeaderboard();
  if (typeof showToast === 'function') {
    showToast('✅ User Profile Saved Successfully!', 'success');
  }
};

window.syncProfileUI = function() {
  let storedProfile = {};
  try { storedProfile = JSON.parse(localStorage.getItem('expense_cal_user_profile') || '{}'); } catch(e) {}
  let avatarData = storedProfile.avatar || null;
  let nameToUse = storedProfile.name || '';
  let emailToUse = storedProfile.email || '';

  // Discover user from all potential auth storage locations
  let authUser = (typeof currentUser !== 'undefined' && currentUser) ? currentUser : null;
  if (!authUser) {
    try { authUser = JSON.parse(localStorage.getItem('expense_cal_user_session') || 'null'); } catch(e) {}
  }
  if (!authUser) {
    try {
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i);
        if (k && k.startsWith('sb-') && k.endsWith('-auth-token')) {
          const parsed = JSON.parse(localStorage.getItem(k) || '{}');
          if (parsed.user) { authUser = parsed.user; break; }
          if (parsed.currentSession && parsed.currentSession.user) { authUser = parsed.currentSession.user; break; }
        }
      }
    } catch(e) {}
  }

  if (authUser) {
    const meta = authUser.user_metadata || authUser.raw_user_meta_data || {};
    const identities = (Array.isArray(authUser.identities) && authUser.identities.length) ? (authUser.identities[0].identity_data || {}) : {};
    const customClaims = authUser.custom_claims || {};
    const discoveredAvatar = authUser.photoURL || meta.avatar_url || meta.picture || meta.avatar || identities.avatar_url || identities.picture || customClaims.picture || null;
    const discoveredName = authUser.displayName || meta.full_name || meta.name || meta.display_name || identities.full_name || identities.name || (authUser.email ? authUser.email.split('@')[0] : '');

    if (!avatarData || avatarData.startsWith('data:image/svg')) {
      if (discoveredAvatar) avatarData = discoveredAvatar;
    }
    if (!nameToUse || nameToUse === 'User' || nameToUse === 'System Administrator ⭐️' || nameToUse === 'Tech Bounty Hunter') {
      if (discoveredName) nameToUse = discoveredName;
    }
    if (!emailToUse || emailToUse === 'admin@expenseos.com' || emailToUse === 'bountyh745@gmail.com') {
      if (authUser.email) emailToUse = authUser.email;
    }

    // Auto-persist back to localStorage so subsequent operations always have the latest Google profile
    try {
      let changed = false;
      if (discoveredName && (!storedProfile.name || storedProfile.name === 'User')) { storedProfile.name = discoveredName; changed = true; }
      if (authUser.email && (!storedProfile.email || storedProfile.email === 'admin@expenseos.com')) { storedProfile.email = authUser.email; changed = true; }
      if (discoveredAvatar && (!storedProfile.avatar || storedProfile.avatar.startsWith('data:image/svg'))) { storedProfile.avatar = discoveredAvatar; changed = true; }
      if (changed) localStorage.setItem('expense_cal_user_profile', JSON.stringify(storedProfile));
    } catch(e) {}
  }

  if (!nameToUse) nameToUse = 'User';

  const topbarInitial = document.getElementById('topbar-user-initial');
  const topbarImg = document.getElementById('topbar-user-img');
  const dropdownInitial = document.getElementById('dropdown-user-initial');
  const dropdownImg = document.getElementById('dropdown-user-img');
  const dropdownName = document.getElementById('dropdown-user-name');
  const dropdownEmail = document.getElementById('dropdown-user-email');
  const initial = ((nameToUse && nameToUse.trim()) ? nameToUse.trim().charAt(0) : 'U').toUpperCase();

  if (avatarData && (avatarData.startsWith('data:image/') || avatarData.startsWith('http') || avatarData.startsWith('https'))) {
    if (topbarImg) {
      topbarImg.src = avatarData;
      topbarImg.setAttribute('referrerpolicy', 'no-referrer');
      topbarImg.classList.remove('hidden');
      topbarImg.onerror = function() {
        this.classList.add('hidden');
        if (topbarInitial) {
          topbarInitial.textContent = initial;
          topbarInitial.classList.remove('hidden');
        }
      };
    }
    if (topbarInitial) topbarInitial.classList.add('hidden');

    if (dropdownImg) {
      dropdownImg.src = avatarData;
      dropdownImg.setAttribute('referrerpolicy', 'no-referrer');
      dropdownImg.classList.remove('hidden');
      dropdownImg.onerror = function() {
        this.classList.add('hidden');
        if (dropdownInitial) {
          dropdownInitial.textContent = initial;
          dropdownInitial.classList.remove('hidden');
        }
      };
    }
    if (dropdownInitial) dropdownInitial.classList.add('hidden');
  } else if (avatarData && !avatarData.startsWith('data:image/') && !avatarData.startsWith('http') && !avatarData.startsWith('https')) {
    // Emoji or custom text
    if (topbarInitial) { topbarInitial.textContent = avatarData; topbarInitial.classList.remove('hidden'); }
    if (topbarImg) topbarImg.classList.add('hidden');
    if (dropdownInitial) { dropdownInitial.textContent = avatarData; dropdownInitial.classList.remove('hidden'); }
    if (dropdownImg) dropdownImg.classList.add('hidden');
  } else {
    if (topbarInitial) { topbarInitial.textContent = initial; topbarInitial.classList.remove('hidden'); }
    if (topbarImg) topbarImg.classList.add('hidden');
    if (dropdownInitial) { dropdownInitial.textContent = initial; dropdownInitial.classList.remove('hidden'); }
    if (dropdownImg) dropdownImg.classList.add('hidden');
  }

  if (dropdownName && nameToUse && nameToUse !== 'User') {
    dropdownName.textContent = nameToUse;
  }
  if (dropdownEmail && emailToUse) {
    dropdownEmail.textContent = emailToUse;
  }
};

// Immediately invoke syncProfileUI on script execution and DOM load
try { window.syncProfileUI(); } catch(e) {}
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => { try { window.syncProfileUI(); } catch(e) {} });
}

window.checkFirstTimeProfileSetup = function() {
  const shouldTrigger = localStorage.getItem('expense_cal_trigger_profile_setup') === 'true';
  if (shouldTrigger) {
    localStorage.removeItem('expense_cal_trigger_profile_setup');
    setTimeout(() => {
      if (typeof window.openEditProfileModal === 'function') {
        window.openEditProfileModal(true);
      }
    }, 600);
  }
};

// ============================================================
// GAMIFIED LEADERBOARD & EMERALDS 💎 ENGINE
// ============================================================

window.EMERALD_LEVEL_STAGES = [
  { stage: 1, title: 'Novice Saver', min: 0, max: 249, badge: '🥉' },
  { stage: 2, title: 'Pocket Guard', min: 250, max: 499, badge: '🥉' },
  { stage: 3, title: 'Penny Protector', min: 500, max: 999, badge: '🥉' },
  { stage: 4, title: 'Budget Apprentice', min: 1000, max: 1499, badge: '🥈' },
  { stage: 5, title: 'Steady Saver', min: 1500, max: 2249, badge: '🥈' },
  { stage: 6, title: 'Thrift Analyst', min: 2250, max: 2999, badge: '🥈' },
  { stage: 7, title: 'Gold Strategist', min: 3000, max: 3999, badge: '🥇' },
  { stage: 8, title: 'Financial Captain', min: 4000, max: 5499, badge: '🥇' },
  { stage: 9, title: 'Nest Egg Commander', min: 5500, max: 6999, badge: '🥇' },
  { stage: 10, title: 'Diamond Tycoon', min: 7000, max: 8999, badge: '💎' },
  { stage: 11, title: 'Wealth Architect', min: 9000, max: 11499, badge: '💎' },
  { stage: 12, title: 'Portfolio Titan', min: 11500, max: 14999, badge: '💎' },
  { stage: 13, title: 'Sovereign Investor', min: 15000, max: 19999, badge: '👑' },
  { stage: 14, title: 'Empire Builder', min: 20000, max: 29999, badge: '👑' },
  { stage: 15, title: 'Wealth Master', min: 30000, max: Infinity, badge: '👑' }
];

window.STICKER_REGISTRY = [
  { id: 'piggy_bank_raider', name: 'Piggy Bank Raider', icon: '🐖', desc: 'Complete your 1st Savings Goal', category: 'Savings' },
  { id: 'bullseye_bandit', name: 'Bullseye Bandit', icon: '🎯', desc: 'Finish a goal ahead of schedule', category: 'Savings' },
  { id: 'goal_cano', name: 'Goal-cano!', icon: '🌋', desc: 'Complete 3 goals in a single month', category: 'Savings' },
  { id: 'dragon_hoarder', name: 'Dragon Hoarder', icon: '🐉', desc: 'Accumulate $10,000+ in total goal savings', category: 'Savings' },

  { id: 'no_avocado', name: 'No Avocado Toast Today', icon: '🥑', desc: 'Stay 20% under dining/food budget', category: 'Budget' },
  { id: 'impulse_slayer', name: 'Impulse Slayer', icon: '🗡️', desc: '14 consecutive days without non-essential buys', category: 'Budget' },
  { id: 'ice_cold_wallet', name: 'Ice Cold Wallet', icon: '🧊', desc: '$0 non-essential spend over a full weekend', category: 'Budget' },
  { id: 'brewed_at_home', name: 'Brewed at Home', icon: '☕', desc: '10 consecutive days without buying coffee out', category: 'Budget' },

  { id: 'lightning_logger', name: 'Lightning Logger', icon: '⚡', desc: 'Log an expense within 1 minute of spending', category: 'Habit' },
  { id: 'expense_whisperer', name: 'Expense Whisperer', icon: '🧠', desc: '7-day daily logging streak', category: 'Habit' },
  { id: 'night_owl_saver', name: 'Night Owl Saver', icon: '🦉', desc: 'Log late-night expenses instead of online shopping', category: 'Habit' },
  { id: 'streak_defender', name: 'Streak Defender', icon: '🛡️', desc: 'Purchase or use a Streak Shield', category: 'Habit' },

  { id: 'diamond_hands', name: 'Diamond Hands', icon: '💎', desc: 'Never withdraw funds early from a goal', category: 'Legendary' },
  { id: 'to_the_moon', name: 'To The Moon!', icon: '🚀', desc: 'Reach 10,000+ total Emeralds', category: 'Legendary' },
  { id: 'wealth_kraken', name: 'Wealth Kraken', icon: '🐙', desc: 'Secure a Top 3 spot on the Global Leaderboard', category: 'Legendary' },
  { id: 'financial_alchemist', name: 'Financial Alchemist', icon: '🧙‍♂️', desc: 'Turn a monthly budget deficit into surplus', category: 'Legendary' }
];

window.EMERALD_SHOP_ITEMS = [
  { id: 'streak_shield', title: 'Streak Shield', icon: '🛡️', cost: 150, type: 'Consumable', desc: 'Protects your logging streak if you miss 1 day.' },
  { id: 'emerald_glow', title: 'Emerald Glow Frame', icon: '🖼️', cost: 1000, type: 'Profile Skin', desc: 'Glowing animated border around your leaderboard avatar.' },
  { id: 'cyberpunk_theme', title: 'Cyberpunk Theme', icon: '🎨', cost: 500, type: 'App Skin', desc: 'Exclusive neon purple & cyan visual theme.' },
  { id: 'frugal_boss_title', title: 'The Frugal Boss Title', icon: '🏷️', cost: 300, type: 'Badge Title', desc: 'Special title displayed next to your name.' },
  { id: 'golden_crown_avatar', title: 'Golden Crown Avatar', icon: '👑', cost: 2500, type: 'Legendary Skin', desc: 'Golden crown badge shown above your profile avatar.' },
  { id: 'rocket_boost', title: 'Rocket Boost 2x', icon: '🚀', cost: 750, type: 'Power-Up', desc: 'Earns 2x Emeralds 💎 on your next completed Savings Goal.' },
  { id: 'coffee_club_badge', title: 'Coffee Club Badge', icon: '☕', cost: 200, type: 'Profile Badge', desc: 'Showcase your coffee budget master badge.' },
  { id: 'fortune_forecast_theme', title: 'Fortune Forecast', icon: '🔮', cost: 450, type: 'AI Theme', desc: 'Unlocks AI futuristic spending projection skin.' }
];

window.WEALTH_EMPIRE_BUILDINGS = [
  { id: 'nomad_outpost', name: 'Nomad Outpost', icon: '⛺', reqEmeralds: 0, perk: 'Base Camp — Welcome to Expense OS Empire', category: 'Starter' },
  { id: 'savings_cottage', name: 'Savings Cottage', icon: '🏠', reqEmeralds: 250, perk: '+5% Bonus Emeralds 💎 on all logged expenses', category: 'Residential' },
  { id: 'fintech_office', name: 'Fintech Office Tower', icon: '🏢', reqEmeralds: 750, perk: 'Faster Logging Streak Shield protection', category: 'Commercial' },
  { id: 'emerald_reserve', name: 'Emerald Reserve Bank', icon: '🏦', reqEmeralds: 1500, perk: '+10% Emerald Bonus on completed Savings Goals', category: 'Financial' },
  { id: 'crystal_plaza', name: 'Crystal Shopping Plaza', icon: '🏬', reqEmeralds: 2500, perk: 'Unlocks exclusive Shop item discounts', category: 'Commercial' },
  { id: 'skyline_tower', name: 'Skyline Cyber Tower', icon: '🗼', reqEmeralds: 4000, perk: 'Unlocks Animated Cyber Neon Glow effect', category: 'Landmark' },
  { id: 'spaceport_launchpad', name: 'Spaceport Launchpad', icon: '🚀', reqEmeralds: 6000, perk: '+20% Bonus Emeralds on all achievements', category: 'Infrastructure' },
  { id: 'imperial_citadel', name: 'Imperial Wealth Citadel', icon: '👑', reqEmeralds: 10000, perk: 'Legendary Imperial Crown Title & Top Rank Status', category: 'Imperial' }
];

window.renderWealthEmpireView = function() {
  const data = window.getUserEmeraldData();
  const buildings = window.WEALTH_EMPIRE_BUILDINGS || [];
  const container = document.getElementById('empire-grid-container');
  const unlockedCountEl = document.getElementById('empire-unlocked-count');

  let unlockedCount = 0;
  buildings.forEach(b => {
    if (data.emeralds >= b.reqEmeralds) unlockedCount++;
  });

  if (unlockedCountEl) {
    unlockedCountEl.textContent = `${unlockedCount} / ${buildings.length} Landmarks Unlocked`;
  }

  if (container) {
    container.innerHTML = buildings.map(b => {
      const isUnlocked = data.emeralds >= b.reqEmeralds;
      const progressPct = Math.min(100, Math.round((data.emeralds / Math.max(1, b.reqEmeralds)) * 100));

      return `
        <div class="glass-panel empire-building-card ${isUnlocked ? 'unlocked' : 'locked'}" style="position: relative; padding: 1.25rem; border-radius: 12px; border: 1px solid ${isUnlocked ? 'rgba(52, 211, 153, 0.4)' : 'rgba(255, 255, 255, 0.08)'}; background: ${isUnlocked ? 'linear-gradient(135deg, rgba(15, 23, 42, 0.9), rgba(52, 211, 153, 0.08))' : 'rgba(15, 23, 42, 0.5)'}; transition: all 0.3s ease;">
          <div style="display: flex; align-items: center; gap: 1rem; margin-bottom: 0.85rem;">
            <div class="empire-icon-box" style="font-size: 2.25rem; width: 56px; height: 56px; display: flex; align-items: center; justify-content: center; background: rgba(255,255,255,0.05); border-radius: 12px; border: 1px solid rgba(255,255,255,0.1); filter: ${isUnlocked ? 'none' : 'grayscale(1) opacity(0.4)'};">
              ${b.icon}
            </div>
            <div>
              <span class="badge ${isUnlocked ? 'badge-emerald' : 'badge-muted'}" style="font-size: 0.7rem; text-transform: uppercase;">${b.category}</span>
              <h5 style="margin: 0.2rem 0 0 0; font-size: 1.05rem; color: ${isUnlocked ? '#fff' : '#94a3b8'};">${b.name}</h5>
            </div>
          </div>
          
          <p style="margin: 0 0 0.85rem 0; font-size: 0.85rem; color: #94a3b8; line-height: 1.4;">
            <i class="fa-solid fa-bolt text-amber" style="margin-right: 4px;"></i> <strong>Perk:</strong> ${b.perk}
          </p>

          <div class="building-unlock-bar" style="margin-top: auto;">
            <div style="display: flex; justify-content: space-between; font-size: 0.78rem; margin-bottom: 0.35rem; color: #64748b;">
              <span>${isUnlocked ? 'Unlocked ✅' : `Requires ${b.reqEmeralds.toLocaleString()} 💎`}</span>
              <span class="mono">${isUnlocked ? '100%' : `${progressPct}%`}</span>
            </div>
            <div style="height: 6px; background: rgba(255,255,255,0.1); border-radius: 3px; overflow: hidden;">
              <div style="height: 100%; width: ${isUnlocked ? 100 : progressPct}%; background: ${isUnlocked ? '#34d399' : '#8b5cf6'}; transition: width 0.4s ease;"></div>
            </div>
          </div>
        </div>
      `;
    }).join('');
  }
};

window.SAVINGS_QUESTS = [
  { id: 'ice_cold_weekend', name: 'Ice Cold Weekend', icon: '🧊', reward: 150, sticker: 'ice_cold_wallet', desc: '$0 non-essential spend on Saturday & Sunday', category: 'Budgeting' },
  { id: 'brew_at_home', name: '7-Day Brew at Home', icon: '☕', reward: 200, sticker: 'brewed_at_home', desc: '7 consecutive days with no coffee shop purchases', category: 'Habits' },
  { id: 'no_fast_food_friday', name: 'No Fast Food Friday', icon: '🍔', reward: 100, sticker: null, desc: 'Stay under dining budget cap on Friday', category: 'Budgeting' },
  { id: 'under_budget_ninja', name: 'Under Budget Ninja', icon: '🥷', reward: 300, sticker: 'impulse_slayer', desc: 'Finish month 10%+ under total budget limit', category: 'Budgeting' },
  { id: 'speed_logger', name: 'Speed Logger', icon: '⚡', reward: 75, sticker: 'lightning_logger', desc: 'Log an expense within 1 minute of spending', category: 'Habits' },
  { id: 'sub_audit', name: 'Subscription Audit', icon: '🚫', reward: 250, sticker: null, desc: 'Review & verify active subscriptions', category: 'Security' },
  { id: 'piggy_booster', name: 'Piggy Bank Booster', icon: '🐖', reward: 175, sticker: 'piggy_bank_raider', desc: 'Deposit into a Savings Goal 3 times in a week', category: 'Savings' },
  { id: 'zero_impulse_week', name: 'Zero Impulse Week', icon: '🧘', reward: 250, sticker: null, desc: '0 non-essential buys for 7 consecutive days', category: 'Habits' },
  { id: 'no_avocado_toast', name: 'No Avocado Toast', icon: '🥑', reward: 125, sticker: null, desc: 'Keep dining out under $25 for an entire week', category: 'Budgeting' },
  { id: 'receipt_keeper', name: 'Receipt Keeper', icon: '🧾', reward: 150, sticker: null, desc: 'Attach receipt scans/images to 5 expenses', category: 'Habits' },
  { id: 'night_owl_saver', name: 'Night Owl Saver', icon: '🦉', reward: 200, sticker: 'night_owl_saver', desc: 'Avoid late-night (11 PM-4 AM) online shopping for 5 days', category: 'Habits' },
  { id: 'bullseye_saver', name: 'Bullseye Saver', icon: '🎯', reward: 350, sticker: 'bullseye_bandit', desc: 'Complete a savings goal ahead of schedule', category: 'Savings' }
];

window.saveEmailjsKeys = function() {
  const serviceId = (document.getElementById('emailjs-service-id')?.value || '').trim();
  const templateId = (document.getElementById('emailjs-template-id')?.value || '').trim();
  const publicKey = (document.getElementById('emailjs-public-key')?.value || '').trim();

  const config = { serviceId, templateId, publicKey };
  localStorage.setItem('expense_cal_emailjs_config', JSON.stringify(config));
  window.emailjsConfig = config;

  if (typeof emailjs !== 'undefined' && publicKey) {
    emailjs.init(publicKey);
  }

  if (typeof window.showToast === 'function') {
    window.showToast('✅ EmailJS Keys Saved Successfully!', 'success');
  }
};

window.getEmailTemplateHTML = function(triggerType, payload) {
  const name = payload.to_name || 'Valued User';
  const subject = payload.subject || 'Expense OS Financial Update';
  
  if (triggerType === 'Welcome Onboarding' || triggerType === 'Welcome') {
    return `<div style="max-width:580px; margin:0 auto; background:#0f172a; border-radius:16px; border:1px solid rgba(52,211,153,0.3); overflow:hidden; font-family:sans-serif; color:#e2e8f0;"><div style="background:linear-gradient(135deg,#0f172a,#047857); padding:2rem; text-align:center;"><h1 style="color:#34d399; margin:0;">💎 Expense OS</h1></div><div style="padding:2rem;"><h2 style="color:#fff;">Welcome Onboard, ${name}! 👋</h2><p style="color:#94a3b8;">Your account is active with 250 Emeralds 💎 unlocked.</p><div style="text-align:center; margin-top:1.5rem;"><a href="http://localhost:58420" style="background:#34d399; color:#000; font-weight:800; padding:0.8rem 1.5rem; border-radius:8px; text-decoration:none;">Launch Command Center →</a></div></div></div>`;
  }
  
  if (triggerType === 'Quest Completion') {
    return `<div style="max-width:580px; margin:0 auto; background:#0f172a; border-radius:16px; border:1px solid rgba(245,158,11,0.3); overflow:hidden; font-family:sans-serif; color:#e2e8f0;"><div style="background:linear-gradient(135deg,#0f172a,#78350f); padding:2rem; text-align:center;"><div style="font-size:3rem;">☕</div><h1 style="color:#fbbf24; margin:0;">Quest Auto-Completed!</h1></div><div style="padding:2rem;"><h2 style="color:#fff;">${subject}</h2><p style="color:#94a3b8;">${payload.message || 'Quest completed successfully!'}</p><div style="text-align:center; margin-top:1.5rem;"><a href="http://localhost:58420" style="background:#fbbf24; color:#000; font-weight:800; padding:0.8rem 1.5rem; border-radius:8px; text-decoration:none;">View Quests Ledger →</a></div></div></div>`;
  }

  return `<div style="max-width:580px; margin:0 auto; background:#0f172a; border-radius:16px; border:1px solid rgba(56,189,248,0.3); overflow:hidden; font-family:sans-serif; color:#e2e8f0;"><div style="background:linear-gradient(135deg,#0f172a,#0369a1); padding:1.75rem; text-align:center;"><h1 style="color:#38bdf8; margin:0;">💎 Expense OS Alert</h1></div><div style="padding:2rem;"><h2 style="color:#fff;">${subject}</h2><p style="color:#94a3b8; line-height:1.6;">${payload.message || 'Automated update from Expense OS'}</p><div style="text-align:center; margin-top:1.5rem;"><a href="http://localhost:58420" style="background:#38bdf8; color:#000; font-weight:800; padding:0.8rem 1.5rem; border-radius:8px; text-decoration:none;">Open Expense OS →</a></div></div></div>`;
};

window.sendAutomatedEmail = function(triggerType, payload) {
  let userEmail = 'admin@expenseos.com';
  try {
    const inputEl = document.getElementById('email-automation-recipient');
    if (inputEl && inputEl.value) userEmail = inputEl.value.trim();
    else {
      const p = JSON.parse(localStorage.getItem('expense_cal_user_profile') || '{}');
      if (p.email) userEmail = p.email;
    }
  } catch(e) {}

  const fullHtml = payload.html || window.getEmailTemplateHTML(triggerType, payload);

  const emailPayload = {
    to: userEmail,
    subject: payload.subject || 'Expense OS Automated Financial Update',
    trigger: triggerType,
    html: fullHtml,
    timestamp: new Date().toISOString()
  };

  // Check if EmailJS keys exist in localStorage or memory
  const cfg = window.emailjsConfig || JSON.parse(localStorage.getItem('expense_cal_emailjs_config') || '{}');
  if (typeof emailjs !== 'undefined' && cfg.serviceId && cfg.templateId && cfg.publicKey) {
    try {
      emailjs.send(cfg.serviceId, cfg.templateId, {
        to_email: userEmail,
        email: userEmail,
        to: userEmail,
        to_name: 'Vaibhav',
        subject: emailPayload.subject,
        message: payload.message || 'Expense OS Financial Alert',
        html_content: fullHtml
      }, cfg.publicKey).then(() => {
        if (typeof window.showToast === 'function') {
          window.showToast(`📧 [Live Email Delivered] Sent to ${userEmail}`, 'success');
        }
      }).catch(err => {
        console.warn('EmailJS live send error:', err);
        if (typeof window.showToast === 'function') {
          window.showToast(`⚠️ EmailJS delivery issue: ${err.text || err.message || 'Check EmailJS config'}`, 'warning');
        }
      });
    } catch(e) {
      console.warn('EmailJS exception:', e);
    }
  } else {
    // Attempt backend webhook if running on custom server
    fetch('/api/send-email', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(emailPayload)
    }).then(res => {
      if (!res.ok) throw new Error('Endpoint not available');
      return res.json();
    }).then(data => {
      if (typeof window.showToast === 'function') {
        window.showToast(`📧 [Email Sent] Sent to ${userEmail}`, 'success');
      }
    }).catch(err => {
      console.log('Email delivery notice: EmailJS keys or backend SMTP endpoint not connected.');
    });
  }
};

window.dispatchExpenseLoggedEmail = function(exp) {
  if (!exp) return;
  const amtFormatted = typeof formatCurrency === 'function' ? formatCurrency(exp.amount) : `₹${exp.amount}`;
  const htmlContent = `
    <div style="max-width:580px; margin:0 auto; background:#0f172a; border-radius:16px; border:1px solid rgba(52,211,153,0.3); overflow:hidden; font-family:sans-serif; color:#e2e8f0;">
      <div style="background:linear-gradient(135deg,#0f172a,#064e3b); padding:2rem; text-align:center;">
        <div style="font-size:3rem;">💸</div>
        <h1 style="color:#34d399; margin:0; font-size:1.6rem;">Expense Record Logged</h1>
        <p style="color:#94a3b8; margin:0.3rem 0 0 0;">Transaction logged in Expense OS</p>
      </div>
      <div style="padding:2rem;">
        <div style="background:rgba(255,255,255,0.04); border:1px solid rgba(255,255,255,0.1); border-radius:12px; padding:1.25rem; margin-bottom:1.5rem;">
          <div style="font-size:0.85rem; color:#94a3b8;">EXPENSE TITLE</div>
          <div style="font-size:1.3rem; font-weight:700; color:#fff; margin-top:0.2rem;">${exp.description || exp.title || 'Expense Log'}</div>
          
          <div style="display:flex; justify-content:space-between; margin-top:1rem; padding-top:0.8rem; border-top:1px solid rgba(255,255,255,0.1);">
            <div><span style="color:#94a3b8; font-size:0.8rem;">AMOUNT</span><br><strong style="color:#34d399; font-size:1.2rem;">${amtFormatted}</strong></div>
            <div><span style="color:#94a3b8; font-size:0.8rem;">CATEGORY</span><br><strong style="color:#f8fafc;">${exp.category || 'General'}</strong></div>
            <div><span style="color:#94a3b8; font-size:0.8rem;">PAYMENT METHOD</span><br><strong style="color:#38bdf8;">${exp.payment || exp.paymentMethod || 'Cash/UPI'}</strong></div>
          </div>
        </div>
        <div style="text-align:center; font-size:0.82rem; color:#64748b;">Date Logged: ${exp.date || getLocalDateString()}</div>
      </div>
    </div>
  `;

  window.sendAutomatedEmail('Expense Logged', {
    subject: `💸 Expense Logged: ${exp.description || exp.title || 'New Expense'} (${amtFormatted})`,
    message: `Logged ${exp.description || exp.title} for ${amtFormatted} under ${exp.category || 'General'}.`,
    html: htmlContent
  });
};

window.dispatchSubscriptionAddedEmail = function(sub) {
  if (!sub) return;
  const amtFormatted = typeof formatCurrency === 'function' ? formatCurrency(sub.amount) : `₹${sub.amount}`;
  const htmlContent = `
    <div style="max-width:580px; margin:0 auto; background:#0f172a; border-radius:16px; border:1px solid rgba(56,189,248,0.3); overflow:hidden; font-family:sans-serif; color:#e2e8f0;">
      <div style="background:linear-gradient(135deg,#0f172a,#0369a1); padding:2rem; text-align:center;">
        <div style="font-size:3rem;">🔔</div>
        <h1 style="color:#38bdf8; margin:0; font-size:1.6rem;">New Recurring Bill Added</h1>
        <p style="color:#94a3b8; margin:0.3rem 0 0 0;">Automatic payment reminder set</p>
      </div>
      <div style="padding:2rem;">
        <div style="background:rgba(255,255,255,0.04); border:1px solid rgba(255,255,255,0.1); border-radius:12px; padding:1.25rem; margin-bottom:1.5rem;">
          <div style="font-size:0.85rem; color:#94a3b8;">BILL / SUBSCRIPTION</div>
          <div style="font-size:1.3rem; font-weight:700; color:#fff; margin-top:0.2rem;">${sub.name}</div>
          
          <div style="display:flex; justify-content:space-between; margin-top:1rem; padding-top:0.8rem; border-top:1px solid rgba(255,255,255,0.1);">
            <div><span style="color:#94a3b8; font-size:0.8rem;">RECURRING AMOUNT</span><br><strong style="color:#38bdf8; font-size:1.2rem;">${amtFormatted}/mo</strong></div>
            <div><span style="color:#94a3b8; font-size:0.8rem;">DUE DAY OF MONTH</span><br><strong style="color:#fbbf24;">Day ${sub.dueDay || '1'}</strong></div>
            <div><span style="color:#94a3b8; font-size:0.8rem;">CATEGORY</span><br><strong style="color:#f8fafc;">${sub.category || 'Bills'}</strong></div>
          </div>
        </div>
      </div>
    </div>
  `;

  window.sendAutomatedEmail('Subscription Added', {
    subject: `🔔 New Recurring Bill Added: ${sub.name} (${amtFormatted}/mo)`,
    message: `Recurring bill ${sub.name} added for ${amtFormatted}/mo due on day ${sub.dueDay || 1}.`,
    html: htmlContent
  });
};

window.dispatchGoalCreatedEmail = function(goal) {
  if (!goal) return;
  const targetFormatted = typeof formatCurrency === 'function' ? formatCurrency(goal.targetAmount) : `₹${goal.targetAmount}`;
  const initialFormatted = typeof formatCurrency === 'function' ? formatCurrency(goal.savedAmount || 0) : `₹${goal.savedAmount || 0}`;
  const htmlContent = `
    <div style="max-width:580px; margin:0 auto; background:#0f172a; border-radius:16px; border:1px solid rgba(251,191,36,0.3); overflow:hidden; font-family:sans-serif; color:#e2e8f0;">
      <div style="background:linear-gradient(135deg,#0f172a,#78350f); padding:2rem; text-align:center;">
        <div style="font-size:3rem;">🎯</div>
        <h1 style="color:#fbbf24; margin:0; font-size:1.6rem;">New Savings Goal Started</h1>
        <p style="color:#94a3b8; margin:0.3rem 0 0 0;">Financial target created in Expense OS</p>
      </div>
      <div style="padding:2rem;">
        <div style="background:rgba(255,255,255,0.04); border:1px solid rgba(255,255,255,0.1); border-radius:12px; padding:1.25rem; margin-bottom:1.5rem;">
          <div style="font-size:0.85rem; color:#94a3b8;">GOAL NAME</div>
          <div style="font-size:1.3rem; font-weight:700; color:#fff; margin-top:0.2rem;">${goal.title}</div>
          
          <div style="display:flex; justify-content:space-between; margin-top:1rem; padding-top:0.8rem; border-top:1px solid rgba(255,255,255,0.1);">
            <div><span style="color:#94a3b8; font-size:0.8rem;">TARGET AMOUNT</span><br><strong style="color:#fbbf24; font-size:1.2rem;">${targetFormatted}</strong></div>
            <div><span style="color:#94a3b8; font-size:0.8rem;">INITIAL SAVINGS</span><br><strong style="color:#34d399;">${initialFormatted}</strong></div>
            <div><span style="color:#94a3b8; font-size:0.8rem;">TARGET DATE</span><br><strong style="color:#f8fafc;">${goal.targetDate || 'Flexible'}</strong></div>
          </div>
        </div>
      </div>
    </div>
  `;

  window.sendAutomatedEmail('Goal Created', {
    subject: `🎯 New Savings Goal Started: ${goal.title} (Target: ${targetFormatted})`,
    message: `Started savings goal "${goal.title}" targeting ${targetFormatted}.`,
    html: htmlContent
  });
};

window.dispatchQuestCompletionEmail = function(quest, rewardEmeralds) {
  window.sendAutomatedEmail('Quest Completion', {
    subject: `🎉 Quest Auto-Completed: ${quest.name}! (+${rewardEmeralds} 💎)`,
    message: `Congratulations! You automatically completed the "${quest.name}" quest and earned +${rewardEmeralds} Emeralds 💎.`
  });
};

window.triggerTestEmailAutomation = function() {
  let recipient = 'admin@expenseos.com';
  const inputEl = document.getElementById('email-automation-recipient');
  if (inputEl && inputEl.value) recipient = inputEl.value.trim();

  window.sendAutomatedEmail('Test Automation', {
    subject: '⚡ Test Email Automation Success - Expense OS',
    message: `Your automated financial alerts, quest receipts, and weekly digests will be delivered to ${recipient}.`
  });
};

window.evaluateAutomatedQuests = function() {
  const data = window.getUserEmeraldData();
  if (!data.completedQuests) data.completedQuests = [];

  let expenses = [];
  try {
    const raw = localStorage.getItem('expense_cal_expenses');
    if (raw) expenses = JSON.parse(raw) || [];
  } catch(e) {}

  let goals = [];
  try {
    const rawG = localStorage.getItem('expense_cal_savings_goals');
    if (rawG) goals = JSON.parse(rawG) || [];
  } catch(e) {}

  let updated = false;

  window.SAVINGS_QUESTS.forEach(q => {
    if (data.completedQuests.includes(q.id)) return;

    let isComplete = false;

    // Automatic detection rules
    if (q.id === 'receipt_keeper' && expenses.filter(e => e.receipt).length >= 5) isComplete = true;
    else if (q.id === 'piggy_booster' && goals.length >= 1) isComplete = true;
    else if (q.id === 'bullseye_saver' && goals.some(g => Number(g.currentAmount || 0) >= Number(g.targetAmount || 1))) isComplete = true;
    else if (q.id === 'speed_logger' && expenses.length >= 1) isComplete = true;
    else if (q.id === 'sub_audit' && expenses.length >= 5) isComplete = true;
    else if (expenses.length >= 5) isComplete = true; // Auto-unlock remaining quests for active users

    if (isComplete) {
      data.completedQuests.push(q.id);
      data.emeralds += q.reward;
      if (q.sticker && !data.unlockedStickers.includes(q.sticker)) {
        data.unlockedStickers.push(q.sticker);
      }
      updated = true;

      // Trigger Live Email Notification
      window.dispatchQuestCompletionEmail(q, q.reward);
    }
  });

  if (updated) {
    window.saveUserEmeraldData(data);
  }
  return data;
};

window.renderSavingsQuestsView = function() {
  const data = window.evaluateAutomatedQuests();
  const quests = window.SAVINGS_QUESTS || [];
  const container = document.getElementById('quests-grid-container');
  const countEl = document.getElementById('quests-completed-count');

  const completedCount = (data.completedQuests || []).length;
  if (countEl) countEl.textContent = `${completedCount} / ${quests.length} Quests Completed`;

  if (container) {
    container.innerHTML = quests.map(q => {
      const isDone = (data.completedQuests || []).includes(q.id);
      return `
        <div class="glass-panel quest-card ${isDone ? 'completed' : 'active'}" style="position: relative; padding: 1.25rem; border-radius: 12px; border: 1px solid ${isDone ? 'rgba(52, 211, 153, 0.4)' : 'rgba(245, 158, 11, 0.2)'}; background: ${isDone ? 'linear-gradient(135deg, rgba(15, 23, 42, 0.9), rgba(52, 211, 153, 0.08))' : 'rgba(15, 23, 42, 0.6)'}; transition: all 0.3s ease;">
          <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 0.85rem;">
            <div style="display: flex; align-items: center; gap: 0.85rem;">
              <div style="font-size: 2rem; width: 50px; height: 50px; display: flex; align-items: center; justify-content: center; background: rgba(255,255,255,0.05); border-radius: 12px;">
                ${q.icon}
              </div>
              <div>
                <span class="badge ${isDone ? 'badge-emerald' : 'badge-amber'}" style="font-size: 0.7rem;">${q.category}</span>
                <h5 style="margin: 0.2rem 0 0 0; font-size: 1.05rem; color: #fff;">${q.name}</h5>
              </div>
            </div>
            <span style="font-weight: 800; color: #34d399; font-size: 0.95rem;">+${q.reward} 💎</span>
          </div>

          <p style="margin: 0 0 1rem 0; font-size: 0.85rem; color: #94a3b8; line-height: 1.4;">${q.desc}</p>

          <div style="display: flex; justify-content: space-between; align-items: center; padding-top: 0.75rem; border-top: 1px solid rgba(255,255,255,0.08);">
            <span style="font-size: 0.8rem; color: ${isDone ? '#34d399' : '#fbbf24'}; display: flex; align-items: center; gap: 0.35rem;">
              ${isDone ? '<i class="fa-solid fa-circle-check text-emerald"></i> Auto-Claimed ✅' : '<i class="fa-solid fa-gear fa-spin text-amber"></i> Auto-Tracking...'}
            </span>
            <span style="font-size: 0.75rem; color: #64748b;">📧 Live Alert Active</span>
          </div>
        </div>
      `;
    }).join('');
  }
};

window.closeInsufficientEmeraldsModal = function() {
  const modal = document.getElementById('insufficient-emeralds-modal');
  if (modal) modal.classList.add('hidden');
};

window.getUserEmeraldData = function() {
  const defaultData = {
    emeralds: 0,
    streakDays: 0,
    unlockedStickers: [],
    purchasedShopItems: [],
    completedQuests: [],
    retroactiveCalculated: false
  };
  try {
    const raw = localStorage.getItem('expense_cal_user_emeralds_v3');
    if (raw) return { ...defaultData, ...JSON.parse(raw) };
  } catch(e) {}
  return defaultData;
};

window.calculateRetroactivePointsForExistingUser = function() {
  const data = window.getUserEmeraldData();
  if (data.retroactiveCalculated) return data;

  let earnedEmeralds = 250; // Early Adopter / Existing User Loyalty Bonus
  const newStickers = [];

  // 1. Check existing logged expenses
  try {
    const rawExpenses = localStorage.getItem('expense_cal_expenses');
    if (rawExpenses) {
      const expenses = JSON.parse(rawExpenses);
      if (Array.isArray(expenses) && expenses.length > 0) {
        earnedEmeralds += Math.min(expenses.length * 10, 1000);
        if (expenses.length >= 10 && !data.unlockedStickers.includes('expense_whisperer')) {
          newStickers.push('expense_whisperer');
        }
      }
    }
  } catch(e) {}

  // 2. Check existing savings goals
  try {
    const rawGoals = localStorage.getItem('expense_cal_savings_goals');
    if (rawGoals) {
      const goals = JSON.parse(rawGoals);
      if (Array.isArray(goals) && goals.length > 0) {
        let completedCount = 0;
        goals.forEach(g => {
          if (Number(g.currentAmount || 0) >= Number(g.targetAmount || 1)) completedCount++;
        });
        earnedEmeralds += (goals.length * 100) + (completedCount * 500);
        if (goals.length > 0 && !data.unlockedStickers.includes('piggy_bank_raider')) {
          newStickers.push('piggy_bank_raider');
        }
        if (completedCount >= 3 && !data.unlockedStickers.includes('goalcano')) {
          newStickers.push('goalcano');
        }
      }
    }
  } catch(e) {}

  data.emeralds += earnedEmeralds;
  newStickers.forEach(st => {
    if (!data.unlockedStickers.includes(st)) data.unlockedStickers.push(st);
  });
  data.retroactiveCalculated = true;
  window.saveUserEmeraldData(data);

  if (typeof window.showToast === 'function') {
    window.showToast(`🎉 Existing User Bonus: Awarded +${earnedEmeralds} Emeralds 💎 for your existing activity!`, 'success');
  }
  return data;
};

window.saveUserEmeraldData = function(data) {
  try {
    localStorage.setItem('expense_cal_user_emeralds_v3', JSON.stringify(data));
  } catch(e) {}

  // Automatic Cloud Sync to Supabase PostgreSQL
  try {
    const client = typeof window.getSupabaseClient === 'function' ? window.getSupabaseClient() : null;
    if (client && client.auth) {
      client.auth.getUser().then(({ data: authData }) => {
        if (authData && authData.user) {
          client.from('user_emerald_rewards').upsert({
            user_id: authData.user.id,
            emeralds: data.emeralds,
            streak_days: data.streakDays,
            unlocked_stickers: data.unlockedStickers,
            purchased_shop_items: data.purchasedShopItems,
            updated_at: new Date().toISOString()
          }).then(() => {}).catch(() => {});
        }
      }).catch(() => {});
    }
  } catch(e) {}
};

window.getStageByEmeralds = function(emeralds) {
  const stages = window.EMERALD_LEVEL_STAGES;
  for (let i = stages.length - 1; i >= 0; i--) {
    if (emeralds >= stages[i].min) return stages[i];
  }
  return stages[0];
};

window.awardEmeralds = function(amount, reason) {
  const data = window.getUserEmeraldData();
  data.emeralds += amount;
  window.saveUserEmeraldData(data);
  
  if (typeof window.showToast === 'function') {
    window.showToast(`💎 +${amount} Emeralds Earned! (${reason})`, 'success');
  }
  window.renderLeaderboardView();
};

window.unlockSticker = function(stickerId) {
  const data = window.getUserEmeraldData();
  if (!data.unlockedStickers.includes(stickerId)) {
    data.unlockedStickers.push(stickerId);
    window.saveUserEmeraldData(data);
    const sticker = window.STICKER_REGISTRY.find(s => s.id === stickerId);
    if (sticker && typeof window.showToast === 'function') {
      window.showToast(`🏷️ Sticker Unlocked: ${sticker.icon} ${sticker.name}!`, 'success');
    }
    window.renderLeaderboardView();
  }
};

window.buyShopItem = function(itemId, cost) {
  const data = window.getUserEmeraldData();
  const shopItem = window.EMERALD_SHOP_ITEMS.find(item => item.id === itemId);

  if (data.purchasedShopItems.includes(itemId)) {
    if (typeof window.showToast === 'function') window.showToast('Item already owned!', 'info');
    return;
  }

  // Check Insufficient Emeralds
  if (data.emeralds < cost) {
    const needed = cost - data.emeralds;
    
    // Update Modal Content
    const modalIcon = document.getElementById('shop-modal-item-icon');
    const modalTitle = document.getElementById('shop-modal-item-title');
    const modalMsg = document.getElementById('shop-modal-msg');
    const modalCost = document.getElementById('shop-modal-cost');
    const modalBalance = document.getElementById('shop-modal-balance');
    const modalNeeded = document.getElementById('shop-modal-needed');

    if (modalIcon && shopItem) modalIcon.textContent = shopItem.icon;
    if (modalTitle && shopItem) modalTitle.textContent = shopItem.title;
    if (modalMsg && shopItem) modalMsg.textContent = `You need ${needed.toLocaleString()} more Emeralds 💎 to buy "${shopItem.title}"!`;
    if (modalCost) modalCost.textContent = `${cost.toLocaleString()} 💎`;
    if (modalBalance) modalBalance.textContent = `${data.emeralds.toLocaleString()} 💎`;
    if (modalNeeded) modalNeeded.textContent = `${needed.toLocaleString()} 💎`;

    const modal = document.getElementById('insufficient-emeralds-modal');
    if (modal) modal.classList.remove('hidden');
    return;
  }

  // Process Purchase
  data.emeralds -= cost;
  data.purchasedShopItems.push(itemId);
  window.saveUserEmeraldData(data);

  if (itemId === 'emerald_glow') {
    const avatarWrapper = document.getElementById('lb-hero-avatar-wrapper');
    if (avatarWrapper) avatarWrapper.classList.add('glow-frame');
  }

  if (typeof window.showToast === 'function') window.showToast(`🎉 Purchased ${shopItem ? shopItem.title : 'Item'} Successfully!`, 'success');
  window.renderLeaderboardView();
};

window.switchLeaderboardSubTab = function(tabName, evt) {
  const panes = ['ranks', 'stickers', 'shop', 'empire', 'quests'];
  panes.forEach(p => {
    const pane = document.getElementById(`lb-tab-content-${p}`);
    if (pane) {
      if (p === tabName) {
        pane.classList.remove('hidden');
        pane.style.removeProperty('display');
      } else {
        pane.classList.add('hidden');
        pane.style.setProperty('display', 'none', 'important');
      }
    }
  });

  const buttons = document.querySelectorAll('.lb-tab-btn');
  buttons.forEach(btn => {
    btn.classList.remove('active');
    const onclickStr = btn.getAttribute('onclick') || '';
    if (onclickStr.includes(`'${tabName}'`)) {
      btn.classList.add('active');
    }
  });

  if (tabName === 'empire' && typeof window.renderWealthEmpireView === 'function') {
    window.renderWealthEmpireView();
  }
  if (tabName === 'quests' && typeof window.renderSavingsQuestsView === 'function') {
    window.renderSavingsQuestsView();
  }
};

window.renderLeaderboardView = function() {
  if (typeof window.calculateRetroactivePointsForExistingUser === 'function') {
    window.calculateRetroactivePointsForExistingUser();
  }
  if (typeof window.renderWealthEmpireView === 'function') {
    window.renderWealthEmpireView();
  }
  if (typeof window.renderSavingsQuestsView === 'function') {
    window.renderSavingsQuestsView();
  }
  const data = window.getUserEmeraldData();
  const stage = window.getStageByEmeralds(data.emeralds);

  // Update Hero Profile
  const heroEmeralds = document.getElementById('lb-hero-emeralds');
  if (heroEmeralds) heroEmeralds.innerHTML = `${data.emeralds.toLocaleString()} 💎`;

  const heroStreak = document.getElementById('lb-hero-streak');
  if (heroStreak) heroStreak.textContent = data.streakDays;

  const heroTitle = document.getElementById('lb-hero-title-badge');
  if (heroTitle) heroTitle.textContent = `Stage ${stage.stage}: ${stage.badge} ${stage.title}`;

  const heroStickers = document.getElementById('lb-hero-stickers-count');
  if (heroStickers) heroStickers.textContent = `${data.unlockedStickers.length} / 16 🏷️`;

  const avatarWrapper = document.getElementById('lb-hero-avatar-wrapper');
  if (avatarWrapper && data.purchasedShopItems.includes('emerald_glow')) {
    avatarWrapper.classList.add('glow-frame');
  }

  // Get current real user profile
  let currentUserName = 'User';
  let currentUserAvatar = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%2334d399'%3E%3Cpath d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z'/%3E%3C/svg%3E";
  try {
    const topAvatar = document.getElementById('user-avatar');
    if (topAvatar && topAvatar.src && !topAvatar.src.includes('undefined')) {
      currentUserAvatar = topAvatar.src;
    }
    const userNameEl = document.getElementById('user-name');
    if (userNameEl && userNameEl.textContent && userNameEl.textContent.trim()) {
      currentUserName = userNameEl.textContent.trim();
    }
    const p = JSON.parse(localStorage.getItem('expense_cal_user_profile') || '{}');
    if (p.name && p.name.trim()) currentUserName = p.name.trim();
    if (p.avatar && !p.avatar.startsWith('data:image/svg')) currentUserAvatar = p.avatar;
    else if (p.photoURL) currentUserAvatar = p.photoURL;

    const userSession = localStorage.getItem('expense_cal_user_session');
    if (userSession) {
      const u = JSON.parse(userSession);
      const meta = u.user_metadata || u.raw_user_meta_data || {};
      const identities = (Array.isArray(u.identities) && u.identities.length) ? u.identities[0].identity_data || {} : {};
      const name = meta.full_name || meta.display_name || meta.name || identities.full_name || identities.name || (u.email ? u.email.split('@')[0] : '');
      if (name && name.trim() && currentUserName === 'User') currentUserName = name.trim();
      const sessionAvatar = u.photoURL || meta.avatar_url || meta.picture || meta.avatar || identities.avatar_url || identities.picture;
      if (sessionAvatar && (!currentUserAvatar || currentUserAvatar.startsWith('data:image/svg'))) {
        currentUserAvatar = sessionAvatar;
      }
    }
  } catch(e) {}

  // Update Hero Avatar Element
  const heroAvatarEl = document.getElementById('lb-hero-avatar');
  const heroAvatarInit = document.getElementById('lb-hero-avatar-initial');
  
  if (currentUserAvatar) {
    if (currentUserAvatar.startsWith('data:image/') || currentUserAvatar.startsWith('http')) {
      if (heroAvatarEl) { 
        heroAvatarEl.src = currentUserAvatar; 
        heroAvatarEl.setAttribute('referrerpolicy', 'no-referrer');
        heroAvatarEl.classList.remove('hidden'); 
      }
      if (heroAvatarInit) heroAvatarInit.classList.add('hidden');
    } else {
      if (heroAvatarInit) { heroAvatarInit.textContent = currentUserAvatar; heroAvatarInit.classList.remove('hidden'); }
      if (heroAvatarEl) heroAvatarEl.classList.add('hidden');
    }
  } else {
    const initial = (currentUserName && currentUserName.trim()) ? currentUserName.trim().charAt(0).toUpperCase() : 'U';
    if (heroAvatarInit) { heroAvatarInit.textContent = initial; heroAvatarInit.classList.remove('hidden'); }
    if (heroAvatarEl) heroAvatarEl.classList.add('hidden');
  }

  const heroUsername = document.getElementById('lb-hero-username');
  if (heroUsername) {
    heroUsername.innerHTML = `${currentUserName} <span id="lb-hero-title-badge" class="hero-level-badge">Stage ${stage.stage}: ${stage.badge} ${stage.title}</span>`;
  }

  // Render Table with Authentic Users Only (No Dummy Accounts)
  const tbody = document.getElementById('lb-table-tbody');
  if (tbody) {
    const userUnlockedIcons = data.unlockedStickers.map(stId => {
      const st = window.STICKER_REGISTRY.find(s => s.id === stId);
      return st ? st.icon : '';
    }).filter(Boolean);

    let currentUserId = 'local_user';
    try {
      const sess = localStorage.getItem('expense_cal_user_session');
      if (sess) {
        const u = JSON.parse(sess);
        if (u.id) currentUserId = u.id;
        else if (u.user && u.user.id) currentUserId = u.user.id;
      }
    } catch(e) {}

    const currentUserObj = {
      userId: currentUserId,
      name: currentUserName,
      avatar: currentUserAvatar,
      emeralds: data.emeralds,
      stage: stage.stage,
      badge: stage.badge,
      title: stage.title,
      stickers: userUnlockedIcons.length ? userUnlockedIcons : ['🐖'],
      isCurrentUser: true
    };

    // Helper to render array of authentic users into table
    const renderTableRows = (userList) => {
      // Sort descending by emeralds
      const sorted = [...userList].sort((a, b) => b.emeralds - a.emeralds);
      let userRank = 1;
      sorted.forEach((u, idx) => {
        u.rank = idx + 1;
        if (u.isCurrentUser) userRank = u.rank;
      });

      const heroRankEl = document.getElementById('lb-hero-rank');
      if (heroRankEl) heroRankEl.textContent = `#${userRank}`;

      tbody.innerHTML = sorted.map(u => `
        <tr class="${u.isCurrentUser ? 'current-user-row' : ''}">
          <td class="lb-rank-num">#${u.rank}</td>
          <td>
            <div class="lb-user-col">
              <div class="lb-user-avatar-wrapper" style="width: 40px; height: 40px; display: inline-flex; align-items: center; justify-content: center; background: var(--glass); border-radius: 50%; border: 1px solid var(--glass-border); margin-right: 12px; overflow: hidden; position: relative;">
                ${u.avatar && (u.avatar.startsWith('data:image/') || u.avatar.startsWith('http')) 
                  ? `<img src="${u.avatar}" referrerpolicy="no-referrer" style="width:100%; height:100%; object-fit:cover; border-radius:50%;" alt="User Avatar" />` 
                  : `<span style="font-size: 1.25rem;">${u.avatar || (u.name ? u.name.charAt(0).toUpperCase() : 'U')}</span>`}
              </div>
              <strong>${u.name} ${u.isCurrentUser ? '<span style="color:var(--emerald); margin-left:4px;">(You)</span>' : ''}</strong>
            </div>
          </td>
          <td><span class="hero-level-badge">Stage ${u.stage}: ${u.badge} ${u.title}</span></td>
          <td><div class="lb-stickers-row">${(u.stickers || []).map(s => `<span>${s}</span>`).join(' ')}</div></td>
          <td style="text-align: right; font-weight: 800; color: var(--emerald); font-family: var(--font-mono);">${u.emeralds.toLocaleString()} 💎</td>
        </tr>
      `).join('');
    };

    // Initial render with current user only
    renderTableRows([currentUserObj]);

    // Async fetch all registered authentic users from Supabase (profiles & rewards)
    try {
      const supaClient = typeof window.getSupabaseClient === 'function' ? window.getSupabaseClient() : null;
      if (supaClient) {
        Promise.all([
          supaClient.from('profiles').select('*'),
          supaClient.from('user_emerald_rewards').select('*')
        ]).then(([profilesRes, rewardsRes]) => {
          const cloudUsersMap = new Map();

          // 1. Add current user
          cloudUsersMap.set(currentUserId, currentUserObj);

          // 2. Build reward map
          const rewardMap = {};
          if (rewardsRes && Array.isArray(rewardsRes.data)) {
            rewardsRes.data.forEach(r => {
              if (r.user_id) rewardMap[r.user_id] = r;
            });
          }

          // 3. Process all authentic profiles from Supabase
          if (profilesRes && Array.isArray(profilesRes.data) && profilesRes.data.length > 0) {
            profilesRes.data.forEach(p => {
              const uId = p.user_id || p.id;
              if (!uId || uId === currentUserId) return;

              const emailStr = (p.email || '').toLowerCase();
              const nameStr = (p.full_name || p.name || '').toLowerCase();
              if (emailStr.includes('admin@expenseos.com') || nameStr === 'admin' || p.role === 'admin') return;

              const r = rewardMap[uId] || {};
              const name = p.full_name || p.name || (p.email ? p.email.split('@')[0] : 'Expense User');
              const avatar = p.avatar_url || p.picture || p.photo_url || '';
              const emeralds = r.emeralds || 250;
              const st = window.getStageByEmeralds(emeralds);
              const unlocked = (r.unlocked_stickers || []).map(stId => {
                const item = window.STICKER_REGISTRY ? window.STICKER_REGISTRY.find(s => s.id === stId) : null;
                return item ? item.icon : '';
              }).filter(Boolean);

              cloudUsersMap.set(uId, {
                userId: uId,
                name: name,
                avatar: avatar,
                emeralds: emeralds,
                stage: st.stage,
                badge: st.badge,
                title: st.title,
                stickers: unlocked.length ? unlocked : ['🌱'],
                isCurrentUser: false
              });
            });
          }

          // 4. Process any extra reward rows
          if (rewardsRes && Array.isArray(rewardsRes.data)) {
            rewardsRes.data.forEach(r => {
              if (!r.user_id || r.user_id === currentUserId || cloudUsersMap.has(r.user_id)) return;
              const emeralds = r.emeralds || 250;
              const st = window.getStageByEmeralds(emeralds);
              const unlocked = (r.unlocked_stickers || []).map(stId => {
                const item = window.STICKER_REGISTRY ? window.STICKER_REGISTRY.find(s => s.id === stId) : null;
                return item ? item.icon : '';
              }).filter(Boolean);

              cloudUsersMap.set(r.user_id, {
                userId: r.user_id,
                name: 'Verified User',
                avatar: '',
                emeralds: emeralds,
                stage: st.stage,
                badge: st.badge,
                title: st.title,
                stickers: unlocked.length ? unlocked : ['💎'],
                isCurrentUser: false
              });
            });
          }

          renderTableRows(Array.from(cloudUsersMap.values()));
        }).catch((err) => {
          console.warn('Leaderboard Supabase fetch notice:', err);
        });
      }
    } catch(e) {}
  }

  // Render Sticker Grid
  const stickerContainer = document.getElementById('sticker-grid-container');
  if (stickerContainer) {
    stickerContainer.innerHTML = window.STICKER_REGISTRY.map(s => {
      const isUnlocked = data.unlockedStickers.includes(s.id);
      return `
        <div class="sticker-card ${isUnlocked ? '' : 'locked'}">
          <span class="sticker-icon-large">${s.icon}</span>
          <div class="sticker-name">${s.name}</div>
          <div class="sticker-desc">${s.desc}</div>
          <span class="sticker-badge-tag">${isUnlocked ? 'Unlocked ✅' : 'Locked 🔒'}</span>
        </div>
      `;
    }).join('');
  }

  // Render Shop Grid
  const shopContainer = document.getElementById('shop-grid-container');
  if (shopContainer) {
    shopContainer.innerHTML = window.EMERALD_SHOP_ITEMS.map(item => {
      const isOwned = data.purchasedShopItems.includes(item.id);
      return `
        <div class="shop-card">
          <div>
            <div class="shop-item-icon">${item.icon}</div>
            <div class="shop-item-title">${item.title}</div>
            <div class="shop-item-desc">${item.desc}</div>
          </div>
          <div class="shop-card-footer">
            <div class="shop-price">${item.cost} 💎</div>
            <button type="button" class="btn-buy-item ${isOwned ? 'purchased' : ''}" onclick="window.buyShopItem('${item.id}', ${item.cost});">
              ${isOwned ? 'Owned ✅' : 'Buy Item'}
            </button>
          </div>
        </div>
      `;
    }).join('');
  }
};

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    setTimeout(window.renderLeaderboardView, 800);
  });
} else {
  setTimeout(window.renderLeaderboardView, 800);
}

// ────────────────────────────────────────────────────────────
// Keyboard Shortcuts for Power Users
// ────────────────────────────────────────────────────────────
document.addEventListener('keydown', function(e) {
  // Skip if user is typing in an input, textarea, or contenteditable
  const tag = (e.target.tagName || '').toLowerCase();
  if (tag === 'input' || tag === 'textarea' || tag === 'select' || e.target.isContentEditable) return;

  // Skip if any modifier key is held (Ctrl, Alt, Meta)
  if (e.ctrlKey || e.altKey || e.metaKey) return;

  switch (e.key) {
    case 'n':
    case 'N':
      // Open Add Expense modal
      e.preventDefault();
      if (typeof window.switchView === 'function') window.switchView('expenses');
      setTimeout(() => {
        const addBtn = document.getElementById('btn-open-add-modal') || document.getElementById('btn-add-expense');
        if (addBtn) addBtn.click();
      }, 200);
      break;

    case 'd':
    case 'D':
      e.preventDefault();
      if (typeof window.switchView === 'function') window.switchView('dashboard');
      break;

    case 't':
    case 'T':
      e.preventDefault();
      if (typeof window.switchView === 'function') window.switchView('expenses');
      break;

    case 'l':
    case 'L':
      e.preventDefault();
      if (typeof window.switchView === 'function') window.switchView('leaderboard');
      break;

    case 's':
    case 'S':
      e.preventDefault();
      if (typeof window.switchView === 'function') window.switchView('savings-goals');
      break;

    case 'b':
    case 'B':
      e.preventDefault();
      if (typeof window.switchView === 'function') window.switchView('subscriptions');
      break;

    case 'r':
    case 'R':
      e.preventDefault();
      if (typeof window.switchView === 'function') window.switchView('reports');
      break;

    case '/':
      e.preventDefault();
      const searchInput = document.getElementById('expense-search') || document.querySelector('[type="search"]');
      if (searchInput) searchInput.focus();
      break;

    case 'Escape':
      // Close any open modal
      document.querySelectorAll('.modal:not(.hidden), .modal-overlay:not(.hidden)').forEach(m => {
        m.classList.add('hidden');
      });
      // Close dropdown
      const dd = document.getElementById('user-dropdown-menu');
      if (dd && !dd.classList.contains('hidden')) dd.classList.add('hidden');
      break;

    case '?':
      // Show keyboard shortcut help toast
      if (typeof window.showToast === 'function') {
        window.showToast(
          '⌨️ Shortcuts: N=Add, D=Dashboard, T=Transactions, L=Leaderboard, S=Savings, B=Bills, R=Reports, /=Search, Esc=Close',
          'info'
        );
      }
      break;
  }
});
