# Entity Language 구문 레퍼런스 — WPF Variant

## 결론

Entity Language는 외부 프로세스(PowerShell, Python, JS 등)가 stdout으로 한 줄씩 출력하면 UI를 제어하는 텍스트 프로토콜이다. Redis 커맨드처럼 `동사 대상 값` 구조를 따르며, 15개 동사로 속성 변경, 컬렉션 조작, 동적 컨트롤 생성/삭제, 태그 기반 그룹 연산을 모두 처리한다.

> **WPF Variant.** 이 문서는 Entity Language의 WPF 구현을 기술한다. 동사 어휘(`set`, `enable`, `spawn` 등)와 프로토콜 형식(한 줄 텍스트, `동사 대상 값`)은 프레임워크에 독립적이지만, 대상의 **속성명**(`Foreground`, `IsChecked`, `Visibility`), **속성값**(`#4CAF50`, `Collapsed`), **타입명**(`TextBox`, `StackPanel`)은 WPF에 종속된다. 다른 UI 프레임워크(HTML, Qt, MAUI 등)로 포팅할 경우 동사 어휘는 유지하되, 속성·타입 매핑 계층을 교체해야 한다.

핵심 설계 원칙:

- 모든 명령은 **한 줄 텍스트**다. 언어에 종속되지 않는다.
- 대상 자리에 **`@그룹명`** 을 쓰면 태그된 엔티티 전체에 적용된다.
- `set`은 리플렉션으로 **타입을 자동 감지**한다. 문자열 캐스팅 오류가 없다.
- `spawn`/`destroy`로 런타임에 컨트롤을 **동적 생성·제거**한다.

## Quick Start

ComboBox에 항목을 넣고, CheckBox를 체크하고, 동적 입력 필드를 만드는 예제:

```
clear cboGreeting
add cboGreeting Hello
add cboGreeting Hi
select cboGreeting 0

set chkFormal.IsChecked true

archetype labeled-input Label TextBox
spawn @labeled-input server-field pnlDynamic
set server-field_lbl.Content Server:
set server-field_tbx.Text localhost

destroy server-field
```

Python에서 사용할 때:

```python
print("disable btnSubmit")
print("set lblStatus.Text 처리 중...")
print("add cboResults 항목1")
print("enable btnSubmit")
```

PowerShell에서 사용할 때:

```powershell
"disable btnSubmit"
"set lblStatus.Text 처리 중..."
"add cboResults 항목1"
"enable btnSubmit"
```

---

## 1. 문법 구조

모든 명령은 공백으로 구분된 토큰열이다.

```
동사 대상 [값]
```

| 위치 | 역할 | 예시 |
|------|------|------|
| 첫 번째 토큰 | 동사 | `set`, `show`, `spawn` |
| 두 번째 토큰 | 대상 — 엔티티 이름 또는 `@태그` | `txtName`, `@input` |
| 세 번째 이후 | 값 — 나머지 토큰을 공백으로 재결합 | `Hello, world!` |

`#`으로 시작하는 줄과 빈 줄은 무시된다.

`set`의 대상은 **`엔티티.속성`** 형식이다. 점(`.`) 왼쪽이 엔티티, 오른쪽이 WPF 속성명이다.

---

## 2. 동사 분류

15개 동사는 기능에 따라 5개 범주로 나뉜다. 각 범주는 상호 배타적이며, 전체를 합치면 프로토콜의 모든 연산을 포괄한다.

### 2.1 속성 변경

UI 컨트롤의 속성 하나를 변경한다.

#### set

```
set 대상.속성 값
```

리플렉션으로 속성 타입을 감지한 뒤 자동 캐스팅한다.

| 감지된 타입 | 변환 규칙 |
|------------|----------|
| **Boolean** / **Nullable\<Boolean\>** | `true` → `$true`, 그 외 → `$false` |
| **Int32** | `[int]` 캐스팅 |
| **Double** | `[double]` 캐스팅 |
| **Brush** | `BrushConverter.ConvertFromString()` — `#RGB`, `#RRGGBB`, 색상명 등 |
| 그 외 | 문자열 그대로 전달 (WPF TypeConverter가 Thickness 등 처리) |

```
set txtName.Text 홍길동
set lblOutput.Foreground #FF5722
set chkFormal.IsChecked true
set lblOutput.FontSize 24
```

#### setb64

```
setb64 대상.속성 base64값
```

`set`과 동일하되 값을 **Base64 디코딩**(UTF-8)한 뒤 적용한다. 멀티라인 텍스트를 한 줄 커맨드로 전달할 때 사용한다.

```
setb64 txtResponse.Text SGVsbG8sIFdvcmxkIQ==
```

위 명령은 `txtResponse.Text`를 `"Hello, World!"`로 설정한다.

### 2.2 가시성·활성화

컨트롤의 표시 여부와 활성 상태를 전환한다. 값 토큰 없이 대상만 받는다.

| 동사 | 효과 |
|------|------|
| **show** | `Visibility = Visible` |
| **hide** | `Visibility = Collapsed` |
| **enable** | `IsEnabled = $true` |
| **disable** | `IsEnabled = $false` |

```
hide lblOutput
show lblOutput
disable @input
enable btnHello
```

### 2.3 컬렉션 조작

ComboBox, ListBox 등 **Items** 속성을 가진 컨트롤을 대상으로 한다.

