# Task Plan: Historical vs Real-Time Gas Log with Odometer Validation

## Goal
Add a historical/real-time toggle to gas log creation. Real-time logs pre-fill odometer from automobile meter, validate odometer >= current reading, warn on large gaps, and refresh automobile state after creation. Historical logs use a separate backend endpoint that doesn't update automobile meter.

## Current Phase
All phases complete

## Phases

### Phase 1: Data/Repository/UseCase — Historical gas log endpoint
- [x] Added `createHistoryGasLog()` to `GasLogRemoteDataSource` (POST `/gaslogs/historylog`)
- [x] Added `createHistoryGasLog()` to `IGasLogRepository` interface
- [x] Implemented in `_GasLogApiRepository`
- [x] Created `CreateHistoryGasLogUseCase` with Riverpod provider
- **Status:** complete

### Phase 2: State Layer — Historical/Real-time branching
- [x] Added `isHistorical` parameter to `CreateGasLogState.create()`
- [x] Historical → uses `createHistoryGasLogUseCaseProvider`
- [x] Real-time → uses `createGasLogUseCaseProvider` + refreshes `automobilesStateProvider`
- **Status:** complete

### Phase 3: Validator — Odometer vs automobile meter
- [x] Added `validateOdometerAgainstMeter()` — error if odometer < current meterReading
- [x] Added `warnOdometerGap()` — advisory warning for large gaps (non-blocking)
- **Status:** complete

### Phase 4: Form Screen — Toggle, pre-fill, validation
- [x] Added `_isHistorical` toggle (SwitchListTile, create mode only)
- [x] Pre-fills odometer from automobile meterReading for real-time mode
- [x] Clears odometer when switching to historical mode
- [x] Uses `validateOdometerAgainstMeter` for real-time, basic `validateOdometer` for historical
- [x] Shows amber gap warning below odometer field
- [x] Passes `isHistorical` flag to `create()` on submit
- **Status:** complete

### Phase 5: Tests & Verification
- [x] Added `createHistoryGasLog` stub to 5 test fake/mock implementations
- [x] `flutter analyze` — 2 pre-existing issues only, no new issues
- [x] `flutter test` — 289 pass, 0 fail
- **Status:** complete

## Key Decisions
| Decision | Rationale |
|----------|-----------|
| `isHistorical` is a creation-time param, not persisted on GasLog | It's behavioral routing, not data |
| Same DTO for both endpoints | Backend accepts identical request body |
| Gap warning is advisory (non-blocking) | User may legitimately have a large gap |
| Toggle only on create mode | Editing doesn't change historical/real-time status |
| Refresh automobiles after real-time create | Backend updates meter; keep Flutter state in sync |

## Files Created
- `lib/features/gas_log/usecases/create_history_gas_log_usecase.dart`

## Files Modified
- `lib/features/gas_log/data/datasources/gas_log_remote_datasource.dart`
- `lib/features/gas_log/data/repositories/i_gas_log_repository.dart`
- `lib/features/gas_log/data/repositories/gas_log_api_repository.dart`
- `lib/features/gas_log/states/create_gas_log_state.dart`
- `lib/features/gas_log/domain/validators/gas_log_validator.dart`
- `lib/features/gas_log/presentation/screens/gas_log_form_screen.dart`
- 5 test files (added `createHistoryGasLog` stubs)
