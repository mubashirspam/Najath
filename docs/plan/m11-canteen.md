# M11 · Canteen Management

**Phase P3.**

> ⛔ **BLOCKED — Q13.** The handwritten notes say only "Canteen Management" with
> no workflow. **Everything below is a proposal and must be confirmed before
> build.** The answer decides whether this is a two-day module or a two-week one:
>
> - **Meal attendance only** → `M11-DB-01`, `M11-API-01..03`, two parent screens.
>   Two or three days.
> - **Plus a prepaid wallet** → adds a ledger, transactions, credit limits,
>   statements and a reconciliation story. Two weeks, and it drags finance
>   questions (Q14) in with it.
>
> Do not start the wallet tasks until the answer is in writing.

## Tasks — meal attendance (the confirmed-safe core)

| ID           | Task                                                     | Depends      | Acceptance                                                                       |
| ------------ | -------------------------------------------------------- | ------------ | -------------------------------------------------------------------------------- |
| `M11-DB-01`  | `canteen_items`, `daily_menus` per meal type             | `M13-DB-01`  | Menu publishable a week ahead                                                    |
| `M11-DB-02`  | `meal_records` — unique per `(student, date, meal_type)` | `M02-DB-03`  | Enforced by a unique index                                                       |
| `M11-API-01` | Items and menu CRUD                                      | `M11-DB-01`  | Scoped to `CANTEEN_MANAGER` and admin                                            |
| `M11-API-02` | `POST /canteen/meal-records/batch`                       | `M11-DB-02`  | `Idempotency-Key`; per-item status                                               |
| `M11-API-03` | `GET /canteen/reports/consumption?from=&to=`             | `M11-DB-02`  | Headcount per meal per day; students on approved leave excluded from projections |
| `M11-ADM-01` | Item catalogue with unit prices                          | `M11-API-01` |                                                                                  |
| `M11-ADM-02` | Daily menu planner per meal type                         | `M11-API-01` |                                                                                  |
| `M11-ADM-03` | Meal attendance capture — batch scan or manual roster    | `M11-API-02` |                                                                                  |
| `M11-ADM-04` | Consumption report with wastage tracking                 | `M11-API-03` | Exports CSV                                                                      |
| `M11-APP-01` | Parent: this week's menu                                 | `M11-API-01` | Cached; readable offline                                                         |
| `M11-APP-02` | Parent: ward's meal record                               | `M11-DB-02`  |                                                                                  |

## Tasks — wallet (build only if Q13 confirms it)

| ID           | Task                                                            | Acceptance                                                            |
| ------------ | --------------------------------------------------------------- | --------------------------------------------------------------------- |
| `M11-DB-03`  | `wallet_ledger`, `wallet_transactions`                          | Balance is derived from the ledger, never stored as a mutable column  |
| `M11-API-04` | `GET /canteen/ledger/:studentId`                                | Guardian sees only their ward's ledger                                |
| `M11-API-05` | `POST /canteen/transactions` — credit by office, debit per meal | Negative balance allowed to a configured credit limit, blocked beyond |
| `M11-ADM-05` | Top-ups and monthly statement per student                       | Statement is reproducible from the ledger for any past month          |
| `M11-APP-03` | Parent: wallet balance, statement, low-balance alert            | Alert threshold is a setting                                          |

## Rules that bite

- Meal records are unique per `(student, date, meal_type)`.
- Wallet balance may go negative up to a configured credit limit; blocked beyond.
- Students on approved leave are **excluded from headcount projections**
  automatically — otherwise the kitchen over-caters every exam week.
- If the wallet ships, balance is always derived from the ledger. A stored
  balance column and a ledger will disagree, and the ledger will be right.

## API surface

```
GET/POST /api/v1/canteen/items
GET/POST /api/v1/canteen/menus?date=
POST     /api/v1/canteen/meal-records/batch
GET      /api/v1/canteen/ledger/:studentId
POST     /api/v1/canteen/transactions
GET      /api/v1/canteen/reports/consumption?from=&to=
```
