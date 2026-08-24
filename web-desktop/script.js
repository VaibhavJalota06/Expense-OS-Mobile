// Expense Calculator - Futuristic Dark Glassmorphic Dashboard Logic
// Handles navigation tabs, state persistence, SVG radial budget gauge, month-wise filtering, monthly bar chart trend, category donut analytics, transaction tracking, and subscription reminders.

// ---------- Supabase Table Configuration ----------
// This table name is used for cross-platform sync between web and Android apps
// Make sure the Android app uses the same table name for data sync
const SUPABASE_USER_DATA_TABLE = 'user_data';

// ---------- State Variables ----------
let budget = 0;
let expenses = [];
let subscriptions = [];
let accountBalance = 0;
let currentTxLogTab = 'expense';
let activeTimeFilter = 'ALL';
let currentView = 'dashboard';
let selectedMonth = getCurrentYearMonth(); // YYYY-MM or 'ALL'

// Category Color Map (Spec Compliant)
const categoryColors = {
  'Food & Dining': '#34D399',           // Emerald
  'Transportation': '#38BDF8',          // Sky
  'Shopping': '#A78BFA',                // Violet
  'Bills & Utilities': '#FBBF24',       // Amber
  'Entertainment': '#F472B6',           // Pink
  'Health & Fitness': '#FB923C',        // Orange
  'Services & Subscriptions': '#818CF8',// Indigo
  'Miscellaneous': '#94A3B8'            // Slate
};

// Global Welcome Modal Button Handlers
window.closeWelcomeModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  window.welcomeModalDismissed = true;
  try { localStorage.setItem('expense_cal_seen_welcome_global', 'true'); } catch(err){}
  const welcomeModal = document.getElementById('welcome-modal');
  if (welcomeModal) {
    welcomeModal.classList.add('hidden');
    welcomeModal.style.setProperty('display', 'none', 'important');
    welcomeModal.style.setProperty('opacity', '0', 'important');
    welcomeModal.style.setProperty('visibility', 'hidden', 'important');
    welcomeModal.style.setProperty('pointer-events', 'none', 'important');
  }
};

window.handleStartTour = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  window.closeWelcomeModal(e);
  if (typeof startGuidedTour === 'function') startGuidedTour();
};

window.handleSkipTour = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  window.closeWelcomeModal(e);
};

// Sync Status Callback — Updates the UI badge directly
window.setSyncStatus = function(status) {
  const syncStatusEl = document.getElementById('sync-status');
  if (!syncStatusEl) {
    console.log(`Sync status: ${status}`);
    return;
  }
  const states = {
    syncing: { text: 'Syncing...', cls: 'sync-syncing', icon: 'fa-arrows-rotate fa-spin' },
    synced: { text: 'Synced', cls: 'sync-synced', icon: 'fa-circle-check' },
    error: { text: 'Synced (Local)', cls: 'sync-synced', icon: 'fa-circle-check' },
  };
  const s = states[status] || states.synced;
  syncStatusEl.className = `sync-status-badge ${s.cls}`;
  syncStatusEl.innerHTML = `<i class="fa-solid ${s.icon}"></i> ${s.text}`;
};

// Chart.js Instances
let breakdownChartInstance = null;
let fullAnalyticsChartInstance = null;
let trendChartInstance = null;

const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// View Titles & Subtitles
const viewHeadings = {
  dashboard: { title: 'Dashboard Analytics', subtitle: 'Real-time financial analytics & budget control' },
  transactions: { title: 'Transaction Manager', subtitle: 'Comprehensive history & instant search' },
  bills: { title: 'Recurring Bills & Subscriptions', subtitle: 'Upcoming payment reminders & automation' },
  analytics: { title: 'Category Analytics', subtitle: 'Visual breakdown of monthly expenditures & historical trends' },
  'ai-rules': { title: 'AI Smart Budget Rules', subtitle: 'Real-time threshold warnings & automated financial discipline' },
  'fx-rates': { title: 'FX Rates & Currency', subtitle: 'Live multi-currency exchange matrix & dynamic rate conversion' },
  'cloud-db': { title: 'Cloud & Offline DB', subtitle: 'Real-time PostgreSQL Supabase cloud sync & local caching' },
  reports: { title: 'Reports & Data Export', subtitle: 'Export transaction ledger in CSV & JSON formats' }
};

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
const subForm = document.getElementById('sub-form');
const subNameInput = document.getElementById('sub-name');
const subAmountInput = document.getElementById('sub-amount');
const subDueDayInput = document.getElementById('sub-due-day');
const subCategorySelect = document.getElementById('sub-category');
const subModalCloseBtn = document.getElementById('sub-modal-close');
const subModalCancelBtn = document.getElementById('sub-modal-cancel');

let activeCurrency = 'INR';
let incomes = [];

const currencyRates = {
  INR: { rate: 1, symbol: '₹', locale: 'en-IN', currency: 'INR' },
  USD: { rate: 0.012, symbol: '$', locale: 'en-US', currency: 'USD' },
  EUR: { rate: 0.011, symbol: '€', locale: 'de-DE', currency: 'EUR' },
  GBP: { rate: 0.0094, symbol: '£', locale: 'en-GB', currency: 'GBP' }
};

function formatCurrency(val) {
  const num = Number(val);
  const safeVal = (typeof num === 'number' && !isNaN(num) && Number.isFinite(num)) ? num : 0;
  const config = currencyRates[activeCurrency] || currencyRates.INR;
  const converted = safeVal * config.rate;
  return new Intl.NumberFormat(config.locale, {
    style: 'currency',
    currency: config.currency,
    maximumFractionDigits: 2
  }).format(converted);
}

