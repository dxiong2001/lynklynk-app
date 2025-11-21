import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:lynklynk/utils/suggestions.dart' as Suggestions;

class Cursor {
  Cursor(
      {this.line = 0,
      this.column = 0,
      this.anchorLine = 0,
      this.anchorColumn = 0});

  int line = 0;
  int column = 0;
  int anchorLine = 0;
  int anchorColumn = 0;

  Cursor copy() {
    return Cursor(
        line: line,
        column: column,
        anchorLine: anchorLine,
        anchorColumn: anchorColumn);
  }

  Cursor normalized() {
    Cursor res = copy();
    if (line > anchorLine || (line == anchorLine && column > anchorColumn)) {
      res.line = anchorLine;
      res.column = anchorColumn;
      res.anchorLine = line;
      res.anchorColumn = column;
      return res;
    }
    return res;
  }

  bool hasSelection() {
    return line != anchorLine || column != anchorColumn;
  }
}

class Document {
  String docPath = '';
  String currentString = '';
  List<String> lines = <String>[''];
  Cursor cursor = Cursor();
  String? clipboardText = '';
  bool focused = false;
  bool controlActive = false;
  bool shiftActive = false;
  List<bool> bulletActive = List.generate(1, (index) => false);
  List<int> bulletLevel = List.generate(1, (index) => 0);
  double fontSize = 16.0;
  bool disableClick = false;
  Suggestions.Suggestions suggestion = Suggestions.Suggestions();
  List<String> suggestionList = <String>[];

  Future<bool> openFile(String path) async {
    docPath = path;
    File f = File(docPath);
    String fileString = await f.readAsString();
    fileString = fileString.replaceAll(r'\n', '\n');
    print("string: $fileString");
    const splitter = LineSplitter();
    final linesList = splitter.convert(fileString);

    print(linesList);
    print("-------");
    suggestion.initTerms(linesList);
    for (var i = 0; i < linesList.length; i++) {
      print(linesList[i]);

      insertText(linesList[i]);
      if (linesList[i].isNotEmpty && i < linesList.length - 1) {
        insertNewLine();
      }
    }
    // await f
    //     .openRead()
    //     .map(utf8.decode)
    //     .transform(const LineSplitter())
    //     .forEach((line) {
    //   print("line $line");
    //   insertText(line);
    //   if (line.isEmpty) {
    //     insertNewLine();
    //   }
    // });
    moveCursorToStartOfDocument();
    print(lines);
    return true;
  }

  void setFocus(bool focus) {
    focused = focus;
  }

  bool getFocus() {
    return focused;
  }

  bool getDisableClick() {
    return disableClick;
  }

  void setDisableClick(bool disable) {
    disableClick = disable;
  }

  Future<bool> saveFile({String? path}) async {
    File f = File(path ?? docPath);
    String content = '';
    int i;
    for (i = 0; i < lines.length; i++) {
      if (i < lines.length - 1) {
        content += '${lines[i]}\n';
      } else {
        content += lines[i];
      }
    }
    print(bulletLevel);
    print(content);
    suggestion.initTerms(lines);
    f.writeAsString(content);
    return true;
  }

  double getFontSize() {
    return fontSize;
  }

  void setFontSize(double size) {
    if (size < 5 || size > 35) {
      return;
    }
    fontSize = size;
  }

  bool getControlActive() {
    return controlActive;
  }

  void setControlTrue() {
    controlActive = true;
  }

  void setControlFalse() {
    controlActive = false;
  }

  bool getShiftActive() {
    return shiftActive;
  }

  void setShiftTrue() {
    shiftActive = true;
  }

  void setShiftFalse() {
    shiftActive = false;
  }

  void setCursorColumn(int col) {
    cursor.column = col;
  }

  void setCursorLine(int line) {
    cursor.line = line;
  }

  void _validateCursor(bool keepAnchor) {
    if (cursor.line >= lines.length) {
      cursor.line = lines.length - 1;
    }
    if (cursor.line < 0) {
      cursor.line = 0;
    } else {}
    if (cursor.column > lines[cursor.line].length) {
      cursor.column = lines[cursor.line].length;
    }
    if (cursor.column == -1) cursor.column = lines[cursor.line].length;
    if (cursor.column < 0) cursor.column = 0;
    if (!keepAnchor) {
      cursor.anchorLine = cursor.line;
      cursor.anchorColumn = cursor.column;
    }
  }

  void moveCursor(int line, int column, {bool keepAnchor = false}) {
    if (disableClick) {
      return;
    }
    if (cursor.hasSelection() && column < 0) {
      return;
    }
    cursor.line = line;
    cursor.column = column;
    _validateCursor(keepAnchor);
    resetCurrent();
  }

