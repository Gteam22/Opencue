#!/usr/bin/env python3
"""Generates lib/l10n/strings_en.dart and lib/l10n/strings_ja.dart.

Both tables come from one source of truth below, so a key can never exist in
one language and be missing from the other. Enum-derived keys are generated
from lib/domain/enums/enums.dart, which means adding an enum value produces a
missing-label failure at generation time instead of a raw key in the UI.

Run:  python3 tool/build_strings.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# key: (english, japanese)
S = {}


def add(key, en, ja):
    if key in S:
        raise SystemExit('duplicate string key: %s' % key)
    S[key] = (en, ja)


# ---------------------------------------------------------------------------
# App-level
# ---------------------------------------------------------------------------
add('app.name', 'OpenCue', 'OpenCue')
add('app.tagline', 'Conversation openers that fit the moment',
    '場面に合った会話の一言')
add('app.version', 'Version {0}', 'バージョン {0}')

# Navigation
add('nav.home', 'Home', 'ホーム')
add('nav.library', 'Library', 'ライブラリ')
add('nav.history', 'History', '履歴')
add('nav.favorites', 'Favourites', 'お気に入り')
add('nav.settings', 'Settings', '設定')

# Common actions
add('action.save', 'Save', '保存')
add('action.cancel', 'Cancel', 'キャンセル')
add('action.delete', 'Delete', '削除')
add('action.edit', 'Edit', '編集')
add('action.duplicate', 'Duplicate', '複製')
add('action.close', 'Close', '閉じる')
add('action.back', 'Back', '戻る')
add('action.confirm', 'Confirm', '確認')
add('action.clear', 'Clear', 'クリア')
add('action.clearAll', 'Clear all', 'すべてクリア')
add('action.apply', 'Apply', '適用')
add('action.retry', 'Try again', 'もう一度')
add('action.addLine', 'Add line', '新しい一言を追加')
add('action.showAnother', 'Show another', '別の候補')
add('action.usedThisLine', 'I used this line', 'この一言を使った')
add('action.favorite', 'Add to favourites', 'お気に入りに追加')
add('action.unfavorite', 'Remove from favourites', 'お気に入りから外す')
add('action.viewDetails', 'View details', '詳細を見る')
add('action.restore', 'Restore', '復元')
add('action.reset', 'Reset', '初期化')
add('action.startOver', 'Start over', '最初から')

# ---------------------------------------------------------------------------
# Home
# ---------------------------------------------------------------------------
add('home.findLine', 'Find a line', '一言を探す')
add('home.findLineSubtitle', 'Describe the situation and see what fits',
    '今の状況を入力して候補を見る')
add('home.browseLibrary', 'Browse library', 'ライブラリを見る')
add('home.favorites', 'Favourites', 'お気に入り')
add('home.recent', 'Recent', '最近の記録')
add('home.recentEmpty', 'Nothing recorded yet.', 'まだ記録はありません。')
add('home.scan', 'Scan surroundings', '周囲をスキャン')
add('home.scanPlanned', 'Planned for a later version',
    '今後のバージョンで対応予定')
add('home.scanExplain',
    'A later version may read environmental context from a scan you trigger '
    'yourself. This version has no camera or microphone access of any kind.',
    '将来のバージョンでは、ユーザーが自分で開始したスキャンから周囲の状況を'
    '読み取ることを検討しています。このバージョンではカメラもマイクも一切'
    '使用しません。')
add('home.libraryCount', '{0} lines in your library',
    'ライブラリに {0} 件')

# ---------------------------------------------------------------------------
# Situation builder
# ---------------------------------------------------------------------------
add('context.title', 'Describe the situation', '状況を入力')
add('context.subtitle', 'Only the location matters. Skip anything you are '
    'not sure about.',
    '必須は場所だけです。分からない項目は空のままで構いません。')
add('context.location', 'Where are you?', '場所')
add('context.activity', 'What is happening?', '何をしている場面か')
add('context.activityNone', 'Not sure', '分からない')
add('context.groupSize', 'Who are they with?', '人数')
add('context.noiseLevel', 'How loud is it?', '騒がしさ')
add('context.cues', 'What can you actually see?', '見て分かること')
add('context.cuesHint',
    'Neutral, observable things only. A drink on the table, a dog, an '
    'umbrella.',
    '客観的に見えるものだけを選んでください。飲み物、犬、傘など。')
add('context.tonePreference', 'Preferred tone', '希望するトーン')
add('context.tonePreferenceAny', 'No preference', '指定なし')
add('context.directness', 'How direct do you want to be?', '直接さ')
add('context.checks', 'Anything else true right now?', '当てはまるもの')
add('context.eyeContact', 'We have made eye contact', '目が合った')
add('context.conversationStarted', 'We are already talking',
    'すでに会話が始まっている')
add('context.personOccupied', 'They look busy or preoccupied',
    '忙しそう・手が離せない様子')
add('context.movingQuickly', 'They are walking quickly', '早足で歩いている')
add('context.isWorking', 'They are working', '仕事中')
add('context.headphones', 'They are wearing headphones',
    'ヘッドホンをしている')
add('context.isolated', 'We are somewhere isolated or after dark',
    '人が少ない場所、または暗くなってから')
add('context.notes', 'Private note (optional)', 'メモ（任意）')
add('context.showSuggestions', 'Show suggestions', '候補を表示')
add('context.sourceLabel', 'Source: {0}', '入力元: {0}')

# ---------------------------------------------------------------------------
# Recommendations
# ---------------------------------------------------------------------------
add('rec.title', 'Suggestions', '候補')
add('rec.category.safest', 'Safest', '無理のない一言')
add('rec.category.playful', 'Playful', '軽い一言')
add('rec.category.moreDirect', 'More direct', 'より直接的な一言')
add('rec.category.alternative', 'Another option', 'その他の候補')
add('rec.category.gracefulExit', 'Graceful exit', '引き際の一言')
add('rec.matchingReasons', 'Why this fits', '選ばれた理由')
add('rec.conditions', 'Use it when', '使える条件')
add('rec.avoidConditions', 'Avoid when', '避けるべき場面')
add('rec.followUp', 'If it goes well', 'うまくいったら')
add('rec.notes', 'Note', '補足')
add('rec.noResults',
    'No line in your library fits this situation closely enough.',
    'この状況に合う一言がライブラリにありません。')
add('rec.noResultsHint',
    'Try clearing a filter, widening the noise level, or adding a line of '
    'your own.',
    '条件を緩めるか、自分で一言を追加してみてください。')
add('rec.noGuarantee',
    'These are ranked for how well they fit the situation. Nothing here '
    'predicts how someone will respond.',
    'これは状況との相性で並べたものです。相手の反応を予測するものでは'
    'ありません。')
add('rec.exitLines', 'If they are not interested', '相手が乗り気でないとき')
add('rec.exitLinesHint',
    'Say it once, warmly, and then actually leave.',
    '一度だけ穏やかに言って、そのまま離れてください。')
add('rec.debugTitle', 'Score breakdown', 'スコアの内訳')
add('rec.debugToggle', 'Show score breakdown', 'スコアの内訳を表示')
add('rec.consideredCount', '{0} lines scored, {1} ruled out',
    '{0} 件を評価、{1} 件を除外')

# The advisory. The exact wording of advisory.title is specified.
add('advisory.title', 'This may not be a good time to approach.',
    '今は声をかけるのに向いていないかもしれません。')
add('advisory.becauseYouSelected', 'You selected:', '選択した項目:')
add('advisory.explain',
    'OpenCue is not offering openers for this situation. The library is still '
    'available if you want to read through it.',
    'この状況では候補を表示しません。ライブラリの閲覧はいつでもできます。')
add('advisory.browseInstead', 'Browse the library instead',
    'ライブラリを見る')
add('advisory.changeSituation', 'Change the situation', '状況を修正する')

# Outcome recording
add('outcome.title', 'How did it go?', 'どうでしたか？')
add('outcome.subtitle',
    'This is only for your own records. It stays on this device.',
    'これはご自身の記録用です。この端末の外には出ません。')
add('outcome.note', 'Private note (optional)', 'メモ（任意）')
add('outcome.saved', 'Recorded.', '記録しました。')

# ---------------------------------------------------------------------------
# Library
# ---------------------------------------------------------------------------
add('library.title', 'Library', 'ライブラリ')
add('library.search', 'Search Japanese or English', '日本語・英語で検索')
add('library.filters', 'Filters', '絞り込み')
add('library.filtersActive', '{0} active', '{0} 件適用中')
add('library.clearFilters', 'Clear filters', '絞り込みを解除')
add('library.sortBy', 'Sort by', '並び順')
add('library.favoritesOnly', 'Favourites only', 'お気に入りのみ')
add('library.userCreatedOnly', 'My lines only', '自分で追加した分のみ')
add('library.directnessRange', 'Directness {0} to {1}',
    '直接さ {0}〜{1}')
add('library.count', '{0} lines', '{0} 件')
add('library.empty', 'No lines match.', '該当する一言がありません。')
add('library.emptyHint', 'Try a shorter search or clear the filters.',
    '検索語を短くするか、絞り込みを解除してください。')
add('library.emptyLibrary', 'Your library is empty.',
    'ライブラリが空です。')
add('library.emptyLibraryHint',
    'Restore the starter lines from Settings, or add your own.',
    '設定から初期データを復元するか、自分で追加してください。')
add('library.seedLine', 'Starter line', '初期データ')
add('library.userLine', 'Your line', '自分の一言')
add('library.usedCount', 'Used {0} times', '{0} 回使用')
add('library.shownCount', 'Suggested {0} times', '{0} 回表示')
add('library.neverUsed', 'Not used yet', 'まだ使っていません')
add('library.deleteTitle', 'Delete this line?', 'この一言を削除しますか？')
add('library.deleteBody',
    'This cannot be undone. Any interaction records for it are removed too.',
    'この操作は取り消せません。関連する記録も削除されます。')
add('library.deleteSeedNote',
    'This is a starter line. You can bring it back with "Restore starter '
    'lines" in Settings.',
    'これは初期データです。設定の「初期データを復元」で元に戻せます。')
add('library.duplicated', 'Copied to a new line you can edit.',
    '編集できる新しい一言として複製しました。')

# ---------------------------------------------------------------------------
# Editor
# ---------------------------------------------------------------------------
add('editor.newTitle', 'New line', '新規作成')
add('editor.editTitle', 'Edit line', '編集')
add('editor.japanese', 'Japanese', '日本語')
add('editor.japaneseHint', 'The words you would actually say',
    '実際に言う言葉')
add('editor.english', 'English meaning', '英語の意味')
add('editor.englishHint', 'Optional, but it makes the library searchable',
    '任意です。検索しやすくなります。')
add('editor.category', 'Category', 'カテゴリ')
add('editor.locations', 'Locations', '場所')
add('editor.locationsHint', 'Leave empty for a line that works anywhere',
    '空にすると場所を問わない一言になります')
add('editor.activities', 'Activities', '場面')
add('editor.cues', 'Observable cues', '見て分かること')
add('editor.groupSizes', 'Group sizes', '人数')
add('editor.noiseLevels', 'Noise levels', '騒がしさ')
add('editor.tones', 'Tone', 'トーン')
add('editor.directness', 'Directness', '直接さ')
add('editor.conditions', 'Only suggest when', '次の条件を満たすときだけ提案')
add('editor.avoidConditions', 'Never suggest when', '次の場面では提案しない')
add('editor.followUp', 'Follow-up suggestion', '次の一手')
add('editor.notes', 'Notes', 'メモ')
add('editor.unsavedTitle', 'Discard changes?', '変更を破棄しますか？')
add('editor.unsavedBody', 'Your edits to this line will be lost.',
    '編集内容は保存されません。')
add('editor.saved', 'Saved.', '保存しました。')

# Validation
add('validation.idRequired', 'This line has no identifier.',
    '識別子がありません。')
add('validation.japaneseRequired', 'Japanese text is required.',
    '日本語の入力は必須です。')
add('validation.directnessRange', 'Directness must be between 1 and 5.',
    '直接さは1〜5で指定してください。')
add('validation.toneRequired', 'Choose at least one tone.',
    'トーンを1つ以上選んでください。')

# ---------------------------------------------------------------------------
# History and statistics
# ---------------------------------------------------------------------------
add('history.title', 'History', '履歴')
add('history.statistics', 'Your numbers', '集計')
add('history.suggestionsViewed', 'Suggestions viewed', '候補の表示回数')
add('history.linesUsed', 'Lines used', '使用回数')
add('history.outcomes', 'Outcomes', '結果の内訳')
add('history.topLocations', 'Most common locations', 'よく使った場所')
add('history.topTones', 'Most used tones', 'よく使ったトーン')
add('history.bestLines', 'Your strongest lines', '自分の記録が良い一言')
add('history.notEnoughData',
    'Not enough records yet to show proportions. Counts only for now.',
    '割合を出せるほどの記録がまだありません。件数のみ表示します。')
add('history.notEnoughForRanking',
    'A per-line ranking needs more records than this to mean anything.',
    '一言ごとの順位付けには、もう少し記録が必要です。')
add('history.empty', 'No history yet.', 'まだ履歴がありません。')
add('history.emptyHint',
    'Records appear here once you note that you used a line.',
    '一言を使ったことを記録すると、ここに表示されます。')
add('history.recordCount', '{0} records', '{0} 件の記録')
add('history.lineDeleted', 'Line no longer in library',
    'ライブラリに存在しない一言')
add('history.recorded', 'Outcomes recorded', '結果を記録した回数')
add('history.patterns', 'Where and how you have used lines',
    '使った場面の傾向')
add('history.patternsEmpty',
    'Once you record a few interactions, the situations you use most will '
    'show up here.',
    '記録が増えると、よく使う場面がここに表示されます。')
add('history.log', 'Recorded interactions', '記録一覧')
add('history.bestLinesNote',
    'Based only on your own records, and shown once there are enough of them '
    'to be worth reading.',
    '自分の記録だけをもとにしています。十分な件数がある場合のみ表示します。')

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------
add('settings.title', 'Settings', '設定')
add('settings.appearance', 'Appearance', '表示')
add('settings.language', 'Interface language', '表示言語')
add('settings.languageHint',
    'Lines are always shown in Japanese. This setting controls the interface '
    'and whether the English meaning appears underneath.',
    '一言は常に日本語で表示されます。この設定は画面の言語と、英語の意味を'
    '併記するかどうかを切り替えます。')
add('settings.theme', 'Theme', 'テーマ')
add('settings.defaultDirectness', 'Default directness', '直接さの初期値')
add('settings.defaultDirectnessHint',
    'Where the slider starts when you describe a new situation.',
    '状況を入力する画面でスライダーの初期位置になります。')
add('settings.data', 'Your data', 'データ')
add('settings.export', 'Export data', 'データを書き出す')
add('settings.exportSubtitle',
    'Saves your own lines, favourites and settings as a JSON file.',
    '自分の一言・お気に入り・設定をJSONファイルに保存します。')
add('settings.exportIncludeHistory', 'Include interaction history',
    '履歴も含める')
add('settings.exportIncludeHistoryNote',
    'Your private notes are in the history. Leave this off unless you need '
    'them in the backup.',
    '履歴にはメモも含まれます。必要なとき以外はオフのままにしてください。')
add('settings.import', 'Import data', 'データを読み込む')
add('settings.importSubtitle', 'Read a JSON file exported from OpenCue.',
    'OpenCueで書き出したJSONファイルを読み込みます。')
add('settings.restoreStarter', 'Restore starter lines', '初期データを復元')
add('settings.restoreStarterSubtitle',
    'Puts back any starter line you deleted. Your own lines are untouched.',
    '削除した初期データを戻します。自分で追加した分はそのままです。')
add('settings.clearHistory', 'Clear interaction history', '履歴を消去')
add('settings.clearHistorySubtitle',
    'Deletes every record and resets the counts. Lines are kept.',
    'すべての記録を削除し、集計をリセットします。一言は残ります。')
add('settings.resetAll', 'Reset all local data', 'すべてのデータを初期化')
add('settings.resetAllSubtitle',
    'Deletes everything and reinstalls the starter library.',
    'すべて削除して初期データを再インストールします。')
add('settings.about', 'About and privacy', 'このアプリとプライバシー')
add('settings.dataLocation', 'Data location', 'データの保存先')
add('settings.dangerZone', 'Deleting data', 'データの削除')
add('settings.exportFirst',
    'Export a backup first if there is anything here you might want later.',
    '後で必要になりそうなものがある場合は、先に書き出してください。')
add('settings.restored', 'Restored {0} starter lines.',
    '初期データを {0} 件復元しました。')
add('settings.resetAllFinalTitle', 'Delete everything, including your own '
    'lines?', '自分で追加した一言も含めて、すべて削除しますか？')
add('settings.resetAllFinalBody',
    'This is the last confirmation. Every line you wrote, every note and '
    'every record is removed from this computer and cannot be recovered from '
    'inside the app.',
    'これが最後の確認です。自分で書いた一言・メモ・記録はすべてこのパソコンから'
    '削除され、アプリ内から復元することはできません。')

# Confirmations
add('confirm.restoreStarterTitle', 'Restore starter lines?',
    '初期データを復元しますか？')
add('confirm.restoreStarterBody',
    'Missing starter lines will be added back. Nothing you wrote is changed '
    'or deleted.',
    '不足している初期データを追加します。自分で書いた内容は変更されません。')
add('confirm.clearHistoryTitle', 'Clear interaction history?',
    '履歴を消去しますか？')
add('confirm.clearHistoryBody',
    'Every record and private note is deleted, and the per-line counts go '
    'back to zero. This cannot be undone.',
    'すべての記録とメモが削除され、集計はゼロに戻ります。取り消せません。')
add('confirm.resetAllTitle', 'Reset all local data?',
    'すべてのデータを初期化しますか？')
add('confirm.resetAllBody',
    'Your lines, favourites, history and settings are all deleted, and the '
    'starter library is reinstalled. Export a backup first if you might want '
    'any of it. This cannot be undone.',
    '一言・お気に入り・履歴・設定のすべてが削除され、初期データが再作成'
    'されます。必要なものがある場合は先に書き出してください。取り消せません。')
add('confirm.typeToConfirm', 'Type RESET to confirm', '確認のため RESET と入力')
add('confirm.done', 'Done.', '完了しました。')

# Import flow
add('import.chooseMode', 'How should this be imported?', '読み込み方法')
add('import.merge', 'Add to my library', 'ライブラリに追加')
add('import.mergeSubtitle',
    'Keeps everything you have and adds the imported lines. Lines whose id '
    'already exists are given a new one.',
    '既存の内容を保持したうえで追加します。IDが重複する分は新しいIDを'
    '割り当てます。')
add('import.replace', 'Replace my library', 'ライブラリを置き換え')
add('import.replaceSubtitle',
    'Deletes every line you currently have first. This cannot be undone.',
    '現在のすべての一言を削除してから読み込みます。取り消せません。')
add('import.preview', 'This file contains {0} lines and {1} records.',
    'このファイルには一言 {0} 件、記録 {1} 件が含まれています。')
add('import.fromVersion', 'Written by OpenCue {0}',
    'OpenCue {0} で書き出されたファイル')
add('import.migratedNote',
    'This file uses an older format and was upgraded on read.',
    '古い形式のファイルを読み込み時に変換しました。')
add('import.summary',
    'Added {0} lines, re-keyed {1}, imported {2} records.',
    '一言 {0} 件を追加、{1} 件はID変更、記録 {2} 件を読み込みました。')
add('import.warningsTitle', 'Some entries were skipped', '一部を読み飛ばしました')
add('import.failedTitle', 'That file could not be imported',
    'このファイルは読み込めませんでした')
add('import.moreWarnings', 'and {0} more.', 'ほか {0} 件。')

# Import errors
add('import.error.emptyFile', 'That file is empty.',
    'ファイルが空です。')
add('import.error.notJson',
    'That file is not valid JSON. ({0})',
    'JSONとして読み取れません。（{0}）')
add('import.error.notAnObject',
    'That file does not look like an OpenCue export.',
    'OpenCueの書き出しファイルではないようです。')
add('import.error.badVersionField',
    'The schemaVersion field is not a number.',
    'schemaVersion が数値ではありません。')
add('import.error.versionTooOld',
    'That file uses format version {0}, which this build cannot read.',
    '形式バージョン {0} には対応していません。')
add('import.error.versionTooNew',
    'That file was written by a newer version of OpenCue (format {0}). '
    'Update the app and try again.',
    'より新しいバージョンのOpenCueで作成されたファイルです（形式 {0}）。'
    'アプリを更新してください。')
add('import.error.linesNotAList', 'The "lines" field is not a list.',
    '"lines" がリストではありません。')
add('import.error.interactionsNotAList',
    'The "interactions" field is not a list.',
    '"interactions" がリストではありません。')
add('import.error.nothingUsable',
    'Nothing in that file could be read as a line or a record.',
    'ファイル内に読み込めるデータがありませんでした。')
add('import.warning.lineNotAnObject', 'Entry {0} is not a line.',
    '{0} 番目の項目が一言ではありません。')
add('import.warning.invalidLine', 'Line {0} was missing required fields.',
    '一言 {0} に必須項目がありません。')
add('import.warning.unreadableLine', 'Entry {0} could not be read.',
    '{0} 番目の項目を読み取れませんでした。')
add('import.warning.duplicateIdInFile',
    'Id {0} appeared more than once and the later copy was re-keyed.',
    'ID {0} が重複していたため、後の項目のIDを変更しました。')
add('import.warning.interactionNotAnObject',
    'Record {0} is not a record.', '{0} 番目の記録が不正です。')
add('import.warning.unreadableInteraction',
    'Record {0} could not be read.', '{0} 番目の記録を読み取れませんでした。')
add('import.warning.orphanInteraction',
    'A record refers to line {0}, which is not in this file.',
    '記録が参照する一言 {0} がファイル内にありません。')
add('import.warning.settingsIgnored',
    'The settings block was not readable and was ignored.',
    '設定情報を読み取れなかったため無視しました。')
add('import.warning.migratedFromV0',
    'Upgraded from the pre-release format.',
    '旧形式から変換しました。')

# Export / file dialog
add('export.saveTitle', 'Save your OpenCue backup', 'バックアップの保存先')
add('export.done', 'Saved to {0}', '{0} に保存しました')
add('export.failed', 'Could not write that file. ({0})',
    'ファイルを保存できませんでした。（{0}）')
add('export.cancelled', 'Export cancelled.', '書き出しを中止しました。')
add('import.openTitle', 'Choose an OpenCue backup', '読み込むファイルを選択')
add('import.readFailed', 'Could not read that file. ({0})',
    'ファイルを読み取れませんでした。（{0}）')
add('import.cancelled', 'Import cancelled.', '読み込みを中止しました。')

# ---------------------------------------------------------------------------
# About and privacy
# ---------------------------------------------------------------------------
add('about.title', 'About OpenCue', 'OpenCue について')
add('about.what',
    'OpenCue is a personal library of conversation openers with a local '
    'recommendation engine. You describe the situation, it suggests lines '
    'that fit, and you keep your own notes on how things went.',
    'OpenCueは、会話の第一声を集めた個人用ライブラリと、ローカルで動作する'
    '推薦機能です。状況を入力すると合いそうな一言が表示され、結果は自分用の'
    'メモとして残せます。')
add('about.privacyTitle', 'Privacy', 'プライバシー')
add('about.privacyLocal',
    'All data in this version is stored locally on this computer.',
    'このバージョンのデータはすべてこのパソコン内に保存されます。')
add('about.privacyNoCamera',
    'This version does not access the camera.',
    'このバージョンはカメラを使用しません。')
add('about.privacyNoMic',
    'This version does not access the microphone.',
    'このバージョンはマイクを使用しません。')
add('about.privacyNoProfiling',
    'This version does not identify or profile other people.',
    'このバージョンは他人を識別したりプロファイリングしたりしません。')
add('about.privacyNotes',
    'Interaction notes stay on this device unless you export them yourself.',
    '記録したメモは、自分で書き出さない限りこの端末の外には出ません。')
add('about.privacyNoTelemetry',
    'There is no analytics, advertising, tracking or telemetry of any kind, '
    'and the app makes no network connections.',
    '解析・広告・トラッキング・テレメトリは一切ありません。ネットワーク通信も'
    '行いません。')
add('about.privacyFuture',
    'If a scan feature is added later, it is intended to read environmental '
    'context such as how loud a room is or what kind of place it is. It is '
    'not intended to judge whether a person is interested or has consented, '
    'and it will not be built to do so.',
    '将来スキャン機能を追加する場合、その目的は室内の騒がしさや場所の種類'
    'といった環境情報の把握です。相手が好意を持っているかや同意しているかを'
    '判断するためのものではなく、そのようには作りません。')
add('about.respectTitle', 'A note on how this is meant to be used',
    '使い方についての注意')
add('about.respect',
    'A line only works when the other person is free to ignore it. OpenCue '
    'declines to suggest openers when you tell it someone looks busy, is '
    'working, has headphones on, is moving quickly, or that the setting is '
    'isolated. The graceful exits matter more than the openers.',
    '第一声が成り立つのは、相手が断れる状況にあるときだけです。相手が忙しい、'
    '仕事中、ヘッドホンをしている、早足で歩いている、周囲に人がいないと入力'
    'された場合、OpenCueは候補を表示しません。引き際の一言のほうが、第一声'
    'よりも大切です。')
add('about.license', 'Licence', 'ライセンス')
add('about.publisher', 'Publisher', '提供者')
add('about.repository', 'Source code', 'ソースコード')
add('about.starterLibraryNote', 'Starter library: {0} lines',
    '初期データ: {0} 件')

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------
add('error.title', 'Something went wrong', 'エラーが発生しました')
add('error.databaseOpen',
    'OpenCue could not open its database. Your data has not been changed.',
    'データベースを開けませんでした。データは変更されていません。')
add('error.detail', 'Details: {0}', '詳細: {0}')

# ---------------------------------------------------------------------------
# Directness scale
# ---------------------------------------------------------------------------
add('directness.1', 'Barely a remark', 'ひと言だけ')
add('directness.2', 'Light and easy', '軽い雰囲気')
add('directness.3', 'Clearly starting a conversation', '会話を始める意図あり')
add('directness.4', 'Says what you mean', '意図を伝える')
add('directness.5', 'Completely direct', '率直に伝える')

# ---------------------------------------------------------------------------
# Enum labels
# ---------------------------------------------------------------------------
LOCATIONS = {
    'bar': ('Bar', 'バー'),
    'standingBar': ('Standing bar', '立ち飲み'),
    'club': ('Club', 'クラブ'),
    'cafe': ('Café', 'カフェ'),
    'restaurant': ('Restaurant', 'レストラン'),
    'street': ('Street', '路上'),
    'shoppingArea': ('Shopping area', '商業エリア'),
    'convenienceStore': ('Convenience store', 'コンビニ・スーパー'),
    'bookstore': ('Bookstore or record shop', '書店・レコード店'),
    'park': ('Park', '公園'),
    'waterfront': ('Waterfront', '海辺・川沿い'),
    'trainStation': ('Train station', '駅'),
    'publicTransport': ('Public transport', '電車・バス'),
    'festival': ('Festival', 'お祭り・イベント'),
    'cosplayEvent': ('Cosplay or anime event', 'コスプレ・アニメイベント'),
    'concert': ('Concert', 'ライブ'),
    'gym': ('Gym', 'ジム'),
    'kickboxingClass': ('Kickboxing class', 'キックボクシング'),
    'languageExchange': ('Language exchange', '言語交換'),
    'meetup': ('Meetup or class', 'ミートアップ・教室'),
    'party': ('Party', 'パーティー'),
    'waitingLine': ('Waiting in line', '行列'),
    'other': ('Somewhere else', 'その他'),
}
ACTIVITIES = {
    'browsing': ('Browsing', '眺めている'),
    'waiting': ('Waiting', '待っている'),
    'eating': ('Eating', '食べている'),
    'drinking': ('Drinking', '飲んでいる'),
    'dancing': ('Dancing', '踊っている'),
    'walking': ('Walking', '歩いている'),
    'exercising': ('Exercising', '運動している'),
    'reading': ('Reading', '読んでいる'),
    'photographing': ('Taking photos', '写真を撮っている'),
    'shopping': ('Shopping', '買い物中'),
    'socialising': ('Socialising', '人と話している'),
    'resting': ('Resting', '休んでいる'),
    'commuting': ('Commuting', '移動中'),
    'other': ('Something else', 'その他'),
}
GROUP_SIZES = {
    'alone': ('On their own', '一人'),
    'withOneFriend': ('With one friend', '二人'),
    'smallGroup': ('Small group', '少人数のグループ'),
    'largeGroup': ('Large group', '大人数のグループ'),
    'unknown': ('Not sure', '分からない'),
}
NOISE = {
    'quiet': ('Quiet', '静か'),
    'normal': ('Normal', '普通'),
    'loud': ('Loud', 'にぎやか'),
    'veryLoud': ('Very loud', '非常にうるさい'),
}
TONES = {
    'safe': ('Safe', '無難'),
    'friendly': ('Friendly', '親しみやすい'),
    'situational': ('Situational', '状況について'),
    'playful': ('Playful', '軽口'),
    'direct': ('Direct', '直接的'),
    'flirty': ('Flirty', '好意を示す'),
}
CUES = {
    'eyeContact': ('Eye contact', '目が合った'),
    'smile': ('A smile', '笑顔'),
    'distinctiveOutfit': ('Distinctive outfit', '目を引く服装'),
    'hairstyle': ('Hairstyle or colour', '髪型・髪色'),
    'nails': ('Nails', 'ネイル'),
    'drink': ('A drink', '飲み物'),
    'food': ('Food', '食べ物'),
    'book': ('A book', '本'),
    'characterMerchandise': ('Character merchandise', 'キャラクターグッズ'),
    'cosplay': ('Cosplay', 'コスプレ'),
    'dog': ('A dog', '犬'),
    'music': ('Music', '音楽'),
    'sharedActivity': ('A shared activity', '同じことをしている'),
    'waiting': ('Both waiting', 'どちらも待っている'),
    'takingPhotographs': ('Taking photographs', '写真を撮っている'),
    'weather': ('The weather', '天気'),
    'festivalItem': ('A festival item', 'お祭りのもの'),
    'sportsEquipment': ('Sports equipment', 'スポーツ用品'),
    'groupHavingFun': ('A group enjoying themselves', '楽しそうなグループ'),
    'other': ('Something else', 'その他'),
}
CONDITIONS = {
    'eyeContactEstablished': ('Eye contact has already happened',
                              'すでに目が合っている'),
    'conversationStarted': ('You are already talking', 'すでに会話している'),
    'priorRapport': ('You have built some rapport first',
                     'ある程度打ち解けている'),
    'personIsNotRushing': ('They are not in a hurry', '相手が急いでいない'),
    'sharedActivityInProgress': ('You are both doing the same thing',
                                 '同じことをしている場面'),
    'genuineKnowledgeOfSubject': ('You genuinely know the subject',
                                  '話題について本当に知っている'),
    'busyPublicSetting': ('A busy public place', '人のいる公共の場所'),
}
AVOIDS = {
    'personOccupied': ('They look busy or preoccupied', '相手が忙しそうなとき'),
    'personWorking': ('They are working', '相手が仕事中のとき'),
    'headphonesOn': ('They are wearing headphones',
                     '相手がヘッドホンをしているとき'),
    'movingQuickly': ('They are walking quickly', '相手が早足のとき'),
    'isolatedSetting': ('An isolated setting, or after dark',
                        '人が少ない場所や暗い時間帯'),
    'noEyeContact': ('No eye contact yet', 'まだ目が合っていないとき'),
    'companionsPresent': ('They are with other people',
                          '相手が誰かと一緒のとき'),
    'veryLoudSetting': ('It is too loud to be heard',
                        '声が届かないほどうるさいとき'),
    'quietFocusedSetting': ('A quiet place where people are concentrating',
                            '静かで集中している場所'),
}
CATEGORIES = {
    'universal': ('Works anywhere', '場所を問わない'),
    'eyeContactEstablished': ('After eye contact', '目が合ったあと'),
    'cafe': ('Café', 'カフェ'),
    'bar': ('Bar', 'バー'),
    'standingBar': ('Standing bar', '立ち飲み'),
    'club': ('Club', 'クラブ'),
    'streetOrShopping': ('Street or shopping', '路上・商業エリア'),
    'convenienceStore': ('Convenience store', 'コンビニ・スーパー'),
    'bookstore': ('Bookstore or record shop', '書店・レコード店'),
    'parkOrWaterfront': ('Park or waterfront', '公園・海辺'),
    'festival': ('Festival', 'お祭り'),
    'cosplayEvent': ('Cosplay event', 'コスプレイベント'),
    'concert': ('Concert', 'ライブ'),
    'fitnessClass': ('Gym or class', 'ジム・教室'),
    'meetupOrLanguageExchange': ('Meetup or language exchange',
                                 'ミートアップ・言語交換'),
    'party': ('Party', 'パーティー'),
    'waitingLine': ('Waiting in line', '行列'),
    'transport': ('Station or transport', '駅・交通機関'),
    'weather': ('Weather', '天気'),
    'withOneFriend': ('When she is with a friend', '友人と一緒のとき'),
    'contactExchange': ('Leading to contact details', '連絡先につなげる'),
    'gracefulExit': ('Graceful exit', '引き際'),
}
OUTCOMES = {
    'positive': ('Positive', '良い反応'),
    'neutral': ('Neutral', 'ふつう'),
    'unreceptive': ('Unreceptive', '乗り気でなかった'),
    'notRecorded': ('Not recorded', '記録しない'),
}
SORTS = {
    'recentlyAdded': ('Recently added', '追加順'),
    'mostUsed': ('Most used', '使用回数'),
    'highestPositiveHistory': ('Best personal record', '自分の記録が良い順'),
    'alphabetical': ('Alphabetical', '五十音・アルファベット順'),
}
LANGUAGES = {
    'japanese': ('Japanese', '日本語'),
    'english': ('English', 'English'),
    'bilingual': ('Bilingual', '日本語と英語'),
}
THEMES = {
    'light': ('Light', 'ライト'),
    'dark': ('Dark', 'ダーク'),
    'system': ('Match system', 'システムに合わせる'),
}
SOURCES = {
    'manual': ('Entered by hand', '手入力'),
    'cameraScan': ('Camera scan', 'カメラスキャン'),
    'smartGlasses': ('Smart glasses', 'スマートグラス'),
    'ambientAudio': ('Ambient audio', '環境音'),
}
FACTORS = {
    'locationMatch': ('Suits this location', 'この場所に合う'),
    'universalLine': ('Works anywhere', '場所を問わない'),
    'locationMismatch': ('Written for a different place', '別の場所向け'),
    'cueMatch': ('Matches what you can see', '見えているものに合う'),
    'cueNotObserved': ('Refers to something you did not note',
                       '記録していないものに触れている'),
    'activityMatch': ('Fits what is happening', '場面に合う'),
    'groupSizeMatch': ('Right for this many people', '人数に合う'),
    'groupSizeMismatch': ('Written for a different group size',
                          '別の人数向け'),
    'singlePersonLineWithCompanions':
        ('Speaks to one person while others are there',
         '同席者がいるのに一人だけに向けた言い方'),
    'noiseMatch': ('Right for this noise level', '騒がしさに合う'),
    'noiseNear': ('Close to this noise level', '騒がしさがおおむね合う'),
    'noiseMismatch': ('Written for a different noise level',
                      '別の騒がしさ向け'),
    'shortLineForLoudVenue': ('Short enough to be heard here',
                              '短くて聞き取りやすい'),
    'longLineForLoudVenue': ('Probably too long to be heard here',
                             '長すぎて聞き取りにくい'),
    'directnessAlignment': ('Matches the directness you chose',
                            '希望した直接さに一致'),
    'directnessMismatch': ('Further from the directness you chose',
                           '希望した直接さとずれている'),
    'tonePreference': ('Matches the tone you chose', '希望したトーンに一致'),
    'categoryMatch': ('Written for this kind of place', 'この場面向けの一言'),
    'favorite': ('One of your favourites', 'お気に入り'),
    'positiveHistory': ('Has gone well for you before',
                        '過去にうまくいっている'),
    'cautiousHistory': ('Has not gone well for you before',
                        '過去にあまりうまくいっていない'),
    'recentlyShown': ('Suggested recently', '最近提案した'),
    'conversationAlreadyStarted': ('Fits a conversation already under way',
                                   '会話が始まっている場面に合う'),
}

for prefix, table in (
    ('location', LOCATIONS), ('activity', ACTIVITIES),
    ('groupSize', GROUP_SIZES), ('noiseLevel', NOISE), ('tone', TONES),
    ('cue', CUES), ('condition', CONDITIONS), ('avoid', AVOIDS),
    ('category', CATEGORIES), ('outcome', OUTCOMES), ('sort', SORTS),
    ('language', LANGUAGES), ('theme', THEMES), ('source', SOURCES),
    ('factor', FACTORS),
):
    for name, (en, ja) in table.items():
        add('%s.%s' % (prefix, name), en, ja)


# ---------------------------------------------------------------------------
# Cross-check against the Dart enums
# ---------------------------------------------------------------------------
ENUM_PREFIX = {
    'LocationTag': 'location', 'ActivityTag': 'activity',
    'GroupSize': 'groupSize', 'NoiseLevel': 'noiseLevel', 'Tone': 'tone',
    'ObservableCue': 'cue', 'UseCondition': 'condition',
    'AvoidCondition': 'avoid', 'LineCategory': 'category',
    'InteractionOutcome': 'outcome', 'LibrarySort': 'sort',
    'LanguageMode': 'language', 'AppThemePreference': 'theme',
    'ContextSource': 'source',
}


def check_enum_coverage():
    src = open(os.path.join(ROOT, 'lib/domain/enums/enums.dart'),
               encoding='utf-8').read()
    missing = []
    for match in re.finditer(r'enum\s+(\w+)\s*\{(.*?)\}', src, re.S):
        name, body = match.group(1), match.group(2).split(';')[0]
        prefix = ENUM_PREFIX.get(name)
        if prefix is None:
            continue
        for value in [v.strip() for v in body.split(',')]:
            if not re.fullmatch(r'\w+', value):
                continue
            key = '%s.%s' % (prefix, value)
            if key not in S:
                missing.append(key)
    # Score factor codes come from the recommendation models.
    models = open(
        os.path.join(ROOT,
                     'lib/domain/recommendation/recommendation_models.dart'),
        encoding='utf-8').read()
    match = re.search(r'enum ScoreFactorCode \{(.*?)\}', models, re.S)
    if match:
        for value in [v.strip() for v in match.group(1).split(',')]:
            if re.fullmatch(r'\w+', value) and 'factor.%s' % value not in S:
                missing.append('factor.%s' % value)
    return missing


def dart_escape(text):
    return text.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$')


def emit(path, index, name, language):
    lines = [
        '// GENERATED FILE. Do not edit by hand.',
        '//',
        '// Regenerate with:  python3 tool/build_strings.py',
        '// Both language tables are generated from one source so that a key',
        '// cannot exist in one language and be missing from the other.',
        '',
        '/// %s interface strings, keyed by a dotted identifier.' % language,
        '///',
        '/// `{0}`, `{1}` and so on are substituted by',
        '/// AppLocalizations.f.',
        'const Map<String, String> %s = <String, String>{' % name,
    ]
    for key in sorted(S):
        entry = "  '%s': '%s'," % (key, dart_escape(S[key][index]))
        if len(entry) <= 80:
            lines.append(entry)
        else:
            # Match how dart format wraps a map entry it cannot fit on one
            # line: key on its own line, value indented beneath it.
            lines.append("  '%s':" % key)
            lines.append("      '%s'," % dart_escape(S[key][index]))
    lines.append('};')
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write('\n'.join(lines) + '\n')


def main():
    missing = check_enum_coverage()
    if missing:
        print('Missing labels for enum values:')
        for key in missing:
            print('  - %s' % key)
        return 1
    emit(os.path.join(ROOT, 'lib/l10n/strings_en.dart'), 0, 'stringsEn',
         'English')
    emit(os.path.join(ROOT, 'lib/l10n/strings_ja.dart'), 1, 'stringsJa',
         'Japanese')
    print('Strings OK: %d keys x 2 languages' % len(S))
    return 0


if __name__ == '__main__':
    sys.exit(main())