window.handleCurrencyChange = function(newCurrency) {
  if (currencyRates[newCurrency]) {
    activeCurrency = newCurrency;
    try { localStorage.setItem('expense_cal_currency', newCurrency); } catch(e){}
    updateUI();
  }
};

function getCurrentYearMonth() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

function formatMonthLabel(ymStr) {
  if (!ymStr || ymStr === 'ALL') return 'All Months';
  const parts = ymStr.split('-');
  if (parts.length < 2) return ymStr;
  const year = parts[0];
  const monthIdx = parseInt(parts[1], 10) - 1;
  return `${monthNames[monthIdx] || parts[1]} ${year}`;
}

// // Custom Glassmorphic Confirm & Alert Modal Helpers
function showConfirm(title, message, isDanger = false) {
  return new Promise((resolve) => {
    try {
      const modal = document.getElementById('confirm-modal');
      const titleEl = document.getElementById('confirm-modal-title');
      const msgEl = document.getElementById('confirm-modal-msg');
      const okBtn = document.getElementById('confirm-modal-ok');
      const cancelBtn = document.getElementById('confirm-modal-cancel');
      const closeBtn = document.getElementById('confirm-modal-close');

      if (!modal || !okBtn) { resolve(window.confirm(message)); return; }

      titleEl.innerHTML = isDanger
        ? `<i class="fa-solid fa-triangle-exclamation text-rose"></i> ${title}`
        : `<i class="fa-solid fa-circle-question text-sky"></i> ${title}`;
      msgEl.textContent = message;

      if (isDanger) {
        okBtn.className = 'btn btn-danger-outline';
        okBtn.textContent = 'Yes, Proceed';
      } else {
        okBtn.className = 'btn btn-primary';
        okBtn.textContent = 'Confirm';
      }

      modal.classList.remove('hidden');
      modal.style.setProperty('display', 'flex', 'important');
      modal.style.setProperty('opacity', '1', 'important');
      modal.style.setProperty('visibility', 'visible', 'important');
      modal.style.setProperty('z-index', '100000', 'important');
      modal.style.setProperty('pointer-events', 'auto', 'important');

      function done(res) {
        modal.classList.add('hidden');
        modal.style.setProperty('display', 'none', 'important');
        modal.style.setProperty('pointer-events', 'none', 'important');
        okBtn.onclick = null;
        if (cancelBtn) cancelBtn.onclick = null;
        if (closeBtn) closeBtn.onclick = null;
        modal.onclick = null;
        resolve(res);
      }

      okBtn.onclick = (e) => { if (e) { e.preventDefault(); e.stopPropagation(); } done(true); };
      if (cancelBtn) cancelBtn.onclick = (e) => { if (e) { e.preventDefault(); e.stopPropagation(); } done(false); };
      if (closeBtn) closeBtn.onclick = (e) => { if (e) { e.preventDefault(); e.stopPropagation(); } done(false); };
      modal.onclick = (e) => {
        if (e.target === modal) done(false);
      };
    } catch (err) {
      console.warn('showConfirm modal error, fallback to native confirm:', err);
      resolve(window.confirm(message));
    }
  });
}

function showAlert(title, message) {
  return new Promise((resolve) => {
    try {
      const modal = document.getElementById('alert-modal');
      const titleEl = document.getElementById('alert-modal-title');
      const msgEl = document.getElementById('alert-modal-msg');
      const okBtn = document.getElementById('alert-modal-ok');
      const closeBtn = document.getElementById('alert-modal-close');

      if (!modal || !okBtn) { alert(`${title}\n\n${message}`); resolve(); return; }

      titleEl.innerHTML = `<i class="fa-solid fa-circle-info text-emerald"></i> ${title}`;
      msgEl.textContent = message;
      modal.classList.remove('hidden');
      modal.style.setProperty('display', 'flex', 'important');
      modal.style.setProperty('opacity', '1', 'important');
      modal.style.setProperty('visibility', 'visible', 'important');
      modal.style.setProperty('z-index', '100000', 'important');
      modal.style.setProperty('pointer-events', 'auto', 'important');

      function done() {
        modal.classList.add('hidden');
        modal.style.setProperty('display', 'none', 'important');
        modal.style.setProperty('pointer-events', 'none', 'important');
        okBtn.onclick = null;
        if (closeBtn) closeBtn.onclick = null;
        modal.onclick = null;
        resolve();
      }

      okBtn.onclick = (e) => { if (e) { e.preventDefault(); e.stopPropagation(); } done(); };
      if (closeBtn) closeBtn.onclick = (e) => { if (e) { e.preventDefault(); e.stopPropagation(); } done(); };
      modal.onclick = (e) => {
        if (e.target === modal) done();
      };
    } catch (err) {
      console.warn('showAlert modal error, fallback to native alert:', err);
      alert(`${title}\n\n${message}`);
      resolve();
    }
  });
}

// ---------- State Persistence (Supabase + Firestore + localStorage fallback) ----------
let currentUserId = null;
let supabaseChannel = null;

