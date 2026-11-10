# Toolbox para macOS: plan de implementación

> Documento para que un agente de código lo ejecute de principio a fin. Aquí no se implementa nada: el plan define qué construir, en qué orden y cómo verificarlo.
> Nombre provisional: **Toolbox**. Bundle ID: `com.jchicano.toolbox`. Licencia: **MIT** por defecto (Apache-2.0 como alternativa). Marca propia: **no** es un fork de Vorssaint ni de SuperBar.

### Changelog del plan — actualización 2026-11-04
Cambios respecto a la versión anterior (680 líneas):
- **Snippets pasan al MVP** (§6.7, fase F6): triggers cortos que se expanden a texto, variables `{clipboard}`/`{date}`/`{time}`/`{cursor}`, e inserción buscable desde el menú. Ya no son un "extra" de la fase SuperBar.
- **Catálogo modular de features** (§4.1) inspirado en el hub `AppFeature` de Vorssaint, pero con UX de `NSMenu` simple con checks: flag de activación, permisos requeridos, start/stop limpio y persistencia.
- **Fase YAML (SuperBar-style) acotada** (§7.2, F10): bookmarks, workspaces, comandos shell/Terminal y secciones de menú custom. Yams solo entra en esa fase.
- **Regla transversal "lo público va en inglés"** (§1.1): README, UI (locale por defecto `en`), comentarios, commits, PRs y release notes.
- **Licencia MIT** y nombre propio; reimplementar APIs, nada de copiar código Vorssaint (GPL-3).
- **Fuera de alcance explícito** (§1): mixer de volumen, Dynamic Island/notch, desinstalador, gestor de Homebrew, control de ventiladores, monitor de sistema, etc.
- Fases renumeradas (F0–F10), DoD, CA, riesgos y backlog de tareas (68) actualizados.

### Adaptación de entorno — 2026-11-09 (build machine: macOS 12.7.6 Intel, Xcode 14.2)
- **Deployment target macOS 12.0** (en lugar de 13.0): `SMAppService` no existe → login item híbrido (F1); `Localizable.strings` en vez de `.xcstrings`; `TimeInterval` en vez de `Duration`; Swift 5.7 (sin macros ni Observation).
- Hardened runtime desactivado en Debug (los bundles de tests no cargan con ad-hoc + runtime); activo en Release.
- Firma ad-hoc; notarización pendiente de Developer ID. QA manual solo en Intel.

---

## 0. Resumen

Toolbox es una app de barra de menús (sin icono en el Dock) para macOS 13 o posterior. Se distribuye como binario universal (arm64 + x86_64). Agrupa utilidades que se activan con un toggle:

| # | Ítem del menú | Tipo | Fase |
|---|---|---|---|
| 1 | Descansos | toggle | MVP |
| 2 | Mantener despierto | toggle (+ submenú de duración) | MVP |
| 3 | Scroll Vim (^D/^U) | toggle | MVP |
| 4 | Autocerrar `( [ { " ' \` < ¿ ¡` | toggle | MVP |
| 5 | Snippets (expansión de triggers) | toggle (+ submenú `Insertar snippet…`) | MVP |
| 6 | 🎨 Color picker | acción | MVP |
| 7 | ─── separador ─── | | MVP |
| 8 | ❓ Ayuda | acción | MVP |
| 9 | Salir de Toolbox | acción | MVP |

> Los títulos de la tabla están en español por legibilidad del plan; en la app la UI por defecto es **inglés** (`Breaks`, `Keep Awake`, `Vim Scroll`, `Auto-close`, `Snippets`, `Color Picker`, `Help`, `Quit Toolbox`). Ver §1.1.

En la fase 2 (F10) se añaden módulos inspirados en SuperBar, definidos por el usuario en YAML: bookmarks, workspaces, comandos y secciones de menú custom (incluido cambio a modo oscuro).

---

## 1. Objetivo y no-objetivos

### Objetivos
- Una app nativa, ligera (< 30 MB RAM en reposo, ~0 % CPU en reposo) y universal (Intel + Apple Silicon).
- Que el menú reproduzca el de la captura "Toolbox": un check (✓) marca cada utilidad activa y el estado se mantiene tras reiniciar.
- Cada utilidad está aislada en su propio módulo, se activa y desactiva en caliente y no deja hooks vivos cuando está apagada.
- Que la app explique y pida bien los permisos (Accesibilidad), y que funcione sin ellos con las features que no los necesitan.
- Distribución fuera de la Mac App Store: firmada con Developer ID, hardened runtime y notarizada.

### No-objetivos
- **No** es un clon de SuperBar. No se copia su código, sus assets ni su formato `.superbar.yml` literal; solo se toman ideas.
- **No** se publica en la Mac App Store (ver §12: el sandbox no permite los event taps globales que necesitamos).
- **No** se da soporte a macOS 12 o anterior.
- **No** hay sincronización en la nube, cuentas ni telemetría.
- **No** se reemplaza a Vimium ni a los editores: Scroll Vim y Autocerrar son ayudas ligeras y globales, no motores de edición.
- El MVP **no** incluye Sparkle ni autoupdate (quedan en el backlog).
- **No** es un fork de Vorssaint (GPL-3, marca propia). Se toman ideas (catálogo de features, keep awake, color picker, snippets) y se reimplementan con APIs públicas de Apple. No se copia código, strings, iconos ni nombres.
- **Fuera de alcance explícito (bloat de Vorssaint que no entra):** mixer de volumen por app, Dynamic Island / notch / HUDs de notch, desinstalador de apps, gestor de Homebrew, control de ventiladores / sensores, monitor de sistema completo (CPU/RAM/red/disco), limpiador de caché, gestor de ventanas, panel/hub a pantalla completa, widgets, reproductor/now playing, gestor de portapapeles con historial completo. Cualquier propuesta de este tipo se rechaza o va a un proyecto aparte.

### 1.1 Regla transversal: lo público va en inglés
- **Todo artefacto público está en inglés:** README y `docs/` públicos, strings de UI (locale por defecto y de desarrollo `en`), comentarios de código, nombres de identificadores, mensajes de commit, títulos y cuerpos de PR, issues creadas por el agente, release notes / CHANGELOG y textos del DMG.
- El español solo se permite en **este plan** (documento interno para Jay) y en una localización opcional futura `es.lproj` / entrada `es` del `.xcstrings`, **nunca** como UI por defecto.
- Los ejemplos de copy en español de este plan (p. ej. §5) se traducen al inglés al implementar; el texto en español queda como referencia para la futura localización `es`.
- Licencia: fichero `LICENSE` MIT (copyright Jay Chicano) y cabecera SPDX `// SPDX-License-Identifier: MIT` opcional en los ficheros fuente.

---

## 2. Personas y casos de uso

| Persona | Caso de uso |
|---|---|
| Dev que pasa muchas horas delante del teclado | Activa "Descansos" para que le avise cada 50 min y "Mantener despierto" mientras dura una build o una descarga. |
| Usuario de Vim | Quiere hacer `^D`/`^U` para bajar o subir media página en Safari, Chrome, Mail o Notas sin que interfiera con Terminal o iTerm. |
| Quien escribe en español en apps sin autocierre (Notas, Slack, navegador, Mail) | Escribe `¿` y obtiene `¿|?`. Escribe `(` y obtiene `(|)`. Al pulsar Tab, el cursor salta detrás del cierre. |
| Diseñador o frontend | Pulsa "Color picker", hace clic en cualquier píxel y tiene `#1E90FF` en el portapapeles. |
| Quien repite textos (emails, firma, respuestas) | Escribe `;sig` y se expande a su firma; o busca "dirección" en `Insertar snippet…` y lo pega. |
| Power user (fase 2) | Define bookmarks, workspaces, comandos y secciones de menú en YAML, los recarga y los lanza desde el menú. |

---

## 3. Stack recomendado y decisiones técnicas

