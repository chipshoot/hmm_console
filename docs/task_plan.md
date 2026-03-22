# Task Plan: Gas Station Dropdown Enhancement

## Goal
Enhance gas station selection in gas log create/update forms with a dedicated "Add Gas Station" button, full station property editing (especially country/city), smart sorting with recently-used stations prioritized, location-based station discovery, distinct display names, and a dedicated station management page.

## Current Phase
All phases complete

## Phases

### Phase 1: Backend - Add Country field to GasStation
- [x] Add `Country` property to `GasStation` domain entity (max 50 chars)
- [x] Add `Country` to FluentValidation in `GasStationValidator.cs`
- [x] Add `Country` to all DTOs: `ApiGasStation`, `ApiGasStationForCreate`, `ApiGasStationForUpdate`
- [x] Add `Country` to GasStationManager.UpdateAsync property copy
- [x] Build + test backend (1,052 tests pass)
- **Status:** complete

### Phase 2: Flutter - Expand GasStation model
- [x] Add missing fields to Flutter `GasStation` entity: `state`, `zipCode`, `description`, `country`
- [x] Update `ApiGasStation` model to include `country`
- [x] Update `ApiGasStation.toJson()` to send all fields (not just name)
- [x] Update `gas_station_repository.dart` mapper to include all fields
- [x] Update `createGasStation` in repository/datasource to send full station object
- **Status:** complete

### Phase 3: Flutter - Gas Station Form Dialog
- [x] Create `GasStationFormDialog` widget with fields: name, address, city, state/province, country, zipCode, description
- [x] Add validation (name required, max lengths matching backend)
- [x] Wire to `gasStationsStateProvider` for creation
- [x] Return created `GasStation` on success
- **Status:** complete

### Phase 4: Flutter - Integrate "Add Station" button in dropdown
- [x] Add "Add New Station" button/option at top of `StationDropdown` autocomplete options
- [x] On tap, open `GasStationFormDialog`
- [x] On dialog success, set the newly created station as the selected station
- [x] Added add_business icon button in text field suffix
- **Status:** complete

### Phase 5: Flutter - Sort stations (recently-used first)
- [x] Derive recently-used from gas log dates
- [x] Sort dropdown: recently-used stations first, then alphabetical
- [x] Show city + country in station subtitle
- **Status:** complete

### Phase 6: Testing & Verification (Phases 1-5)
- [x] Build backend: `dotnet build Hmm.sln` — 0 errors
- [x] Run backend tests: `dotnet test Hmm.sln` — 1,052 pass
- [x] Flutter analyze — no new errors
- [x] Launch Flutter app on iOS simulator
- **Status:** complete

### Phase 7: Distinct station display names (location-aware)
- [x] Created `station_display_name.dart` utility with disambiguation logic
- [x] Show "Name - City" when multiple stations share the same name
- [x] Show "Name - City, Country" when city also duplicates
- [x] Show just "Name" when station name is unique
- [x] Updated dropdown `displayStringForOption` to use disambiguated name
- [x] Updated dropdown options view titles to show disambiguated name
- [x] Updated search to also match on city/country
- [x] Updated onChanged matching to work with display names
- **Status:** complete

### Phase 7.5: Make Country and City mandatory for gas station
- [x] Backend: Added `[Required]` to GasStation domain entity for City and Country
- [x] Backend: Added `NotEmpty()` to GasStationValidator for City and Country
- [x] Backend: Added `[Required]` to ApiGasStationForCreate for City and Country
- [x] Backend: ApiGasStationForUpdate — City and Country remain optional (partial update)
- [x] Flutter: Updated GasStationFormDialog — City and Country now show "*" and validate as required
- [x] Fixed 10 test files (57 edits) to include City/Country in GasStation fixtures
- [x] Build: 0 errors, all 1,589 tests pass
- [x] Flutter analyze: no issues
- **Status:** complete

### Phase 8: Location-based station discovery
- [x] Added `geolocator` package (v14.0.2) for device GPS access
- [x] Added latitude/longitude to GasStation (backend entity + DTOs + Flutter model + repository)
- [x] Created `location_provider.dart` with currentPositionProvider and Haversine distance calc
- [x] Added "Capture Current Location" button in gas station form dialog
- [x] Station dropdown sorts by distance when GPS + station coordinates available
- [x] Distance badge shown in dropdown options (e.g. "1.2 km")
- [x] Added iOS location permission (NSLocationWhenInUseUsageDescription)
- [x] Backend: range validation (-90/90, -180/180) in GasStationValidator
- [x] Committed and pushed: backend `37a1010`, Flutter `6f65c7f`
- **Status:** complete

### Phase 9: Gas Station Management Page
- [x] Created GasStationManagementScreen with active/inactive sections
- [x] Created ManageableGasStationTile widget with edit/toggle-active buttons
- [x] Added update (PUT) and delete (DELETE) to gas station datasource and repository
- [x] Added updateStation/deleteStation to GasStationsState
- [x] GasStationFormDialog supports edit mode via station parameter
- [x] Registered /gas-stations route and gasStationManagement route name
- [x] Added navigation icon button in gas log list app bar
- [x] Updated gas_log_list_tile_test to use GasLogDisplayModel
- [x] Flutter analyze: only pre-existing warnings
- [x] Committed and pushed: `ed6bcc0`
- **Status:** complete

### Phase 10: Final Testing & Verification
- [x] Build backend: 0 errors
- [x] Run backend tests: 1,589 pass, 0 fail
- [x] Flutter analyze: only 2 pre-existing issues (no new issues)
- [x] Flutter tests: 289 pass, 0 fail (fixed 2 pre-existing failures)
- [x] Fixed create/update gas log state tests (missing gasStationRepository mock)
- [x] Committed and pushed: `7b98a4c`
- **Status:** complete

## Key Questions
1. Should "recently used" be based on gas log dates or a dedicated lastUsedDate on station? → Use gas log data (no backend change needed)
2. Should the Add Station dialog be a full screen or a modal dialog? → Modal dialog (quicker UX)
3. Does the backend need a new Country field or is it already there? → Added in Phase 1
4. Should we add an edit station capability too? → Yes, done in Phase 9
5. For location-based discovery, use device GPS only or also integrate external API (Google Places)? → TBD
6. Should lat/lng be stored on GasStation entity or kept client-side only? → TBD
7. Where should the Gas Station Management page be accessible from? → Gas log list app bar (icon button)

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Add `Country` field to backend GasStation | User specifically requested country/city support |
| Modal dialog for Add Station | Faster UX than navigating to a separate screen |
| Derive recently-used from gas logs | Avoids adding new backend field; gas log dates already available |
| Sort: recent first, then alphabetical | Intuitive: stations you use often are at the top |
| "Name - City" display for duplicates | Distinguishes same-brand stations at different locations |
| Dedicated management page for stations | Full CRUD needs more space than a dialog provides |
| Gas station nav in gas log list app bar | Quick access from the most relevant screen |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| GasLogsData type mismatch in station_dropdown | 1 | Changed List<GasLog> to GasLogsData, use .items |
| 42 backend test failures after making City/Country required | 1 | Updated 10 test files (57 edits) with City/Country values |

## Notes
- All 10 phases complete
- All code committed and pushed to both repos
- Backend: 1,589 tests pass, Flutter: 289 tests pass
