# WPF Scaffold for PowerShell

C# 없이 PowerShell만으로 WPF GUI 앱을 만드는 선언형 스캐폴드입니다.

UI는 XAML로, 트레이와 타이머는 XML로 선언하고 로직은 `logic/` 폴더에 언어 무관하게 분리합니다.
`main.ps1` 실행 시 누락된 핸들러 파일을 자동으로 생성합니다.

## 실행

```powershell
powershell -ExecutionPolicy Bypass -File main.ps1
```

![윈도우](screenshot-window.png)

## 적합한 용도

- 개인 도구, 사내 유틸리티, 프로토타입
- PowerShell 하나로 GUI를 빠르게 붙이고 싶을 때
- 로직을 Python/Ruby/Node 등 다른 언어로 작성하고 싶을 때

## 한계

- **암시적 스코프 바인딩**: `$window`, `$logicDir`, `$btnHello` 등이 dot-source 스코프 체인으로 전파됩니다. 액션이 많아지면 변수 출처 추적이 어렵습니다.
- **프로세스 생성 비용**: 로직 호출 시마다 외부 프로세스를 spawn합니다. 타이머 틱마다 `powershell.exe`를 실행하는 시계처럼 빈번한 호출에는 과도할 수 있습니다.
- **디버깅 제약**: Runspace 내부에서 breakpoint를 설정할 수 없고 stderr 출력도 제한적입니다.
- **적정 규모**: 액션 20개, 로직 10개 이상이면 C# WPF 등으로 전환을 권장합니다.

## 요구 사항

- Windows PowerShell 5.1 이상
- .NET Framework (Windows 기본 포함)

## 아키텍처

### UI ↔ 로직 분리

로직 스크립트는 stdout으로 UI 명령을 출력합니다. 어떤 언어로든 작성할 수 있습니다.

```
set lblOutput.Text Hello, World!
disable btnHello
enable btnHello
show lblOutput
hide lblOutput
```

### 백그라운드 실행

iOS의 Grand Central Dispatch(GCD)와 같은 패턴입니다.
무거운 작업을 백그라운드 스레드에서 실행하고, 결과를 메인(UI) 스레드로 마샬링합니다.

| 개념 | GCD (iOS/ObjC) | 이 프로젝트 (PowerShell WPF) |
|------|----------------|------------------------------|
| 백그라운드 실행 | `dispatch_async(global_queue)` | Runspace + `BeginInvoke()` |
| UI 갱신 | `dispatch_async(main_queue)` | DispatcherTimer가 큐를 드레인 |
| 메시지 전달 | 블록 캡처 | `ConcurrentQueue<string>` |

```
[actions] → Start-LogicStream → [Runspace] → 서브프로세스 (stdout)
                                     ↓
                              ConcurrentQueue
                                     ↓
                          DispatcherTimer (16ms) → Invoke-UICommands → UI 갱신
```

- **Runspace**: 백그라운드 스레드에서 서브프로세스를 실행하고 stdout을 줄 단위로 읽음
- **ConcurrentQueue**: 스레드 안전한 메시지 버스
- **DispatcherTimer**: UI 스레드에서 큐를 드레인하여 컨트롤에 반영 (60fps)

### 다국어 로직 지원

`Start-LogicStream`이 확장자에 따라 적절한 런타임을 선택합니다:

| 확장자 | 런타임 |
|--------|--------|
| `.ps1` | `powershell` |
| `.py`  | `uv run` (없으면 `python -u`) |
| `.js`  | `deno run` (없으면 `node`) |
| `.ts`  | `deno run` |
| `.rb`  | `ruby` |

## 프로젝트 구조