| Decisión | Elección | Justificación |
|---|---|---|
| Lenguaje | **Swift 5.10+ / Swift 6 en modo de lenguaje 5** | Es nativo y tiene acceso directo a AppKit, CoreGraphics e IOKit. |
| UI de barra de menús | **AppKit `NSStatusItem` + `NSMenu`** | Da control total sobre los checks, los submenús, el `NSMenuDelegate.menuWillOpen` (estado de los permisos) y los ítems dinámicos. `MenuBarExtra` de SwiftUI es más limitado (no hay forma fácil de reconstruir el menú en vivo ni de tener checks por ítem en modo menú). |
| Ventanas (Ayuda, Preferencias, onboarding de permisos, overlay de descanso) | **SwiftUI** alojado en `NSHostingController` / `NSWindow` | Permite iterar rápido y requiere poco código. |
| Target mínimo | **macOS 13 Ventura** | `SMAppService` (login item moderno), APIs de SwiftUI estables y `NSColorSampler` (10.15+). Bajar a 12 obligaría a usar el `SMLoginItemSetEnabled` deprecado y a cambiar otras APIs, y no compensa. |
| Arquitecturas | **Universal: `arm64 x86_64`** (`ARCHS = arm64 x86_64`, `ONLY_ACTIVE_ARCH = NO` en Release) | Es un requisito del producto. |
| Proyecto | **XcodeGen (`project.yml`)** para generar el `.xcodeproj` + **paquete SPM local `ToolboxCore`** con la lógica pura | Un agente no edita bien los `.pbxproj` a mano. `project.yml` es diffable. La lógica que no depende de la UI (la máquina de estados de Autocerrar, el parser del config o los timers) se prueba con `swift test` sin la app. |
| Dependencias | **Ninguna en el MVP.** **Yams** solo en F10 (YAML). Sparkle va al backlog. | Superficie mínima. Los snippets del MVP se guardan en JSON (Codable), no en YAML. |
| Licencia | **MIT** (alternativa Apache-2.0) | Permisiva; evita GPL. Incompatible con copiar código de Vorssaint (GPL-3), por eso se reimplementa. |
| Idioma público | **Inglés** (§1.1) | Proyecto open source publicado. |
| Hooks de teclado | **Un único `CGEventTap`** compartido (`EventTapManager`) en un hilo dedicado con su `CFRunLoop`, que reparte los eventos entre los features suscritos | Un solo permiso y un solo punto donde gestionar el timeout y la re-habilitación. Se evitan varios taps compitiendo entre sí. |
| Mantener despierto | **`IOPMAssertionCreateWithName`** (IOKit) | Es la API oficial que usan Caffeine y Amphetamine. No usar `caffeinate` como subproceso. |
| Color picker | **`NSColorSampler`** | Es la lupa nativa del sistema y **no requiere permiso de Grabación de pantalla**. |
| Notificaciones | **`UserNotifications`** | Sirven para los avisos de Descansos. |
| Persistencia | **`UserDefaults`** (estado de los toggles y prefs simples) + **`~/Library/Application Support/Toolbox/snippets.json`** (MVP) + **`~/.config/toolbox/config.yml`** (fase 2, contenido del usuario) | Separa el estado de la app de los datos que edita el usuario. |
| Login item | **`SMAppService.mainApp`** | Es la API moderna de macOS 13+. |
| App agente | `LSUIElement = YES` | Sin icono en el Dock, solo en la barra de menús. |
| Sandbox | **Desactivado**. Hardened runtime **activado**. | Ver §12. |
| Firma y notarización | Developer ID Application + `notarytool` + `stapler` | Hace falta para distribuir fuera de la App Store sin bloqueos de Gatekeeper. |

### Decisiones abiertas (máximo 3, con valor por defecto)
1. **Icono de la barra de menús**: por defecto, el SF Symbol `wrench.and.screwdriver` como template image. Se puede cambiar más adelante por un asset propio.
2. **Duración por defecto de Descansos**: 50 min de trabajo y 5 min de descanso. Se puede ajustar en Preferencias.
3. **Nombre definitivo y bundle ID**: por defecto, `Toolbox` / `com.jchicano.toolbox`.

---

## 4. Arquitectura de módulos

```
┌────────────────────────── App (target Toolbox.app) ──────────────────────────┐
│ AppDelegate                                                                  │
│  ├─ StatusItemController ── construye el NSMenu a partir de FeatureRegistry  │
│  ├─ FeatureRegistry ─────── catálogo [FeatureDescriptor + Feature], on/off  │
│  │    ├─ BreaksFeature          (Timer + UserNotifications + overlay)        │
│  │    ├─ KeepAwakeFeature       (IOPMAssertion)                              │
│  │    ├─ ScrollVimFeature       (EventTap consumer)                          │
│  │    ├─ AutoCloseFeature       (EventTap consumer + AutoCloseEngine)        │
│  │    ├─ SnippetsFeature        (EventTap consumer + SnippetEngine + picker) │
│  │    └─ ColorPickerAction      (NSColorSampler)                             │
│  ├─ EventTapManager ─────── único CGEventTap, hilo propio, re-enable         │
│  ├─ PermissionsService ──── AX / Input Monitoring / Notificaciones           │
│  ├─ FrontmostAppTracker ─── NSWorkspace.didActivateApplication → bundleID    │
│  ├─ SettingsStore ───────── UserDefaults tipado (Codable)                    │
│  ├─ LoginItemService ────── SMAppService                                     │
│  └─ Windows (SwiftUI): Help, Preferences, PermissionOnboarding, BreakOverlay │
└──────────────────────────────────────────────────────────────────────────────┘
┌──────────────── ToolboxCore (SPM, sin AppKit siempre que se pueda) ──────────┐
│ AutoCloseEngine (máquina de estados pura)   PairTable                        │
│ BreakScheduler (lógica de tiempos, reloj inyectable)                         │
│ AppFilter (allowlist/denylist por bundleID)                                  │
│ ColorFormatter (NSColor/RGB → hex, rgb(), hsl())                             │
│ SnippetEngine (matcher de triggers) + SnippetTemplate (variables) + Store    │
│ Config (F10): ConfigModel + YAMLLoader + Validator                           │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Catálogo modular de features (inspirado en `AppFeature` de Vorssaint, UX de menú simple)
- Cada feature se declara con un **descriptor estático** en un catálogo único (`FeatureCatalog.all`), que define orden en el menú, título localizado, permisos y si es toggle o acción. El menú se genera a partir del catálogo: añadir una feature = un descriptor + una clase, sin tocar `MenuBuilder`.
- **UX:** un `NSMenu` plano con checks (✓) y submenús opcionales. Nada de panel/hub gigante, ventanas flotantes ni Dynamic Island.
- **Ciclo de vida:** `start()` / `stop()` idempotentes. `stop()` debe dejar cero recursos vivos (timers, aserciones, consumidores del tap, observers). El registry llama a `stop()` en `applicationWillTerminate`.
- **Permisos:** el descriptor declara `requiredPermissions`. El registry no llama a `start()` si falta alguno; en su lugar lanza el onboarding (§5) y deja el check sin marcar.
- **Persistencia:** `Settings.enabled: Set<FeatureID>` se guarda en cada toggle y se restaura al arrancar (primero las features sin permisos).
- Features de "Ocultar del menú" (backlog): el catálogo admite `isVisible` para que el usuario esconda las que no usa.

```swift
// Public code: English identifiers and comments (§1.1).
enum Permission: Hashable { case accessibility, notifications, automation }
enum FeatureKind { case toggle, action }

struct FeatureDescriptor {
    let id: FeatureID                       // .breaks, .keepAwake, .scrollVim, .autoClose, .snippets, .colorPicker
    let titleKey: String.LocalizationValue  // "Breaks", "Keep Awake", … (en by default)
    let kind: FeatureKind
    let requiredPermissions: Set<Permission>
    let menuOrder: Int
}

