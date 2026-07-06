import { Placeholder } from '../components/Placeholder';

export function DashboardScreen() {
  return (
    <Placeholder
      title="Dashboard"
      subtitle="Daily overview from Garmin + VeSync (ticket P4-01)"
      items={[
        '👟  Steps · resting HR · body battery',
        '😴  Sleep score + stages',
        '⚖️  Weight & body-composition trend',
        '💡  Insight of the day',
      ]}
    />
  );
}
