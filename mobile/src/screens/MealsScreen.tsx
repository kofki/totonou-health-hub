import { Placeholder } from '../components/Placeholder';

export function MealsScreen() {
  return (
    <Placeholder
      title="Meals"
      subtitle="Personal meal library + recommendations (tickets P5-01, P5-02)"
      items={[
        '📚  Meal library CRUD',
        '⭐  Recommended next meal (owner algorithm)',
        '🎯  Macro fit vs remaining daily budget',
      ]}
    />
  );
}