protocol Feature: AnyObject {
    static var descriptor: FeatureDescriptor { get }
    var isRunning: Bool { get }
    func start() throws                     // idempotent; throws PermissionError if missing
    func stop()                             // idempotent; releases every resource
    func makeSubmenu() -> NSMenu?           // optional (durations, quick settings)
}
```

### `EventTapManager`
- Instala el tap **solo si** hay al menos un consumidor activo y lo destruye cuando no queda ninguno.
- Eventos: `keyDown`, `keyUp` (para limpiar el estado de los modificadores), `flagsChanged`, `leftMouseDown` y `rightMouseDown` (para invalidar el estado de Autocerrar).
- Consumidores con prioridad: `AutoClose` antes que `ScrollVim`. Cada uno devuelve `.pass`, `.consume` o `.replace([CGEvent])`.
- Marca los eventos sintéticos con `eventSourceUserData = 0x544F4F4C` ("TOOL") y **los ignora** al recibirlos, para evitar bucles.
- Gestiona `kCGEventTapDisabledByTimeout` y `kCGEventTapDisabledByUserInput`: vuelve a habilitar el tap con `CGEvent.tapEnable(tap:enable:true)` y registra el evento.
- El callback debe tardar menos de 1 ms: nada de AX síncrono pesado ni de I/O.
- `FrontmostAppTracker` mantiene en caché el `bundleIdentifier` de la app activa. El callback lee ese valor y nunca llama a `NSWorkspace` dentro del tap.

---

## 5. Permisos de macOS y copy de UX

| Permiso | ¿Quién lo necesita? | API de comprobación / petición |
|---|---|---|
| **Accesibilidad** | Scroll Vim, Autocerrar y expansión de Snippets (event tap activo que consume y publica eventos) | `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`; `CGPreflightPostEventAccess()` / `CGRequestPostEventAccess()` |
| **Monitorización de entrada** | Puede pedirlo el sistema al crear un tap de teclado en algunas versiones | `CGPreflightListenEventAccess()` / `CGRequestListenEventAccess()` (solo se muestra el estado y se pide si el tap falla) |
| **Notificaciones** | Descansos | `UNUserNotificationCenter.requestAuthorization([.alert, .sound])` |
| **Grabación de pantalla** | **Ninguno**. `NSColorSampler` no la requiere | No pedirlo. Documentarlo en la Ayuda. |

### Flujo
1. El primer arranque no pide nada. Las features que no necesitan permisos (Descansos, Mantener despierto, Color picker) funcionan al momento.
2. Si el usuario activa Scroll Vim, Autocerrar o Snippets sin Accesibilidad, **no** se marca el check y se abre la ventana `PermissionOnboarding`.
3. Mientras esa ventana está abierta, se consulta `AXIsProcessTrusted()` cada 1 s. Cuando pasa a `true`, la feature pendiente se activa sola y la ventana se cierra.
4. En `menuWillOpen`, si una feature que requiere AX está guardada como activa pero el permiso se ha revocado, se muestra un ítem `⚠️ Falta permiso de Accesibilidad…` encima del separador.

### Copy (referencia en ES; en la app se implementa en **inglés** por defecto, ver §1.1)
- **Título:** "Toolbox necesita permiso de Accesibilidad"
- **Cuerpo:** "Para que *Scroll Vim* y *Autocerrar* funcionen, Toolbox tiene que leer las teclas que pulsas y enviar pulsaciones o scroll en tu nombre. Todo ocurre en tu Mac: no se guarda ni se envía nada de lo que escribes. En los campos de contraseña macOS bloquea este acceso automáticamente."
- **Pasos:** "1. Pulsa *Abrir Ajustes*. 2. En *Privacidad y seguridad › Accesibilidad*, activa **Toolbox**. 3. Vuelve aquí; se activará solo."
- **Botones:** `Abrir Ajustes` (abre `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`) · `Ahora no`
- **Nota de desarrollo** (para el README, no para la UI): al recompilar con otra firma, macOS invalida la concesión. Hay que quitar y volver a añadir la app o usar `tccutil reset Accessibility com.jchicano.toolbox`.

---

## 6. Especificación de las features del MVP

Convención: **CA-x.y** es un criterio de aceptación verificable (manual o con test).

### 6.1 Descansos
**Comportamiento**
- Con la feature activa, `BreakScheduler` cuenta el tiempo de trabajo (por defecto 50 min). Al cumplirse, lanza una notificación: "Hora de descansar ☕ — 5 min". La notificación tiene las acciones `Empezar descanso`, `Posponer 5 min` y `Saltar`.
- Opción "Overlay suave" (desactivada por defecto): una ventana translúcida a pantalla completa en todas las pantallas, con una cuenta atrás y los botones `Saltar` y `Posponer`. Nunca bloquea el teclado de forma dura.
- Si el usuario está inactivo más de 5 min (`CGEventSource.secondsSinceLastEventType(.combinedSessionState, .any)`, consultado cada 30 s) o la pantalla está bloqueada o en reposo (`NSWorkspace.screensDidSleepNotification`, `com.apple.screenIsLocked`), el contador **se pausa**. Si la ausencia supera la duración del descanso, el contador **se reinicia**.
- Submenú: `Siguiente descanso en 23 min` (solo información), `Descansar ahora`, `Intervalo ▸ 25/50/60/90 min`.

**CA**
- CA-1.1: Con un intervalo de prueba de 1 min (flag de debug), la notificación aparece a los 60 s ±2 s.
- CA-1.2: "Posponer 5 min" reprograma el aviso a 5 min ±2 s.
- CA-1.3: Con 6 min de inactividad simulada (reloj inyectado en un test unitario), el contador se reinicia.
- CA-1.4: Al desactivar el toggle se cancelan los timers y las notificaciones pendientes (`removeAllPendingNotificationRequests` del identificador propio).
- CA-1.5: El estado on/off se mantiene tras reiniciar la app.

### 6.2 Mantener despierto
**Comportamiento**
- Al activarse, crea `IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep, …, "Toolbox: Mantener despierto")`. El tipo `PreventUserIdleDisplaySleep` también impide el reposo del sistema por inactividad.
- Submenú de duración: `Indefinido` (por defecto), `15 min`, `1 h`, `2 h`, `Hasta las …` (opcional). Si se elige una duración, se programa un timer que libera la aserción y desmarca el check.
- Opción `Permitir que se apague la pantalla`: usa `kIOPMAssertionTypePreventUserIdleSystemSleep`.
- El icono de la barra de menús muestra un punto o una variante (`cup.and.saucer.fill`) mientras la aserción está activa (opcional pero recomendado).
- Al salir de la app (`applicationWillTerminate`), se libera siempre con `IOPMAssertionRelease`.

**CA**
- CA-2.1: Con la feature activa, `pmset -g assertions` muestra `PreventUserIdleDisplaySleep` con el nombre "Toolbox: Mantener despierto".
- CA-2.2: Al desactivarla, la aserción desaparece de `pmset -g assertions` en menos de 1 s.
- CA-2.3: Con la duración "15 min" (en debug: 10 s), la aserción se libera sola y el check se desmarca.
- CA-2.4: Si se fuerza la salida de la app, la aserción no queda colgada (el kernel la libera al morir el proceso; se verifica con `pmset`).

### 6.3 Scroll Vim (^D / ^U)
**Comportamiento**
- Con la feature activa, `Ctrl+D` hace scroll de media página hacia abajo y `Ctrl+U` media página hacia arriba en la app frontal. El evento de teclado se **consume**.
- Solo se activa con `Ctrl` como **único** modificador: sin ⌘, ⌥ ni ⇧, porque ⇧ queda reservado para un posible ^⇧D.
- **Filtro por app (`AppFilter`)**, en modo denylist por defecto:
  - Denylist por defecto: Terminal (`com.apple.Terminal`), iTerm2 (`com.googlecode.iterm2`), Ghostty (`com.mitchellh.ghostty`), kitty (`net.kovidgoyal.kitty`), Alacritty (`org.alacritty`), WezTerm (`com.github.wez.wezterm`), Warp (`dev.warp.Warp-Stable`), MacVim (`org.vim.MacVim`), Xcode (`com.apple.dt.Xcode`), VS Code (`com.microsoft.VSCode`), Cursor (`com.todesktop.230313mzl4w4u92`), JetBrains (`com.jetbrains.*`, con comodín), Zed (`dev.zed.Zed`), Emacs (`org.gnu.Emacs`).
  - Se puede cambiar a modo allowlist en Preferencias.
- **No actúa dentro de campos de texto**: en Cocoa, `^D` es forward-delete y hay que respetarlo. Para saberlo, se cachea el rol AX del elemento con foco. La caché se actualiza fuera del tap (en un `AXObserver` de `kAXFocusedUIElementChangedNotification` para la app frontal, o cada 250 ms en background como fallback). Si el rol es `AXTextField`, `AXTextArea` o `AXComboBox`, o `AXSearchField` en el subrol, el evento pasa intacto.
- Cálculo de "media página": la altura de la ventana con foco (`kAXFocusedWindowAttribute` → `kAXSizeAttribute`, cacheada) × 0,5. Si no se puede leer, se usan 400 px.
- Scroll: `CGEvent(scrollWheelEvent2Source:units: .pixel, wheelCount: 1, wheel1: ±delta, …)` en la posición actual del ratón. Si el ratón está fuera de la ventana con foco, antes del scroll se mueve **virtualmente** la posición del evento (`event.location`) al centro de esa ventana, sin mover el cursor real.
- Opción de "scroll suave": dividir el delta en 6 eventos separados por 8 ms (activada por defecto; desactivable).

**CA**
- CA-3.1: En Safari, en un artículo largo, `^D` desplaza unos 50 % de la altura visible y `^U` vuelve a la posición anterior (±10 %).
- CA-3.2: En Terminal o iTerm, `^D` llega a la shell (envía EOF / cierra `cat`). Es decir, no se consume.
- CA-3.3: En la barra de direcciones de Safari, o en un `NSTextField` de Notas, `^D` borra hacia delante como siempre.
- CA-3.4: `^⌘D` y `^⇧D` no se interceptan.
- CA-3.5: Al desactivar la feature (y si Autocerrar también está apagado), el tap se destruye: `EventTapManager.isInstalled == false` y no aparece en `CGGetEventTapList`.
- CA-3.6: Test unitario de `AppFilter`: denylist, allowlist, comodín `com.jetbrains.*`.

### 6.4 Autocerrar
**Definición del usuario:** con la feature activa, al escribir un carácter de apertura se inserta su cierre y el cursor queda **entre ambos**. Si a continuación se pulsa **Tab**, el cursor salta **detrás** del cierre.

**Tabla de pares (`PairTable`, configurable)**

| Apertura | Cierre | Por defecto |
|---|---|---|
| `(` | `)` | ✅ |
| `[` | `]` | ✅ |
| `{` | `}` | ✅ |
| `"` | `"` | ✅ |
| `'` | `'` | ✅ (con heurística, ver abajo) |
| `` ` `` | `` ` `` | ✅ |
| `<` | `>` | ⬜ desactivado (choca con `<` como "menor que" en prosa o mates; activable) |
| `¿` | `?` | ✅ |
| `¡` | `!` | ✅ |
| `“` | `”` | ✅ |
| `«` | `»` | ✅ |
| `‘` | `’` | ⬜ |

> La captura muestra `( [ < " ¿` en el título del ítem. El título del menú se genera a partir de los pares activos: `Autocerrar ( [ { " ¿ …`.

**Decisiones clave**
1. **Se trabaja con caracteres, no con keycodes.** El carácter se obtiene con `event.keyboardGetUnicodeString` del `keyDown`. Así funciona con el teclado español (donde `(` es ⇧8, `[` es ⌥`, `¿` es ⇧¡, etc.) y con cualquier layout.
2. **Teclas muertas:** en el teclado español, `` ` `` y `´` son teclas muertas. La primera pulsación produce una cadena vacía y no se hace nada. El carácter compuesto que llega luego (`` ` `` tras pulsar espacio) se recibe como `keyDown` con la cadena final. Si llega con la cadena `` ` ``, se trata como apertura. Si el sistema lo entrega por la vía del IME sin `keyDown` utilizable, no se autocierra (limitación documentada).
3. **Inserción:** se **consume** el `keyDown` original y se publica: (a) un evento Unicode con la cadena `apertura+cierre` (`CGEvent(keyboardEventSource:virtualKey:0,keyDown:true)` + `keyboardSetUnicodeString`, y luego su `keyUp`); (b) una pulsación de `←` (keycode 123). Todo se marca como sintético.
4. **Tab-out:** se mantiene una pila `pending: [Closer]` con un "token de validez". Tab (keycode 48, sin modificadores), con la pila no vacía y el token válido → se consume Tab, se publica `→` (124) y se hace `pop`. Si la pila está vacía, Tab pasa intacto (indentación, cambio de foco, etc.).
5. **Invalidación del estado** (se vacía la pila): clic de ratón, cambio de app frontal, flechas ↑ ↓ ← → (que no sean sintéticas), ⌘ con cualquier tecla, Esc, Return/Enter, Home/End/PageUp/PageDown, cambio de foco AX y 30 s sin teclear.
6. **Overtype** (activado por defecto): si la pila no está vacía y el usuario escribe exactamente el carácter de cierre que está en la cima, se consume, se publica `→` y se hace `pop`. Así no queda `())`.
7. **Backspace de par** (activado por defecto): si lo último que pasó fue una inserción de par y no se ha escrito nada dentro, el Backspace borra la apertura y además se publica `⌦` (forward delete, keycode 117) para borrar el cierre. Luego se hace `pop`.
8. **Heurística para comillas simétricas** (`' " ``): **no** se autocierran si el carácter anterior escrito (según un buffer circular interno de los últimos 8 caracteres, invalidado como la pila) es alfanumérico. Por ejemplo, `don't` o `l'amic` no se tocan. La misma regla vale para `'` tras un dígito (`5'`).
9. **No pelear con apps que ya autocierran.** Modo **denylist** por defecto, con la misma lista que Scroll Vim menos las terminales. Las terminales **también** van en la denylist por defecto, porque en la shell un `"` extra es peligroso. A eso se suman Xcode, VS Code, Cursor, JetBrains, Sublime (`com.sublimetext.4`), Nova (`com.panic.Nova`), Zed, BBEdit (`com.barebones.bbedit`), Obsidian (`md.obsidian`, que tiene autopair propio) y Notion (`notion.id`). Es configurable en Preferencias, con la opción de cambiar a allowlist.
10. **Campos seguros:** cuando hay Secure Input (contraseñas), macOS no entrega las teclas al tap. No hace falta hacer nada; se documenta.
11. **Solo se actúa si el elemento con foco es editable** (rol AX cacheado de texto o `AXWebArea` con `AXEditable`). Si no se puede determinar, se actúa (fail-open). Esto se puede cambiar con `autoClose.requireEditableFocus` (falso por defecto).

**Pseudocódigo del consumidor en el tap**
```swift
// Se ejecuta en el hilo del tap; sin I/O ni AX síncrono.
func handle(_ e: CGEvent, type: CGEventType) -> TapResult {
    if e.isSynthetic(tag: TOOL) { return .pass }
    if type == .leftMouseDown || type == .rightMouseDown { engine.invalidate(); return .pass }
    guard type == .keyDown else { return .pass }
    guard !filter.isBlocked(frontmost.bundleID) else { engine.invalidate(); return .pass }

    let flags = e.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
    let key   = e.keycode
    let chars = e.unicodeString            // "" si es tecla muerta

    switch engine.onKey(keycode: key, chars: chars, flags: flags, now: clock.now) {
    case .pass:                         return .pass
    case .insertPair(let open, let close):
        return .replace(typeString(open + close) + [keyPress(.leftArrow)])
    case .tabOut, .overtype:
        return .replace([keyPress(.rightArrow)])
    case .deletePair:
        return .replace([keyPress(.delete), keyPress(.forwardDelete)])
    }
}
```

**`AutoCloseEngine` (en ToolboxCore, puro y testeable)**
```
state: pending: [Character]   // cierres pendientes (pila)
       lastTyped: RingBuffer<Character>(8)
       justInserted: Bool      // para Backspace de par
       lastEventAt: Date

onKey(keycode, chars, flags, now):
  if now - lastEventAt > 30s → invalidate()
  lastEventAt = now
  if flags ∩ {cmd, ctrl} ≠ ∅          → invalidate(); return .pass
  if keycode ∈ {arrows, esc, return, home, end, pgUp, pgDn} → invalidate(); return .pass
  if keycode == TAB && flags == ∅ && !pending.empty → pending.pop(); justInserted=false; return .tabOut
  if keycode == BACKSPACE && justInserted && !pending.empty → pending.pop(); justInserted=false; return .deletePair
  guard let c = chars.single else { return .pass }      // teclas muertas / múltiple → pass
  if overtypeEnabled && pending.top == c                → pending.pop(); lastTyped.push(c); return .overtype
  if let close = pairs[c], shouldPair(c, prev: lastTyped.last):
        pending.push(close); justInserted = true; lastTyped.push(c); return .insertPair(c, close)
  justInserted = false; lastTyped.push(c); return .pass

shouldPair(c, prev): if c ∈ symmetricQuotes && prev?.isLetterOrNumber == true → false else true
```

**CA**
- CA-4.1: En TextEdit (texto plano), escribir `(` da `(|)`. Escribir `hola` da `(hola|)`. Pulsar Tab da `(hola)|`.
- CA-4.2: Con teclado **español**, `¿` da `¿|?`, y `¿qué tal` + Tab da `¿qué tal?|`.
- CA-4.3: Pares anidados: `([` da `([|])`. Tab da `([]|)`. Tab da `([])|`.
- CA-4.4: Overtype: `(` + `)` da `()|`, sin `())`.
- CA-4.5: Backspace de par: `(` + ⌫ da `|` (borra ambos).
- CA-4.6: `don't` queda tal cual (sin `'` extra). `"hola"` con overtype queda `"hola"|`.
- CA-4.7: Con la pila vacía, Tab funciona normal (en un formulario web cambia de campo).
- CA-4.8: En VS Code, Xcode o Terminal (denylist), no se inserta nada extra.
- CA-4.9: Tras un clic de ratón o un cambio de app, Tab vuelve a funcionar normal (la pila se ha invalidado).
- CA-4.10: En campos de contraseña no hay efecto (Secure Input).
- CA-4.11: Tests unitarios de `AutoCloseEngine` con al menos 25 casos de las secuencias anteriores, incluido el timeout de 30 s con reloj inyectado.
- CA-4.12: Latencia: el callback del tap tarda < 1 ms p99. Se mide con `os_signpost` y en Instruments en ambas arquitecturas.

### 6.5 Color picker
**Comportamiento**
- El ítem `🎨 Color picker` llama a `NSColorSampler().show { color in … }`. Aparece la lupa del sistema; Esc cancela.
- El color se convierte al espacio **sRGB** (`color.usingColorSpace(.sRGB)`) y se copia al portapapeles en el formato por defecto (`#RRGGBB`, mayúsculas).
- El submenú `Formato ▸ HEX / rgb() / hsl() / SwiftUI Color / NSColor` cambia el formato por defecto.
- El submenú `Recientes ▸` muestra los últimos 10 colores con un swatch (un `NSImage` de 12×12) y su valor. Al hacer clic, se copia de nuevo.
- Un HUD breve (`NSPanel` no activante, 1,2 s) muestra "Copiado #1E90FF".

**CA**
- CA-5.1: Al seleccionar un píxel blanco puro, el portapapeles contiene `#FFFFFF`.
- CA-5.2: Con Esc no se modifica el portapapeles.
- CA-5.3: No se solicita el permiso de Grabación de pantalla en ningún momento (se verifica en Ajustes: Toolbox no aparece en esa lista).
- CA-5.4: Tests unitarios de `ColorFormatter`: `(30,144,255)` → `#1E90FF`, `rgb(30, 144, 255)`, `hsl(210, 100%, 56%)`.
- CA-5.5: Los recientes se mantienen tras reiniciar (hasta 10, el más nuevo primero, sin duplicados consecutivos).

### 6.6 Snippets (MVP)
**Comportamiento**
- El usuario define snippets `{ trigger, title, body, enabled }`. Ejemplos: `;sig` → firma, `;mail` → email, `;addr` → dirección.
- **Expansión por trigger** (requiere Accesibilidad, usa el `EventTapManager`): `SnippetEngine` mantiene un buffer de los últimos N caracteres tecleados (N = longitud del trigger más largo, máx. 32). Cuando el sufijo coincide con un trigger y el siguiente carácter es un delimitador (espacio, Tab, Return o puntuación; configurable `expandImmediately` para expandir sin delimitador), se publican `trigger.count` backspaces y se inserta el cuerpo (vía `keyboardSetUnicodeString` en trozos de ≤ 20 UTF-16, o pegando con el portapapeles para cuerpos > 200 caracteres, restaurando el portapapeles anterior).
- **Variables** en el cuerpo: `{clipboard}`, `{date}` (formato ISO `yyyy-MM-dd`, configurable), `{time}` (`HH:mm`) y `{cursor}` (posición final del cursor: tras insertar se publican tantos `←` como caracteres haya detrás de `{cursor}`). `{{` escapa la llave.
- **Inserción buscable desde el menú:** submenú `Insert Snippet…` que abre un pequeño `NSPanel` con campo de búsqueda (fuzzy por título y trigger) y lista; Return inserta en la app que tenía el foco (se reactiva la app previa y se pega). Funciona aunque la expansión por trigger esté apagada o sin Accesibilidad (usa portapapeles + ⌘V simulado, que sí requiere AX; sin AX, solo copia al portapapeles y muestra el HUD "Copied").
- Mismo filtro por app (`AppFilter`, denylist vacía por defecto salvo terminales opcionales) e invalidación de buffer que Autocerrar (clic, cambio de app, flechas, ⌘).
- Coordinación con Autocerrar: Snippets se evalúa **antes** que Autocerrar en el tap; el texto insertado es sintético, así que Autocerrar no lo toca.
- Persistencia: `~/Library/Application Support/Toolbox/snippets.json` (Codable, versionado). Edición en Preferencias › Snippets (tabla añadir/editar/borrar, importar/exportar JSON). En F10 el YAML puede **añadir** snippets de solo lectura, pero la fuente principal es este JSON.

**CA**
- CA-6.1: En TextEdit, `;sig` + espacio se sustituye por el cuerpo; no quedan restos del trigger.
- CA-6.2: `{date}` produce la fecha actual; `{clipboard}` el contenido actual; `{cursor}` deja el cursor en la posición marcada.
- CA-6.3: `Insert Snippet…` → buscar "sig" → Return inserta en la app previa (Notas, Slack, Safari).
- CA-6.4: Sin Accesibilidad, el picker copia al portapapeles y avisa; no se bloquea nada.
- CA-6.5: Tests unitarios de `SnippetEngine` (≥ 15 casos: coincidencia, delimitadores, prefijos solapados `;s`/`;sig`, invalidación, Unicode/acentos) y de `SnippetTemplate` (variables, escape, cursor).
- CA-6.6: Desactivar el toggle elimina el consumidor del tap (y el tap si no queda ninguno); los snippets persisten tras reiniciar.
- CA-6.7: El texto expandido no dispara Autocerrar ni otros triggers (marca sintética).

### 6.7 Separador, Ayuda y Salir
- **Ayuda**: abre una ventana SwiftUI con una descripción breve de cada utilidad, atajos, el **estado de los permisos** (✅/❌ y un botón "Abrir Ajustes"), la versión y la build (`arm64`/`x86_64` en ejecución, vía `sysctl hw.optional.arm64` o `#if arch`), y un enlace al README.
- **Salir de Toolbox**: `NSApp.terminate`. Antes el registry llama a `stop()` en todas las features (libera la aserción de energía, destruye el tap y cancela los timers).
- Strings de UI por defecto en inglés (`Help`, `Preferences…`, `Launch at Login`, `Quit Toolbox`).
- Extra en el menú del MVP (debajo de Ayuda): `Abrir al iniciar sesión` (toggle de `SMAppService`) y `Preferencias…` (⌘,).

**CA**
- CA-7.1: La Ayuda muestra el estado real de Accesibilidad. Al revocarlo en Ajustes y reabrir la Ayuda, pasa a ❌.
- CA-7.2: "Abrir al iniciar sesión" queda reflejado en *Ajustes › General › Ítems de inicio*.
- CA-7.3: Tras salir, `pmset -g assertions` no muestra Toolbox y no quedan procesos de Toolbox vivos.

---

## 7. Modelo de datos y preferencias

### 7.1 `UserDefaults` (estado y prefs; clave raíz `toolbox.settings`, JSON Codable versionado)
```swift
struct Settings: Codable, Equatable {
    var schemaVersion = 1
    var enabled: Set<FeatureID> = []                  // persistencia de checks

    var breaks = BreaksSettings()
    struct BreaksSettings: Codable, Equatable {
        var workMinutes = 50; var breakMinutes = 5
        var idleResetMinutes = 5; var overlay = false; var sound = true
    }

    var keepAwake = KeepAwakeSettings()
    struct KeepAwakeSettings: Codable, Equatable {
        var allowDisplaySleep = false
        var defaultDuration: Duration? = nil          // nil = indefinido
    }

    var scrollVim = ScrollVimSettings()
    struct ScrollVimSettings: Codable, Equatable {
        var filter = AppFilter(mode: .denylist, bundleIDs: AppFilter.defaultScrollDeny)
        var smooth = true; var fraction = 0.5; var skipTextFields = true
    }

    var autoClose = AutoCloseSettings()
    struct AutoCloseSettings: Codable, Equatable {
        var pairs: [Pair] = Pair.defaults             // Pair(open:"(", close:")", enabled:true)
        var tabOut = true; var overtype = true; var deletePair = true
        var smartQuotes = true                        // heurística alfanumérica
        var requireEditableFocus = false
        var filter = AppFilter(mode: .denylist, bundleIDs: AppFilter.defaultAutoCloseDeny)
    }

    var colorPicker = ColorPickerSettings()
    struct ColorPickerSettings: Codable, Equatable {
        var format: ColorFormat = .hex; var uppercase = true
        var recents: [String] = []                    // hex sRGB, máx. 10
    }
    var snippets = SnippetsSettings()               // el contenido va en snippets.json
    struct SnippetsSettings: Codable, Equatable {
        var expandOnDelimiter = true; var expandImmediately = false
        var dateFormat = "yyyy-MM-dd"; var timeFormat = "HH:mm"
        var filter = AppFilter(mode: .denylist, bundleIDs: [])
    }
    var launchAtLogin = false
}

struct Snippet: Codable, Equatable, Identifiable {  // snippets.json: { "version": 1, "snippets": [Snippet] }
    var id: UUID; var trigger: String; var title: String; var body: String; var enabled = true
}

struct AppFilter: Codable, Equatable {
    enum Mode: String, Codable { case denylist, allowlist }
    var mode: Mode; var bundleIDs: [String]           // admite sufijo ".*"
    func allows(_ bundleID: String?) -> Bool
}
```
- Las migraciones se hacen por `schemaVersion`. Si la decodificación falla, se registra en el log, se hace backup de la clave antigua (`toolbox.settings.bak`) y se cargan los valores por defecto.

### 7.2 Fichero de usuario (F10, SuperBar-style): `~/.config/toolbox/config.yml`
Esquema propio (inspirado en SuperBar, no compatible con él). Alcance cerrado a cuatro bloques: **bookmarks**, **workspaces**, **commands** y **sections** (secciones de menú custom que mezclan ítems de los anteriores). Se pueden incluir ficheros extra con `include:` (p. ej. `~/.config/toolbox/work.yml`). Yams solo se usa aquí.
```yaml
version: 1
include: ["~/.config/toolbox/work.yml"]   # optional, merged in order
bookmarks:
  - { id: gmail, title: "📬 Gmail", url: "https://mail.google.com" }
  - { id: gh,    title: "🐙 GitHub", url: "https://github.com" }
workspaces:
  - { id: dev, title: "💻 Dev", apps: ["Cursor", "iTerm", "Safari"], urls: ["http://localhost:3000"] }
commands:
  - { id: flushdns, title: "Flush DNS", run: terminal, command: "sudo dscacheutil -flushcache" }
  - { id: disk,     title: "Disk usage", run: shell, command: "df -h", output: notification }
  - { id: branch,   title: "🌿 Git: current branch", run: shell, command: "git -C ~/code/app branch --show-current", output: clipboard }
  - { id: dark,     title: "🌗 Toggle dark mode", run: builtin, action: toggle_dark_mode }
sections:                                   # rendered below the core features, in this order
  - { title: "🔖 Bookmarks", items: [gmail, gh] }
  - { title: "🧰 Workspaces", items: [dev] }
  - { title: "⚙️ Commands", items: [flushdns, disk, branch, dark] }
snippets:                                   # optional, read-only, merged into the MVP snippets
  - { trigger: ";yml", title: "From YAML", body: "hello" }
```
- Acciones resultantes: bookmark → `open_url`; workspace → `launch_apps` (+ URLs); command `run: terminal` → `run_terminal`; `run: shell` → `run_shell`; `run: builtin` → `toggle_dark_mode`. Detalle: `open_url`, `launch_apps`, `run_terminal` (abre Terminal o iTerm con el comando vía AppleScript, lo que requiere el permiso **Automatización**), `run_shell` (con `Process` en `/bin/zsh -lc`, timeout de 30 s, salida a `notification`, `clipboard` o `none`) y `toggle_dark_mode` (AppleScript a System Events, también con permiso de Automatización).
- Ítems del menú `Editar config…` (abre el fichero en el editor por defecto, creándolo desde una plantilla si no existe) y `Recargar config` (⌘R). Además hay un **FSEvents watcher** opcional que recarga automáticamente.
- Si hay errores de validación, se muestra un ítem `⚠️ config.yml: línea 12 — acción desconocida "opn_url"` y se conserva el último config válido.

---

## 8. Estructura de carpetas del repo

```
toolbox/
├── README.md                      # English: install, permissions, build, tccutil reset
├── LICENSE                        # MIT
├── CHANGELOG.md                   # English release notes
├── project.yml                    # XcodeGen (target app + tests)
├── Makefile                       # bootstrap, gen, build, test, universal, dmg, notarize
├── .swiftlint.yml / .swift-format # opcional
├── Config/
│   ├── Toolbox.entitlements       # sin sandbox; apple-events (fase 2)
│   ├── Info.plist                 # LSUIElement, NSAppleEventsUsageDescription
│   └── Release.xcconfig           # ARCHS, MACOSX_DEPLOYMENT_TARGET=13.0, hardened runtime
├── App/
│   ├── ToolboxApp.swift           # @main + NSApplicationDelegateAdaptor
│   ├── AppDelegate.swift
│   ├── StatusItem/
│   │   ├── StatusItemController.swift
│   │   └── MenuBuilder.swift
│   ├── Features/
│   │   ├── Feature.swift
│   │   ├── FeatureRegistry.swift
│   │   ├── Breaks/ (BreaksFeature.swift, BreakOverlayWindow.swift)
│   │   ├── KeepAwake/KeepAwakeFeature.swift
│   │   ├── ScrollVim/ (ScrollVimFeature.swift, ScrollPoster.swift)
│   │   ├── AutoClose/ (AutoCloseFeature.swift, KeyPoster.swift)
│   │   ├── Snippets/ (SnippetsFeature.swift, SnippetPickerPanel.swift, TextInserter.swift)
│   │   ├── ColorPicker/ (ColorPickerAction.swift, CopiedHUD.swift)
│   │   └── FeatureCatalog.swift   # descriptors: order, permissions, kind
│   ├── Input/
│   │   ├── EventTapManager.swift
│   │   ├── FrontmostAppTracker.swift
│   │   └── FocusedElementCache.swift   # AXObserver: rol + tamaño de ventana
│   ├── System/
│   │   ├── PermissionsService.swift
│   │   ├── LoginItemService.swift
│   │   └── Notifications.swift
│   ├── Persistence/SettingsStore.swift
│   ├── UI/ (HelpView.swift, PreferencesView.swift, PermissionOnboardingView.swift)
│   └── Resources/ (Assets.xcassets, Localizable.xcstrings [en por defecto; es opcional futuro])
├── Packages/ToolboxCore/
│   ├── Package.swift
│   ├── Sources/ToolboxCore/
│   │   ├── AutoClose/ (AutoCloseEngine.swift, PairTable.swift, RingBuffer.swift)
│   │   ├── Breaks/BreakScheduler.swift
│   │   ├── Filtering/AppFilter.swift
│   │   ├── Color/ColorFormatter.swift
│   │   ├── Snippets/ (SnippetEngine.swift, SnippetTemplate.swift, SnippetStore.swift)
│   │   ├── Settings/Settings.swift
│   │   ├── Util/Clock.swift            # protocolo reloj inyectable
│   │   └── Config/ (F10: ConfigModel.swift, YAMLLoader.swift, Validator.swift)
│   └── Tests/ToolboxCoreTests/ (AutoCloseEngineTests, SnippetEngineTests, SnippetTemplateTests, BreakSchedulerTests, AppFilterTests, ColorFormatterTests, SettingsMigrationTests, ConfigTests)
├── Tests/ToolboxAppTests/          # tests de integración ligeros (MenuBuilder, SettingsStore)
├── scripts/
│   ├── build-universal.sh
│   ├── verify-universal.sh         # lipo -archs → "x86_64 arm64"
│   ├── make-dmg.sh                 # hdiutil (o create-dmg si está instalado)
│   └── notarize.sh                 # notarytool submit --wait + stapler staple
└── docs/
    ├── PLAN.md                     # este documento (interno, en español; o mantenerlo fuera del repo público)
    ├── MANUAL_QA.md                # checklist §10.2
    └── PERMISSIONS.md
```

---

## 9. Fases de implementación

Regla común a todas las fases: código, comentarios, strings de UI, commits y PRs en **inglés** (§1.1).

| Fase | Contenido | Depende de | Definition of Done |
|---|---|---|---|
| **F0 – Bootstrap** | Repo, `LICENSE` MIT, README en inglés (esqueleto), `project.yml`, `Makefile`, paquete `ToolboxCore` vacío con un test, app `LSUIElement` con un `NSStatusItem` y un menú con solo "Quit Toolbox". Firma ad-hoc en local. | — | `make gen && make build` compila; `make test` pasa; al lanzar la app aparece el icono y Quit funciona; `lipo -archs` del Release devuelve `x86_64 arm64`; README/LICENSE presentes en inglés. |
| **F1 – Núcleo y catálogo** | `FeatureDescriptor`, `FeatureCatalog`, protocolo `Feature` (start/stop), `FeatureRegistry` (gating de permisos), `SettingsStore` (+ migración), `MenuBuilder` generado desde el catálogo, Help (v0), login item, `Localizable.xcstrings` con `en` por defecto. | F0 | Toggles "fake" del catálogo se mantienen tras reiniciar; el menú coincide en orden con §0 y en inglés; añadir una feature de prueba solo requiere descriptor + clase; tests de `Settings` y del registry (start/stop idempotente) en verde. |
| **F2 – Features sin permisos** | Mantener despierto, Descansos y Color picker. | F1 | CA-1.x, CA-2.x y CA-5.x en verde (unit + manual). |
| **F3 – Infra de input** | `PermissionsService`, onboarding, `EventTapManager` (instalar/destruir bajo demanda, re-enable, marca sintética), `FrontmostAppTracker`, `FocusedElementCache`, `AppFilter`, `TextInserter` compartido. | F1 | Un consumidor de debug registra las teclas en `os_log` solo en debug; el tap se instala o destruye según haya consumidores; la re-habilitación tras un timeout está probada; el onboarding activa la feature al conceder AX. |
| **F4 – Scroll Vim** | Consumidor + `ScrollPoster`. | F3 | CA-3.x en verde en Intel y ARM. |
| **F5 – Autocerrar** | `AutoCloseEngine` (TDD en Core) + `AutoCloseFeature` + `KeyPoster`. | F3 | CA-4.x en verde, incluidos el teclado español y la latencia. |
| **F6 – Snippets** | `SnippetEngine`, `SnippetTemplate`, `SnippetStore` (JSON), `SnippetsFeature` (consumidor del tap, prioridad sobre Autocerrar), picker buscable `Insert Snippet…`. | F3 (F5 para coordinación) | CA-6.x en verde; latencia del tap sigue < 1 ms p99 con Snippets + Autocerrar activos. |
| **F7 – Preferencias y Ayuda final** | Ventana de preferencias (pestañas: General, Breaks, Keep Awake, Vim Scroll, Auto-close con tabla de pares y lista de apps, Snippets con editor, Color), Ayuda completa, revisión de strings en inglés. | F2, F4, F5, F6 | Todas las opciones de §7.1 son editables y tienen efecto en caliente; ninguna string de UI en español en la build por defecto. |
| **F8 – Empaquetado** | Script universal, firma con Developer ID, hardened runtime, notarización, DMG, `CHANGELOG.md` en inglés. | F7 | `spctl -a -vv Toolbox.app` → `accepted, source=Notarized Developer ID`; el DMG se abre y la app arranca en una máquina limpia Intel y otra ARM. **Fin del MVP.** |
| **F9 – Release MVP** | README final en inglés (features, permisos, build, limitaciones, licencia MIT), release notes en inglés, QA M1–M17 firmada. | F8 | Checklist §10.2 (MVP) completo en ambas arquitecturas. |
| **F10 – Fase 2 YAML (SuperBar-style)** | Yams; `config.yml` con bookmarks, workspaces, commands, sections, `include:` y snippets de solo lectura; Edit/Reload; watcher; Automatización. | F9 | `ConfigTests` (válido, inválido con línea, ids desconocidos, include) en verde y M18 OK. |

Orden crítico: F0 → F1 → (F2 ‖ F3) → (F4 ‖ F5) → F6 → F7 → F8 → F9 → F10.

---

## 10. Testing

### 10.1 Automático
- `swift test` en `Packages/ToolboxCore` (rápido, sin UI) para `AutoCloseEngine`, `SnippetEngine`, `SnippetTemplate`, `BreakScheduler` (reloj fake), `AppFilter`, `ColorFormatter`, `Settings` (round-trip y migración) y `Config` (F10).
- Test de `FeatureRegistry`: start/stop idempotente, gating por permisos y restauración del estado.
- `xcodebuild test -scheme Toolbox -destination 'platform=macOS,arch=arm64'` y también con `arch=x86_64` (Rosetta en ARM) para `MenuBuilder` y `SettingsStore`.
- `make verify-universal`: `lipo -archs Toolbox.app/Contents/MacOS/Toolbox` debe dar `x86_64 arm64`.
- CI (opcional, si el propietario lo pide): un workflow de GitHub Actions con `macos-14` (ARM) que ejecute `swift test` + `xcodebuild build` universal. **Este plan no crea el CI.**

### 10.2 Checklist manual (hay que ejecutarlo en **Intel** y en **Apple Silicon**; marcar ambas columnas)
| # | Prueba | Intel | ARM |
|---|---|---|---|
| M1 | La app arranca sin icono en el Dock; el icono aparece en la barra de menús | ☐ | ☐ |
| M2 | Orden y títulos del menú = §0, **en inglés**; los checks se mantienen tras reiniciar | ☐ | ☐ |
| M3 | Mantener despierto: `pmset -g assertions` aparece y desaparece; la duración funciona | ☐ | ☐ |
| M4 | Descansos: notificación, posponer, saltar, pausa por inactividad o bloqueo | ☐ | ☐ |
| M5 | Color picker: hex correcto, Esc cancela, recientes, sin permiso de pantalla | ☐ | ☐ |
| M6 | Onboarding de Accesibilidad: denegar → no se activa; conceder → se activa solo | ☐ | ☐ |
| M7 | Scroll Vim: Safari, Chrome, Mail, Finder (lista), Notas fuera del campo de texto | ☐ | ☐ |
| M8 | Scroll Vim: Terminal, iTerm y VS Code no se ven afectados; `^D` en campo de texto = borrar | ☐ | ☐ |
| M9 | Autocerrar: CA-4.1 a 4.7 en TextEdit, Notas, Slack, campos de texto de Safari y Chrome | ☐ | ☐ |
| M10 | Autocerrar con teclado **Español – ISO**: `¿`, `¡`, `(`, `[`, `{`, `"`, `'`, `` ` `` (tecla muerta) | ☐ | ☐ |
| M11 | Autocerrar no actúa en VS Code, Xcode, Terminal ni en campos de contraseña | ☐ | ☐ |
| M12 | Revocar Accesibilidad con la app abierta → aparece el aviso ⚠️ en el menú y no se bloquea la entrada | ☐ | ☐ |
| M13 | Suspender y reanudar el Mac: el tap sigue funcionando y los timers se reprograman | ☐ | ☐ |
| M14 | Monitor de Actividad: < 30 MB, ~0 % CPU en reposo con todas las features activas | ☐ | ☐ |
| M15 | Salir: no queda ninguna aserción ni proceso | ☐ | ☐ |
| M16 | (F8) Notarizada: abrir el DMG en una cuenta nueva sin avisos de Gatekeeper | ☐ | ☐ |
| M17 | Snippets: `;sig` en TextEdit, Notas, Slack, Safari; variables; picker `Insert Snippet…`; sin AX copia al portapapeles | ☐ | ☐ |
| M18 | (F10) Edit config, Reload, error de YAML visible, bookmarks, workspaces, run_terminal, modo oscuro, `include:` | ☐ | ☐ |

---

## 11. Empaquetado

1. **Build universal:**
   ```bash
   xcodebuild -scheme Toolbox -configuration Release \
     ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
     -derivedDataPath build archive -archivePath build/Toolbox.xcarchive
   ```
   Después, `lipo -archs …/Toolbox` debe dar `x86_64 arm64`.
2. **Firma:** `Developer ID Application: <Nombre> (<TEAMID>)`, `ENABLE_HARDENED_RUNTIME=YES`, `--options runtime --timestamp`. Entitlements: **sin** `com.apple.security.app-sandbox`; en F10, `com.apple.security.automation.apple-events = true`.
3. **Exportación:** `xcodebuild -exportArchive` con `ExportOptions.plist` (`method = developer-id`).
4. **Notarización:** `xcrun notarytool submit Toolbox.zip --keychain-profile toolbox-notary --wait`, luego `xcrun stapler staple Toolbox.app`. El perfil se crea **una vez, a mano, por el propietario** (`notarytool store-credentials`). El agente no maneja credenciales de Apple.
5. **DMG (opcional):** `hdiutil create -volname Toolbox -srcfolder dist/ -ov -format UDZO Toolbox.dmg`, con un enlace a `/Applications`. Luego firmar y notarizar también el DMG.
6. **Sin certificado:** los builds locales llevan firma ad-hoc (`CODE_SIGN_IDENTITY=-`). El README explica que hay que hacer clic derecho → Abrir y que el permiso de Accesibilidad se pierde en cada rebuild.
7. **Backlog:** Sparkle 2 (appcast + EdDSA), Homebrew cask.

---

## 12. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| **Sandbox / App Store.** Un `CGEventTap` global que consume y publica teclas y `AXUIElement` en otras apps **no** son compatibles con el App Sandbox. Las utilidades de barra de menús con Accesibilidad se distribuyen **fuera de la App Store y sin sandbox**. | No hay App Store. | Decisión explícita: distribución con Developer ID y notarización, sandbox desactivado, hardened runtime activado. Se documenta en el README. |
| El tap se desactiva por timeout si el callback es lento | Teclado "atascado" o features muertas | El callback es O(1), sin AX síncrono ni I/O; se re-habilita en `tapDisabledByTimeout`; signposts. |
| Bucle de eventos sintéticos | Teclas repetidas sin fin | Marca `eventSourceUserData` y se ignora; test de debug. |
| Autocerrar choca con apps que ya autocierran | Caracteres duplicados | Denylist por defecto amplia; overtype; filtros editables. |
| Teclado español y teclas muertas (`` ` ``, `´`, `^`) | Autocierre inconsistente | Se trabaja con la cadena Unicode resuelta; las teclas muertas → pass; QA M10. Limitación documentada. |
| `←`/`→` sintéticos en apps con un modelo de cursor raro (webviews complejos, Google Docs) | Cursor mal colocado | Tab-out solo con la pila válida; invalidación agresiva; añadir a la denylist desde Preferencias. |
| `^D` = forward delete en Cocoa | Romper la edición | No actuar en campos de texto (rol AX cacheado). |
| Rol AX no disponible (Electron, apps sin AX) | Falsos positivos | Fail-open para Autocerrar y fail-safe para Scroll Vim (si no se sabe el rol en una app Electron, Scroll Vim actúa igualmente; configurable). |
| Permiso de Accesibilidad invalidado al recompilar o cambiar la firma | Confusión en el desarrollo | README + `tccutil reset`; Ayuda con el estado real. |
| Secure Input activo (otra app lo deja encendido) | Features de teclado mudas | En la Ayuda, detectar `IsSecureEventInputEnabled()` y mostrar el aviso "Secure Input activo (app X)". |
| Descansos molestos | Desinstalación | El overlay viene desactivado por defecto; siempre se puede saltar o posponer. |
| Diferencias entre Intel y ARM (scroll en píxeles, rendimiento) | Comportamiento distinto | QA en ambas arquitecturas; tests en `arch=x86_64` con Rosetta. |
| Propiedad intelectual de SuperBar | Legal | No se copia código, assets ni formato literal; solo se toma inspiración funcional. |
| Licencia / marca de Vorssaint (GPL-3) | Contaminar MIT; conflicto de marca | No se copia código, strings ni iconos; nombre y bundle propios; reimplementación con APIs públicas; mención solo como "inspired by" en README si se desea. |
| Scope creep hacia "Vorssaint completo" | App pesada, mantenimiento | Lista explícita de fuera de alcance (§1); cada feature nueva necesita descriptor en el catálogo y justificación; objetivo < 30 MB RAM. |
| Snippets: expansión incorrecta o en campos sensibles | Texto basura / fugas | Delimitador obligatorio por defecto; buffer invalidado como Autocerrar; Secure Input bloquea el tap; restaurar el portapapeles tras pegar; denylist por app. |
| Snippets + Autocerrar en el mismo tap | Interferencias, latencia | Orden fijo (Snippets → Autocerrar → Scroll Vim); eventos sintéticos marcados; signposts con ambos activos. |
| Strings en español colándose en la UI pública | Inconsistencia | Locale de desarrollo `en`; revisión en F7 (`grep` de caracteres `¿¡áéíóúñ` en `.swift` fuera de tests de Autocerrar). |

