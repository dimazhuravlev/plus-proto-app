# ProtoPlus — политика конфиденциальности

ProtoPlus — дизайн-прототип для исследования интерфейса. Его раздают тестировщикам через TestFlight.

**Какие данные собираются.** Никакие. В приложении нет регистрации, аккаунтов, аналитики, рекламы и трекинга.

**Что хранится на устройстве.** Состояние прототипа — сохранённое в коллекции, история просмотра и поиска, последний открытый контент — хранится только на устройстве и никуда не отправляется. Удаляется вместе с приложением.

**Сетевые запросы.** Чтобы показать фильмы, музыку и книги, приложение обращается к публичным API: poiskkino.dev (фильмы), Deezer (музыка), Google Books (книги) и Википедии. Картинки и музыкальные превью загружаются с серверов этих сервисов и через прокси картинок images.weserv.nl. Эти сервисы получают стандартные данные запроса, например IP-адрес, и обрабатывают их по своим правилам. Никаких данных о пользователе приложение им не передаёт.

**TestFlight.** Apple может собирать отчёты о сбоях и отзывы тестировщиков по правилам TestFlight.

**Контакты.** Вопросы — через issues репозитория: https://github.com/dimazhuravlev/plus-proto-app/issues

---

# ProtoPlus — Privacy Policy

ProtoPlus is an interaction-design prototype distributed to testers via TestFlight.

**Data collection.** None. There is no sign-up, accounts, analytics, advertising or tracking.

**On-device storage.** Prototype state — saved items, viewing and search history, last opened content — is stored only on the device and is never sent anywhere. It is deleted together with the app.

**Network requests.** To show movies, music and books, the app calls public APIs: poiskkino.dev (movies), Deezer (music), Google Books (books) and Wikipedia. Images and music previews are loaded from these services' servers and through the images.weserv.nl image proxy. These services receive standard request data, such as the IP address, and process it under their own policies. The app sends them no information about the user.

**TestFlight.** Apple may collect crash reports and tester feedback under the TestFlight terms.

**Contact.** Questions — via the repository issues: https://github.com/dimazhuravlev/plus-proto-app/issues