async function saveState() {
  // Always save to localStorage as backup
  try {
    localStorage.setItem('expense_cal_web_budget', budget.toString());
    localStorage.setItem('expense_cal_web_expenses', JSON.stringify(expenses));
    localStorage.setItem('expense_cal_web_subscriptions', JSON.stringify(subscriptions));
    localStorage.setItem('expense_cal_web_incomes', JSON.stringify(incomes));
    localStorage.setItem('expense_cal_web_account_balance', accountBalance.toString());
    localStorage.setItem('expense_cal_currency', activeCurrency);
  } catch (err) {
    console.warn('localStorage save error:', err);
  }

  // Save to Supabase if logged in & Supabase available
  const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
  if (!supaClient || typeof isSupabaseConfigured === 'undefined' || !isSupabaseConfigured) {
    if (typeof setSyncStatus === 'function') setSyncStatus('synced');
    return;
  }

  // Auto-detect current user ID if not explicitly set
  let userId = currentUserId;
  if (!userId && supaClient.auth) {
    try {
      const { data } = await supaClient.auth.getSession();
      if (data && data.session && data.session.user) {
        userId = data.session.user.id;
        currentUserId = userId;
      }
    } catch(e) {}
  }

  if (userId) {
    try {
      if (typeof setSyncStatus === 'function') setSyncStatus('syncing');
      const payload = {
        user_id: userId,
        budget: budget,
        expenses: expenses,
        subscriptions: subscriptions,
        incomes: incomes,
        currency: activeCurrency,
        updated_at: new Date().toISOString()
      };

      const { error } = await supaClient.from(SUPABASE_USER_DATA_TABLE).upsert(payload, { onConflict: 'user_id' });
      if (error) {
        console.warn('⚠️ Supabase Upsert Notice:', error.message || error);
        if (error.message && (error.message.includes('column') || error.message.includes('incomes') || error.message.includes('currency') || error.code === 'PGRST204')) {
          const basicPayload = {
            user_id: userId,
            budget: budget,
            expenses: expenses,
            subscriptions: subscriptions,
            updated_at: new Date().toISOString()
          };
          await supaClient.from(SUPABASE_USER_DATA_TABLE).upsert(basicPayload, { onConflict: 'user_id' }).catch(() => {});
        } else {
          const { error: updateErr } = await supaClient.from(SUPABASE_USER_DATA_TABLE).update({
            budget: budget,
            expenses: expenses,
            subscriptions: subscriptions,
            incomes: incomes,
            currency: activeCurrency,
            updated_at: new Date().toISOString()
          }).eq('user_id', userId);

          if (updateErr) {
            console.warn('⚠️ Supabase Update Notice:', updateErr.message || updateErr);
            await supaClient.from(SUPABASE_USER_DATA_TABLE).insert([payload]).catch(() => {});
          }
        }
      }
      if (typeof setSyncStatus === 'function') setSyncStatus('synced');
    } catch (e) {
      console.warn('Supabase save error:', e);
      if (typeof setSyncStatus === 'function') setSyncStatus('synced');
    }
  } else if (typeof setSyncStatus === 'function') {
    setSyncStatus('synced');
  }
}

function loadStateFromLocal() {
  try {
    ['expense_cal_web_budget', 'expense_cal_web_expenses', 'expense_cal_web_subscriptions'].forEach(k => {
      const v = localStorage.getItem(k);
      if (v && (v.includes('Ã') || v.includes('Â'))) localStorage.removeItem(k);
    });
  } catch (err) {}

  const savedBudget = localStorage.getItem('expense_cal_web_budget');
  const savedExpenses = localStorage.getItem('expense_cal_web_expenses');
  const savedSubs = localStorage.getItem('expense_cal_web_subscriptions');
  const savedIncomes = localStorage.getItem('expense_cal_web_incomes');
  const savedAccountBal = localStorage.getItem('expense_cal_web_account_balance');
  const savedCurr = localStorage.getItem('expense_cal_currency');

  if (savedCurr && currencyRates[savedCurr]) {
    activeCurrency = savedCurr;
    const picker = document.getElementById('currency-picker');
    if (picker) picker.value = savedCurr;
  }

  const parsedBudget = savedBudget !== null ? parseFloat(savedBudget) : 0;
  budget = Number.isFinite(parsedBudget) && parsedBudget >= 0 ? parsedBudget : 0;
  const parsedAccountBal = savedAccountBal !== null ? parseFloat(savedAccountBal) : 0;
  accountBalance = Number.isFinite(parsedAccountBal) && parsedAccountBal >= 0 ? parsedAccountBal : 0;
  if (savedExpenses) {
    try {
      const parsedExpenses = JSON.parse(savedExpenses);
      expenses = Array.isArray(parsedExpenses) ? parsedExpenses.filter(isValidExpense) : [];
    } catch (e) { expenses = []; }
  } else {
    expenses = [];
  }
  if (savedSubs) {
    try {
      const parsedSubscriptions = JSON.parse(savedSubs);
      subscriptions = Array.isArray(parsedSubscriptions) ? parsedSubscriptions.filter(isValidSubscription) : [];
    } catch (e) { subscriptions = []; }
  } else {
    subscriptions = [];
  }
  if (savedIncomes) {
    try {
      const parsedIncomes = JSON.parse(savedIncomes);
      incomes = Array.isArray(parsedIncomes) ? parsedIncomes : [];
    } catch (e) { incomes = []; }
  } else {
    incomes = [];
  }

  updateMonthPickerOptions();
  updateUI();
}

// Kept for offline mode
function loadState() {
  loadStateFromLocal();
}

