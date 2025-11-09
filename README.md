# Lemix Gear Optimizer

A World of Warcraft addon for Legion Remix that optimizes gear based on customizable stat priorities.

## Features

- **Automatic Gear Optimization**: Scans your bags and equipped items to find the best gear combination
- **Percentage-Based Stats**: Designed specifically for Legion Remix where stats are percentages (e.g., "25% Haste")
- **Multiple Profiles per Spec**: Create different gear sets for different situations
- **Priority System**: Set primary stats, threshold requirements, and secondary priorities
- **Auto-Equip on Spec Change**: Automatically equips your chosen profile when you switch specs
- **Equipment Manager Integration**: Adds a button to the character panel for quick access

## Installation

1. Download or clone this repository
2. Copy the `lemix-gear-optimizer` folder to:
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
3. Restart WoW or type `/reload` in-game

## Usage

### Quick Start

1. Open the configuration window:
   - Type `/lgo` or `/lemixgear`
   - Or click the "Lemix Optimizer" button on your character panel

2. Create a new profile:
   - Click "Create Profile"
   - Enter a name for your profile

3. Edit the profile:
   - Click "Edit" on your profile
   - Set your Primary Stat (the stat you want to maximize)
   - Set Thresholds (minimum percentages for specific stats)
   - The addon will prioritize remaining stats automatically

4. Optimize your gear:
   - Click "Optimize Gear" to scan your bags
   - Then click "Equip Set" to equip the optimized gear

5. Set as active (optional):
   - Click "Set Active" to make this profile auto-equip when you switch to this spec

### Example Profile: Guardian Druid

For a Guardian Druid that wants to:
- Prioritize Haste
- Maintain at least 100% Crit
- Then maximize Mastery

Set up the profile like this:
- **Primary Stat**: HASTE
- **Thresholds**: CRIT = 100
- **Secondary Stats**: MASTERY

The optimizer will:
1. First maximize Haste on all gear
2. Ensure you have at least 100% Crit
3. Then prioritize Mastery for remaining slots

## Commands

- `/lgo` - Open configuration window
- `/lemixgear` - Open configuration window (alternative)

## How It Works

The addon uses a greedy optimization algorithm:

1. **Scans** all equipped items and items in your bags
2. **Parses** tooltips to extract percentage-based stats
3. **Scores** each item based on your profile priorities:
   - Primary stat gets highest weight (1000x)
   - Threshold stats get high weight (800x) until requirement met
   - Secondary stats weighted by priority order
4. **Selects** the best item for each equipment slot
5. **Equips** the optimized gear set

## Settings

- **Auto-equip on spec change**: When enabled, automatically equips your active profile when switching specs

## Supported Stats

- Haste
- Critical Strike
- Mastery
- Versatility

## Limitations

- Currently only scans bags and equipped items (not bank)
- Combat restrictions apply (cannot change gear during combat)
- Does not consider set bonuses or special item effects
- Optimizes for stat totals only, not item level or other factors

## Troubleshooting

**Addon not showing up:**
- Make sure the folder is named correctly and in the AddOns directory
- Check that all files are present
- Try `/reload` or restart WoW

**Stats not being detected:**
- This addon is designed for Legion Remix percentage-based stats
- Regular WoW gear with raw stat numbers won't be parsed correctly
- Try `/reload` to clear the cache

**Can't equip gear:**
- You cannot change gear during combat
- Make sure the gear is in your bags (not bank)
- Run optimization before trying to equip

## Development

See `.github/copilot-instructions.md` for detailed development documentation, API reference, and contribution guidelines.

## Version

Current version: 1.0.0

## License

This addon is provided as-is for World of Warcraft Legion Remix.

