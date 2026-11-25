# Third-party components

| Component | Where | License |
|---|---|---|
| Inter font (Rasmus Andersson) | `app/assets/fonts/Inter.ttf` | SIL Open Font License 1.1 (`app/assets/fonts/OFL.txt`) |
| Body map drawings: [react-native-body-highlighter](https://github.com/HichamELBSI/react-native-body-highlighter) (ELABBASSI Hicham) | `app/assets/data/vucut.json` | MIT (`app/assets/data/VUCUT_LISANS.txt`) |
| Anatomical exercise animations: [ExerciseDB V1](https://exercisedb.dev) free tier (AscendAPI) | Fetched from `oss.exercisedb.dev` while the app runs | Not in this repo. The service's own terms apply: data is not stored, and the GIF address is requested from the API on every open. |
| Material Icons "fitness_center" (Google): the notification icon | `app/android/app/src/main/res/drawable/ada_bildirim.xml` | Apache License 2.0 |
| Step circle, glow and their animations, from [Agent Presence](https://github.com/DenizTanisman/agent-presence) (same author), in the island's orange | `AdaDaire.kt`, `AdaKok.kt`, `AdaRenk.kt` | MIT |
| Flutter packages: `path_provider`, `path_drawing`, `wakelock_plus`, `cupertino_icons` | `app/pubspec.yaml` | Each package's own license (BSD-3 / MIT) |

The program, exercise descriptions, muscle lists, drawn animations and the interface are this repo's own content and are licensed under MIT.

The decision rules of the setup flow (weekly volume, recovery times, pain monitoring, healing times, red flags, PAR-Q+ questions) were compiled from published guidelines and research: WHO 2020, ACSM, NSCA, the PAR-Q+ Collaboration and peer-reviewed sports medicine journals. The texts are this repo's own writing; the sources themselves are not included in the repo. The suggestions are not medical advice.