---

## 13. Checklist de tareas (para ir marcando)

### F0 – Bootstrap
- [x] 1. Crear el repo `toolbox/` con la estructura de §8 (carpetas vacías + `.gitignore` de Xcode/SPM), `LICENSE` MIT y README esqueleto **en inglés**.
- [x] 2. Escribir `project.yml` (XcodeGen): target `Toolbox` (app, macOS 13, `LSUIElement`, development region `en`), target `ToolboxAppTests`, dependencia local `Packages/ToolboxCore`.
- [x] 3. Crear `Packages/ToolboxCore/Package.swift` (macOS 13) con un test dummy.
- [x] 4. `Makefile`: `bootstrap` (brew install xcodegen), `gen`, `build`, `test`, `universal`, `verify-universal`, `dmg`, `notarize`.
- [x] 5. `Release.xcconfig`: `ARCHS = arm64 x86_64`, `ONLY_ACTIVE_ARCH = NO`, `MACOSX_DEPLOYMENT_TARGET = 13.0`, `ENABLE_HARDENED_RUNTIME = YES`.
- [x] 6. `Toolbox.entitlements` sin sandbox.
- [x] 7. `AppDelegate` + `StatusItemController` con el icono template y el ítem "Quit Toolbox".
- [x] 8. `scripts/verify-universal.sh` y comprobar que devuelve `x86_64 arm64`.