  void moveCursorLeft({int count = 1, bool keepAnchor = false}) {
    cursor.column = cursor.column - count;
    if (cursor.column < 0 && cursor.line > 0) {
      moveCursorUp(keepAnchor: keepAnchor);
      moveCursorToEndOfLine(keepAnchor: keepAnchor);
    }
    _validateCursor(keepAnchor);
  }

  void moveCursorRight({int count = 1, bool keepAnchor = false}) {
    cursor.column = cursor.column + count;
    if (cursor.column > lines[cursor.line].length) {
      moveCursorDown(keepAnchor: keepAnchor);
      moveCursorToStartOfLine(keepAnchor: keepAnchor);
    }
    _validateCursor(keepAnchor);
  }

  void moveCursorUp({int count = 1, bool keepAnchor = false}) {
    cursor.line = cursor.line - count;
    _validateCursor(keepAnchor);
    resetCurrent();
  }

  void moveCursorDown({int count = 1, bool keepAnchor = false}) {
    cursor.line = cursor.line + count;
    _validateCursor(keepAnchor);
    resetCurrent();
  }

  void moveCursorToStartOfLine({bool keepAnchor = false}) {
    cursor.column = 0;
    _validateCursor(keepAnchor);
    resetCurrent();
  }

  void moveCursorToEndOfLine({bool keepAnchor = false}) {
    cursor.column = lines[cursor.line].length;
    _validateCursor(keepAnchor);
    resetCurrent();
  }

  void moveCursorToStartOfDocument({bool keepAnchor = false}) {
    cursor.line = 0;
    cursor.column = 0;
    _validateCursor(keepAnchor);
    resetCurrent();
  }

  void moveCursorToEndOfDocument({bool keepAnchor = false}) {
    cursor.line = lines.length - 1;
    cursor.column = lines[cursor.line].length;
    _validateCursor(keepAnchor);
    resetCurrent();
  }

  void initBulletLists(List<int> bulletList) {
    if (bulletList.isEmpty) return;
    print(bulletList);
    List<bool> bulletListActive = List.generate(0, (index) => false);
    List<int> bulletListLevel = List.generate(0, (index) => 0);
    for (int i = 0; i < bulletList.length; i++) {
      if (bulletList[i] < 0) {
        bulletListActive.add(false);
        bulletListLevel.add(0);
      } else {
        bulletListActive.add(true);
        bulletListLevel.add(bulletList[i]);
      }
    }

    bulletActive = bulletListActive;
    bulletLevel = bulletListLevel;
  }

  void updateBulletLevel(int level, bool increase) {
    if (increase) {
      if (bulletLevel[level] == 15) return;
      bulletLevel[level] += 1;
    } else {
      if (bulletLevel[level] == 0) return;
      bulletLevel[level] -= 1;
    }
  }

  void bulletMode() {
    if (cursor.hasSelection()) {
    } else {
      bulletActive[cursor.line] = !bulletActive[cursor.line];
    }
  }

  void insertNewLine() {
    deleteSelectedText();
    insertText('\n');
  }

