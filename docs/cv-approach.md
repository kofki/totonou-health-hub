# Food/Calorie CV: API vs own model vs pretrained scaffold

Ticket **P3-01** (OWNER decides + builds). This doc is Claude's analysis of the options —
the decision and all implementation are yours.

## The three options

### 1. Commercial API (e.g. food-recognition APIs)
- **Pros**: best accuracy day one, zero training, portion estimation sometimes included.
- **Cons**: costs money per call, no learning value (CLAUDE.md's core constraint), your
  meal photos leave your infrastructure, rate limits.
- **Verdict**: fails the learning mandate as a primary path. Useful later as a *benchmark*
  to measure your model against.

### 2. Train your own model from scratch
- **Pros**: maximum learning.
- **Cons**: food datasets are huge (Food-101 = 101k images); training a competitive
  classifier from random weights needs serious GPU time and still loses to pretrained
  backbones. Weeks of effort before anything works end-to-end.
- **Verdict**: bad first step — you'd learn training mechanics but stall the product.

### 3. Pretrained scaffold → fine-tune (RECOMMENDED)
Start from a pretrained food classifier, wire the inference pipeline yourself, then
fine-tune on your own meal photos. This is how practitioners actually work, and every step
teaches a real skill:

| Step | What you build | What you learn |
|---|---|---|
| a | Load `nateraw/food` (ViT fine-tuned on Food-101) or a `timm` backbone; run inference on a meal photo | tensors, preprocessing, transforms, top-k softmax |
| b | Dish class → calorie mapping via USDA FoodData Central table + portion heuristic | feature engineering, data joining, uncertainty |
| c | Collect your own meal photos (you eat from a personal meal library — small label space!) | dataset curation, labeling, class imbalance |
| d | Fine-tune: freeze backbone, replace classification head with your ~30–50 personal dishes | transfer learning, overfitting control, eval (top-k acc, calorie MAE) |
| e | Benchmark vs a commercial API on 50 held-out photos | honest evaluation |

Key insight from your Notion notes: you mostly eat recurring meals from known sources. A
personal fine-tune over a small class space will likely *beat* a generic API for your
plates — and that result is a great portfolio story.

## Same pattern for the other models
- **Body-fat**: pretrained vision backbone → regression head, calibrated against your
  VeSync scale readings (P3-02).
- **Acne**: detection/segmentation or ordinal severity grading; pretrained backbones again.

## Claude's role (per CLAUDE.md)
Claude never selects the final model, trains, or writes inference. Claude may: explain any
concept above, review your notebooks/code, scaffold FastAPI deployment (P3-03), and write
test harnesses after your logic works.