### F1 – Núcleo y catálogo
- [x] 9. `Settings` (Codable, versionado, incluye `snippets`) + `SettingsMigrationTests`.
- [x] 10. `SettingsStore` (UserDefaults, publicación de cambios con Combine u Observation).
- [x] 11. `FeatureDescriptor`, `Permission`, `FeatureKind` y `FeatureCatalog` (orden de §0).
- [x] 12. Protocolo `Feature` (`start`/`stop` idempotentes) + `FeatureRegistry` (gating de permisos, persistencia de `enabled`, `stopAll` en terminate) + tests.
- [x] 13. `MenuBuilder` generado desde el catálogo: checks, submenús, separador, Help, Preferences…, Launch at Login, Quit.
- [x] 14. `Localizable.xcstrings` con `en` como idioma base; todas las strings vía `String(localized:)`.
- [x] 15. `LoginItemService` (`SMAppService.mainApp`).
- [x] 16. Ventana de Help v0 (SwiftUI) con la versión y la arquitectura en ejecución.
- [x] 17. Restaurar el estado de las features al arrancar (las que no necesitan permisos primero).

### F2 – Features sin permisos
- [x] 18. `KeepAwakeFeature` (IOPMAssertion, duraciones, liberar en `stop`) + CA-2.x.
- [x] 19. `BreakScheduler` en Core (reloj inyectable) + tests de CA-1.3.
- [x] 20. `BreaksFeature`: notificaciones con acciones, detección de inactividad y bloqueo, submenú de intervalo.
- [x] 21. `BreakOverlayWindow` opcional (multipantalla, Skip/Snooze).
- [x] 22. `ColorFormatter` en Core + tests de CA-5.4.
- [x] 23. `ColorPickerAction` (NSColorSampler, sRGB, portapapeles, recientes, HUD).

