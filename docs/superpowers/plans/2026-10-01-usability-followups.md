# 사용성 후속 개선 작업 계획

> **For agentic workers:** 구현자는 `superpowers:subagent-driven-development`(권장) 또는 `superpowers:executing-plans` 스킬을 사용해 작업을 단계별로 진행해야 합니다. 각 단계는 체크박스로 추적합니다.

**Goal:** 현재 앱 동작을 사용자에게 더 정확히 설명하고, 백업 내보내기·빠른 일정 입력·온보딩 및 검색 흐름의 검증 공백을 메운다.

**Architecture:** 기존 Riverpod 서비스와 화면 구조를 유지한다. 자동 백업은 앱 시작/복귀 시점에 실행하는 현재 정책을 문구와 테스트로 명확히 하고, 빠른 일정 추가는 저장되는 1시간 구간 전체를 미리 보여 준다. 외부 공유와 앱 재시작 동작은 기존 서비스 경계를 통해 검증하며, 테스트를 위해 필요한 경우 공유 동작만 주입 가능한 작은 경계로 분리한다.

**Tech Stack:** Flutter, Dart, Riverpod, SharedPreferences, Flutter localization (ARB), flutter_test, Mockito.

**Spec:** [기존 사용성 개선 계획 및 구현 기록](2026-09-29-usability-improvements.md)과 이번 개선 조사 결과. 이 계획은 이미 반영된 개선을 되풀이하지 않고 후속 항목만 다룬다.

## Global Constraints

- 현재 체크아웃과 브랜치에서 작업한다. 신규 브랜치, 커밋, 푸시는 하지 않는다.
- `Transfer.md`와 `.gitignore`에 관한 프로젝트 지침을 따른다. 변경 규모가 큰 경우에만 Transfer 문서를 갱신한다.
- 한국어와 영어 ARB를 함께 수정하고 생성된 localization 파일은 프로젝트의 기존 생성 절차로 갱신한다.
- 자동 백업은 앱이 시작되거나 포그라운드로 돌아왔을 때만 확인한다. 백그라운드 예약 작업이 있는 것처럼 표현하지 않는다.
- 앱 데이터 형식과 기존 백업 파일 형식을 바꾸지 않는다. 공유 임시 파일은 시스템 공유가 끝난 뒤 정리한다.
- 실패 안내에 내부 예외나 사용자 데이터 경로를 노출하지 않는다.

## Review Focus

- 자동 백업 문구가 실행 조건과 24시간 간격을 정확히 표현하는가?
- 빠른 일정 미리보기의 종료 시간이 실제 저장되는 `startAt + 1시간`과 항상 일치하는가?
- 공유가 취소되거나 실패해도 임시 파일이 정리되고 앱 화면이 정상 상태로 남는가?
- 온보딩에서 알림 요청을 미룬 선택이 앱 재시작 후에도 다시 권한 요청으로 이어지지 않는가?
- 검색 시트를 닫았다 다시 열었을 때 검색어와 결과가 유지되며, 완료된 할 일과 시간이 없는 일정도 결과에 포함되는가?
- iOS/Android 공유 플러그인 차이와 현재 시뮬레이터 서비스 장애가 검증 결과에 영향을 주는가?

---

## Task 1: 자동 백업 안내 문구를 실제 실행 조건에 맞춘다

**Files:**
- Modify: `lib/l10n/app_ko.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/app_localizations.dart`
- Regenerate: `lib/l10n/app_localizations_ko.dart`
- Regenerate: `lib/l10n/app_localizations_en.dart`
- Modify: `test/widgets/auto_backup_screen_test.dart`

- [x] 한국어와 영어 문구가 “앱을 열거나 다시 활성화할 때, 마지막 성공 백업 후 24시간이 지났으면 자동 백업한다”는 의미를 전달하도록 변경한다. 백그라운드에서 주기적으로 실행된다는 인상을 주지 않는다.
- [x] 기존 화면의 마지막 백업 목록 및 빈 상태를 확인하고, 최신 백업 시간이 이미 노출되는 경우 그 상태를 중복 UI로 추가하지 않는다. 빈 상태에서는 자동 백업이 아직 생성되지 않았음을 명확히 유지한다.
- [x] 위젯 테스트에서 양 언어의 안내 문구와 백업이 없는 상태를 확인한다. 문구가 과도하게 구현 세부사항에 묶이지 않도록 핵심 조건만 검증한다.
- [x] 프로젝트 localization 생성 명령을 실행하고, 생성 파일이 ARB와 일치하는지 확인한다.

## Task 2: 빠른 일정 추가 미리보기에 시작 및 종료 시각을 표시한다

**Files:**
- Modify: `lib/features/schedule/presentation/event_edit/quick_add_sheet.dart`
- Modify: `lib/l10n/app_ko.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/app_localizations.dart`
- Regenerate: `lib/l10n/app_localizations_ko.dart`
- Regenerate: `lib/l10n/app_localizations_en.dart`
- Modify: `test/widgets/quick_add_event_sheet_test.dart`