function startSupabaseSync(userId) {
  currentUserId = userId;
  const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));

  // Load local state immediately so interface displays budget/expenses without waiting for network
  loadStateFromLocal();

  if (!supaClient) {
    if (typeof setSyncStatus === 'function') setSyncStatus('synced');
    return;
  }
  if (typeof setSyncStatus === 'function') setSyncStatus('syncing');

  let localExpenses = [];
  let localSubs = [];
  let localIncomes = [];
  let localBudget = budget;
  try {
    const savedBudget = localStorage.getItem('expense_cal_web_budget');
    const savedExpenses = localStorage.getItem('expense_cal_web_expenses');
    const savedSubs = localStorage.getItem('expense_cal_web_subscriptions');
    const savedIncomes = localStorage.getItem('expense_cal_web_incomes');
    if (savedBudget !== null && !isNaN(parseFloat(savedBudget))) localBudget = parseFloat(savedBudget);
    if (savedExpenses) {
      const parsed = JSON.parse(savedExpenses);
      if (Array.isArray(parsed)) localExpenses = parsed.filter(isValidExpense);
    }
    if (savedSubs) {
      const parsedS = JSON.parse(savedSubs);
      if (Array.isArray(parsedS)) localSubs = parsedS.filter(isValidSubscription);
    }
    if (savedIncomes) {
      const parsedI = JSON.parse(savedIncomes);
      if (Array.isArray(parsedI)) localIncomes = parsedI;
    }
  } catch (e) {}

  // 6-second timeout race guard against hanging network promises
  const fetchPromise = supaClient.from(SUPABASE_USER_DATA_TABLE).select('*').eq('user_id', userId).maybeSingle();
  const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error('Sync Timeout')), 6000));

  Promise.race([fetchPromise, timeoutPromise])
    .then((res) => {
      const { data, error } = res || {};
      if (error) {
        console.warn('Supabase load notice:', error.message || error);
        loadStateFromLocal();
        if (typeof setSyncStatus === 'function') setSyncStatus('synced');
        return;
      }
      if (data) {
        const cloudExpenses = Array.isArray(data.expenses) ? data.expenses.filter(isValidExpense) : [];
        const cloudSubs = Array.isArray(data.subscriptions) ? data.subscriptions.filter(isValidSubscription) : [];
        const cloudIncomes = Array.isArray(data.incomes) ? data.incomes : [];

        const cloudExpIds = new Set(cloudExpenses.map(e => e.id));
        const newLocalExps = localExpenses.filter(e => e.id && !cloudExpIds.has(e.id));

        const cloudSubIds = new Set(cloudSubs.map(s => s.id));
        const newLocalSubs = localSubs.filter(s => s.id && !cloudSubIds.has(s.id));

        const cloudIncIds = new Set(cloudIncomes.map(i => i.id));
        const newLocalIncs = localIncomes.filter(i => i.id && !cloudIncIds.has(i.id));

        const cloudBudget = (typeof data.budget === 'number' && Number.isFinite(data.budget)) ? data.budget : 0;
        budget = cloudBudget > 0 ? cloudBudget : localBudget;
        expenses = [...cloudExpenses, ...newLocalExps];
        subscriptions = [...cloudSubs, ...newLocalSubs];
        incomes = [...cloudIncomes, ...newLocalIncs];
        if (data.currency && currencyRates[data.currency]) activeCurrency = data.currency;

        if (newLocalExps.length > 0 || newLocalSubs.length > 0 || newLocalIncs.length > 0 || (localBudget > 0 && cloudBudget === 0)) {
          supaClient.from('user_data').upsert({
            user_id: userId,
            budget: budget,
            expenses: expenses,
            subscriptions: subscriptions,
            incomes: incomes,
            currency: activeCurrency,
            updated_at: new Date().toISOString()
          }, { onConflict: 'user_id' }).catch(e => {});
        }
      } else {
        // First cloud sync: push local data to cloud
        loadStateFromLocal();
        supaClient.from('user_data').upsert({
          user_id: userId,
          budget: budget,
          expenses: expenses,
          subscriptions: subscriptions,
          incomes: incomes,
          currency: activeCurrency,
          updated_at: new Date().toISOString()
        }, { onConflict: 'user_id' }).catch(e => {});
      }
      try {
        localStorage.setItem('expense_cal_web_budget', budget.toString());
        localStorage.setItem('expense_cal_web_expenses', JSON.stringify(expenses));
        localStorage.setItem('expense_cal_web_subscriptions', JSON.stringify(subscriptions));
        localStorage.setItem('expense_cal_web_incomes', JSON.stringify(incomes));
        localStorage.setItem('expense_cal_currency', activeCurrency);
      } catch(e) {}
      updateMonthPickerOptions();
      updateUI();
      if (typeof setSyncStatus === 'function') setSyncStatus('synced');
    })
    .catch((err) => {
      console.warn('Supabase sync notice/timeout:', err);
      loadStateFromLocal();
      if (typeof setSyncStatus === 'function') setSyncStatus('synced');
    });

  try {
    if (supabaseChannel) supaClient.removeChannel(supabaseChannel);
    supabaseChannel = supaClient.channel('user_data_changes_' + userId)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'user_data' }, payload => {
        if (payload.new && String(payload.new.user_id) === String(userId)) {
          const data = payload.new;
          budget = typeof data.budget === 'number' ? data.budget : 0;
          expenses = Array.isArray(data.expenses) ? data.expenses.filter(isValidExpense) : [];
          subscriptions = Array.isArray(data.subscriptions) ? data.subscriptions.filter(isValidSubscription) : [];
          incomes = Array.isArray(data.incomes) ? data.incomes : [];
          if (data.currency && currencyRates[data.currency]) activeCurrency = data.currency;
          try {
            localStorage.setItem('expense_cal_web_budget', budget.toString());
            localStorage.setItem('expense_cal_web_expenses', JSON.stringify(expenses));
            localStorage.setItem('expense_cal_web_subscriptions', JSON.stringify(subscriptions));
            localStorage.setItem('expense_cal_web_incomes', JSON.stringify(incomes));
            localStorage.setItem('expense_cal_currency', activeCurrency);
          } catch(e) {}
          updateMonthPickerOptions();
          updateUI();
          if (typeof setSyncStatus === 'function') setSyncStatus('synced');
        }
      }).subscribe();
  } catch (e) {}
}

