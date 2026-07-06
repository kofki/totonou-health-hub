import { Placeholder } from '../components/Placeholder';

export function SettingsScreen() {
  return (
    <Placeholder
      title="Settings"
      subtitle="Accounts + sync"
      items={[
        '⌚  Garmin Connect account',
        '⚖️  VeSync account',
        '🔐  Sign in (blocked on ticket P1-07)',
        '🔄  Sync status',
      ]}
    />
  );
}