| 동사 | 구문 | 효과 |
|------|------|------|
| **add** | `add 대상 값` | `Items.Add(값)` |
| **remove** | `remove 대상 인덱스` | `Items.RemoveAt(int)` |
| **clear** | `clear 대상` | `Items.Clear()` |
| **select** | `select 대상 인덱스` | `SelectedIndex = int` |

```
clear cboGreeting
add cboGreeting Hello
add cboGreeting Hi
add cboGreeting Hey
select cboGreeting 0
remove cboGreeting 2
```

### 2.4 태그 관리

엔티티에 태그를 붙이거나 떼어서 그룹을 구성한다.

| 동사 | 구문 | 효과 |
|------|------|------|
| **tag** | `tag 엔티티 태그명` | 엔티티를 태그 그룹에 추가 |
| **untag** | `untag 엔티티 태그명` | 엔티티를 태그 그룹에서 제거 |

```
tag txtName input
tag cboGreeting input
disable @input
untag txtName input
```

태그 그룹의 마지막 엔티티가 제거되면 태그 인덱스 자체도 삭제된다.

### 2.5 동적 생성·제거

런타임에 WPF 컨트롤을 만들거나 없앤다.

#### archetype

재사용 가능한 컨트롤 조합을 정의한다. 실제 컨트롤은 아직 생성하지 않는다.

```
archetype 이름 타입1 타입2 ...
```

```
archetype labeled-input Label TextBox
archetype checkbox-pair CheckBox CheckBox
```

#### spawn — 단일 컨트롤

```
spawn 타입 이름 부모
```

`System.Windows.Controls.타입`의 인스턴스를 생성하고 부모의 **Children**에 추가한다.

```
spawn TextBox dynInput pnlDynamic
spawn Button dynBtn pnlDynamic
```

#### spawn — 아키타입 인스턴스

```
spawn @아키타입 엔티티명 부모
```

StackPanel 컨테이너를 만들고, 아키타입에 정의된 타입마다 자식 컨트롤을 생성한다.

자식 이름 생성 규칙:

| 조건 | 이름 패턴 | 예시 |
|------|----------|------|
| 타입이 아키타입 내에서 **유일** | `엔티티명_약어` | `server-field_lbl` |
| 타입이 아키타입 내에서 **중복** | `엔티티명_약어N` | `myfield_chk1`, `myfield_chk2` |

타입 약어 표:

| WPF 타입 | 약어 |
|----------|------|
| TextBox | **tbx** |
| TextBlock | **tbl** |
| Label | **lbl** |
| Button | **btn** |
| CheckBox | **chk** |
| ComboBox | **cmb** |
| StackPanel | **stk** |
| WrapPanel | **wrp** |
| Grid | **grd** |

미등록 타입은 타입명을 소문자로 변환해서 약어로 쓴다.

아키타입으로 생성된 자식은 자동으로 부모 엔티티명이 태그로 붙는다.

```
archetype labeled-input Label TextBox
spawn @labeled-input server-field pnlDynamic
# 생성되는 엔티티:
#   server-field       (StackPanel 컨테이너)
#   server-field_lbl   (Label,   태그: server-field)
#   server-field_tbx   (TextBox, 태그: server-field)
```

#### destroy

```
destroy 이름
```

엔티티와 그 자식을 재귀적으로 제거한다. 부모의 Children에서 빠지고, 태그 인덱스에서도 정리되며, PowerShell 변수도 삭제된다.

```
destroy server-field
```

---

## 3. 대상 지정

모든 동사에서 대상 토큰은 두 가지 형태를 받는다.

| 형태 | 문법 | 해석 |
|------|------|------|
| 단일 엔티티 | `txtName` | 해당 이름의 엔티티 하나 |
| 태그 그룹 | `@input` | 해당 태그가 붙은 모든 엔티티 |

존재하지 않는 이름이나 빈 태그 그룹은 `Write-Warning`을 출력하고 건너뛴다.

---

## 4. 엔티티 레지스트리

앱 기동 시 XAML에 `x:Name`이 있는 컨트롤은 자동으로 레지스트리에 등록된다. `spawn`으로 생성된 컨트롤도 등록된다.

레지스트리 항목 구조:

```
$script:EntityRegistry["txtName"] = @{
    Control = <WPF 객체>
    Tags    = <List[string]>
    Parent  = <부모 엔티티 이름 또는 $null>
}
```

`Register-Entity`는 `Set-Variable`도 호출하므로, 기존 PowerShell 코드에서 `$txtName`으로 직접 접근하는 방식이 그대로 동작한다.

---

## 5. 오류 처리

| 상황 | 동작 |
|------|------|
| 알 수 없는 동사 | `Write-Warning "UI: unknown command '동사'"` |
| 존재하지 않는 엔티티 | `Write-Warning "UI: unknown control '이름'"` |
| 존재하지 않는 아키타입 | `Write-Warning "UI: unknown archetype '이름'"` |
| 존재하지 않는 부모 | `Write-Warning "UI: unknown parent '이름'"` |

프로세스는 중단되지 않는다. 경고를 출력하고 다음 명령으로 넘어간다.

---

## 6. 하위 호환성

| 기존 코드 | 변경 필요 여부 |
|-----------|--------------|
| `$txtName.Text = "값"` (PowerShell 직접 접근) | 변경 없음 — `Set-Variable`로 동일 객체 참조 |
| `set ctrl.prop value` (기존 프로토콜) | 변경 없음 — 동일 문법, 타입 감지만 추가 |
| `show`, `hide`, `enable`, `disable` | 변경 없음 |
| `Get-Variable`로 컨트롤 참조 | 변경 없음 |
