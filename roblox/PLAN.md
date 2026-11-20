# Midnight Haul — план

1. ✅ RarityConfig + CarSpawner (weighted random, 5–7 машин, деспавн 4 мин, кулдаун точки 60 сек)
2. ✅ LockpickGui + TheftHandler (мини-игра, серверная валидация, сигнализация, «второй шанс»)
3. 🟡 ScrapyardHandler + HUD — сервер и HUD готовы; осталось меню сдачи `StarterGui/SellGui` (слушает `OpenScrapyard`, кнопка шлёт `SellCar(carId)`)
4. 🟡 UpgradeHandler + GarageMenu — сервер готов (улучшения, пады, пассивный доход, косметика); осталось `StarterGui/GarageMenu` (вкладки Улучшения/Слоты/Статистика)
5. 🟡 MonetizationHandler + ShopGui — сервер готов (ProcessReceipt, пассы, VIP-ник, daily); осталось `StarterGui/ShopGui` и `StarterGui/DailyGui`
6. ⬜ Клиентские скрипты в `StarterPlayer/StarterPlayerScripts`:
   - управление угнанной машиной (VehicleSeat Throttle/Steer → `Drive`/`Steer` констрейнты, атрибуты `MaxSpeed`/`TurnRate`, запись `ClientState.Speed`)
   - маркеры сканера (BillboardGui по `UpgradeConfig.CanScan`, таймер по `ExpiresAt` на ур. 5)
   - открытие меню с ProximityPrompt'ов гаража, доска статистики
7. ⬜ `StarterGui/NotificationGui` — тосты справа сверху (`Notify` remote + `ClientState.ToastRequested`)
8. ⬜ Полировка: партиклы по `Effect` remote, звуки, тест на телефоне/планшете/ПК
