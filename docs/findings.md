# Findings & Decisions

## Requirements
- Add "Add Gas Station" button in gas station dropdown (gas log create/update forms)
- New station form must capture all properties: name, address, city, state, country, zipCode, description
- Country and city are required fields
- Sort gas stations: recently-used stations first, then alphabetical
- Disambiguate station names when duplicates exist (append city/country)
- Dedicated gas station management page with edit and activate/deactivate

## Research Findings

### Backend GasStation Entity
- **File:** `src/Hmm.Automobile/DomainEntity/GasStation.cs`
- Properties: Id, Name, Address, City (required), State, Country (required), ZipCode, Description, IsActive, AuthorId
- Uses note-based storage pattern (serialized as JSON in HmmNote)
- Validator: `src/Hmm.Automobile/Validator/GasStationValidator.cs` (FluentValidation)

### Backend DTOs
- **Read:** `src/Hmm.ServiceApi.DtoEntity/GasLogNotes/ApiGasStation.cs`
- **Create:** `src/Hmm.ServiceApi.DtoEntity/GasLogNotes/ApiGasStationForCreate.cs` (City, Country required)
- **Update:** `src/Hmm.ServiceApi.DtoEntity/GasLogNotes/ApiGasStationForUpdate.cs` (City, Country optional for partial update)

### Backend Controller
- **File:** `src/Hmm.ServiceApi/Areas/AutomobileInfoService/Controllers/GasStationController.cs`
- POST creates station, PUT updates, DELETE soft-deletes (marks inactive)

### Flutter GasStation Entity
- **File:** `lib/features/gas_log/domain/entities/gas_station.dart`
- Full model with: id, name, address, city, state, country, zipCode, description, isActive, copyWith

### Flutter Station Dropdown
- **File:** `lib/features/gas_log/presentation/widgets/station_dropdown.dart`
- Uses `Autocomplete<GasStation>` widget
- "Add New Station" button at top of options list
- add_business icon in text field suffix
- Recently-used sorting, city/country search
- Display name disambiguation via `stationDisplayName()`

### Flutter Station Management
- **Screen:** `lib/features/gas_log/presentation/screens/gas_station_management_screen.dart`
- **Tile:** `lib/features/gas_log/presentation/widgets/manageable_gas_station_tile.dart`
- Active/Inactive sections, edit dialog, toggle active/deactivate
- Route: `/gas-stations` (gasStationManagement), icon in gas log list app bar

### Flutter State Management
- **File:** `lib/features/gas_log/states/gas_stations_state.dart`
- Methods: createStation, updateStation, deleteStation (marks inactive)
- **Important:** gasLogsStateProvider returns `AsyncValue<GasLogsData>`, use `.items` for the list

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Add Country to backend entity | User specifically requested country/city support |
| City and Country required | User requested mandatory fields |
| Expand Flutter GasStation to match backend | Need all fields for the Add Station form |
| Modal dialog for Add Station | Quick interaction without leaving the form |
| Recently-used sorting from gas log data | Already have gas logs with station references; no backend changes needed |
| "Name - City" disambiguation | Distinguishes same-brand stations at different locations |
| Gas station management as separate screen | Full CRUD needs more space than a dialog |
| Navigation via gas log list app bar icon | Quick access from the most relevant screen |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| GasLogsData type mismatch | Changed List<GasLog> to GasLogsData, use .items |
| 42 test failures after City/Country required | Updated 10 test files (57 edits) with fixture values |

## Resources
- Backend station entity: `src/Hmm.Automobile/DomainEntity/GasStation.cs`
- Backend station DTOs: `src/Hmm.ServiceApi.DtoEntity/GasLogNotes/ApiGasStation*.cs`
- Backend controller: `src/Hmm.ServiceApi/Areas/AutomobileInfoService/Controllers/GasStationController.cs`
- Flutter station entity: `lib/features/gas_log/domain/entities/gas_station.dart`
- Flutter station dropdown: `lib/features/gas_log/presentation/widgets/station_dropdown.dart`
- Flutter station state: `lib/features/gas_log/states/gas_stations_state.dart`
- Flutter station repo: `lib/features/gas_log/data/repositories/gas_station_repository.dart`
- Flutter station management: `lib/features/gas_log/presentation/screens/gas_station_management_screen.dart`
- Flutter display name util: `lib/features/gas_log/domain/services/station_display_name.dart`