### F3 – Infra de input
- [x] 24. `PermissionsService` (AX, Post/Listen event access, notificaciones, Secure Input).
- [x] 25. `PermissionOnboardingView` con el copy de §5 **traducido al inglés** y polling cada 1 s.
- [x] 26. `FrontmostAppTracker` (NSWorkspace, bundleID cacheado y atómico).
- [x] 27. `FocusedElementCache` (AXObserver de la app frontal: rol con foco, tamaño de la ventana con foco).
- [x] 28. `AppFilter` en Core (denylist/allowlist, comodín `.*`) + tests.
- [x] 29. `EventTapManager`: hilo propio, instalar/destruir bajo demanda, consumidores con prioridad (Snippets → AutoClose → ScrollVim), `.pass/.consume/.replace`, marca sintética, re-enable por timeout, signposts.
- [x] 30. `TextInserter` compartido (Unicode por trozos, pegado vía portapapeles con restauración) y `KeyPoster` (←, →, ⌫, ⌦) con marca sintética.
- [x] 31. Aviso ⚠️ en el menú si falta un permiso con la feature guardada como activa.

### F4 – Scroll Vim
- [x] 32. `ScrollPoster` (scroll en píxeles, modo suave, ubicación virtual en el centro de la ventana).
- [x] 33. `ScrollVimFeature`: solo `Ctrl` + D/U, filtro por app, omitir campos de texto.
- [x] 34. Verificar CA-3.1 a CA-3.6.

