"""Apply OpenCue-specific privacy capabilities to generated Flutter runners.

The repository intentionally does not commit android/ or ios/. CI and local
builders run this after `flutter create`, keeping the generated boilerplate out
of source control while making microphone requirements reproducible.
"""

from pathlib import Path


def configure_android(root: Path) -> None:
    manifest = root / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest.exists():
        return
    text = manifest.read_text(encoding="utf-8")
    permissions = (
        ("android.permission.RECORD_AUDIO", "RECORD_AUDIO"),
        ("android.permission.INTERNET", "INTERNET"),
    )
    missing_permissions = [
        short_name
        for full_name, short_name in permissions
        if full_name not in text
    ]
    if missing_permissions:
        manifest_start = text.find("<manifest")
        close = text.find(">", manifest_start)
        additions = "".join(
            '    <uses-permission android:name="android.permission.%s"/>\n'
            % permission
            for permission in missing_permissions
        )
        text = text[: close + 1] + "\n" + additions + text[close + 1 :]
    query_actions = []
    if "android.speech.RecognitionService" not in text:
        query_actions.append("android.speech.RecognitionService")
    if "android.intent.action.TTS_SERVICE" not in text:
        # Android 11 package visibility: flutter_tts cannot reliably discover
        # installed engines unless the generated app declares this query.
        query_actions.append("android.intent.action.TTS_SERVICE")
    if query_actions:
        intents = "".join(
            "        <intent>\n"
            f'            <action android:name="{action}"/>\n'
            "        </intent>\n"
            for action in query_actions
        )
        if "</queries>" in text:
            text = text.replace(
                "    </queries>", intents + "    </queries>", 1
            )
        else:
            query = "    <queries>\n" + intents + "    </queries>\n"
            application = text.find("<application")
            application_line = text.rfind("\n", 0, application) + 1
            text = text[:application_line] + query + text[application_line:]
    manifest.write_text(text, encoding="utf-8")


def configure_ios(root: Path) -> None:
    info = root / "ios" / "Runner" / "Info.plist"
    if not info.exists():
        return
    text = info.read_text(encoding="utf-8")
    additions = ""
    if "NSMicrophoneUsageDescription" not in text:
        additions += (
            "\t<key>NSMicrophoneUsageDescription</key>\n"
            "\t<string>Listen to a short conversation turn after you tap "
            "Listen.</string>\n"
        )
    if "NSSpeechRecognitionUsageDescription" not in text:
        additions += (
            "\t<key>NSSpeechRecognitionUsageDescription</key>\n"
            "\t<string>Transcribe a short conversation turn into reply "
            "suggestions.</string>\n"
        )
    if additions:
        text = text.replace("</dict>", additions + "</dict>", 1)
        info.write_text(text, encoding="utf-8")


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    configure_android(root)
    configure_ios(root)


if __name__ == "__main__":
    main()
