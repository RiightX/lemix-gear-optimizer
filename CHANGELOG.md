# Changelog

All notable changes to Lemix Gear Optimizer will be documented in this file.

## [1.0.0] - 2024-11-09

### Initial Release

#### Added
- Profile management system with multiple profiles per spec
- Tooltip-based stat scanner for percentage stats (Haste, Crit, Mastery, Versatility)
- Greedy optimization algorithm with priority scoring
- Auto-equip on spec change functionality
- Configuration UI with profile creation, editing, and deletion
- Profile selector integrated with Equipment Manager
- Button added to character panel for quick access
- SavedVariables for persistent data storage
- Support for stat priorities: primary stat, thresholds, and secondary stats
- Item caching for improved performance
- Combat lockdown handling
- Ring and trinket dual-slot support

#### Features
- Scan equipped items and bags (bags 0-4)
- Parse percentage-based stats from Legion Remix gear
- Set primary stat to maximize
- Define threshold requirements (e.g., maintain 100% Crit)
- Order secondary stats by priority
- Create multiple profiles per specialization
- Set active profile for automatic equipping
- Manual equip via UI
- Slash commands: `/lgo`, `/lemixgear`

#### Technical
- Modular code structure with separate managers
- Event-driven architecture
- Efficient tooltip scanning with caching
- Protection against duplicate item equipping
- Support for decimal percentage values
- Handles multi-word stat names

#### Documentation
- Comprehensive README with quick start guide
- Detailed installation instructions
- Development documentation in .github/copilot-instructions.md
- Complete testing checklist
- API reference for all managers

### Known Limitations
- Bank item scanning not implemented
- No set bonus consideration
- No item level weighting
- Greedy algorithm may not find absolute optimal solution
- No visual stat comparison view
- No profile import/export

### Future Enhancements
- Bank item scanning
- Current vs optimized stat comparison
- Profile templates for common specs
- Import/export functionality
- Advanced optimization algorithms
- Set bonus awareness
- Item level considerations
- Visual gear preview

