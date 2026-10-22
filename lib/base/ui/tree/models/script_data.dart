import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:json_conversion_annotation/json_conversion_annotation.dart';

import '../tree_node.dart';
import '../utilities.dart';

/// Defines the data used to display a [TreeNode].
///
/// Used by [TreeView] to display a [TreeNode].
///
/// This object allows the creation of key, label and icon to display
/// a node on the [TreeView] widget. The key and label properties are
/// required. The key is needed for events that occur on the generated
/// [TreeNode]. It should always be unique.
///
/// ## Path semantics
///
/// QingLong's `/scripts` listing returns, for every entry:
///   * `key`    – the path of the entry relative to the scripts root,
///                e.g. `folder/sub/file.py`
///   * `parent` – the directory that contains it, relative to the root,
///                e.g. `folder/sub`
///
/// The app used to forward the server's `parent` verbatim when opening a
/// file (`GET /scripts/<name>?path=<parent>`). When that value is anything
/// other than the *full* relative directory — older panels send only the
/// immediate parent folder name, some proxies send an absolute path — the
/// request lands on a non-existent file, so scripts nested two or more
/// folders deep could never be opened.
///
/// [normalizeTree] now derives each node's directory from the tree itself,
/// which is authoritative, and [pathCandidates] keeps the server value as a
/// fallback so an unusual panel still has a chance.
@JsonConversion()
class ScriptData {
  final String key;

  final String title;
  final String type;

  final bool expanded;

  final List<ScriptData> children;

  /// Directory containing this entry, relative to the scripts root.
  /// Derived from the tree by [normalizeTree]; equals "" at the root.
  final String parent;

  /// The raw `parent` value the server sent, kept for fallback attempts.
  final String serverParent;

  ScriptData({
    required this.key,
    required this.title,
    required this.type,
    this.children = const [],
    this.expanded = false,
    this.parent = "",
    this.serverParent = "",
  });

  static ScriptData jsonConversion(Map<String, dynamic> json) {
    return ScriptData.fromMap(json);
  }

  /// Creates a [ScriptData] from a Map<String, dynamic> map. The map
  /// should contain a "label" value. If the key value is
  /// missing, it generates a unique key.
  /// If the expanded value, if present, can be any 'truthful'
  /// value. Excepted values include: 1, yes, true and their
  /// associated string values.
  static ScriptData fromMap(Map<String, dynamic> map) {
    String? _key = map['key'];
    String? title = map['title'];

    String? parent = map['parent'];
    List<ScriptData> _children = [];

    if (map['children'] != null) {
      List<Map<String, dynamic>> _childrenMap = List.from(map['children']);
      _children = _childrenMap.map((Map<String, dynamic> child) => ScriptData.fromMap(child)).toList();
    }
    String? type = map['type'];

    if (type == null || type.isEmpty) {
      if (_children.isNotEmpty) {
        type = "directory";
      } else {
        type = "file";
      }
    }

    return ScriptData(
      key: '$_key',
      title: title ?? "",
      type: type ?? "",
      expanded: false,
      parent: parent ?? "",
      serverParent: parent ?? "",
      children: _children,
    );
  }

  /// Rewrites `parent` on every node to the directory path implied by the
  /// tree structure. This is the path the panel's `/scripts?path=` and
  /// `/scripts/<file>?path=` endpoints expect, at any depth.
  static List<ScriptData> normalizeTree(List<ScriptData> nodes, [String dir = ""]) {
    return nodes.map((ScriptData node) {
      if (node.isParent) {
        return node.copyWith(
          parent: dir,
          children: normalizeTree(node.children, joinPath(dir, node.title)),
        );
      }
      return node.copyWith(parent: dir);
    }).toList();
  }

  static String joinPath(String dir, String name) {
    if (dir.isEmpty) return name;
    if (name.isEmpty) return dir;
    return "$dir/$name";
  }

  /// Directory paths to try, most trustworthy first.
  ///
  /// 1. the structural path derived from the tree,
  /// 2. whatever the panel reported as `parent`,
  /// 3. the dirname of the server's `key`.
  ///
  /// The empty string (scripts root) is only returned when this entry really
  /// sits at the root, so a deep file can never accidentally resolve to a
  /// same-named file in the root directory.
  List<String> get pathCandidates {
    final List<String> out = <String>[];

    void add(String? value) {
      if (value == null) return;
      final String v = value.trim();
      if (v.isEmpty && !parent.isEmpty) return;
      if (out.contains(v)) return;
      out.add(v);
    }

    add(parent);
    add(serverParent);

    final String k = key;
    final int slash = k.lastIndexOf('/');
    if (slash >= 0) {
      add(k.substring(0, slash));
    } else if (parent.isEmpty) {
      add("");
    }
    if (out.isEmpty) out.add(parent);
    return out;
  }

  /// Creates a copy of this object but with the given fields
  /// replaced with the new values.
  ScriptData copyWith({
    String? key,
    String? title,
    String? type,
    List<ScriptData>? children,
    bool? expanded,
    String? parent,
    String? serverParent,
    IconData? icon,
    Color? iconColor,
    Color? selectedIconColor,
  }) =>
      ScriptData(
        key: key ?? this.key,
        title: title ?? this.title,
        type: type ?? this.type,
        expanded: expanded ?? this.expanded,
        parent: parent ?? this.parent,
        serverParent: serverParent ?? this.serverParent,
        children: children ?? this.children,
      );

  /// Whether this object has children [ScriptData].
  bool get isParent => type == "directory";

  @override
  String toString() {
    return "";
  }

  @override
  int get hashCode {
    return hashValues(
      key,
      title,
      expanded,
      parent,
      children,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is ScriptData &&
        other.key == key &&
        other.title == title &&
        other.expanded == expanded &&
        other.parent == parent &&
        other.children.length == children.length;
  }
}