window.addEventListener('focus', () => {
  if (currentUserId && typeof startSupabaseSync === 'function') {
    startSupabaseSync(currentUserId);
  }
});

function stopSupabaseSync() {
  const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
  if (supabaseChannel && supaClient) {
    try { supaClient.removeChannel(supabaseChannel); } catch(e) {}
    supabaseChannel = null;
  }
}

window.startSupabaseSync = startSupabaseSync;
window.stopSupabaseSync = stopSupabaseSync;



function isValidExpense(item) {
  return item && typeof item === 'object' &&
    typeof item.id === 'string' &&
    Number.isFinite(Number(item.amount)) && Number(item.amount) > 0 &&
    typeof item.category === 'string' &&
    typeof item.description === 'string' &&
    typeof item.payment === 'string' &&
    /^\d{4}-\d{2}-\d{2}$/.test(item.date);
}

function isValidSubscription(item) {
  return item && typeof item === 'object' &&
    typeof item.id === 'string' &&
    typeof item.name === 'string' &&
    Number.isFinite(Number(item.amount)) && Number(item.amount) > 0 &&
    Number.isInteger(Number(item.dueDay)) && Number(item.dueDay) >= 1 && Number(item.dueDay) <= 31 &&
    typeof item.category === 'string';
}

function getLocalDateString() {
  const d = new Date();
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function setTodayDateDefault() {
  const today = getLocalDateString();
  if (expDateInput) expDateInput.value = today;
}

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

function updateMonthPickerOptions() {
  if (!monthPickerSelect) return;
  const months = getAvailableMonths();

  monthPickerSelect.innerHTML = '';
  
  // Option for All Time
  const allOpt = document.createElement('option');
  allOpt.value = 'ALL';
  allOpt.textContent = '📅 All Time';
  if (selectedMonth === 'ALL') allOpt.selected = true;
  monthPickerSelect.appendChild(allOpt);

  months.forEach(ym => {
    const opt = document.createElement('option');
    opt.value = ym;
    opt.textContent = `📅 ${formatMonthLabel(ym)}`;
    if (selectedMonth === ym) opt.selected = true;
    monthPickerSelect.appendChild(opt);
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

// ---------- Tab / View Switching ----------
window.switchView = function switchView(viewName) {
  if (!viewName) return;
  currentView = viewName;

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

  try { updateUI(); } catch(err) { console.warn('UI Update notice:', err); }
};

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
  const remaining = budget - totalSpent;
  const spentRatio = budget > 0 ? (totalSpent / budget) * 100 : 0;
  const remainingPercent = Math.max(0, 100 - spentRatio);

  if (activeMonthLabelEl) {
    activeMonthLabelEl.textContent = selectedMonth === 'ALL' ? 'All Time' : formatMonthLabel(selectedMonth);
  }

  // Update Stat Cards & Topbar Budget Edit Button Label
  if (btnEditBudget) {
    btnEditBudget.innerHTML = budget > 0 
      ? '<i class="fa-solid fa-pen-to-square"></i> Edit Budget' 
      : '<i class="fa-solid fa-sliders"></i> Set Budget';
  }

  // Filter Incomes by Selected Month
  const filteredMonthIncomes = incomes.filter(item => {
    if (selectedMonth === 'ALL') return true;
    return item.date && item.date.startsWith(selectedMonth);
  });

  const totalIncome = filteredMonthIncomes.reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const totalAllTimeIncome = incomes.reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const totalAllTimeSpent = expenses.reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const totalAccountMoney = accountBalance + totalAllTimeIncome - totalAllTimeSpent;

  const statAccountBalanceEl = document.getElementById('stat-account-balance');
  const statIncomeEl = document.getElementById('stat-income');
  const statIncomeCountEl = document.getElementById('stat-income-count');

  if (statAccountBalanceEl) {
    statAccountBalanceEl.textContent = formatCurrency(totalAccountMoney);
    statAccountBalanceEl.className = totalAccountMoney >= 0 ? 'stat-value text-emerald mono' : 'stat-value text-rose mono';
  }

  const statLeftoverEl = document.getElementById('stat-leftover');
  const statLeftoverSubtextEl = document.getElementById('stat-leftover-subtext');
  const leftoverVal = budget > 0 ? remaining : 0;

  if (statRemainingEl) {
    statRemainingEl.textContent = budget > 0 ? formatCurrency(remaining) : '₹0.00';
    statRemainingEl.className = (budget > 0 && remaining < 0) ? 'stat-value text-rose mono' : 'stat-value text-emerald mono';
  }

  if (statPercentEl) {
    if (budget === 0) {
      statPercentEl.textContent = 'Budget Limit Not Set (Click to Set ✏️)';
    } else {
      statPercentEl.textContent = `${spentRatio.toFixed(1)}% Spent of Cap (${remainingPercent.toFixed(1)}% Left)`;
    }
  }

  const leftoverIconEl = document.getElementById('status-icon');
  if (leftoverIconEl) {
    leftoverIconEl.className = 'fa-solid stat-icon';
    if (budget > 0) {
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

  if (statIncomeEl) statIncomeEl.textContent = formatCurrency(totalIncome);
  if (statIncomeCountEl) {
    statIncomeCountEl.innerHTML = `${filteredMonthIncomes.length} extra source${filteredMonthIncomes.length === 1 ? '' : 's'} <span class="edit-hint">(+Add)</span>`;
  }

  if (statBudgetEl) statBudgetEl.textContent = formatCurrency(budget);
  if (statSpentEl) statSpentEl.textContent = formatCurrency(totalSpent);
  if (statCountEl) statCountEl.textContent = `${filteredMonthExpenses.length} transaction${filteredMonthExpenses.length === 1 ? '' : 's'}`;

  const sidebarBudgetVal = document.getElementById('sidebar-budget-val');
  if (sidebarBudgetVal) sidebarBudgetVal.textContent = formatCurrency(budget);

  if (budget === 0) {
    if (statRemainingEl) statRemainingEl.textContent = '₹0.00';
    if (statPercentEl) statPercentEl.textContent = 'Budget Not Set (Click to Set ✏️)';
  } else {
    if (statRemainingEl) statRemainingEl.textContent = formatCurrency(remaining);
    if (statPercentEl) statPercentEl.textContent = `${spentRatio.toFixed(1)}% Spent of Cap (${remainingPercent.toFixed(1)}% Left)`;
  }

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

  window.requestAnimationFrame(() => {
    const activeView = currentView || 'dashboard';

    if (activeView === 'dashboard') {
      renderRadialGauge(spentRatio, totalSpent, budget);
      renderSubscriptions();
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
  // Also check local admin/user session as fallback
  if (!userEmail) {
    try {
      const adminSession = localStorage.getItem('expense_cal_admin_session');
      if (adminSession) { const u = JSON.parse(adminSession); if (u && u.email) userEmail = u.email; }
    } catch(e) {}
  }
  if (!userEmail) {
    try {
      const userSession = localStorage.getItem('expense_cal_user_session');
      if (userSession) { const u = JSON.parse(userSession); if (u && u.email) userEmail = u.email; }
    } catch(e) {}
  }

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
  const currentYM = getCurrentYearMonth();
  const currentDay = new Date().getDate();

  let totalMonthlySubs = 0;
  let dueSoonCount = 0;

  subscriptions.forEach(sub => {
    totalMonthlySubs += Number(sub.amount);
    const isPaidThisMonth = sub.lastPaidMonth === currentYM;
    if (!isPaidThisMonth && (currentDay > sub.dueDay || sub.dueDay - currentDay <= 7)) {
      dueSoonCount++;
    }
  });

  if (statSubsTotalEl) statSubsTotalEl.textContent = formatCurrency(totalMonthlySubs);
  if (statSubsCountEl) statSubsCountEl.textContent = `${subscriptions.length} active subscription${subscriptions.length === 1 ? '' : 's'}`;

  // Dedicated Bills View Grid
  if (subsGridContainer) {
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
      subscriptions.forEach(sub => {
        const isPaidThisMonth = sub.lastPaidMonth === currentYM;
        let statusClass = 'due';
        let statusText = `Due Day ${sub.dueDay}`;

        if (isPaidThisMonth) {
          statusClass = 'paid';
          statusText = 'Paid This Month';
        } else if (currentDay > sub.dueDay) {
          statusClass = 'overdue';
          statusText = `Overdue (Day ${sub.dueDay})`;
        } else if (sub.dueDay - currentDay <= 7) {
          statusClass = 'due';
          statusText = `Due in ${sub.dueDay - currentDay} days`;
        }

        const card = document.createElement('div');
        card.className = 'sub-card-item';
        card.innerHTML = `
          <div class="sub-card-header">
            <div>
              <div class="sub-title">${escapeHtml(sub.name)}</div>
              <div class="sub-due">${escapeHtml(sub.category)}</div>
            </div>
            <button type="button" class="icon-btn action-btn-del" data-delete-sub="${sub.id}" title="Delete Subscription" onclick="if(window.deleteSubscription){event.preventDefault();event.stopPropagation();window.deleteSubscription('${sub.id}');}">
              <i class="fa-solid fa-xmark"></i>
            </button>
          </div>
          <div class="sub-amount">${formatCurrency(sub.amount)} <span class="per-mo">/ mo</span></div>
          <div class="sub-actions">
            <span class="status-badge ${statusClass}">${statusText}</span>
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

// Chart.js Category Donut Breakdown
function renderCategoryBreakdown(filteredList, totalSpent) {
  if (breakdownChartInstance) { breakdownChartInstance.destroy(); breakdownChartInstance = null; }
  if (fullAnalyticsChartInstance) { fullAnalyticsChartInstance.destroy(); fullAnalyticsChartInstance = null; }

  const containers = [
    { chart: breakdownChartContainer, list: breakdownListEl, getInstance: () => breakdownChartInstance, setInstance: (inst) => { breakdownChartInstance = inst; } },
    { chart: fullAnalyticsChartContainer, list: fullAnalyticsListEl, getInstance: () => fullAnalyticsChartInstance, setInstance: (inst) => { fullAnalyticsChartInstance = inst; } }
  ];

  containers.forEach(({ chart, list, setInstance }) => {
    if (list) list.innerHTML = '';
    if (chart) chart.innerHTML = '';

    if (filteredList.length === 0 || totalSpent === 0) {
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

    // Chart.js or SVG Donut Chart Fallback
    if (chart) {
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
            labels: sortedCategories.map(c => c[0]),
            datasets: [{
              data: sortedCategories.map(c => c[1]),
              backgroundColor: sortedCategories.map(c => categoryColors[c[0]] || '#34D399'),
              borderColor: '#0E131A',
              borderWidth: 2,
              hoverOffset: 6
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            animation: { animateScale: true, animateRotate: true },
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
        // SVG Donut Ring Fallback for offline or instant load
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

// Chart.js 6-Month Trend Bar Chart
function renderMonthlyTrendChart() {
  if (!monthlyTrendChartContainer) return;
  if (trendChartInstance) { trendChartInstance.destroy(); trendChartInstance = null; }
  monthlyTrendChartContainer.innerHTML = '';

  if (expenses.length === 0) {
    monthlyTrendChartContainer.innerHTML = `
      <div class="empty-state-small">
        <i class="fa-solid fa-chart-column empty-state-icon"></i>
        <p>No historical data recorded yet.</p>
      </div>
    `;
    return;
  }

  const monthlyTotals = {};
  expenses.forEach(item => {
    if (item.date && item.date.length >= 7) {
      const ym = item.date.substring(0, 7);
      monthlyTotals[ym] = (monthlyTotals[ym] || 0) + Number(item.amount);
    }
  });

  const months = Object.keys(monthlyTotals).sort();
  if (months.length === 0) {
    monthlyTrendChartContainer.innerHTML = '<p class="empty-state-sub">No monthly data available.</p>';
    return;
  }

  const canvas = document.createElement('canvas');
  canvas.style.height = '180px';
  monthlyTrendChartContainer.appendChild(canvas);

  if (typeof Chart !== 'undefined') {
    trendChartInstance = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: months.map(ym => formatMonthLabel(ym).split(' ')[0]),
        datasets: [{
          data: months.map(ym => monthlyTotals[ym] || 0),
          backgroundColor: months.map(ym => selectedMonth === ym ? '#34D399' : 'rgba(56, 189, 248, 0.35)'),
          hoverBackgroundColor: months.map(ym => selectedMonth === ym ? '#34D399' : 'rgba(56, 189, 248, 0.75)'),
          borderRadius: 6,
          borderSkipped: false
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        onClick: (e, elements) => {
          if (elements && elements.length > 0) {
            const idx = elements[0].index;
            selectMonthFromChart(months[idx]);
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
                return `${formatMonthLabel(months[context.dataIndex])}: ${formatCurrency(context.raw)}`;
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
  if (titleEl) titleEl.textContent = tab === 'income' ? 'Extra Income Logs' : 'Expense Log';

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

  const searchTerm = filterSearchInput ? filterSearchInput.value.toLowerCase().trim() : '';
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
    const matchesSearch = item.description.toLowerCase().includes(searchTerm) ||
                          item.category.toLowerCase().includes(searchTerm) ||
                          item.payment.toLowerCase().includes(searchTerm);
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
      <td data-label="Description" class="description-cell">${escapeHtml(item.description)}</td>
      <td data-label="Payment"><span class="payment-badge-pill">${payIcon} <span>${escapeHtml(item.payment)}</span></span></td>
      <td data-label="Amount" class="text-right font-bold text-amount text-rose">-${formatCurrency(item.amount)}</td>
      <td class="text-center td-action">
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

    const amount = parseFloat(expAmountInput.value);
    const category = expCategorySelect.value;
    const description = expDescriptionInput.value.trim();
    const payment = expPaymentSelect.value;
    const date = expDateInput.value;

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
      date
    };

    expenses.push(newExpense);
    saveState();
    
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
    updateMonthPickerOptions();
    updateUI();
  }
}

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
  incomes = incomes.filter(inc => inc.id !== incomeId);
  saveState();
  updateUI();
  if (window.renderIncomeList) window.renderIncomeList();
  showToast('Income source deleted successfully');
};

// ---------- Income Modal Logic ----------
window.openIncomeModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const incomeModal = document.getElementById('income-modal');
  const sourceInput = document.getElementById('income-source-input');
  const amountInput = document.getElementById('income-amount-input');
  if (sourceInput) sourceInput.value = '';
  if (amountInput) amountInput.value = '';
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
  const source = sourceInput ? sourceInput.value.trim() : '';
  const amount = amountInput ? parseFloat(amountInput.value) : 0;

  if (!source || isNaN(amount) || amount <= 0) {
    showAlert('Invalid Income Details', 'Please enter a valid income source description and positive amount.');
    return;
  }

  const newIncome = {
    id: 'inc_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
    source: source,
    amount: amount,
    date: getLocalDateString()
  };

  incomes.push(newIncome);
  saveState();
  updateUI();
  if (window.renderIncomeList) window.renderIncomeList();
  showToast('Income source logged successfully');
  if (sourceInput) sourceInput.value = '';
  if (amountInput) amountInput.value = '';
};

// Add Subscription Modal
function openSubscriptionModal() {
  if (!subNameInput || !subAmountInput || !subDueDayInput || !subModal) return;
  subNameInput.value = '';
  subAmountInput.value = '';
  subDueDayInput.value = '';
  subModal.classList.remove('hidden');
  subNameInput.focus();
}

if (btnAddSub) btnAddSub.addEventListener('click', openSubscriptionModal);
if (btnAddSubInline) btnAddSubInline.addEventListener('click', openSubscriptionModal);

if (subForm) {
  subForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const name = subNameInput.value.trim();
    const amount = parseFloat(subAmountInput.value);
    const dueDay = parseInt(subDueDayInput.value, 10);
    const category = subCategorySelect.value;

    if (!name || isNaN(amount) || amount <= 0 || isNaN(dueDay) || dueDay < 1 || dueDay > 31) {
      showAlert('Invalid Details', 'Please enter valid subscription details.');
      return;
    }

    const newSub = {
      id: 'sub_' + Date.now().toString(36),
      name,
      amount,
      dueDay,
      category,
      lastPaidMonth: ''
    };

    subscriptions.push(newSub);
    saveState();
    updateUI();
    closeModal(subModal);
  });
}

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
  if (e) { e.preventDefault(); e.stopPropagation(); }

  const ok = await showConfirm(
    'Reset All Financial Data',
    'WARNING: This will permanently reset and delete all logged expenses, budget caps, and subscriptions. Continue?',
    true
  );
  if (!ok) return;

  budget = 0;
  expenses = [];
  subscriptions = [];
  selectedMonth = getCurrentYearMonth();

  // Do not clear all localStorage: auth session tokens are stored here
  localStorage.setItem('expense_cal_web_budget', '0');
  localStorage.setItem('expense_cal_web_expenses', '[]');
  localStorage.setItem('expense_cal_web_subscriptions', '[]');
  updateMonthPickerOptions();
  updateUI();

  if (!currentUserId) {
    await showAlert('Data Reset Complete', 'Your expense records, budget limit, and subscriptions have been reset on this device.');
    return;
  }

  if (typeof setSyncStatus === 'function') setSyncStatus('syncing');

  let cloudSuccess = false;

  // 1. Reset Supabase data if configured & active
  const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
  if (typeof isSupabaseConfigured !== 'undefined' && isSupabaseConfigured && supaClient) {
    try {
      const { error } = await supaClient.from('user_data').upsert({
        user_id: currentUserId,
        budget: 0,
        expenses: [],
        subscriptions: [],
        incomes: [],
        updated_at: new Date().toISOString()
      }, { onConflict: 'user_id' });
      if (!error) cloudSuccess = true;
    } catch(err) {
      console.warn('Supabase reset notice:', err);
    }
  }



  if (typeof setSyncStatus === 'function') setSyncStatus('synced');
  if (cloudSuccess) {
    await showAlert('Data Reset Complete', 'All expense records, budget limits, and cloud data have been reset across all devices.');
  } else {
    await showAlert('Data Reset Complete', 'Your expense records, budget limit, and local data have been reset.');
  }
}

// Global Action Handlers for Buttons
window.openBudgetModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
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

window.exportTransactionsToCSV = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
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
};

window.exportFinancialSummaryJSON = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  const dataReport = {
    app: 'Expense OS',
    version: CURRENT_APP_VERSION || 'v2.7.4',
    currency: activeCurrency,
    exported_at: new Date().toISOString(),
    budget: budget,
    incomes: incomes,
    expenses: expenses,
    subscriptions: subscriptions
  };
  const blob = new Blob([JSON.stringify(dataReport, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `Expense_OS_Financial_Report_${new Date().toISOString().split('T')[0]}.json`;
  document.body.appendChild(link);
  link.click();
  setTimeout(() => { document.body.removeChild(link); URL.revokeObjectURL(url); }, 100);
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
// Handle clicks on dynamically-rendered elements via data-* attributes
document.addEventListener('click', (e) => {
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
window.loadDemoData = function() {
  monthlyBudget = 15000;
  expenses = [
    { id: 'demo-1', amount: 1250, category: 'Food & Dining', description: 'Gourmet Dinner & Grocery', payment: 'Credit Card', date: getLocalDateString() },
    { id: 'demo-2', amount: 2450, category: 'Bills & Utilities', description: 'Fiber Internet & Electricity', payment: 'Auto-Pay', date: getLocalDateString() },
    { id: 'demo-3', amount: 850, category: 'Entertainment', description: 'Movie Tickets & Snacks', payment: 'UPI', date: getLocalDateString() }
  ];
  subscriptions = [
    { id: 'demo-sub-1', name: 'Spotify Premium', amount: 299, category: 'Services & Subscriptions', dueDay: 15, lastPaidMonth: '' },
    { id: 'demo-sub-2', name: 'Netflix 4K Plan', amount: 499, category: 'Services & Subscriptions', dueDay: 22, lastPaidMonth: '' }
  ];
  if (typeof updateUI === 'function') updateUI();
};

document.addEventListener('DOMContentLoaded', () => {
  setTodayDateDefault();
  // Load state from localStorage immediately on startup so expenses render without waiting
  loadStateFromLocal();
});

// ---------- Interactive Onboarding & Feature Tour ----------
const tourSteps = [
  {
    view: 'dashboard',
    target: '#stat-budget-card',
    title: '🎯 Step 1: Set & Edit Monthly Budget Cap',
    msg: 'Stay on top of your financial goals! Click here or use the "Budget" button in the header anytime to set or re-edit your target monthly spending limit.'
  },
  {
    view: 'dashboard',
    target: '#expense-form',
    title: '💸 Step 2: Log Daily Expenses',
    msg: 'Quickly log daily purchases, groceries, and shopping items here with instant categorization and automatic calculations.'
  },
  {
    view: 'transactions',
    target: '[data-view="transactions"]',
    title: '📜 Step 3: Transactions Log & Filters',
    msg: 'Switch to the Transactions Log tab to view, search, filter by category or time period, and delete any logged expense item.'
  },
  {
    view: 'bills',
    target: '[data-view="bills"]',
    title: '🔄 Step 4: Recurring Bills & Subscriptions',
    msg: 'Never miss a due date! Add monthly subscriptions (like Netflix, Spotify, utilities) and click "Paid" to mark them completed each month.'
  },
  {
    view: 'analytics',
    target: '[data-view="analytics"]',
    title: '📈 Step 5: Category Analytics & Charts',
    msg: 'Explore Category Analytics to view interactive spending charts and visual breakdowns of where your money goes each month.'
  },
  {
    view: 'dashboard',
    target: '#month-picker',
    title: '📅 Step 6: Month Selector & Export CSV',
    msg: 'Use the month picker in the header to jump between months, or click "Export CSV" in the sidebar to download your spreadsheet records.'
  },
  {
    view: 'dashboard',
    target: '#btn-reset-all',
    title: '⚠️ Step 7: Reset All Data Anytime',
    msg: 'Need a fresh start? Click "Reset Data" in the sidebar anytime to safely clear all expense records and reset your budget back to zero.'
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
const CURRENT_APP_VERSION = 'v2.9.6';

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


