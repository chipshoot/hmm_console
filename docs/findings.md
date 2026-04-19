# Findings & Decisions

## Requirements
- Historical vs real-time gas log creation toggle
- Real-time: pre-fill odometer, validate against auto meter, update auto after creation
- Historical: use /gaslogs/historylog endpoint, no meter update
- Odometer validation: must be >= current meter reading (real-time only)
- Gap warning: advisory when odometer has large deviation from expected

## Research Findings

### Backend Endpoints
- **Real-time:** `POST /automobiles/{autoId}/gaslogs` — creates gas log AND atomically updates automobile MeterReading
- **Historical:** `POST /automobiles/{autoId}/gaslogs/historylog` — creates gas log without updating automobile meter
- Both accept identical `ApiGasLogForCreation` request body
- Backend `GasLogManager.CreateAsync()` validates odometer against auto meter; `LogHistoryAsync()` skips this

### Flutter Architecture
- `CreateGasLogState` orchestrates creation: resolves station, calls use case, refreshes gas logs
- `automobilesStateProvider` has `refresh()` to re-fetch automobile data
- `selectedAutomobileIdProvider` stores current auto selection
- Automobile entity has `meterReading: int` for current odometer

## Resources
- Backend GasLogManager: `src/Hmm.Automobile/GasLogManager.cs` (CreateAsync vs LogHistoryAsync)
- Flutter datasource: `lib/features/gas_log/data/datasources/gas_log_remote_datasource.dart`
- Flutter form: `lib/features/gas_log/presentation/screens/gas_log_form_screen.dart`
- Flutter state: `lib/features/gas_log/states/create_gas_log_state.dart`
- Flutter validator: `lib/features/gas_log/domain/validators/gas_log_validator.dart`
