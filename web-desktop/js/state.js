// ---------- State Variables ----------
let budget = 0;
let expenses = [];
let subscriptions = [];
let accountBalance = 0;
let currentTxLogTab = 'expense';
let activeTimeFilter = 'ALL';
let currentView = (typeof localStorage !== 'undefined' && localStorage.getItem('expense_cal_current_view')) || (typeof window !== 'undefined' && window.location.hash.replace('#', '')) || 'dashboard';
window.currentView = currentView;
let selectedMonth = getCurrentYearMonth(); // YYYY-MM or 'ALL'
let savingsGoals = [];

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
  syncStatusEl.innerHTML = `<span class="sync-dot"></span><i class="fa-solid ${s.icon}"></i> <span class="sync-text">${s.text}</span>`;
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
  'savings-goals': { title: 'Savings Goals & Target Trackers', subtitle: 'Define financial targets, track deposit progress & reach your milestones' },
  leaderboard: { title: 'Leaderboard & Emeralds 💎', subtitle: 'Earn Emeralds, unlock stickers, and level up through 15 stages of wealth building' },
  smarthub: undefined,
  reports: { title: 'Reports & Financial Exports', subtitle: 'Generate PDF statements and CSV data exports' }
};


// --- Privacy Mode & Per-Card Eye Toggle State ---
let privacyMode = false;
try {
  privacyMode = localStorage.getItem('expense_cal_privacy_mode') === 'true';
} catch(e) {}

let singleCardPrivacyMap = {};
try {
  const saved = localStorage.getItem('expense_cal_card_privacy');
  if (saved) singleCardPrivacyMap = JSON.parse(saved);
} catch(e) {}

function isCardMasked(cardId) {
  return privacyMode || !!singleCardPrivacyMap[cardId];
}

