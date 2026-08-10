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
        '    <uses-permission android:name="android.permission.RECORD_AUDIO"/>\n'
        '    <uses-permission android:name="android.permission.INTERNET"/>\n'
    )
    if "android.permission.RECORD_AUDIO" not in text:
        manifest_start = text.find("<manifest")
        close = text.find(">", manifest_start)
        text = text[: close + 1] + "\n" + permissions + text[close + 1 :]
    if "android.speech.RecognitionService" not in text:
        query = (
            "    <queries>\n"
            "        <intent>\n"
            '            <action android:name="android.speech.RecognitionService"/>\n'
            "        </intent>\n"
            "    </queries>\n"
        )
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
