/* ==========================================================================
   Expense OS - 3D Showcase & Interactive Script Engine
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {

  // ---------- 1. Canvas Starfield Background ----------
  const canvas = document.getElementById('bg-canvas');
  if (canvas) {
    const ctx = canvas.getContext('2d');
    let width = canvas.width = window.innerWidth;
    let height = canvas.height = window.innerHeight;

    window.addEventListener('resize', () => {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    });

    const particles = [];
    const particleCount = 60;

    for (let i = 0; i < particleCount; i++) {
      particles.push({
        x: Math.random() * width,
        y: Math.random() * height,
        radius: Math.random() * 1.5 + 0.5,
        alpha: Math.random() * 0.6 + 0.2,
        speedX: (Math.random() - 0.5) * 0.3,
        speedY: (Math.random() - 0.5) * 0.3
      });
    }

    function animateParticles() {
      ctx.clearRect(0, 0, width, height);

      particles.forEach(p => {
        p.x += p.speedX;
        p.y += p.speedY;

        if (p.x < 0) p.x = width;
        if (p.x > width) p.x = 0;
        if (p.y < 0) p.y = height;
        if (p.y > height) p.y = 0;

        ctx.beginPath();
        ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(52, 211, 153, ${p.alpha})`;
        ctx.shadowBlur = 10;
        ctx.shadowColor = '#10b981';
        ctx.fill();
      });

      requestAnimationFrame(animateParticles);
    }

    animateParticles();
  }

  // ---------- 2. Interactive 3D Perspective Tilt ----------
  const heroMockup = document.querySelector('.hero-mockup');
  const heroWrapper = document.querySelector('.hero-mockup-wrapper');

  if (heroWrapper && heroMockup) {
    heroWrapper.addEventListener('mousemove', (e) => {
      const rect = heroWrapper.getBoundingClientRect();
      const x = e.clientX - rect.left - rect.width / 2;
      const y = e.clientY - rect.top - rect.height / 2;

      const rotateX = (y / (rect.height / 2)) * -10;
      const rotateY = (x / (rect.width / 2)) * 10;

      heroMockup.style.transform = `rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(1.02, 1.02, 1.02)`;
    });

    heroWrapper.addEventListener('mouseleave', () => {
      heroMockup.style.transform = `rotateX(0deg) rotateY(0deg) scale3d(1, 1, 1)`;
    });
  }

  // ---------- 3. 3D Tilt for Feature Cards ----------
  const cards = document.querySelectorAll('.feature-card, .highlight-card');
  cards.forEach(card => {
    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left - rect.width / 2;
      const y = e.clientY - rect.top - rect.height / 2;

      const rotateX = (y / (rect.height / 2)) * -6;
      const rotateY = (x / (rect.width / 2)) * 6;

      card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) translateY(-4px)`;
    });

    card.addEventListener('mouseleave', () => {
      card.style.transform = `perspective(1000px) rotateX(0deg) rotateY(0deg) translateY(0px)`;
    });
  });

  // ---------- 4. Gallery Feature Views Renderer ----------
  const tabBtns = document.querySelectorAll('.tab-btn');
  const galleryTitle = document.getElementById('gallery-preview-title');
  const galleryDesc = document.getElementById('gallery-preview-desc');
  const galleryUrlTitle = document.getElementById('gallery-url-title');
  const previewPillsEl = document.getElementById('preview-pills');
  const galleryViewContainer = document.getElementById('gallery-view-container');

  const galleryData = {
    dashboard: {
      title: "Clean Monthly Overview",
      desc: "Instant breakdown of monthly income vs expenses, category spending progress, net savings trends, and bill trackers.",
      url: "https://expenseos.app/dashboard",
      pills: [
        '<i class="fa-solid fa-chart-simple"></i> Income vs Expense Split',
        '<i class="fa-solid fa-wallet"></i> Net Savings Metric',
        '<i class="fa-solid fa-arrows-rotate"></i> Bill Reminder Tracker',
        '<i class="fa-solid fa-bolt"></i> Quick Expense Bar'
      ],
      html: `
        <div class="mockup-ui-wrapper">
          <div class="mockup-ui-topbar">
            <div class="mockup-ui-title"><i class="fa-solid fa-chart-pie" style="color:var(--primary-bright);"></i> Main Financial Dashboard</div>
            <div class="mockup-ui-status"><span class="status-dot"></span> Active Session</div>
          </div>
          <div class="mockup-stats-grid">
            <div class="mockup-stat-card">
              <div class="stat-label">Net Balance</div>
              <div class="stat-value" style="color:var(--primary-bright);">$14,850.00</div>
              <div class="stat-sub">+12.4% this month</div>
            </div>
            <div class="mockup-stat-card">
              <div class="stat-label">Monthly Income</div>
              <div class="stat-value" style="color:var(--accent-cyan);">$6,200.00</div>
              <div class="stat-sub">2 Income Sources</div>
            </div>
            <div class="mockup-stat-card">
              <div class="stat-label">Total Expenses</div>
              <div class="stat-value" style="color:#f87171;">$2,150.00</div>
              <div class="stat-sub">18 Transactions</div>
            </div>
          </div>
          <div class="mockup-chart-box">
            <div style="font-weight:600; margin-bottom:12px; font-size:0.9rem;">Category Breakdown & Spending Distribution</div>
            <div class="mockup-bar-row"><span style="width:100px;">🍔 Dining</span><div class="mockup-bar"><div style="width:38%; background:var(--primary);"></div></div><span>$817.00 (38%)</span></div>
            <div class="mockup-bar-row"><span style="width:100px;">✈️ Travel</span><div class="mockup-bar"><div style="width:26%; background:var(--accent-cyan);"></div></div><span>$559.00 (26%)</span></div>
            <div class="mockup-bar-row"><span style="width:100px;">⚡ Utilities</span><div class="mockup-bar"><div style="width:20%; background:#f59e0b;"></div></div><span>$430.00 (20%)</span></div>
            <div class="mockup-bar-row"><span style="width:100px;">🛍️ Shopping</span><div class="mockup-bar"><div style="width:16%; background:var(--accent-purple);"></div></div><span>$344.00 (16%)</span></div>
          </div>
        </div>
      `
    },
    leaderboard: {
      title: "Gamified Leaderboard & Emerald Rewards 💎",
      desc: "Earn Emeralds 💎 for building daily expense logging streaks and completing savings goals. Level up across 15 stages, unlock 16 stickers, and shop in the Emerald Marketplace!",
      url: "https://expenseos.app/leaderboard",
      pills: [
        '<i class="fa-solid fa-trophy"></i> 15 Level Stages',
        '<i class="fa-solid fa-tags"></i> 16 Collectible Stickers',
        '<i class="fa-solid fa-store"></i> Emerald Marketplace Shop',
        '<i class="fa-solid fa-shield-halved"></i> 100% Financial Privacy'
      ],
      html: `
        <div class="mockup-ui-wrapper">
          <div class="mockup-ui-topbar">
            <div class="mockup-ui-title"><i class="fa-solid fa-trophy" style="color:#fbbf24;"></i> Gamified Leaderboard & Emerald Rewards</div>
            <div class="mockup-ui-status"><span class="status-dot"></span> Active Gamer</div>
          </div>
          <div class="mockup-stats-grid">
            <div class="mockup-stat-card">
              <div class="stat-label">Emerald Balance</div>
              <div class="stat-value" style="color:#34d399;">1,250 💎</div>
              <div class="stat-sub">Stage 4: 🥈 Budget Apprentice</div>
            </div>
            <div class="mockup-stat-card">
              <div class="stat-label">Logging Streak</div>
              <div class="stat-value" style="color:#fbbf24;">🔥 7 Days</div>
              <div class="stat-sub">Active Daily Streak</div>
            </div>
            <div class="mockup-stat-card">
              <div class="stat-label">Stickers Unlocked</div>
              <div class="stat-value" style="color:#38bdf8;">5 / 16 🏷️</div>
              <div class="stat-sub">Piggy Raider, Impulse Slayer</div>
            </div>
          </div>
        </div>
      `
    },
    transactions: {
      title: "Full Transaction History & Log",
      desc: "View, search, filter, and edit all transactions with date selectors, category tags, and instant file downloads.",
      url: "https://expenseos.app/transactions",
      pills: [
        '<i class="fa-solid fa-magnifying-glass"></i> Instant Search',
        '<i class="fa-solid fa-filter"></i> Category & Date Filters',
        '<i class="fa-solid fa-pen-to-square"></i> Inline Transaction Editing',
        '<i class="fa-solid fa-file-csv"></i> Download CSV & JSON'
      ],
      html: `
        <div class="mockup-ui-wrapper">
          <div class="mockup-ui-topbar">
            <div class="mockup-ui-title"><i class="fa-solid fa-receipt" style="color:var(--accent-cyan);"></i> Transaction History & Ledger</div>
            <div style="font-size:0.8rem; color:var(--text-dim);">18 Total Transactions</div>
          </div>
          <div class="mockup-filter-bar">
            <input type="text" class="widget-input" value="Search transactions..." readonly style="width:220px; padding:6px 12px; font-size:0.8rem;">
            <span class="preview-pill" style="background:var(--primary); color:#000;"><i class="fa-solid fa-list"></i> All</span>
            <span class="preview-pill"><i class="fa-solid fa-arrow-down"></i> Expenses</span>
            <span class="preview-pill"><i class="fa-solid fa-arrow-up"></i> Income</span>
          </div>
          <table class="mockup-table">
            <thead>
              <tr><th>Date</th><th>Description</th><th>Category</th><th>Amount</th></tr>
            </thead>
            <tbody>
              <tr><td>2026-08-04</td><td>Starbucks Reserve Coffee</td><td><span class="mockup-tag" style="background:rgba(16,185,129,0.15); color:var(--primary-bright);">Food & Dining</span></td><td style="color:#f87171; font-weight:600;">-$8.50</td></tr>
              <tr><td>2026-08-03</td><td>Client Project Payment</td><td><span class="mockup-tag" style="background:rgba(6,182,212,0.15); color:var(--accent-cyan);">Income</span></td><td style="color:var(--primary-bright); font-weight:600;">+$1,250.00</td></tr>
              <tr><td>2026-08-02</td><td>Uber Airport Transfer</td><td><span class="mockup-tag" style="background:rgba(139,92,246,0.15); color:var(--accent-purple);">Travel</span></td><td style="color:#f87171; font-weight:600;">-$34.00</td></tr>
              <tr><td>2026-08-01</td><td>AWS Cloud Server Hosting</td><td><span class="mockup-tag" style="background:rgba(245,158,11,0.15); color:#f59e0b;">Utilities</span></td><td style="color:#f87171; font-weight:600;">-$45.00</td></tr>
            </tbody>
          </table>
        </div>
      `
    },
    budgeting: {
      title: "Custom Category Budget Limits",
      desc: "Set monthly target budgets per category with real-time warning alerts before overspending.",
      url: "https://expenseos.app/budgeting",
      pills: [
        '<i class="fa-solid fa-sliders"></i> Category Budget Limits',
        '<i class="fa-solid fa-triangle-exclamation"></i> Over-Budget Warning Alerts',
        '<i class="fa-solid fa-robot"></i> Automatic Category Tagging',
        '<i class="fa-solid fa-circle-notch"></i> Visual Progress Bars'
      ],
      html: `
        <div class="mockup-ui-wrapper">
          <div class="mockup-ui-topbar">
            <div class="mockup-ui-title"><i class="fa-solid fa-sliders" style="color:var(--primary-bright);"></i> Category Rules & Budget Limits</div>
            <div style="font-size:0.8rem; color:var(--primary-bright);"><i class="fa-solid fa-check"></i> 4 Active Rules</div>
          </div>
          <div style="display:grid; grid-template-columns:1fr 1fr; gap:16px;">
            <div class="mockup-chart-box">
              <div style="font-weight:600; margin-bottom:10px; font-size:0.85rem; color:var(--text-high);">Target Monthly Budgets</div>
              <div class="progress-item" style="margin-bottom:12px;">
                <div class="progress-label"><span>🍔 Dining & Food</span><span>$360 / $500 (72%)</span></div>
                <div class="progress-bar-bg"><div class="progress-bar-fill" style="width:72%; background:var(--primary);"></div></div>
              </div>
              <div class="progress-item" style="margin-bottom:12px;">
                <div class="progress-label"><span>✈️ Travel</span><span>$450 / $1000 (45%)</span></div>
                <div class="progress-bar-bg"><div class="progress-bar-fill" style="width:45%; background:var(--accent-cyan);"></div></div>
              </div>
              <div class="progress-item">
                <div class="progress-label"><span>⚡ Utilities</span><span>$264 / $300 (88%)</span></div>
                <div class="progress-bar-bg"><div class="progress-bar-fill" style="width:88%; background:#f59e0b;"></div></div>
              </div>
            </div>
            <div class="mockup-chart-box">
              <div style="font-weight:600; margin-bottom:10px; font-size:0.85rem; color:var(--text-high);">Automatic Category Rules</div>
              <div class="mockup-rule-item"><span>"coffee", "starbucks", "pizza"</span> ➔ <span style="color:var(--primary-bright); font-weight:600;">Food</span></div>
              <div class="mockup-rule-item"><span>"uber", "flight", "fuel"</span> ➔ <span style="color:var(--accent-cyan); font-weight:600;">Travel</span></div>
              <div class="mockup-rule-item"><span>"netflix", "spotify"</span> ➔ <span style="color:var(--accent-purple); font-weight:600;">Subscriptions</span></div>
            </div>
          </div>
        </div>
      `
    },
    currency: {
      title: "Multi-Currency & Real-Time Exchange Rates",
      desc: "Track expenses in USD, EUR, INR, GBP, JPY, CAD and instantly convert balances with live exchange rates.",
      url: "https://expenseos.app/fx-exchange",
      pills: [
        '<i class="fa-solid fa-coins"></i> Multiple Currencies (USD, EUR, INR, GBP, CAD, JPY)',
        '<i class="fa-solid fa-chart-line"></i> Live Exchange Rates',
        '<i class="fa-solid fa-calculator"></i> Automatic Converter'
      ],
      html: `
        <div class="mockup-ui-wrapper">
          <div class="mockup-ui-topbar">
            <div class="mockup-ui-title"><i class="fa-solid fa-coins" style="color:var(--accent-cyan);"></i> Multi-Currency & Live Exchange Rates</div>
            <div style="font-size:0.8rem; color:var(--accent-cyan);">Base: USD ($)</div>
          </div>
          <div class="mockup-currency-grid">
            <div class="mockup-stat-card"><div class="stat-label">USD / EUR</div><div class="stat-value" style="font-size:1.3rem;">€0.92</div><div class="stat-sub">Eurozone</div></div>
            <div class="mockup-stat-card"><div class="stat-label">USD / INR</div><div class="stat-value" style="font-size:1.3rem; color:var(--primary-bright);">₹83.50</div><div class="stat-sub">India</div></div>
            <div class="mockup-stat-card"><div class="stat-label">USD / GBP</div><div class="stat-value" style="font-size:1.3rem;">£0.79</div><div class="stat-sub">United Kingdom</div></div>
            <div class="mockup-stat-card"><div class="stat-label">USD / CAD</div><div class="stat-value" style="font-size:1.3rem;">$1.36</div><div class="stat-sub">Canada</div></div>
          </div>
        </div>
      `
    },
    sync: {
      title: "Offline & Cloud Sync",
      desc: "Seamlessly synchronizes your expense records across devices, with 100% offline support when you're without internet.",
      url: "https://expenseos.app/cloud-sync",
      pills: [
        '<i class="fa-solid fa-database"></i> 100% Offline Support',
        '<i class="fa-solid fa-cloud"></i> Automatic Cloud Sync',
        '<i class="fa-solid fa-shield-halved"></i> Private Data Protection'
      ],
      html: `
        <div class="mockup-ui-wrapper">
          <div class="mockup-ui-topbar">
            <div class="mockup-ui-title"><i class="fa-solid fa-shield-halved" style="color:var(--primary-bright);"></i> Cloud & Offline Device Sync</div>
            <div style="font-size:0.8rem; color:var(--primary-bright);"><i class="fa-solid fa-circle-check"></i> All Systems Active</div>
          </div>
          <div style="display:grid; grid-template-columns:1fr 1fr; gap:16px;">
            <div class="mockup-chart-box" style="border-left:3px solid var(--primary);">
              <div style="font-weight:700; color:var(--primary-bright); margin-bottom:6px;"><i class="fa-solid fa-cloud"></i> Automatic Device Sync</div>
              <div style="font-size:0.85rem; color:var(--text-med); margin-bottom:8px;">Real-time multi-device cloud synchronization enabled.</div>
              <div style="font-size:0.75rem; color:var(--text-dim);">Status: Synced</div>
            </div>
            <div class="mockup-chart-box" style="border-left:3px solid var(--accent-cyan);">
              <div style="font-weight:700; color:var(--accent-cyan); margin-bottom:6px;"><i class="fa-solid fa-database"></i> Offline Storage Engine</div>
              <div style="font-size:0.85rem; color:var(--text-med); margin-bottom:8px;">100% offline persistence with local device data protection.</div>
              <div style="font-size:0.75rem; color:var(--text-dim);">Status: Ready</div>
            </div>
          </div>
        </div>
      `
    },
    export: {
      title: "Download Financial Statements & Records",
      desc: "Export your complete expense data in formatted CSV or JSON at any time for personal records or accounting.",
      url: "https://expenseos.app/reports",
      pills: [
        '<i class="fa-solid fa-file-csv"></i> One-Click CSV Export',
        '<i class="fa-solid fa-file-code"></i> JSON Data Backup',
        '<i class="fa-solid fa-clock-rotate-left"></i> Transaction History Archives'
      ],
      html: `
        <div class="mockup-ui-wrapper">
          <div class="mockup-ui-topbar">
            <div class="mockup-ui-title"><i class="fa-solid fa-file-export" style="color:var(--accent-purple);"></i> Comprehensive Financial Reports & Export</div>
            <div style="font-size:0.8rem; color:var(--text-dim);">Export Manager</div>
          </div>
          <div style="display:flex; gap:16px; justify-content:center; padding:20px 0;">
            <div class="mockup-stat-card" style="width:240px; text-align:center;">
              <i class="fa-solid fa-file-csv" style="font-size:2rem; color:var(--primary-bright); margin-bottom:8px;"></i>
              <div style="font-weight:700;">Export as CSV</div>
              <div style="font-size:0.75rem; color:var(--text-dim); margin-bottom:12px;">Spreadsheet Ready</div>
              <a href="/" target="_blank" class="preview-pill" style="background:var(--primary); color:#000; display:inline-block;">Download CSV</a>
            </div>
            <div class="mockup-stat-card" style="width:240px; text-align:center;">
              <i class="fa-solid fa-file-code" style="font-size:2rem; color:var(--accent-cyan); margin-bottom:8px;"></i>
              <div style="font-weight:700;">Backup JSON</div>
              <div style="font-size:0.75rem; color:var(--text-dim); margin-bottom:12px;">Complete Raw Ledger</div>
              <a href="/" target="_blank" class="preview-pill" style="background:var(--accent-cyan); color:#000; display:inline-block;">Download JSON</a>
            </div>
          </div>
        </div>
      `
    }
  };

  function updateGalleryView(tabName) {
    const data = galleryData[tabName] || galleryData.dashboard;
    if (galleryTitle) galleryTitle.textContent = data.title;
    if (galleryDesc) galleryDesc.textContent = data.desc;
    if (galleryUrlTitle) galleryUrlTitle.innerHTML = `<i class="fa-solid fa-lock" style="font-size:0.7rem;"></i> ${data.url}`;
    if (previewPillsEl && data.pills) {
      previewPillsEl.innerHTML = data.pills.map(p => `<span class="preview-pill">${p}</span>`).join('');
    }
    if (galleryViewContainer) {
      galleryViewContainer.innerHTML = data.html;
    }
  }

  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      tabBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const target = btn.getAttribute('data-tab');
      updateGalleryView(target);
    });
  });

  // Initial load
  updateGalleryView('dashboard');

  // ---------- 5. Live FX Calculator Demo Widget ----------
  const fxAmount = document.getElementById('demo-fx-amount');
  const fxFrom = document.getElementById('demo-fx-from');
  const fxResult = document.getElementById('demo-fx-result');

  const exchangeRates = {
    USD: { INR: 83.5, EUR: 0.92, GBP: 0.79, CAD: 1.36, USD: 1.0 },
    EUR: { INR: 90.7, USD: 1.08, GBP: 0.86, CAD: 1.48, EUR: 1.0 },
    INR: { USD: 0.012, EUR: 0.011, GBP: 0.0095, CAD: 0.016, INR: 1.0 },
    GBP: { USD: 1.26, EUR: 1.16, INR: 105.4, CAD: 1.72, GBP: 1.0 },
    CAD: { USD: 0.73, EUR: 0.67, INR: 61.3, GBP: 0.58, CAD: 1.0 }
  };

  function updateFxDemo() {
    if (!fxAmount || !fxFrom || !fxResult) return;
    const amt = parseFloat(fxAmount.value) || 0;
    const curr = fxFrom.value;
    const inrVal = (amt * (exchangeRates[curr] ? exchangeRates[curr]['INR'] : 83.5)).toFixed(2);
    const eurVal = (amt * (exchangeRates[curr] ? exchangeRates[curr]['EUR'] : 0.92)).toFixed(2);
    fxResult.innerHTML = `₹${inrVal} INR &nbsp;|&nbsp; €${eurVal} EUR`;
  }

  if (fxAmount) fxAmount.addEventListener('input', updateFxDemo);
  if (fxFrom) fxFrom.addEventListener('change', updateFxDemo);
  updateFxDemo();

  // ---------- 6. Quick Expense Simulator Widget ----------
  const simName = document.getElementById('demo-sim-name');
  const simResult = document.getElementById('demo-sim-result');

  const categoryRules = [
    { keywords: ['coffee', 'starbucks', 'mcdonalds', 'pizza', 'burger', 'food', 'restaurant', 'cafe', 'dinner'], cat: 'Food & Dining', icon: 'fa-utensils', color: 'var(--accent-cyan)' },
    { keywords: ['uber', 'flight', 'airline', 'cab', 'bus', 'train', 'fuel', 'petrol', 'parking'], cat: 'Travel & Transport', icon: 'fa-plane', color: 'var(--primary-bright)' },
    { keywords: ['netflix', 'spotify', 'amazon', 'hulu', 'disney', 'youtube', 'subscription'], cat: 'Subscriptions', icon: 'fa-film', color: 'var(--accent-purple)' },
    { keywords: ['electricity', 'water', 'internet', 'rent', 'power', 'bill'], cat: 'Utilities & Housing', icon: 'fa-bolt', color: '#f59e0b' }
  ];

  function updateSimDemo() {
    if (!simName || !simResult) return;
    const val = simName.value.toLowerCase().trim();
    let found = categoryRules.find(r => r.keywords.some(k => val.includes(k)));
    if (!found) {
      found = { cat: 'General & Miscellaneous', icon: 'fa-tags', color: 'var(--text-high)' };
    }
    simResult.innerHTML = `
      <div style="font-size:0.85rem; color:var(--text-dim);">Auto-Detected Category</div>
      <div style="font-size:1.1rem; font-weight:700; color:${found.color};"><i class="fa-solid ${found.icon}"></i> ${found.cat}</div>
    `;
  }

  if (simName) simName.addEventListener('input', updateSimDemo);

  // ---------- 7. Mobile Navbar Toggle ----------
  const mobileToggle = document.getElementById('mobile-menu-toggle');
  const navLinks = document.getElementById('nav-links');
  if (mobileToggle && navLinks) {
    mobileToggle.addEventListener('click', (e) => {
      e.stopPropagation();
      navLinks.classList.toggle('active');
    });
    navLinks.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', () => {
        navLinks.classList.remove('active');
      });
    });
  }

  // ---------- 8. Smooth Scroll ----------
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      const targetId = this.getAttribute('href');
      if (targetId && targetId !== '#') {
        const targetEl = document.querySelector(targetId);
        if (targetEl) {
          e.preventDefault();
          targetEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
          if (navLinks) navLinks.classList.remove('active');
        }
      }
    });
  });

  // ---------- 9. Navbar Glassmorphism Scroll Effect ----------
  const navbar = document.querySelector('.navbar');
  if (navbar) {
    window.addEventListener('scroll', () => {
      if (window.scrollY > 40) {
        navbar.style.background = 'rgba(8, 10, 15, 0.95)';
        navbar.style.boxShadow = '0 10px 40px rgba(0, 0, 0, 0.8)';
      } else {
        navbar.style.background = 'rgba(12, 16, 26, 0.75)';
        navbar.style.boxShadow = '0 8px 32px rgba(0, 0, 0, 0.5)';
      }
    });
  }
});

window.handleLandingContactSubmit = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }

  const nameInput = document.getElementById('landing-contact-name');
  const emailInput = document.getElementById('landing-contact-email');
  const msgInput = document.getElementById('landing-contact-message');
  const submitBtn = document.getElementById('btn-landing-contact-submit');

  const name = nameInput ? nameInput.value.trim() : '';
  const email = emailInput ? emailInput.value.trim() : '';
  const message = msgInput ? msgInput.value.trim() : '';

  if (!name || !email || !message) {
    alert('Please fill out your Name, Email, and Message before sending.');
    return;
  }

  if (submitBtn) {
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Sending...';
  }

  fetch('https://formsubmit.co/ajax/vaibhavjalota06@gmail.com', {
    method: 'POST',
    headers: { 
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    },
    body: JSON.stringify({
      "👤 Sender Name": name,
      "✉️ Sender Email": email,
      "📅 Received Date": new Date().toLocaleString('en-US', { dateStyle: 'full', timeStyle: 'short' }),
      "💬 Message Content": message,
      _subject: `🌟 New Contact Inquiry from ${name} (Expense OS)`,
      _template: 'box',
      _captcha: 'false'
    })
  })
  .then(res => res.json())
  .then(data => {
    if (nameInput) nameInput.value = '';
    if (emailInput) emailInput.value = '';
    if (msgInput) msgInput.value = '';

    if (submitBtn) {
      submitBtn.disabled = false;
      submitBtn.innerHTML = '<i class="fa-solid fa-circle-check text-emerald"></i> Message Sent!';
      setTimeout(() => {
        submitBtn.innerHTML = '<i class="fa-solid fa-paper-plane"></i> Send Message';
      }, 3500);
    }
  })
  .catch(() => {
    window.location.href = `mailto:vaibhavjalota06@gmail.com?subject=${encodeURIComponent('Contact Message from ' + name)}&body=${encodeURIComponent('Sender Name: ' + name + '\nSender Email: ' + email + '\n\nMessage:\n' + message)}`;
    if (submitBtn) {
      submitBtn.disabled = false;
      submitBtn.innerHTML = '<i class="fa-solid fa-paper-plane"></i> Send Message';
    }
  });
};