function formatCurrency(val, cardId) {
  if (privacyMode || (cardId && singleCardPrivacyMap[cardId])) return '••••••';
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

// Global Privacy Toggle Button in Topbar (Instant ON/OFF)
window.togglePrivacyMode = function(e) {
  if (e && e.preventDefault) e.preventDefault();
  privacyMode = !privacyMode;
  try { localStorage.setItem('expense_cal_privacy_mode', String(privacyMode)); } catch(err){}
  syncPrivacyBtnUI();
  syncAllCardEyeIcons();
  updateUI();
};

// Single Card Privacy Toggle Button (Instant ON/OFF on specific amount box)
window.toggleSingleCardPrivacy = function(cardId, btnElement, e) {
  if (e && e.stopPropagation) e.stopPropagation();
  if (e && e.preventDefault) e.preventDefault();

  singleCardPrivacyMap[cardId] = !singleCardPrivacyMap[cardId];
  try { localStorage.setItem('expense_cal_card_privacy', JSON.stringify(singleCardPrivacyMap)); } catch(err){}

  syncCardEyeIcon(cardId, btnElement);
  updateUI();
};

function syncCardEyeIcon(cardId, btnElement) {
  if (!btnElement && cardId) {
    btnElement = document.querySelector(`[data-privacy-card="${cardId}"]`);
  }
  if (!btnElement) return;
  const isHidden = isCardMasked(cardId);
  const icon = btnElement.querySelector('i');
  if (icon) {
    icon.className = isHidden ? 'fa-solid fa-eye-slash text-amber' : 'fa-solid fa-eye';
  }
  btnElement.title = isHidden ? "Click to show amount" : "Click to hide amount (Privacy)";
}

function syncAllCardEyeIcons() {
  document.querySelectorAll('[data-privacy-card]').forEach(btn => {
    const cardId = btn.getAttribute('data-privacy-card');
    if (cardId) syncCardEyeIcon(cardId, btn);
  });
}

function syncPrivacyBtnUI() {
  const btn = document.getElementById('btn-toggle-privacy');
  const icon = document.getElementById('privacy-icon');
  if (btn) {
    if (privacyMode) {
      btn.classList.add('active');
      btn.title = "Global Privacy Mode Active (All Amounts Masked). Click to show numbers.";
    } else {
      btn.classList.remove('active');
      btn.title = "Toggle Global Privacy Mode (Mask All Amounts)";
    }
  }
  if (icon) {
    icon.className = privacyMode ? 'fa-solid fa-eye-slash' : 'fa-solid fa-eye';
  }
}

// --- AI Auto-Categorization Rule Engine ---
const categoryKeywordsMap = {
  'Food & Dining': ['swiggy', 'zomato', 'food', 'pizza', 'burger', 'restaurant', 'cafe', 'starbucks', 'dining', 'mcdonalds', 'kfc', 'dominos', 'lunch', 'dinner', 'breakfast', 'tea', 'coffee', 'bakery', 'snack'],
  'Transportation': ['uber', 'ola', 'rapido', 'cab', 'taxi', 'flight', 'train', 'metro', 'petrol', 'diesel', 'fuel', 'bus', 'auto', 'parking', 'toll', 'irctc'],
  'Shopping': ['amazon', 'flipkart', 'myntra', 'zara', 'ajio', 'shopping', 'clothes', 'shoes', 'electronics', 'meesho', 'nykaa', 'mall', 'fashion'],
  'Bills & Utilities': ['rent', 'electricity', 'water', 'internet', 'wifi', 'recharge', 'mobile', 'bill', 'utility', 'broadband', 'gas', 'lpg', 'dth'],
  'Entertainment': ['netflix', 'spotify', 'prime', 'movie', 'cinema', 'bookmyshow', 'hotstar', 'youtube', 'gaming', 'steam', 'playstation', 'concert'],
  'Health & Fitness': ['doctor', 'pharmacy', 'hospital', 'medicine', 'gym', 'health', 'cult.fit', 'fitness', 'lab', 'medical', 'clinic', 'pharmeasy'],
  'Services & Subscriptions': ['icloud', 'google one', 'chatgpt', 'github', 'saas', 'subscription', 'domain', 'hosting']
};

window.autoCategorizeExpense = function(description) {
  if (!description || description.trim().length < 2) return null;
  const descLower = description.toLowerCase();
  for (const [category, keywords] of Object.entries(categoryKeywordsMap)) {
    if (keywords.some(kw => descLower.includes(kw))) {
      return category;
    }
  }
  return null;
};

// --- Financial Health Score Calculation & UI Sync ---
function updateFinancialHealthScore(income, spent, budgetCap) {
  const scoreValEl = document.getElementById('health-score-val');
  const badgeEl = document.getElementById('health-score-badge');
  const adviceEl = document.getElementById('health-score-advice');
  const gaugeCircle = document.getElementById('health-gauge-circle');

  if (!scoreValEl) return;

  const totalSaved = typeof savingsGoals !== 'undefined' && Array.isArray(savingsGoals) 
    ? savingsGoals.reduce((sum, g) => sum + Number(g.savedAmount || 0), 0) 
    : 0;
  const totalTarget = typeof savingsGoals !== 'undefined' && Array.isArray(savingsGoals) 
    ? savingsGoals.reduce((sum, g) => sum + Number(g.targetAmount || 0), 0) 
    : 0;

  // 1. Savings Ratio (40% weight)
  let savingsScore = 0;
  const totalAvailableIncome = income > 0 ? income : (typeof accountBalance !== 'undefined' ? accountBalance : 0);
  if (totalAvailableIncome > 0) {
    const netSavings = Math.max(0, totalAvailableIncome - spent) + totalSaved;
    const savingsRatio = netSavings / totalAvailableIncome;
    savingsScore = Math.min(40, Math.round((savingsRatio / 0.3) * 40));
  } else {
    savingsScore = spent > 0 ? (spent <= budgetCap ? 25 : 10) : 40;
  }

  // 2. Monthly Budget Utilization (40% weight)
  let budgetScore = 40;
  if (budgetCap > 0) {
    const utilRatio = spent / budgetCap;
    if (utilRatio <= 0.8) {
      budgetScore = 40;
    } else if (utilRatio <= 1.0) {
      budgetScore = Math.round(40 * (1 - (utilRatio - 0.8) / 0.2));
    } else {
      budgetScore = 0;
    }
  }

  // 3. Goal Progress (20% weight)
  let goalScore = 20;
  if (totalTarget > 0) {
    const goalRatio = totalSaved / totalTarget;
    goalScore = Math.min(20, Math.round((goalRatio / 0.5) * 20));
  }

  const finalScore = Math.min(100, Math.max(0, savingsScore + budgetScore + goalScore));

  let label = 'Needs Attention';
  let badgeClass = 'health-badge-rose';
  let colorClass = 'health-score-rose';
  let advice = 'Track spending carefully & set budget caps.';

  if (finalScore >= 80) {
    label = 'Excellent';
    badgeClass = 'health-badge-emerald';
    colorClass = 'health-score-emerald';
    advice = 'Healthy savings ratio & strong budget buffer!';
  } else if (finalScore >= 60) {
    label = 'Good';
    badgeClass = 'health-badge-emerald';
    colorClass = 'health-score-emerald';
    advice = 'Solid standing. Keep building your goal savings.';
  } else if (finalScore >= 40) {
    label = 'Fair';
    badgeClass = 'health-badge-amber';
    colorClass = 'health-score-amber';
    advice = 'Budget limit getting tight. Monitor non-essentials.';
  } else {
    label = 'Warning';
    badgeClass = 'health-badge-rose';
    colorClass = 'health-score-rose';
    advice = 'High spending ratio relative to budget cap.';
  }

  scoreValEl.textContent = isCardMasked('stat-health') ? '••' : finalScore;
  if (badgeEl) {
    badgeEl.textContent = label;
    badgeEl.className = `health-badge font-bold ${badgeClass}`;
  }
  if (adviceEl) {
    adviceEl.textContent = advice;
  }
  if (gaugeCircle) {
    gaugeCircle.setAttribute('stroke-dasharray', `${finalScore}, 100`);
    gaugeCircle.className.baseVal = `gauge-fill ${colorClass}`;
  }

  const statHealthScoreEl = document.getElementById('stat-health-score');
  const statHealthSubtextEl = document.getElementById('stat-health-subtext');
  const statHealthIconEl = document.getElementById('health-icon');

  if (statHealthScoreEl) {
    statHealthScoreEl.textContent = privacyMode ? '••••••' : `${finalScore} / 100`;
    statHealthScoreEl.className = finalScore >= 70 ? 'stat-value text-emerald mono' : (finalScore >= 50 ? 'stat-value text-amber mono' : 'stat-value text-rose mono');
  }
  if (statHealthSubtextEl) {
    statHealthSubtextEl.textContent = advice;
  }
  if (statHealthIconEl) {
    statHealthIconEl.className = finalScore >= 70 ? 'fa-solid fa-heart-pulse text-emerald' : (finalScore >= 50 ? 'fa-solid fa-heart-pulse text-amber' : 'fa-solid fa-triangle-exclamation text-rose');
  }
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

// ---------- State Persistence (Supabase + Multi-Table Sync + localStorage Fallback) ----------
let currentUserId = null;
let supabaseChannel = null;
let _isSyncingRelational = false;

// Universal Profile Sync Helper
window.syncProfileToSupabase = async function(profileData) {
  const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
  if (!supaClient || !isSupabaseConfigured) return;
  const uid = currentUserId || (supaClient.auth && (await supaClient.auth.getSession().catch(()=>({})))?.data?.session?.user?.id);
  if (!uid) return;

  try {
    const prof = profileData || JSON.parse(localStorage.getItem('expense_cal_user_profile') || '{}');
    const payload = {
      user_id: uid,
      display_name: prof.name || prof.displayName || '',
      full_name: prof.name || prof.fullName || '',
      email: prof.email || '',
      phone: prof.phone || '',
      job: prof.job || '',
      country: prof.country || 'United States',
      currency: prof.currency || activeCurrency || 'INR',
      bio: prof.bio || '',
      avatar_url: prof.avatar || '',
      updated_at: new Date().toISOString()
    };
    await supaClient.from('profiles').upsert(payload, { onConflict: 'user_id' }).catch(() => {});
  } catch(e) {
    console.warn('Profile Supabase sync notice:', e);
  }
};

// Sync Individual Relational Tables (expenses, subscriptions, budgets, categories, split_bills, profiles)
async function syncAllSupabaseTables(userId) {
  if (_isSyncingRelational) return;
  _isSyncingRelational = true;

  const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
  if (!supaClient || !userId) {
    _isSyncingRelational = false;
    return;
  }

  try {
    // 1. Sync Expenses Table
    if (Array.isArray(expenses) && expenses.length > 0) {
      const expRows = expenses.filter(isValidExpense).map(e => ({
        id: String(e.id),
        user_id: userId,
        amount: Number(e.amount || 0),
        category: e.category || 'Miscellaneous',
        description: e.description || e.title || '',
        payment: e.payment || e.payment_method || 'Cash',
        date: e.date || getLocalDateString(),
        tags: Array.isArray(e.tags) ? JSON.stringify(e.tags) : '[]',
        receipt_url: e.receipt_url || e.receiptUrl || '',
        updated_at: new Date().toISOString()
      }));
      if (expRows.length > 0) {
        await supaClient.from('expenses').upsert(expRows, { onConflict: 'id' }).catch(() => {});
      }
    }

    // 2. Sync Subscriptions Table
    if (Array.isArray(subscriptions) && subscriptions.length > 0) {
      const subRows = subscriptions.filter(isValidSubscription).map(s => ({
        id: String(s.id),
        user_id: userId,
        name: s.name || s.title || 'Subscription',
        amount: Number(s.amount || 0),
        category: s.category || 'Services & Subscriptions',
        date: s.dueDate || s.due_date || s.date || '',
        billing_cycle: s.cycle || 'Monthly',
        next_due: s.dueDate || s.due_date || '',
        is_active: s.is_active !== false,
        updated_at: new Date().toISOString()
      }));
      if (subRows.length > 0) {
        await supaClient.from('subscriptions').upsert(subRows, { onConflict: 'id' }).catch(() => {});
      }
    }

    // 3. Sync Budgets Table
    const budgetId = 'budget_' + userId + '_' + (selectedMonth || 'ALL');
    await supaClient.from('budgets').upsert({
      id: budgetId,
      user_id: userId,
      category: 'ALL',
      amount: Number(budget || 0),
      month: selectedMonth || 'ALL',
      updated_at: new Date().toISOString()
    }, { onConflict: 'id' }).catch(() => {});

    // 4. Sync Categories Table
    const categoryRows = Object.keys(categoryColors || {}).map(catName => ({
      id: 'cat_' + catName.toLowerCase().replace(/[^a-z0-9]/g, '_'),
      user_id: userId,
      name: catName,
      color: categoryColors[catName] || '#34D399',
      icon: 'fa-tag',
      updated_at: new Date().toISOString()
    }));
    if (categoryRows.length > 0) {
      await supaClient.from('categories').upsert(categoryRows, { onConflict: 'id' }).catch(() => {});
    }

    // 5. Sync Split Bills Table
    let splitBills = [];
    try {
      const savedGroup = localStorage.getItem('saved_group_expenses') || localStorage.getItem('expense_cal_web_split_bills');
      if (savedGroup) splitBills = JSON.parse(savedGroup);
    } catch(e) {}
    if (!splitBills.length && Array.isArray(subscriptions)) {
      splitBills = subscriptions.filter(s => s && s.type === 'split_bill');
    }
    if (Array.isArray(splitBills) && splitBills.length > 0) {
      const billRows = splitBills.map(b => ({
        id: String(b.id || ('bill_' + Date.now())),
        user_id: userId,
        title: b.title || b.name || 'Split Bill',
        total_amount: Number(b.totalAmount || b.amount || 0),
        date: b.date || getLocalDateString(),
        category: b.category || 'Food & Dining',
        payer: b.payer || 'You',
        updated_at: new Date().toISOString()
      }));
      await supaClient.from('split_bills').upsert(billRows, { onConflict: 'id' }).catch(() => {});
    }

    // 6. Sync Profiles Table
    let storedProfile = {};
    try { storedProfile = JSON.parse(localStorage.getItem('expense_cal_user_profile') || '{}'); } catch(e) {}
    if (storedProfile && (storedProfile.name || storedProfile.email)) {
      await window.syncProfileToSupabase(storedProfile);
    }
  } catch (err) {
    console.warn('Relational sync notice:', err);
  } finally {
    _isSyncingRelational = false;
  }
}

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

  // Auto-detect current user ID with shared fallback across Web, Desktop, and Mobile
  const SHARED_USER_ID = 'b9290592-fbb4-4c33-b0bb-f35e2d8226d4';
  let userId = currentUserId;
  if (!userId && supaClient && supaClient.auth) {
    try {
      const { data } = await supaClient.auth.getSession();
      if (data && data.session && data.session.user) {
        userId = data.session.user.id;
        currentUserId = userId;
      }
    } catch(e) {}
  }
  if (!userId) {
    userId = SHARED_USER_ID;
    currentUserId = userId;
  }

  if (userId) {
    try {
      if (typeof setSyncStatus === 'function') setSyncStatus('syncing');

      const rawGoals = localStorage.getItem('expense_cal_web_savings_goals') || localStorage.getItem('expense_cal_savings_goals');
      let currentGoals = savingsGoals;
      if (!Array.isArray(currentGoals) && rawGoals) {
        try { currentGoals = JSON.parse(rawGoals) || []; } catch(e){}
      }

      const rawGroup = localStorage.getItem('saved_group_expenses');
      let currentGroup = [];
      if (rawGroup) {
        try { currentGroup = JSON.parse(rawGroup) || []; } catch(e){}
      }

      const bundledSubs = [
        ...subscriptions.filter(isValidSubscription).map(s => ({ ...s, type: 'subscription' })),
        ...(Array.isArray(currentGoals) ? currentGoals : []).map(g => ({
          id: g.id || ('goal_' + Date.now()),
          type: 'savings_goal',
          title: g.title || g.name || 'Goal',
          name: g.title || g.name || 'Goal',
          targetAmount: Number(g.targetAmount || g.target || 0),
          savedAmount: Number(g.savedAmount ?? g.currentAmount ?? 0),
          currentAmount: Number(g.savedAmount ?? g.currentAmount ?? 0),
          contributionType: g.contributionType || 'Monthly',
          deadline: g.deadline || g.targetDate || g.date || '',
          targetDate: g.targetDate || g.deadline || g.date || '',
          icon: g.icon || '🎯',
          notes: g.notes || '',
          createdAt: g.createdAt || new Date().toISOString()
        })),
        ...(Array.isArray(currentGroup) ? currentGroup : []).map(b => ({
          ...b,
          type: 'split_bill'
        })),
        {
          id: 'system_financial_meta',
          type: 'system_financial_meta',
          starting_balance: accountBalance,
          updated_at: new Date().toISOString()
        }
      ];

      const payload = {
        user_id: userId,
        budget: budget,
        expenses: expenses,
        subscriptions: bundledSubs,
        incomes: incomes,
        currency: activeCurrency,
        updated_at: new Date().toISOString()
      };

      // 1. Save Master Snapshot to user_data Table
      const { error } = await supaClient.from('user_data').upsert(payload, { onConflict: 'user_id' });
      if (error) {
        console.warn('⚠️ Supabase user_data Upsert Notice:', error.message || error);
        const { error: updateErr } = await supaClient.from('user_data').update(payload).eq('user_id', userId);
        if (updateErr) {
          await supaClient.from('user_data').insert([payload]).catch(() => {});
        }
      }

      // 2. Asynchronously Sync to All 9 Supabase Relational Tables
      syncAllSupabaseTables(userId);

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

  function detectUserLocalCurrency() {
    try {
      const tz = (Intl.DateTimeFormat().resolvedOptions().timeZone || '').toLowerCase();
      const lang = (navigator.language || '').toLowerCase();

      if (tz.includes('kolkata') || tz.includes('calcutta') || tz.includes('india') || lang.endsWith('-in') || lang.includes('hi')) {
        return 'INR';
      }
      if (tz.includes('london') || tz.includes('belfast') || lang.endsWith('-gb')) {
        return 'GBP';
      }
      if (tz.includes('paris') || tz.includes('berlin') || tz.includes('rome') || tz.includes('madrid') || tz.includes('amsterdam') || lang.includes('de') || lang.includes('fr') || lang.includes('it') || lang.includes('es')) {
        return 'EUR';
      }
      if (tz.includes('america') || tz.includes('new_york') || tz.includes('los_angeles') || lang.endsWith('-us')) {
        return 'USD';
      }
    } catch(e) {}
    return 'INR';
  }

  const savedCurr = localStorage.getItem('expense_cal_currency');
  if (savedCurr && currencyRates[savedCurr]) {
    activeCurrency = savedCurr;
  } else {
    activeCurrency = detectUserLocalCurrency();
  }
  const picker = document.getElementById('currency-picker');
  if (picker) picker.value = activeCurrency;

  selectedMonth = getCurrentYearMonth();

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

  const savedGoals = localStorage.getItem('expense_cal_web_savings_goals');
  if (savedGoals) {
    try {
      const parsedGoals = JSON.parse(savedGoals);
      savingsGoals = Array.isArray(parsedGoals) ? parsedGoals : [];
    } catch (e) { savingsGoals = []; }
  } else {
    savingsGoals = [];
  }

  if (typeof window.syncProfileUI === 'function') {
    window.syncProfileUI();
  }

  updateMonthPickerOptions();
  updateUI();
}

// Kept for offline mode
function loadState() {
  loadStateFromLocal();
}

function startSupabaseSync(userId) {
  const SHARED_USER_ID = 'b9290592-fbb4-4c33-b0bb-f35e2d8226d4';
  currentUserId = userId || SHARED_USER_ID;
  userId = currentUserId;
  const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));

  // Load local state immediately so interface displays budget/expenses without waiting for network
  loadStateFromLocal();

  if (!supaClient) {
    if (typeof setSyncStatus === 'function') setSyncStatus('synced');
    return;
  }
  if (typeof setSyncStatus === 'function') setSyncStatus('syncing');

  function applyCloudData(data) {
    if (!data) return;

    if (typeof data.budget === 'number' && Number.isFinite(data.budget)) {
      budget = data.budget;
    }
    const now = new Date();
    const currentYM = now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0');

    if (Array.isArray(data.subscriptions)) {
      subscriptions = data.subscriptions.filter(isValidSubscription).map(s => {
        const isPaidFlag = Boolean(s.is_paid || s.isPaid || s.lastPaidMonth === currentYM);
        return {
          id: String(s.id),
          name: s.name || s.title || 'Subscription',
          title: s.title || s.name || 'Subscription',
          amount: Number(s.amount || 0),
          category: s.category || 'Services & Subscriptions',
          cycle: s.cycle || s.billing_cycle || 'monthly',
          dueDay: s.dueDay || (s.due_date ? new Date(s.due_date).getDate() : 15) || 15,
          due_date: s.due_date || s.dueDate || '',
          dueDate: s.dueDate || s.due_date || '',
          is_paid: isPaidFlag,
          isPaid: isPaidFlag,
          lastPaidMonth: isPaidFlag ? (s.lastPaidMonth || currentYM) : null,
          last_paid_date: s.last_paid_date || s.lastPaidDate || '',
          lastPaidDate: s.lastPaidDate || s.last_paid_date || '',
          remindOnDueDate: s.remind_on_due_date ?? s.remindOnDueDate ?? true
        };
      });
    }

    if (Array.isArray(data.expenses)) {
      expenses = data.expenses.filter(isValidExpense);
    }
    
    // Auto-clean orphaned bill payments if parent bill was deleted
    const validSubNames = subscriptions.map(s => (s.name || s.title || '').trim().toLowerCase());
    expenses = expenses.filter(e => {
      const desc = (e.description || e.title || '').trim().toLowerCase();
      if (desc.startsWith('bill payment: ')) {
        const bName = desc.substring(14).trim();
        if (!validSubNames.includes(bName)) {
          return false; // Parent bill was deleted!
        }
      }
      return true;
    });

    if (Array.isArray(data.incomes)) {
      incomes = data.incomes.filter(i => i && i.id !== "initial_account_balance" && !i.is_system_balance);
    }
    if (data.currency && currencyRates[data.currency]) activeCurrency = data.currency;

    if (Array.isArray(data.subscriptions)) {
      const goalsFromCloud = data.subscriptions.filter(s => s && s.type === 'savings_goal').map(g => ({
        id: g.id || ('goal_' + Date.now()),
        title: g.title || g.name || 'Goal',
        name: g.title || g.name || 'Goal',
        targetAmount: Number(g.targetAmount || g.target || 0),
        savedAmount: Number(g.savedAmount ?? g.currentAmount ?? 0),
        currentAmount: Number(g.savedAmount ?? g.currentAmount ?? 0),
        contributionType: g.contributionType || 'Monthly',
        targetDate: g.targetDate || g.deadline || g.date || '',
        deadline: g.deadline || g.targetDate || g.date || '',
        icon: g.icon || '🎯',
        notes: g.notes || '',
        createdAt: g.createdAt || new Date().toISOString()
      }));
      if (goalsFromCloud.length > 0) {
        savingsGoals = goalsFromCloud;
        try {
          localStorage.setItem('expense_cal_web_savings_goals', JSON.stringify(savingsGoals));
          localStorage.setItem('expense_cal_savings_goals', JSON.stringify(savingsGoals));
        } catch(e) {}
        if (typeof renderSavingsGoals === 'function') renderSavingsGoals();
      }

      const meta = data.subscriptions.find(s => s && s.type === 'system_financial_meta');
      if (meta && typeof meta.starting_balance === 'number' && Number.isFinite(meta.starting_balance)) {
        accountBalance = meta.starting_balance;
        try { localStorage.setItem('expense_cal_web_account_balance', accountBalance.toString()); } catch(e) {}
      }
    }

    try {
      localStorage.setItem('expense_cal_web_budget', budget.toString());
      localStorage.setItem('expense_cal_web_expenses', JSON.stringify(expenses));
      localStorage.setItem('expense_cal_web_subscriptions', JSON.stringify(subscriptions));
      localStorage.setItem('expense_cal_web_incomes', JSON.stringify(incomes));
      localStorage.setItem('expense_cal_web_account_balance', accountBalance.toString());
      localStorage.setItem('expense_cal_currency', activeCurrency);
    } catch(e) {}

    updateMonthPickerOptions();
    updateUI();
  }

  // 6-second timeout race guard against hanging network promises
  const fetchUserData = supaClient.from('user_data').select('*').eq('user_id', userId).maybeSingle();
  const fetchProfile = supaClient.from('profiles').select('*').eq('user_id', userId).maybeSingle();
  const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error('Sync Timeout')), 6000));

  Promise.race([Promise.all([fetchUserData, fetchProfile]), timeoutPromise])
    .then(([userDataRes, profileRes]) => {
      const { data, error } = userDataRes || {};
      const { data: profileData } = profileRes || {};

      if (profileData) {
        let stored = {};
        try { stored = JSON.parse(localStorage.getItem('expense_cal_user_profile') || '{}'); } catch(e) {}
        const mergedProfile = {
          ...stored,
          name: profileData.display_name || profileData.full_name || stored.name || '',
          email: profileData.email || stored.email || '',
          phone: profileData.phone || stored.phone || '',
          job: profileData.job || stored.job || '',
          country: profileData.country || stored.country || 'United States',
          currency: profileData.currency || stored.currency || activeCurrency || 'INR',
          bio: profileData.bio || stored.bio || '',
          avatar: profileData.avatar_url || stored.avatar || null,
          completed: true
        };
        try { localStorage.setItem('expense_cal_user_profile', JSON.stringify(mergedProfile)); } catch(e) {}
        if (typeof window.syncProfileUI === 'function') window.syncProfileUI();
      }

      if (error) {
        console.warn('Supabase load notice:', error.message || error);
        loadStateFromLocal();
        if (typeof setSyncStatus === 'function') setSyncStatus('synced');
        return;
      }
      if (data) {
        applyCloudData(data);
      } else {
        // Fallback: Check relational tables if user_data is empty
        Promise.all([
          supaClient.from('expenses').select('*').eq('user_id', userId),
          supaClient.from('subscriptions').select('*').eq('user_id', userId),
          supaClient.from('budgets').select('*').eq('user_id', userId)
        ]).then(([expRes, subRes, budRes]) => {
          if (expRes.data && expRes.data.length > 0) {
            expenses = expRes.data.filter(isValidExpense);
          }
          if (subRes.data && subRes.data.length > 0) {
            subscriptions = subRes.data.filter(isValidSubscription);
          }
          if (budRes.data && budRes.data.length > 0) {
            const b = budRes.data[0];
            if (b && typeof b.amount === 'number') budget = b.amount;
          }
          updateMonthPickerOptions();
          updateUI();
        }).catch(() => {});
      }
      if (typeof setSyncStatus === 'function') setSyncStatus('synced');
    })
    .catch((err) => {
      console.warn('Supabase sync notice/timeout:', err);
      loadStateFromLocal();
      if (typeof setSyncStatus === 'function') setSyncStatus('synced');
    });

  // Setup Multi-Table Realtime Listeners
  try {
    if (supabaseChannel) supaClient.removeChannel(supabaseChannel);
    supabaseChannel = supaClient.channel('universal_data_changes_' + userId)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'user_data' }, payload => {
        if (payload.new && String(payload.new.user_id) === String(userId)) {
          applyCloudData(payload.new);
          if (typeof setSyncStatus === 'function') setSyncStatus('synced');
        }
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'expenses' }, payload => {
        if (payload.new && String(payload.new.user_id) === String(userId)) {
          const item = payload.new;
          const idx = expenses.findIndex(e => String(e.id) === String(item.id));
          if (payload.eventType === 'DELETE') {
            expenses = expenses.filter(e => String(e.id) !== String(payload.old.id));
          } else if (isValidExpense(item)) {
            if (idx >= 0) expenses[idx] = item;
            else expenses.unshift(item);
          }
          try { localStorage.setItem('expense_cal_web_expenses', JSON.stringify(expenses)); } catch(e) {}
          updateUI();
        }
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, payload => {
        if (payload.new && String(payload.new.user_id) === String(userId)) {
          const p = payload.new;
          let stored = {};
          try { stored = JSON.parse(localStorage.getItem('expense_cal_user_profile') || '{}'); } catch(e) {}
          const merged = { ...stored, name: p.display_name || p.full_name || stored.name, avatar: p.avatar_url || stored.avatar, email: p.email || stored.email };
          try { localStorage.setItem('expense_cal_user_profile', JSON.stringify(merged)); } catch(e) {}
          if (typeof window.syncProfileUI === 'function') window.syncProfileUI();
        }
      })
      .subscribe();
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
  if (!item || typeof item !== 'object') return false;
  if (!item.description && item.title) item.description = item.title;
  if (!item.payment && item.payment_method) item.payment = item.payment_method;
  if (item.date && typeof item.date === 'string' && item.date.includes('T')) {
    item.date = item.date.split('T')[0];
  }
  return typeof item.id === 'string' &&
    Number.isFinite(Number(item.amount)) && Number(item.amount) > 0 &&
    typeof item.category === 'string' &&
    typeof item.description === 'string' &&
    typeof item.payment === 'string' &&
    /^\d{4}-\d{2}-\d{2}$/.test(item.date);
}

function isValidSubscription(item) {
  if (!item || typeof item !== 'object') return false;
  if (item.type === 'savings_goal' || item.type === 'split_bill' || item.type === 'system_financial_meta') return false;
  const name = item.name || item.title;
  return typeof item.id === 'string' &&
    typeof name === 'string' && name.trim().length > 0 &&
    Number.isFinite(Number(item.amount)) && Number(item.amount) > 0;
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