### F5 – Autocerrar
- [x] 35. `RingBuffer` y `PairTable` (pares por defecto de §6.4) en Core.
- [x] 36. `AutoCloseEngine` con TDD: ≥ 25 casos (insertar, anidar, tab-out, overtype, backspace de par, comillas inteligentes, invalidaciones, timeout).
- [x] 37. `AutoCloseFeature`: conectar el motor al tap, filtro por app, invalidación por ratón y cambio de app.
- [x] 38. Título dinámico del ítem del menú según los pares activos.
- [x] 39. Verificar CA-4.1 a CA-4.12 (incluido el teclado español y la latencia en Instruments).

### F6 – Snippets
- [x] 40. `Snippet` + `SnippetStore` (JSON en Application Support, versionado, import/export) en Core.
- [x] 41. `SnippetTemplate` con TDD: `{clipboard}`, `{date}`, `{time}`, `{cursor}`, escape `{{`.
- [x] 42. `SnippetEngine` con TDD (≥ 15 casos: delimitadores, prefijos solapados, invalidación, Unicode).
- [x] 43. `SnippetsFeature`: consumidor del tap, backspaces del trigger + `TextInserter`, colocación de `{cursor}`, filtro por app.
- [x] 44. `SnippetPickerPanel` (`Insert Snippet…`): búsqueda fuzzy, Return inserta en la app previa; fallback sin AX a portapapeles + HUD.
- [x] 45. Snippets de ejemplo en primer arranque (`;date`, `;sig` vacío editable) y verificar CA-6.1 a CA-6.7.

