# Model Tuning Guide

All parameters below are hot-reloadable in `appsettings.json` — change them and reload the API without restarting.

## SQL Generation Parameters

### Temperature (SqlTemperature)
- **Current: 0.05** (very low, deterministic)
- **Range: 0.0–1.0**
- **What it does**: Controls randomness in token selection. Lower = more predictable, follows the prompt exactly.
- **When to adjust**:
  - If queries are too rigid or repetitive: increase to 0.1–0.15
  - If hallucinating irrelevant columns (like `YearlyIncome`): decrease to 0.02

### Max Tokens (SqlMaxTokens)
- **Current: 400**
- **What it does**: Cuts off model output after N tokens, preventing rambling SQL.
- **When to adjust**:
  - Complex queries with many JOINs: increase to 500–600
  - Getting incomplete SQL: increase by 50 and test
  - Model adding unnecessary comments: decrease to 350

### Top-P (Nucleus Sampling) - SqlTopP
- **Current: 0.9** (keep top 90% probability mass)
- **Range: 0.0–1.0**
- **What it does**: During token selection, only consider tokens in the top P% of probability. Discards low-probability outliers.
- **When to adjust**:
  - If still seeing hallucinations: decrease to 0.8 or 0.75
  - If queries feel too constrained: increase to 0.95

### Top-K (Diversity Constraint) - SqlTopK
- **Current: 40** (consider only the top 40 most likely tokens)
- **What it does**: Limits selection to the K most likely tokens, preventing the model from picking rare/wrong options.
- **When to adjust**:
  - If still hallucinating: decrease to 30 or 25
  - If queries are formulaic: increase to 50–60

## Answer Generation Parameters

### Temperature (AnswerTemperature)
- **Current: 0.2** (low, but slightly less rigid than SQL)
- **What it does**: Allows natural language to be a bit more varied while staying factual.
- **When to adjust**:
  - Answers sound robotic: increase to 0.3–0.5
  - Answers are inaccurate or weird: decrease to 0.1

### Max Tokens (AnswerMaxTokens)
- **Current: 120** (~2–3 sentences)
- **When to adjust**:
  - Answers are cut off mid-sentence: increase to 150–200
  - Answers are too long: decrease to 100

## Schema Filtering

### ExcludedColumnSuffixes
- **Current: [ "Income", "Salary" ]**
- **What it does**: Automatically hides columns ending with these suffixes from the schema context sent to the model.
- **Why Income/Salary**: These were being hallucinated into income-related questions. Excluding them prevents the model from "seeing" them.
- **When to adjust**:
  - If a certain column family keeps appearing in hallucinations (e.g., `BudgetAmount`), add the suffix: `"ExcludedColumnSuffixes": ["Income", "Salary", "Budget"]`
  - If you actually need those columns for a legitimate business question, remove the suffix and instead lower temperature/top-k further.

### ExcludedTables
- **Current: []** (none)
- **What it does**: Completely hide entire tables from schema introspection.
- **Example**: `"ExcludedTables": ["dbo.InternalMetadata", "dbo.Logs"]`

## Performance Impact

On an RTX 5070 with qwen2.5-coder:7b-instruct-q4_K_S:
- Lower temperature (0.05 vs 0.3): **No latency impact** — determinism doesn't slow inference
- Lower top-p (0.8 vs 0.95): **Negligible impact** — maybe 50–100ms savings
- Lower top-k (25 vs 50): **Negligible impact**
- Lower num_predict (400 vs 600): **May see 10–15% faster inference** if model tends to output long responses

Expected per-question latency: **30–45 seconds** (dominated by Ollama inference, not these settings)

## Tuning Strategy

1. **Start with current settings** — they're aggressive but calibrated for your data.
2. **If you see hallucinations** (like `YearlyIncome` when not asked):
   - First: Add the column suffix to `ExcludedColumnSuffixes`
   - Second: Lower `SqlTemperature` to 0.02 or 0.01
   - Third: Lower `SqlTopK` to 25–30

3. **If queries are too simplistic or repetitive**:
   - Increase `SqlTemperature` to 0.1–0.15
   - Increase `SqlTopP` to 0.95

4. **If answers are being cut off**:
   - Increase `AnswerMaxTokens` by 20–30

5. **Test between changes** — A/B test 3–5 questions you know well, track success rate, then adjust.

## Example Tuning for Different Use Cases

### Conservative (fewer hallucinations, more predictable)
```json
"SqlTemperature": 0.02,
"SqlTopP": 0.8,
"SqlTopK": 25,
"AnswerTemperature": 0.1
```

### Balanced (current defaults)
```json
"SqlTemperature": 0.05,
"SqlTopP": 0.9,
"SqlTopK": 40,
"AnswerTemperature": 0.2
```

### Creative (more varied queries, might hallucinate more)
```json
"SqlTemperature": 0.15,
"SqlTopP": 0.95,
"SqlTopK": 60,
"AnswerTemperature": 0.4
```
