Roblox-игра про ночного угонщика: найди машину, взломай её мини-игрой «останови бегунок в зелёной зоне», отвези скупщику, прокачай гараж. Весь код — Luau, сервер авторитетен по деньгам, редкости, взлому и улучшениям.

## Технологии
- Luau, структура под [Rojo](https://rojo.space) (`src/`)
- DataStoreService (UpdateAsync + retry, автосейв 60 сек), MarketplaceService (ProcessReceipt)
- Карта (город, парковки, скупщик, гараж, ночное освещение) генерируется `WorldBuilder`, если в Workspace нет своих `City`/`CarSpawns`/`Scrapyard`/`Garage`

## Запуск в Roblox Studio
1. Установите Rojo и плагин Rojo для Studio.
2. Создайте в корне `default.project.json`:
```json
{
  "name": "MidnightHaul",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": { "Modules": { "$path": "src/ReplicatedStorage/Modules" } },
    "ServerScriptService": { "$path": "src/ServerScriptService" },
    "StarterGui": { "$path": "src/StarterGui" },
    "StarterPlayer": { "StarterPlayerScripts": { "$path": "src/StarterPlayer/StarterPlayerScripts" } }
  }
}
```
3. `rojo serve`, подключитесь из Studio, нажмите Play.
4. Для сохранений: Game Settings → Security → Enable Studio Access to API Services.
5. Перед публикацией создайте пассы/продукты в Creator Hub и впишите их ID в `MonetizationConfig.luau` (пока Id = 0, покупки не открываются).

## Структура
- `src/ReplicatedStorage/Modules` — конфиги (Rarity/Car/Upgrade/Monetization/Game), Util, CarBuilder, UIKit, ClientState
- `src/ServerScriptService` — Main.server + DataManager, WorldBuilder, CarSpawner, TheftHandler, ScrapyardHandler, UpgradeHandler, MonetizationHandler
- `src/StarterGui` — HUD и LockpickGui готовы; остальные экраны в работе

## Дорожная карта
См. `PLAN.md`: меню сдачи, гаража, магазин, ежедневные награды, тосты, управление машиной и маркеры сканера.