- [x] 먼저 위젯 테스트를 추가해 입력한 일정의 시작·종료 시각이 미리보기에 모두 표시되는지 확인한다. 종료 시각은 기본 1시간 길이의 시작 시각 이후여야 한다.
- [x] 화면 문구와 localization 파라미터를 시작 및 종료 시각을 모두 받도록 변경한다. 기존 시간 형식 설정과 로케일별 날짜/시간 표기를 계속 사용한다.
- [x] 저장된 `EventInput`의 `startAt`/`endAt`이 미리보기와 동일하다는 테스트를 추가한다. 자정에 걸치는 일정도 날짜 변경을 포함해 확인한다.
- [x] 날짜만 입력하거나 시간을 입력하지 않은 경우의 기본 시간 안내가 계속 보이는지 확인한다.

## Task 3: 전체 백업 공유 흐름의 취소·실패·정리 동작을 검증한다

**Files:**
- Modify if needed: `lib/core/backup/share_full_backup.dart`
- Modify if needed: `lib/features/settings/presentation/auto_backup_screen.dart`
- Modify: `test/widgets/auto_backup_screen_test.dart`
- Add if needed: `test/share_full_backup_test.dart`

- [x] 현재 `SharePlus.instance.share` 호출을 테스트에서 대체할 수 있는지 확인한다. 대체가 어렵다면 공유 호출만 감싸는 작은 주입 지점을 추가하고, 화면·서비스 전반을 재구성하지 않는다.
- [x] 공유 액션 테스트를 먼저 작성한다. 내보내기 성공 시 생성 파일이 공유 대상으로 전달되고 공유 완료 뒤 삭제되는지 검증한다.
- [x] 공유 시트 취소 결과는 실패로 처리하지 않고 조용히 완료한다. 공유 API 또는 파일 생성 실패는 기존 현지화 오류 안내를 보여 주며, 생성된 임시 파일이 있으면 정리되는지 검증한다.
- [x] 실제 플랫폼 공유 UI를 띄우지 않는 단위/위젯 테스트로 검증한다. 플랫폼 메서드 채널을 쓰는 테스트라면 취소와 예외 응답을 명시적으로 설정하고 테스트 종료 시 채널 핸들러를 복구한다.

## Task 4: 알림 권한 요청 유예 상태가 앱 재시작 뒤에도 유지되는지 검증한다

**Files:**
- Inspect/modify if needed: `lib/core/onboarding_prefs.dart`
- Inspect/modify if needed: `lib/app.dart`
- Inspect/modify if needed: `lib/features/onboarding/presentation/onboarding_screen.dart`
- Modify: `test/widgets/app_router_onboarding_test.dart`
- Add if needed: `test/app_notification_onboarding_test.dart`

- [x] 온보딩에서 권한 요청을 미루는 기존 동작을 확인하는 테스트를 먼저 작성한다. 동일 SharedPreferences를 유지한 채 앱 루트를 폐기하고 다시 구성하는 재시작 시나리오로 검증한다.
- [x] 재구성 뒤 앱 시작/복귀 경로가 권한 요청을 다시 띄우지 않는지 확인한다. 완료 상태와 기존 `notificationPrompted` 사용자 상태도 함께 확인해 회귀를 막는다.
- [x] 구현에 필요한 경우에만 초기화 로직을 좁게 수정한다. 기존 설치의 키 누락 값은 현재 기본값과 동일하게 처리한다.

## Task 5: 검색 시트 재진입 및 결과 범위를 테스트로 고정한다

**Files:**
- Inspect/modify if needed: `lib/features/schedule/presentation/search/event_search_screen.dart`
- Modify: `test/widgets/event_search_screen_test.dart`

- [x] 현재 검색 시트 테스트를 확장해 검색어 입력 후 시트를 닫고 다시 열었을 때 검색어와 결과가 유지되는지 확인한다.
- [x] 완료된 할 일과 시간이 지정되지 않은 일정이 검색 결과에 포함되는 케이스를 각각 추가한다. 날짜 또는 상태에 따라 결과가 빠지면 기존 검색 범위를 유지하도록 수정한다.
- [ ] 검색 결과 상세 화면을 열고 닫은 뒤 검색 상태가 보존되는지 확인한다. (최종 검토에서 상세 화면 진입만 확인했고 닫기 후 보존 검증은 누락된 것으로 확인되어 보류)

## Task 6: 전체 회귀 검증 및 화면 확인

**Files:**
- No planned source changes; fix any failures in the owning task files above.

- [x] 각 작업별 대상 테스트를 실행한다: `flutter test test/widgets/auto_backup_screen_test.dart`, `flutter test test/widgets/quick_add_event_sheet_test.dart`, `flutter test test/widgets/app_router_onboarding_test.dart`, `flutter test test/widgets/event_search_screen_test.dart`, 그리고 새 공유 테스트.
- [x] `flutter gen-l10n`을 실행한 뒤 `flutter analyze`, 전체 `flutter test`, `git diff --check`를 실행한다.
- [x] iOS Simulator Debug 및 Android Debug APK 빌드를 확인한다. CoreSimulatorService 장애가 현재 재현되어 기기 UI 확인은 제한 사항으로 기록했고, Device Hub 직접 실행 workaround도 시도했다.
- [x] 좁은 화면과 큰 글자 배율은 테스트 범위까지만 확인했다. 시뮬레이터 서비스 오류로 4개 탭·백업 화면·일정 미리보기의 수동 화면 확인은 미완료로 기록했다.
- [x] 변경 파일과 실행 결과를 정리한다. 커밋이나 푸시는 하지 않는다.