### F7 – Preferencias y Ayuda
- [x] 46. `PreferencesView` con pestañas (§9 F7), selector de apps (`NSOpenPanel` en `/Applications` → bundleID).
- [x] 47. Pestaña Snippets: tabla añadir/editar/borrar, toggle por snippet, import/export.
- [x] 48. Help completa: descripción de las utilidades, permisos ✅/❌, Secure Input, enlace al README.
- [x] 49. Auditoría de idioma: ninguna string de UI, comentario ni identificador en español (salvo datos de tests y pares `¿¡`).
- [ ] 50. Checklist manual M1–M15 y M17 en Intel y en ARM; guardar los resultados en `docs/MANUAL_QA.md`.

### F8 – Empaquetado
- [x] 51. `scripts/build-universal.sh` (archive + export, Developer ID).
- [x] 52. `scripts/notarize.sh` (notarytool + stapler; usa el perfil del llavero creado por el propietario).
- [x] 53. `scripts/make-dmg.sh` + firmar y notarizar el DMG.
- [ ] 54. Comprobar `spctl -a -vv` y M16. (PENDING Developer ID: ad-hoc verified — hardened runtime on, `spctl` rejects as expected without notarization)

### F9 – Release MVP
- [x] 55. README final en inglés: features, permisos, build local ad-hoc, `tccutil reset`, limitaciones (teclas muertas, Secure Input, sin App Store), licencia MIT, "not affiliated with Vorssaint/SuperBar".
- [x] 56. `CHANGELOG.md` y release notes `v0.1.0` en inglés.

### F10 – Fase 2 YAML (SuperBar-style)
- [ ] 57. Añadir la dependencia Yams; `ConfigModel` (bookmarks, workspaces, commands, sections, snippets, include) + `YAMLLoader` + `Validator` con errores por línea + `ConfigTests`.
- [ ] 58. Plantilla de `~/.config/toolbox/config.yml` (en inglés) y los ítems `Edit Config…` y `Reload Config` (⌘R).
- [ ] 59. Render de `sections` en el menú bajo las features del núcleo, resolviendo ids; ids desconocidos → ⚠️.
- [ ] 60. Bookmarks (`open_url`) y workspaces (`launch_apps` + URLs).
- [ ] 61. Commands `run: shell` (timeout 30 s, salida) y `run: terminal` (Terminal o iTerm vía AppleScript, `NSAppleEventsUsageDescription`).
- [ ] 62. `run: builtin` → `toggle_dark_mode` (System Events) + manejo de la denegación de Automatización.
- [ ] 63. `include:` y fusión de snippets YAML (solo lectura) con los del JSON.
- [ ] 64. Watcher FSEvents opcional para la recarga automática + QA M18.

### Backlog
- [ ] 65. Sparkle 2 (autoupdate) y Homebrew cask.
- [ ] 66. Atajos globales configurables para cada toggle y para `Insert Snippet…`.
- [ ] 67. Scroll Vim extendido (`gg`/`G`, `j`/`k`) y Autocerrar con reglas por app.
- [ ] 68. Ocultar features del menú (`isVisible` en el catálogo), estadísticas de descansos y localización opcional `es`.

---

## 14. Referencias

- SuperBar (inspiración funcional): https://rainerselvet.gumroad.com/l/pzwFR
- Vorssaint utils (inspiración del catálogo de features; GPL-3, no se copia código): https://github.com/vorssaint/vorssaint-utils
- `NSStatusItem` / `NSStatusBar`: https://developer.apple.com/documentation/appkit/nsstatusitem
- `NSColorSampler`: https://developer.apple.com/documentation/appkit/nscolorsampler
- Quartz Event Services, `CGEvent.tapCreate`: https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)
- `CGEventTapEnable` / gestión de `kCGEventTapDisabledByTimeout`: https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout
- `CGEvent(scrollWheelEvent2Source:…)`: https://developer.apple.com/documentation/coregraphics/cgevent/init(scrollwheelevent2source:units:wheelcount:wheel1:wheel2:wheel3:)
- `keyboardSetUnicodeString`: https://developer.apple.com/documentation/coregraphics/cgevent/keyboardsetunicodestring(stringlength:unicodestring:)
- `AXIsProcessTrustedWithOptions`: https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions
- `CGPreflightListenEventAccess` / `CGRequestPostEventAccess` (macOS 10.15+): https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess()
- IOKit Power Assertions (`IOPMAssertionCreateWithName`): https://developer.apple.com/documentation/iokit/1557134-iopmassertioncreatewithname
- Patrón Caffeine / Amphetamine (aserciones IOPM; `pmset -g assertions` para verificar): https://apps.apple.com/app/amphetamine/id937984704
- `SMAppService` (login items, macOS 13): https://developer.apple.com/documentation/servicemanagement/smappservice
- `UserNotifications`: https://developer.apple.com/documentation/usernotifications
- Notarización (`notarytool`): https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Hardened Runtime: https://developer.apple.com/documentation/security/hardened-runtime
- App Sandbox (por qué no aplica aquí): https://developer.apple.com/documentation/security/app-sandbox
- XcodeGen: https://github.com/yonaskolb/XcodeGen
- Yams: https://github.com/jpsim/Yams
- Sparkle (backlog): https://sparkle-project.org

---

## 15. Instrucciones para el agente de código

1. Sigue las fases **en orden** (§9). No empieces una fase hasta cumplir el DoD de la anterior.
2. Marca las tareas de §13 en este mismo fichero (`docs/PLAN.md`) a medida que las completes.
3. La lógica testeable va en `ToolboxCore`. La app solo contiene el pegamento con AppKit y las APIs del sistema.
4. No añadas dependencias fuera de Yams (F10) sin justificarlo en el PR.
5. No toques credenciales de Apple ni certificados. Si falta el perfil de notarización, deja F8 en "build ad-hoc + DMG sin notarizar" y anótalo.
6. Cada PR o commit de fase incluye: qué CA se han verificado, en qué arquitectura y qué queda pendiente.
7. **Todo lo público en inglés** (§1.1): código, comentarios, UI, README, commits, PRs y release notes. Este plan es la única excepción.
8. No implementes nada de la lista de fuera de alcance (§1). Licencia MIT; no copies código de Vorssaint ni de SuperBar.
