# Ponytail Engineering Guidelines (Anti-Overengineering & YAGNI)

## The Decision Ladder
Before writing or refactoring any code:
1. **Does this need to exist at all?** (YAGNI - You Aren't Gonna Need It). If speculative, skip it.
2. **Already in this codebase?** Reuse existing helpers, services, models, and widgets.
3. **Stdlib/Framework does it?** Use Flutter/Dart built-in features directly.
4. **Already-installed dependency solves it?** Use existing packages. Never add new ones for simple tasks.
5. **Can it be one line?** Prefer concise, direct expressions over multi-layered abstractions.
6. **Only then:** Write the absolute minimum code that is robust and functional.

## Practical Rules for Expense OS
- Keep widgets concise and reusable without premature abstraction layers.
- Reuse `CurrencyService.currencySymbolNotifier` across all financial screens.
- Deletion over addition: clean unused code, duplicate variables, and dead imports.
- Boring, clear code over complex clever patterns.
- Never compromise on input validation, security, or error handling.
