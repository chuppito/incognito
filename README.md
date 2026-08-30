# Incognito (com.tomtom.incognito)

Historique de notifications multi-apps : capture le contenu des notifications
reçues (WhatsApp, Messenger, Instagram, Telegram, Snapchat, SMS, etc.) et te
permet de les consulter dans l'appli plutôt que dans l'historique de
notifications Android — avec, pour chaque app, le choix de garder ou non le
bandeau système.

## Comment ça marche

- Un `NotificationListenerService` Android (`NotificationListener.kt`) reçoit
  toutes les notifications système une fois l'accès accordé (réglage Android
  natif "Accès aux notifications" — géré directement par le téléphone, pas de
  permission "cachée").
- Seules les apps que tu coches dans l'écran de réglages sont capturées et
  stockées en local (SQLite, sur l'appareil uniquement — rien n'est envoyé
  nulle part).
- Pour chaque app écoutée, un second interrupteur "Notif." choisit si le
  bandeau système reste affiché normalement, ou si Incognito le retire
  aussitôt après avoir capturé le contenu (mode silencieux : tu ne vois plus
  qu'ici).

⚠️ Comme pour l'app "Unseen", ceci ne fonctionne que sur les notifications de
**ton propre téléphone**, avec une autorisation que **tu accordes toi-même**
dans les réglages Android. Ce n'est pas de l'interception réseau ni de la
surveillance à distance.

## Mise en route (VS Code)

1. Décompresse le zip, ouvre le dossier `incognito` dans VS Code.
2. `flutter pub get`
3. Branche ton Pixel 8 Pro (ou lance un émulateur), puis `flutter run`.
4. Au premier lancement, l'app affiche un bouton "Ouvrir les réglages" tant
   que l'accès aux notifications n'est pas activé — accepte-le pour
   "Incognito" dans la liste.
5. Va dans l'icône réglages (⚙️ en haut) pour choisir les apps à écouter et,
   pour chacune, si tu veux garder le bandeau système ou non.

## Build automatique (GitHub Actions)

Un workflow est déjà présent dans `.github/workflows/build-apk.yml` : à chaque
push sur `main` (ou déclenchement manuel depuis l'onglet Actions), il build un
**APK debug** (pas besoin de clé de signature) et le dépose en artefact
téléchargeable pendant 30 jours, dans l'onglet **Actions** du dépôt GitHub.
Gratuit et illimité sur un dépôt public.

L'APK debug s'installe directement sur ton téléphone (active "sources
inconnues" si besoin) mais n'est pas signé pour la distribution — suffisant
pour tester en attendant ton retour. Un second job (release, signé), commenté
dans le même fichier, est prêt à activer une fois que tu auras généré ta clé
et ajouté les secrets GitHub — les instructions sont dans les commentaires du
fichier.

## Signature release (optionnel)

Comme pour tes autres apps, si tu veux builder un APK/AAB signé avec ta clé
perso, crée `android/key.properties` (non versionné) :

```
storePassword=xxxx
keyPassword=xxxx
keyAlias=upload
storeFile=/chemin/vers/upload-keystore.jks
```

Le `build.gradle.kts` retombe automatiquement sur la signature debug si ce
fichier n'existe pas.

## Structure

```
lib/
  models/            NotificationItem, InstalledApp
  services/          IncognitoChannel (pont MethodChannel)
  screens/           HistoryScreen, SettingsScreen
  widgets/           NotificationTile, AppTile
android/app/src/main/kotlin/com/tomtom/incognito/
  MainActivity.kt        expose le MethodChannel à Flutter
  NotificationListener.kt  capture les notifications système
  NotificationStore.kt     stockage SQLite local
  NotificationPrefs.kt     apps écoutées / apps silencieuses (SharedPreferences)
```

## Pistes d'amélioration

- Regroupement par app / par jour dans l'historique.
- Filtrage et recherche dans l'historique (déjà présent sur l'écran de
  réglages pour les apps, pas encore sur l'historique lui-même).
- Icônes des apps dans la liste d'historique (actuellement seulement dans le
  sélecteur d'apps).
- Export / sauvegarde chiffrée de l'historique.


## Version 1.1.0 — messages complets

- Récupération prioritaire des notifications `MessagingStyle` avec les différents messages et expéditeurs lorsque Android les fournit.
- Conservation du texte complet en SQLite.
- Migration automatique de la base existante vers le schéma v2.
- Aperçu tronqué uniquement dans la liste.
- Appui sur une notification pour ouvrir son contenu complet dans Incognito.
- Détection de la conversation/groupe d'origine quand Android fournit cette information.
- Les messages longs sont défilables et sélectionnables dans l'écran de détail.

> Limite Android : Incognito ne peut pas reconstruire une partie de message que l'application source n'a jamais fournie à Android ou qu'elle a elle-même tronquée avant de créer la notification.