  void copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> pasteText() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    clipboardText = clipboardData?.text;
    print(clipboardText);
  }

  void insertTextInit(String text) {
    deleteSelectedText();
    String l = lines[cursor.line];
    String left = l.substring(0, cursor.column);
    String right = l.substring(cursor.column);
    RegExp exp = RegExp(r'(\r\n|\r|\n)');
    var splitTextByNewline = text.split(exp);
    String bulletString = "";
    if (splitTextByNewline.length <= 2) {
      if (splitTextByNewline[0] == "") {
        lines[cursor.line] = left;

        lines.insert(cursor.line + 1, bulletString + right);

        moveCursorDown();
        moveCursorToStartOfLine();
      } else {
        lines[cursor.line] = left + splitTextByNewline[0] + right;
        moveCursorRight(count: text.length);
      }
      return;
    } else {
      for (int i = 0; i < splitTextByNewline.length; i++) {
        if (i == 0) {
          lines[cursor.line] += splitTextByNewline[0];
        } else {
          lines.insert(cursor.line + 1, splitTextByNewline[i]);
        }
        moveCursorDown();
      }
      lines[cursor.line] += right;
      return;
    }
  }

  void updateSuggestionList(List<String> s) {
    suggestionList = s;
  }

  List<String> getSuggestList() {
    return suggestionList;
  }

  void clearSuggestList() {
    suggestionList = <String>[];
  }

  String getCurrent() {
    return currentString;
  }

  void deleteLastCharCurrent() {
    if (currentString.isEmpty) {
      return;
    }
    currentString = currentString.substring(0, currentString.length - 1);
    print("remaining: $currentString");
  }

  void updateCurrent(String c) {
    currentString += c;
  }

  void resetCurrent() {
    currentString = "";
  }

  void insertText(String text) {
    deleteSelectedText();
    String l = lines[cursor.line];
    String left = l.substring(0, cursor.column);
    String right = l.substring(cursor.column);
    RegExp exp = RegExp(r'(\r\n|\r|\n)');
    var splitTextByNewline = text.split(exp);
    String bulletString = "";
    if (splitTextByNewline.length <= 2) {
      if (splitTextByNewline[0] == "") {
        lines[cursor.line] = left;
        if (bulletActive[cursor.line]) {
          bulletActive.insert(cursor.line + 1, true);
          bulletLevel.insert(cursor.line + 1, bulletLevel[cursor.line]);
        } else {
          bulletActive.insert(cursor.line + 1, false);
          bulletLevel.insert(cursor.line + 1, 0);
        }
        lines.insert(cursor.line + 1, bulletString + right);

        moveCursorDown();
        moveCursorToStartOfLine();
      } else {
        lines[cursor.line] = left + splitTextByNewline[0] + right;
        moveCursorRight(count: text.length);
      }
      return;
    } else {
      for (int i = 0; i < splitTextByNewline.length - 1; i++) {
        if (i == 0) {
          lines[cursor.line] += splitTextByNewline[0];
        } else {
          lines.insert(cursor.line + 1, splitTextByNewline[i]);
          bulletActive.insert(cursor.line + 1, false);
          bulletLevel.insert(cursor.line + 1, 0);
        }
        moveCursorDown();
      }
      lines[cursor.line] += right;
      return;
    }
  }

  void deleteText({int numberOfCharacters = 1, bool line = false}) {
    if (cursor.column == 0 && cursor.line == 0) {
      return;
    }

    if (cursor.column == 0 && bulletActive[cursor.line]) {
      bulletActive[cursor.line] = false;
      return;
    }

    String l = lines[cursor.line];
    int priorCursorColumn = cursor.column;
    if (!line) {
      moveCursorLeft();
    }

    // handle join lines
    if (priorCursorColumn == 0) {
      Cursor cur = cursor.copy();

      // copy then delete previous line to new current line
      lines[cursor.line] += lines[cursor.line + 1];
      lines.removeAt(cursor.line + 1);
      bulletActive.removeAt(cursor.line + 1);
      bulletLevel.removeAt(cursor.line + 1);
      moveCursorUp();
      cursor = cur;
      return;
    }
    Cursor cur = cursor.normalized();
    String left = l.substring(0, cur.column);
    String right = l.substring(cur.column + numberOfCharacters);
    cursor = cur;

    lines[cursor.line] = left + right;
  }

  void deleteLine({int numberOfLines = 1}) {
    for (int i = 0; i < numberOfLines; i++) {
      moveCursorToStartOfLine();
      deleteText(numberOfCharacters: lines[cursor.line].length);
    }
    _validateCursor(false);
  }

  List<String> selectedLines() {
    List<String> res = <String>[];
    Cursor cur = cursor.normalized();
    if (cur.line == cur.anchorLine) {
      String sel = lines[cur.line].substring(cur.column, cur.anchorColumn);
      res.add(sel);
      return res;
    }

    res.add(lines[cur.line].substring(cur.column));
    for (int i = cur.line + 1; i < cur.anchorLine; i++) {
      res.add(lines[i]);
    }
    res.add(lines[cur.anchorLine].substring(0, cur.anchorColumn));
    return res;
  }

  String selectedText() {
    return selectedLines().join('\n');
  }

  void selectAll() {
    moveCursorToStartOfDocument();
    moveCursorToEndOfDocument(keepAnchor: true);
  }

  void deleteSelectedText() {
    if (!cursor.hasSelection()) {
      return;
    }

    Cursor cur = cursor.normalized();
    List<String> res = selectedLines();
    if (res.length == 1) {
      print(cur.anchorColumn - cur.column);
      deleteText(numberOfCharacters: cur.anchorColumn - cur.column);
      clearSelection();
      return;
    }

    String l = lines[cur.line];
    String left = l.substring(0, cur.column);
    l = lines[cur.anchorLine];
    String right = l.substring(cur.anchorColumn);

    cursor = cur;
    lines[cur.line] = left + right;
    lines[cur.anchorLine] = lines[cur.anchorLine].substring(cur.anchorColumn);
    for (int i = 0; i < res.length - 1; i++) {
      lines.removeAt(cur.line + 1);
      bulletActive.removeAt(cur.line + 1);
      bulletLevel.removeAt(cur.line + 1);
    }
    _validateCursor(false);
  }

  void clearSelection() {
    cursor.anchorLine = cursor.line;
    cursor.anchorColumn = cursor.column;
  }

  void command(String cmd) async {
    switch (cmd) {
      case 'ctrl+a':
        selectAll();
        break;
      case 'ctrl+c':
        //clipboardText = selectedText();
        copyText(selectedText());
        break;
      case 'ctrl+x':
        clipboardText = selectedText();
        deleteSelectedText();
        break;
      case 'ctrl+v':
        await pasteText();
        insertText(clipboardText ?? "");

        break;
      case 'ctrl+s':
        saveFile();
        break;
    }
  }
}