```
main.ps1                        앱 진입점 — XAML 로드, 이벤트 연결, 큐 초기화
main.xaml                       WPF UI 레이아웃
tray.xml                        트레이 아이콘 및 컨텍스트 메뉴 정의
timers.xml                      DispatcherTimer 정의
engine/
    Ensure-ActionLoaded.ps1     핸들러 자동 스캐폴딩
    Initialize-Queue.ps1        ConcurrentQueue + 드레인 타이머 (백그라운드 스트림 처리)
    Invoke-UICommands.ps1       UI 명령 디스패처 (set, show, hide, enable, disable)
    Start-LogicStream.ps1       Runspace 기반 비동기 서브프로세스 실행
actions/
    Initialize-Tray.ps1         tray.xml 파싱 및 트레이 초기화
    Initialize-Timers.ps1       timers.xml 파싱 및 타이머 초기화
    Show-Window.ps1             트레이 메뉴: 창 표시
    Stop-App.ps1                트레이 메뉴: 앱 종료
    Update-Clock.ps1            타이머 틱: 시계 갱신 (logic/clock.ps1 호출)
    Invoke-HelloClick.ps1       버튼 클릭 핸들러 (logic/hello.py 호출)
    Invoke-NameKeyDown.ps1      텍스트박스 Enter 키 핸들러
logic/
    clock.ps1                   시계 로직 (PowerShell)
    hello.ps1                   인사 로직 (PowerShell)
    hello.py                    인사 로직 (Python, PEP 723 인라인 메타데이터)
```

## 동작 원리

1. `main.ps1`이 `engine/`의 유틸리티 함수를 먼저 로드합니다.
2. `main.xaml`을 파싱해 컨트롤 이름과 이벤트 핸들러 목록을 수집합니다.
3. `actions/` 폴더에 핸들러 파일이 없으면 자동으로 스텁을 생성합니다.
4. XAML을 로드하고 컨트롤을 변수에 바인딩한 뒤 이벤트 핸들러를 연결합니다.
5. `Initialize-Queue`로 백그라운드 스트림 처리 큐를 시작합니다.
6. `Initialize-Tray`와 `Initialize-Timers`가 각각 `tray.xml`과 `timers.xml`을 읽어 설정합니다.
7. `ShowDialog()` 후 종료 시 큐, 타이머, Runspace를 정리합니다.

## 확장 방법

### 버튼 추가

`main.xaml`에 버튼을 추가하고 `Click` 속성에 핸들러 이름을 지정합니다.

```xml
<Button x:Name="btnSave" Content="저장" Click="Invoke-Save"/>
```

`main.ps1`을 실행하면 `actions/Invoke-Save.ps1`이 자동 생성됩니다.
생성된 파일에 로직을 작성합니다.

### 타이머 추가

`timers.xml`에 `<Timer>` 항목을 추가합니다.

```xml
<Timer Name="refreshTimer" Interval="5000" AutoStart="true" Tick="Invoke-Refresh"/>
```

`main.ps1`을 실행하면 `actions/Invoke-Refresh.ps1`이 자동 생성됩니다.
생성된 파일에 로직을 작성합니다.

### 트레이 메뉴 항목 추가

`tray.xml`에 `<MenuItem>` 항목을 추가합니다.

```xml
<MenuItem Header="설정" Action="Open-Settings"/>
```

`main.ps1`을 실행하면 `actions/Open-Settings.ps1`이 자동 생성됩니다.
구분선은 `Header="---"`로 추가합니다.

### 로직 스크립트 추가

`logic/` 폴더에 아무 언어로 스크립트를 작성합니다. stdout으로 UI 명령을 출력하면 됩니다.

```python
# logic/greet.py
import sys
name = sys.argv[1] if len(sys.argv) > 1 else "World"
print(f"set lblOutput.Text Hello, {name}!")
```

액션에서 `Start-LogicStream`으로 호출합니다:

```powershell
# actions/Invoke-GreetClick.ps1
function Invoke-GreetClick {
    param($sender, $e)
    Start-LogicStream "$logicDir\greet.py" @($txtName.Text)
}
```

서브프로세스는 백그라운드 Runspace에서 실행되므로 UI가 차단되지 않습니다.

## 트레이 동작

창 닫기 버튼을 누르면 앱이 종료되지 않고 시스템 트레이로 최소화됩니다.
트레이 아이콘은 PowerShell 기본 아이콘을 사용합니다.
트레이 아이콘을 더블클릭하면 창이 복원됩니다.
우클릭 메뉴는 `tray.xml`에서 선언합니다.

![트레이](screenshot-tray.png)


