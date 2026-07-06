# models/ — OWNER ONLY

Model selection, training, feature engineering, weights, and inference logic. Tickets
**P3-01** (calorie CV) and **P3-02** (body-fat + acne). Claude never implements here.

## Pretrained starting points (reference only — you evaluate and choose)

Recommended learning path per `docs/cv-approach.md`: start from a pretrained food
classifier, wire inference yourself, then fine-tune on your own meal photos.

| Option | Where | Notes |
|---|---|---|
| Food-101 fine-tuned ViT (e.g. `nateraw/food`) | HuggingFace | 101 dish classes; quickest inference win to learn the pipeline |
| `timm` backbones (EfficientNet/ConvNeXt/ViT) + Food-101 | `timm` + torchvision datasets | You do the transfer learning — freeze backbone, replace head |
| Nutrition5k-style portion estimation | papers/datasets | Later: calories need portion size, not just dish class |

Dish class → calories requires a mapping table (e.g. USDA FoodData Central) plus a portion
heuristic — that design is yours.

Weight files (`*.pt`, `*.pth`, `*.onnx`, `*.safetensors`) are gitignored; store them here
locally or in the GCS bucket.
