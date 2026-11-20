Roblox-проект на Luau (Rojo-раскладка в `src/`). Это не веб-сайт: Netlify здесь только хранит репозиторий. Оставшиеся задачи — в `PLAN.md`.

## Архитектура
- `Main.server.luau` инициализирует модули по порядку: WorldBuilder → DataManager → Monetization → CarSpawner → Theft → Scrapyard → Upgrade.
- Данные игрока меняются только через `DataManager`; после изменений вызывать `DataManager.Sync(player)` — клиент получает снимок по remote `DataSync` и хранит его в `ClientState.Data`.
- RemoteEvent'ы создаёт сервер через `Util.Remote(name)` (список в `Util.RemoteNames`).
- Мини-игра: сервер хранит сессию и сам считает позицию бегунка `Util.RunnerPosition(elapsed, speed)`; клиент шлёт только `(sessionId, elapsed)` или `"cancel"`.
- Угнанная машина: `player:GetAttribute("StolenCarId")`, на модели `StolenBy`, `MaxSpeed`, `TurnRate`, `ExpiresAt`, `Rarity`, `State`. Движение — констрейнты `Drive` (LinearVelocity) и `Steer` (AngularVelocity) на шасси; сетевой владелец — угонщик, клиентский скрипт управления ещё не написан.
- Меню открываются через `ClientState.RegisterMenu/OpenMenu` (одно меню за раз; во время взлома HUD скрыт, меню закрыты).

## Конвенции
- Только `task.wait/task.delay`, никаких `wait()`.
- Редкости/цены/эффекты — только из конфигов в `Modules`, не хардкодить.
- UI через `UIKit` (тема #0D0D12/#1A1A24, циан/маджента), размеры в Scale, UIAspectRatioConstraint на карточках, HUD/меню с `CoreUISafeInsets`.
- Каждый ScreenGui — папка с `init.meta.json` (ResetOnSpawn=false) и `Controller.client.luau`.
- Проверка синтаксиса: `luau-compile --null file.luau`.

## Неочевидное
- Бонус Lockpick = 2.5%/уровень (а не 2%), чтобы Mythical на макс. уровне давал 20%, как в ТЗ.
- ProcessReceipt подтверждает покупку только после успешного сохранения; дубликаты отсекаются по PurchaseId.
