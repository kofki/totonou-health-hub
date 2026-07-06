import { Placeholder } from '../components/Placeholder';

export function FoodScreen() {
  return (
    <Placeholder
      title="Food"
      subtitle="Snap a meal → CV calorie estimate (tickets P3-01, P4-01)"
      items={[
        '📷  Camera capture flow',
        '🔍  Dish recognition + portion estimate',
        '🔥  Calories + macros logged automatically',
        "📆  Today's intake vs target",
      ]}
    />
  );
}
