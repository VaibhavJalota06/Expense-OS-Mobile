/// Smart AI Merchant & Keyword Categorizer Service for Expense OS
/// Automatically maps merchant names, descriptions, and receipt keywords
/// to canonical categories across Flutter Mobile and Web.
class MerchantCategorizer {
  static const Map<String, List<String>> _categoryKeywords = {
    'Food & Dining': [
      'starbucks', 'mcdonalds', 'mcdonald', 'kfc', 'burger king', 'subway', 'dominos', 'pizza',
      'zomato', 'swiggy', 'uber eats', 'doordash', 'grubhub', 'cafe', 'restaurant', 'diner',
      'bakery', 'bistro', 'food', 'coffee', 'tea', 'taco', 'chipotle', 'dunkin', 'baskin robbins'
    ],
    'Transport / Uber': [
      'uber', 'lyft', 'ola', 'rapido', 'grab', 'cab', 'taxi', 'metro', 'subway', 'train',
      'bus', 'transit', 'railway', 'irctc', 'parking', 'toll', 'fastag', 'fuel', 'petrol',
      'diesel', 'shell', 'bp', 'exxon', 'chevron', 'gas'
    ],
    'Shopping': [
      'amazon', 'flipkart', 'walmart', 'target', 'ebay', 'myntra', 'zara', 'h&m', 'nike',
      'adidas', 'uniqlo', 'apple', 'best buy', 'ikea', 'shopping', 'mall', 'clothing', 'fashion'
    ],
    'Groceries': [
      'walmart', 'costco', 'target', 'whole foods', 'trader joe', 'blinkit', 'zepto', 'instamart',
      'bigbasket', 'grocery', 'supermarket', 'mart', 'provision', 'vegetable', 'fruit', 'milk'
    ],
    'Bills & Utilities': [
      'electric', 'electricity', 'power', 'water', 'gas bill', 'utility', 'internet', 'wifi',
      'broadband', 'airtel', 'jio', 'vi', 'vodafone', 'verizon', 'att', 't-mobile', 'recharge',
      'mobile bill', 'dth', 'tata sky'
    ],
    'Subscriptions': [
      'netflix', 'spotify', 'prime', 'amazon prime', 'youtube', 'disney', 'hbo', 'hulu',
      'apple music', 'icloud', 'chatgpt', 'openai', 'midjourney', 'github', 'adobe', 'playstation',
      'xbox', 'nintendo', 'patreon', 'medium', 'substack'
    ],
    'Rent & Housing': [
      'rent', 'landlord', 'apartment', 'housing', 'mortgage', 'maintenance', 'hoa'
    ],
    'Health & Medical': [
      'pharmacy', 'chemist', 'doctor', 'hospital', 'clinic', 'dentist', 'medical', 'medicine',
      'cvs', 'walgreens', 'apollo', 'practo', 'health', 'fitness', 'gym'
    ],
    'Entertainment': [
      'movie', 'cinema', 'bookmyshow', 'amc', 'steam', 'game', 'gaming', 'concert', 'ticket',
      'event', 'bowling', 'arcade'
    ],
    'Education': [
      'udemy', 'coursera', 'edx', 'tuition', 'school', 'college', 'university', 'book',
      'stationery', 'course', 'class'
    ],
    'Salary': [
      'salary', 'payroll', 'stipend', 'employer', 'wages', 'compensation'
    ],
    'Freelance': [
      'freelance', 'upwork', 'fiverr', 'toptal', 'client payment', 'consulting'
    ],
    'Investments': [
      'dividend', 'interest', 'stock', 'crypto', 'binance', 'coinbase', 'zerodha', 'groww',
      'investment', 'return'
    ],
  };

  /// Detects category based on input merchant name or raw OCR receipt text
  static String detectCategory(String input, {String defaultCategory = 'Miscellaneous'}) {
    if (input.trim().isEmpty) return defaultCategory;
    final text = input.toLowerCase();

    for (final entry in _categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return defaultCategory;
  }
}
