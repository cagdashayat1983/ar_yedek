import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  runApp(const BenimUygulamam());
}

// =============================================================================
// 1. AYARLAR & TEMA
// =============================================================================
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class AppColors {
  static const primaryPurple = Color(0xFF8B5CF6);
  static const docBlue = Color(0xFF5E96FC);
  static const gridGreen = Color(0xFF42D39E);
  static const boardOrange = Color(0xFFFFA654);
  static const calendarRed = Color(0xFFFF6B6B);
  static const aiGold = Color(0xFFFFD700);

  static const bgDark = Color(0xFF121212);
  static const cardDark = Color(0xFF1E1E1E);
  static const textGrey = Color(0xFF9CA3AF);
  static const borderGrey = Color(0xFF333333);
}

// =============================================================================
// 2. YAPAY ZEKA SERVİSİ
// =============================================================================
class AIService {
  static String apiKey = "";

  static Future<String?> generateContent(
      String prompt, String contextText) async {
    if (apiKey.isEmpty)
      return "API Key Eksik! Lütfen ana ekrandaki anahtar ikonuna tıklayarak ekleyin.";
    try {
      // Model ismini güncelledik. Eğer 1.5-flash hata verirse 'gemini-pro' deneyin.
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      final content = [Content.text("Context: $contextText\n\nTask: $prompt")];
      final response = await model.generateContent(content);
      return response.text;
    } catch (e) {
      return "AI Hatası: $e";
    }
  }
}

// =============================================================================
// 3. GÜNCELLENMİŞ RESİM MODÜLÜ (Quill v11 Uyumlu)
// =============================================================================
class ImageConfig {
  String path;
  double scale;
  String align;
  String caption;

  ImageConfig(
      {required this.path,
      this.scale = 0.5,
      this.align = 'center',
      this.caption = ''});

  @override
  String toString() =>
      '$path#scale=$scale&align=$align&caption=${Uri.encodeComponent(caption)}';

  static ImageConfig fromString(String data) {
    if (!data.contains('#')) return ImageConfig(path: data);
    try {
      final parts = data.split('#');
      final params = Uri.splitQueryString(parts[1]);
      return ImageConfig(
        path: parts[0],
        scale: double.tryParse(params['scale'] ?? '0.5') ?? 0.5,
        align: params['align'] ?? 'center',
        caption: params['caption'] ?? '',
      );
    } catch (e) {
      return ImageConfig(path: data);
    }
  }
}

// --- DÜZELTME: EmbedBuilder artık EmbedContext alıyor ---
class AdvancedImageEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    // Yeni versiyonda veriler 'embedContext' içinden alınır
    final nodeData = embedContext.node.value.data;
    final controller = embedContext.controller;
    final readOnly = embedContext.readOnly;

    return EditableImageWidget(
      nodeData: nodeData,
      controller: controller,
      node: embedContext.node,
      readOnly: readOnly,
    );
  }
}

class EditableImageWidget extends StatefulWidget {
  final String nodeData;
  final quill.QuillController controller;
  final quill.Embed node;
  final bool readOnly;

  const EditableImageWidget({
    super.key,
    required this.nodeData,
    required this.controller,
    required this.node,
    required this.readOnly,
  });

  @override
  State<EditableImageWidget> createState() => _EditableImageWidgetState();
}

class _EditableImageWidgetState extends State<EditableImageWidget> {
  late ImageConfig config;
  late TextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    config = ImageConfig.fromString(widget.nodeData);
    _captionController = TextEditingController(text: config.caption);
  }

  void _persistChanges() {
    try {
      final doc = widget.controller.document;
      final delta = doc.toDelta();
      int offset = 0;
      bool found = false;
      for (final op in delta.toList()) {
        if (op.key == 'insert' &&
            op.value is Map &&
            op.value['image'] == widget.nodeData) {
          found = true;
          break;
        }
        offset += (op.length ?? 1);
      }
      if (found) {
        final newEmbedData = config.toString();
        if (newEmbedData == widget.nodeData) return;
        // ignoreChange artık yok, direkt replaceText yapıyoruz
        widget.controller
            .replaceText(offset, 1, quill.BlockEmbed.image(newEmbedData), null);
      }
    } catch (e) {
      debugPrint("Image save error: $e");
    }
  }

  void _showOptions() {
    if (widget.readOnly) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      barrierColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(20),
            height: 250,
            child: Column(
              children: [
                const Text("Image Settings",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Icon(Icons.photo_size_select_large,
                        color: Colors.white70),
                    Expanded(
                      child: Slider(
                        value: config.scale,
                        min: 0.1,
                        max: 1.0,
                        activeColor: AppColors.primaryPurple,
                        inactiveColor: Colors.black,
                        onChanged: (val) {
                          setSheetState(() => config.scale = val);
                          setState(() => config.scale = val);
                        },
                        onChangeEnd: (val) => _persistChanges(),
                      ),
                    ),
                    Text("%${(config.scale * 100).toInt()}",
                        style: const TextStyle(color: Colors.white))
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _alignIcon(Icons.format_align_left, 'left', setSheetState),
                    _alignIcon(
                        Icons.format_align_center, 'center', setSheetState),
                    _alignIcon(Icons.format_align_right, 'right', setSheetState)
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _alignIcon(IconData icon, String align, Function setSheetState) {
    return IconButton(
      icon: Icon(icon,
          color: config.align == align ? AppColors.primaryPurple : Colors.grey),
      onPressed: () {
        setSheetState(() => config.align = align);
        setState(() => config.align = align);
        _persistChanges();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (kIsWeb) {
      imageWidget = Image.network(config.path, fit: BoxFit.cover);
    } else {
      imageWidget = Image.file(
        File(config.path),
        fit: BoxFit.cover,
        errorBuilder: (c, o, s) =>
            const Icon(Icons.broken_image, color: Colors.grey),
      );
    }

    Widget content;
    if (config.align == 'center') {
      content = Column(
        children: [
          _buildImageContainer(imageWidget),
          if (!widget.readOnly)
            SizedBox(
              width: MediaQuery.of(context).size.width * config.scale,
              child: _buildCaptionField(center: true),
            )
        ],
      );
    } else {
      List<Widget> children = [
        _buildImageContainer(imageWidget),
        const SizedBox(width: 15),
        Expanded(
          child: widget.readOnly
              ? Text(config.caption,
                  style: const TextStyle(color: Colors.white70))
              : _buildCaptionField(),
        )
      ];
      if (config.align == 'right') children = children.reversed.toList();
      content =
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _showOptions,
        behavior: HitTestBehavior.translucent,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10), child: content),
      ),
    );
  }

  Widget _buildImageContainer(Widget image) {
    return Container(
      width: MediaQuery.of(context).size.width * config.scale,
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
    );
  }

  Widget _buildCaptionField({bool center = false}) {
    return TextField(
      controller: _captionController,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      textAlign: center ? TextAlign.center : TextAlign.left,
      decoration: const InputDecoration(
        hintText: "Write...",
        hintStyle: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        border: InputBorder.none,
        isDense: true,
      ),
      maxLines: null,
      onChanged: (val) {
        config.caption = val;
      },
      onEditingComplete: _persistChanges,
    );
  }
}

// =============================================================================
// 4. DATA MODELLERİ
// =============================================================================
class WorkspaceItem {
  String id;
  String title;
  String type;
  dynamic content;
  String date;
  WorkspaceItem(
      {required this.id,
      required this.title,
      required this.type,
      this.content,
      required this.date});
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'content': content,
        'date': date
      };
  factory WorkspaceItem.fromJson(Map<String, dynamic> json) => WorkspaceItem(
      id: json['id'],
      title: json['title'],
      type: json['type'],
      content: json['content'],
      date: json['date']);
}

class Space {
  String id;
  String name;
  List<WorkspaceItem> items;
  bool isExpanded;
  Space(
      {required this.id,
      required this.name,
      required this.items,
      this.isExpanded = true});
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((i) => i.toJson()).toList(),
        'isExpanded': isExpanded
      };
  factory Space.fromJson(Map<String, dynamic> json) => Space(
      id: json['id'],
      name: json['name'],
      isExpanded: json['isExpanded'] ?? true,
      items: (json['items'] as List)
          .map((i) => WorkspaceItem.fromJson(i))
          .toList());
}

class Workspace {
  String id;
  String name;
  List<Space> spaces;
  Workspace({required this.id, required this.name, required this.spaces});
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'spaces': spaces.map((s) => s.toJson()).toList()
      };
  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
      id: json['id'],
      name: json['name'],
      spaces: (json['spaces'] as List).map((s) => Space.fromJson(s)).toList());
}

// =============================================================================
// 5. ANA UYGULAMA
// =============================================================================
class BenimUygulamam extends StatelessWidget {
  const BenimUygulamam({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scrollBehavior: AppScrollBehavior(),
      debugShowCheckedModeBanner: false,
      title: 'AppFlowy Clone',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bgDark,
        primaryColor: AppColors.primaryPurple,
        cardColor: AppColors.cardDark,
        bottomSheetTheme:
            const BottomSheetThemeData(backgroundColor: AppColors.cardDark),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
            .apply(bodyColor: Colors.white, displayColor: Colors.white),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.bgDark,
            hintStyle: const TextStyle(color: AppColors.textGrey),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none)),
        dialogTheme: DialogThemeData(
            backgroundColor: AppColors.cardDark,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
      ),
      home: const AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});
  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  List<Workspace> workspaces = [];
  int currentWorkspaceIndex = 0;
  Workspace get activeWorkspace => workspaces[currentWorkspaceIndex];

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  Future<void> _verileriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    AIService.apiKey = prefs.getString('gemini_api_key') ?? "";
    final data = prefs.getString('app_data_v50_final_fix');
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        setState(() {
          workspaces = decoded.map((e) => Workspace.fromJson(e)).toList();
          if (workspaces.isEmpty) _createDefaultWorkspace();
        });
      } catch (e) {
        _createDefaultWorkspace();
      }
    } else {
      _createDefaultWorkspace();
    }
  }

  void _createDefaultWorkspace() {
    setState(() {
      workspaces = [
        Workspace(
            id: DateTime.now().toString(),
            name: "My Workspace",
            spaces: [Space(id: "1", name: "General", items: [])])
      ];
      currentWorkspaceIndex = 0;
    });
    _verileriKaydet();
  }

  Future<void> _verileriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_data_v50_final_fix',
        jsonEncode(workspaces.map((w) => w.toJson()).toList()));
  }

  void _moveItemBetweenSpaces(
      String sourceSpaceId, String targetSpaceId, WorkspaceItem item) {
    if (sourceSpaceId == targetSpaceId) return;
    setState(() {
      final sourceSpace =
          activeWorkspace.spaces.firstWhere((s) => s.id == sourceSpaceId);
      sourceSpace.items.removeWhere((i) => i.id == item.id);
      final targetSpace =
          activeWorkspace.spaces.firstWhere((s) => s.id == targetSpaceId);
      targetSpace.items.add(item);
      targetSpace.isExpanded = true;
    });
    _verileriKaydet();
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            "Moved to ${activeWorkspace.spaces.firstWhere((s) => s.id == targetSpaceId).name}"),
        backgroundColor: AppColors.gridGreen,
        duration: const Duration(milliseconds: 800)));
  }

  void _onReorderItemsInSpace(Space space, int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = space.items.removeAt(oldIndex);
      space.items.insert(newIndex, item);
    });
    _verileriKaydet();
  }

  void _showMoveMenu(Space currentSpace, WorkspaceItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            const Text("Move to Space", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: activeWorkspace.spaces.length,
            itemBuilder: (context, index) {
              final target = activeWorkspace.spaces[index];
              if (target.id == currentSpace.id) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.folder_open,
                    color: AppColors.primaryPurple),
                title: Text(target.name,
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  _moveItemBetweenSpaces(currentSpace.id, target.id, item);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))
        ],
      ),
    );
  }

  WorkspaceItem? _addItem(String spaceId, String type) {
    try {
      final space = activeWorkspace.spaces.firstWhere((s) => s.id == spaceId);
      dynamic initialContent;
      if (type == 'Grid')
        initialContent = {
          'properties': [
            {'name': 'Name', 'type': 'text'},
            {'name': 'Status', 'type': 'select'},
            {'name': 'Done', 'type': 'checkbox'}
          ],
          'rows': []
        };
      else if (type == 'Board')
        initialContent = {
          'columns': [
            {'name': 'No Status', 'cards': []},
            {'name': 'To Do', 'cards': []},
            {'name': 'Doing', 'cards': []},
            {'name': 'Done', 'cards': []}
          ]
        };
      else if (type == 'Calendar')
        initialContent = {'events': {}};
      else
        initialContent = [];
      final newItem = WorkspaceItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: "Untitled $type",
          type: type,
          content: initialContent,
          date: DateFormat('dd MMM').format(DateTime.now()));
      setState(() {
        space.items.add(newItem);
        space.isExpanded = true;
      });
      _verileriKaydet();
      return newItem;
    } catch (e) {
      return null;
    }
  }

  void _showAddMenu(BuildContext context, String spaceId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Add New Page",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            _buildMenuItem(Icons.article_rounded, "Document", AppColors.docBlue,
                () {
              Navigator.pop(ctx);
              var i = _addItem(spaceId, 'Document');
              if (i != null) _openPage(i);
            }),
            _buildMenuItem(Icons.grid_view_rounded, "Grid", AppColors.gridGreen,
                () {
              Navigator.pop(ctx);
              var i = _addItem(spaceId, 'Grid');
              if (i != null) _openPage(i);
            }),
            _buildMenuItem(
                Icons.view_kanban_rounded, "Board", AppColors.boardOrange, () {
              Navigator.pop(ctx);
              var i = _addItem(spaceId, 'Board');
              if (i != null) _openPage(i);
            }),
            _buildMenuItem(
                Icons.calendar_month_rounded, "Calendar", AppColors.calendarRed,
                () {
              Navigator.pop(ctx);
              var i = _addItem(spaceId, 'Calendar');
              if (i != null) _openPage(i);
            })
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 22)),
      title: Text(label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  void _openPage(WorkspaceItem item) async {
    Widget pageWidget;
    switch (item.type) {
      case 'Grid':
        pageWidget = GridPage(item: item);
        break;
      case 'Board':
        pageWidget = BoardPage(item: item);
        break;
      case 'Calendar':
        pageWidget = CalendarPage(item: item);
        break;
      default:
        pageWidget = DocumentPage(item: item);
        break;
    }
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => pageWidget));
    setState(() {});
    _verileriKaydet();
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Grid':
        return Icons.grid_view_rounded;
      case 'Board':
        return Icons.view_kanban_rounded;
      case 'Calendar':
        return Icons.calendar_month_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Grid':
        return AppColors.gridGreen;
      case 'Board':
        return AppColors.boardOrange;
      case 'Calendar':
        return AppColors.calendarRed;
      default:
        return AppColors.docBlue;
    }
  }

  void _switchWorkspace(int index) {
    setState(() => currentWorkspaceIndex = index);
    Navigator.pop(context);
  }

  void _createNewWorkspaceDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Workspace"),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Name")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  workspaces.add(Workspace(
                      id: DateTime.now().toString(),
                      name: controller.text,
                      spaces: [
                        Space(
                            id: DateTime.now().toString(),
                            name: "General",
                            items: [])
                      ]));
                  currentWorkspaceIndex = workspaces.length - 1;
                });
                _verileriKaydet();
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          )
        ],
      ),
    );
  }

  void _deleteWorkspace(int index) {
    if (workspaces.length <= 1) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Workspace?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              setState(() {
                workspaces.removeAt(index);
                if (currentWorkspaceIndex >= workspaces.length)
                  currentWorkspaceIndex = workspaces.length - 1;
              });
              _verileriKaydet();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child:
                const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          )
        ],
      ),
    );
  }

  void _showWorkspaceMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text("SWITCH WORKSPACE",
                    style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold))),
            ...List.generate(workspaces.length, (index) {
              bool isActive = index == currentWorkspaceIndex;
              return ListTile(
                leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primaryPurple
                            : AppColors.cardDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isActive
                                ? AppColors.primaryPurple
                                : AppColors.textGrey.withOpacity(0.3))),
                    child: Center(
                        child: Text(workspaces[index].name[0].toUpperCase(),
                            style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : AppColors.textGrey,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)))),
                title: Text(workspaces[index].name,
                    style: TextStyle(
                        color: isActive ? Colors.white : AppColors.textGrey,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16)),
                onTap: () => _switchWorkspace(index),
              );
            }),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: AppColors.textGrey, thickness: 0.2)),
            ListTile(
              leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.textGrey.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add,
                      color: AppColors.textGrey, size: 20)),
              title: const Text("Create New Workspace",
                  style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
              onTap: _createNewWorkspaceDialog,
            )
          ],
        ),
      ),
    );
  }

  void _createSpace() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Space"),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Space Name")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() => activeWorkspace.spaces.add(Space(
                    id: DateTime.now().toString(),
                    name: controller.text,
                    items: [])));
                _verileriKaydet();
                Navigator.pop(ctx);
              }
            },
            child: const Text("Create"),
          )
        ],
      ),
    );
  }

  void _deleteSpace(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Space?"),
        content: const Text("This will delete all pages inside."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              setState(() => activeWorkspace.spaces.removeAt(index));
              _verileriKaydet();
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  void _showApiKeyDialog() {
    TextEditingController controller =
        TextEditingController(text: AIService.apiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Enter Gemini API Key"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Get key from: aistudio.google.com",
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: "API Key"))
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              AIService.apiKey = controller.text;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('gemini_api_key', controller.text);
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (workspaces.isEmpty)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: InkWell(
                onTap: _showWorkspaceMenu,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: AppColors.primaryPurple,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      AppColors.primaryPurple.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ]),
                        child: Center(
                          child: Text(activeWorkspace.name[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(activeWorkspace.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 5),
                      const Icon(Icons.keyboard_arrow_down,
                          color: AppColors.textGrey)
                    ],
                  ),
                ),
              ),
            ),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                    color: AppColors.textGrey.withOpacity(0.3),
                    thickness: 0.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("SPACES",
                      style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1)),
                  Row(children: [
                    IconButton(
                        onPressed: _showApiKeyDialog,
                        icon: const Icon(Icons.key,
                            size: 18, color: AppColors.textGrey)),
                    InkWell(
                        onTap: _createSpace,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: AppColors.cardDark,
                                borderRadius: BorderRadius.circular(20)),
                            child: const Icon(Icons.add,
                                color: AppColors.textGrey, size: 20)))
                  ])
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: activeWorkspace.spaces.length,
                itemBuilder: (context, index) {
                  final space = activeWorkspace.spaces[index];
                  return DragTarget<Map<String, dynamic>>(
                    onWillAccept: (data) => data?['fromSpaceId'] != space.id,
                    onAccept: (data) => _moveItemBetweenSpaces(
                        data['fromSpaceId'], space.id, data['item']),
                    builder: (context, candidateData, rejectedData) {
                      final isHovered = candidateData.isNotEmpty;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        decoration: BoxDecoration(
                            color: isHovered
                                ? AppColors.gridGreen.withOpacity(0.2)
                                : null,
                            border: isHovered
                                ? Border.all(
                                    color: AppColors.gridGreen, width: 2)
                                : null,
                            borderRadius: BorderRadius.circular(10)),
                        child: Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            key: Key(space.id),
                            initiallyExpanded: space.isExpanded,
                            onExpansionChanged: (val) =>
                                setState(() => space.isExpanded = val),
                            leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: AppColors.primaryPurple
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Icon(Icons.folder_rounded,
                                    color: isHovered
                                        ? AppColors.gridGreen
                                        : AppColors.primaryPurple,
                                    size: 20)),
                            title: Text(space.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: isHovered
                                        ? AppColors.gridGreen
                                        : Colors.white)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: const Icon(Icons.add_circle_outline,
                                        color: AppColors.textGrey, size: 20),
                                    onPressed: () =>
                                        _showAddMenu(context, space.id)),
                                IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppColors.textGrey, size: 20),
                                    onPressed: () => _deleteSpace(index))
                              ],
                            ),
                            children: [
                              ReorderableListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: space.items.length,
                                onReorder: (oldIndex, newIndex) =>
                                    _onReorderItemsInSpace(
                                        space, oldIndex, newIndex),
                                itemBuilder: (ctx, itemIndex) {
                                  final item = space.items[itemIndex];
                                  final itemColor = _getColorForType(item.type);
                                  return LongPressDraggable<
                                      Map<String, dynamic>>(
                                    key: Key(item.id),
                                    data: {
                                      'item': item,
                                      'fromSpaceId': space.id
                                    },
                                    hapticFeedbackOnStart: true,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.9,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            color: AppColors.cardDark,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.black54,
                                                  blurRadius: 10)
                                            ]),
                                        child: Row(
                                          children: [
                                            Container(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                    color: itemColor
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6)),
                                                child: Icon(
                                                    _getIconForType(item.type),
                                                    color: itemColor,
                                                    size: 18)),
                                            const SizedBox(width: 12),
                                            Text(item.title,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    decoration:
                                                        TextDecoration.none))
                                          ],
                                        ),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(
                                        opacity: 0.3,
                                        child: _buildListItem(
                                            item, itemColor, space)),
                                    child:
                                        _buildListItem(item, itemColor, space),
                                  );
                                },
                              ),
                              if (space.items.isEmpty && !isHovered)
                                Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text("No pages inside",
                                        style: TextStyle(
                                            color: AppColors.textGrey
                                                .withOpacity(0.5),
                                            fontSize: 12))),
                              if (isHovered)
                                Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text("Drop here to move!",
                                        style: const TextStyle(
                                            color: AppColors.gridGreen,
                                            fontWeight: FontWeight.bold)))
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(WorkspaceItem item, Color itemColor, Space space) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: AppColors.cardDark.withOpacity(0.5),
        contentPadding: const EdgeInsets.only(left: 12, right: 10),
        dense: true,
        leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: itemColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6)),
            child:
                Icon(_getIconForType(item.type), color: itemColor, size: 18)),
        title: Text(item.title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        onTap: () => _openPage(item),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_horiz, size: 18, color: AppColors.textGrey),
          onSelected: (val) {
            if (val == 'delete') {
              setState(() => space.items.remove(item));
              _verileriKaydet();
            } else if (val == 'move') {
              _showMoveMenu(space, item);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
                value: 'move',
                child: Row(children: [
                  Icon(Icons.drive_file_move_outline, size: 18),
                  SizedBox(width: 8),
                  Text("Move to Space")
                ])),
            const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text("Delete", style: TextStyle(color: Colors.red))
                ]))
          ],
        ),
      ),
    );
  }
}

// ================== SAYFALAR ==================
class DocumentPage extends StatefulWidget {
  final WorkspaceItem item;
  const DocumentPage({super.key, required this.item});
  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  late quill.QuillController _controller;
  final TextEditingController _titleController = TextEditingController();
  String? resimYolu;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.item.title;
    try {
      if (widget.item.content != null &&
          (widget.item.content as List).isNotEmpty) {
        _controller = quill.QuillController(
            document: quill.Document.fromJson(widget.item.content),
            selection: const TextSelection.collapsed(offset: 0));
      } else {
        _controller = quill.QuillController.basic();
      }
    } catch (e) {
      _controller = quill.QuillController.basic();
    }
  }

  void _save() {
    widget.item.title = _titleController.text;
    widget.item.content = _controller.document.toDelta().toJson();
  }

  Future<void> _medyaSec(String tip, {bool isCover = false}) async {
    try {
      final picker = ImagePicker();
      if (isCover) {
        final XFile? image =
            await picker.pickImage(source: ImageSource.gallery);
        if (image != null) setState(() => resimYolu = image.path);
        return;
      }
      if (tip == 'image') {
        final XFile? image =
            await picker.pickImage(source: ImageSource.gallery);
        if (image != null)
          _controller.document.insert(_controller.selection.baseOffset,
              quill.BlockEmbed.image(image.path));
      } else if (tip == 'file' || tip == 'pdf') {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null)
          _controller.document.insert(_controller.selection.baseOffset,
              "📎 ${result.files.single.name} ");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Error: Check permissions!"),
          backgroundColor: Colors.red));
    }
  }

  void _formatUygula(quill.Attribute attribute) {
    if (attribute.key == 'header' && attribute.value == null) {
      _controller.formatSelection(quill.Attribute.h1);
      _controller.formatSelection(quill.Attribute.header);
    } else {
      _controller.formatSelection(attribute);
    }
    Navigator.pop(context);
  }

  void _showAIDialog() {
    TextEditingController promptCtrl = TextEditingController();
    String? responseText;
    bool isLoading = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.aiGold),
                    const SizedBox(width: 8),
                    const Text("Ask AI Assistant",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18))
                  ],
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: promptCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Ask anything or type 'Summarize'",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send,
                          color: AppColors.primaryPurple),
                      onPressed: () async {
                        if (promptCtrl.text.isEmpty) return;
                        setModalState(() => isLoading = true);
                        final text = await AIService.generateContent(
                            promptCtrl.text,
                            _controller.document.toPlainText());
                        setModalState(() {
                          isLoading = false;
                          responseText = text;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                if (isLoading)
                  const Center(
                      child: CircularProgressIndicator(color: AppColors.aiGold))
                else if (responseText != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.bgDark,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(responseText!,
                        style: const TextStyle(color: Colors.white70),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _controller.document.insert(
                              _controller.selection.baseOffset,
                              "\n$responseText\n");
                          Navigator.pop(context);
                        },
                        child: const Text("Insert to Doc",
                            style: TextStyle(color: AppColors.gridGreen)),
                      )
                    ],
                  )
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  void _blokMenusuAc() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
              color: Color(0xFF1F1F1F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(2))),
              const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text("Add Block",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16))),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _blokGrid([
                      _menuItem("H1", "H1", const Color(0xFF5E73C7),
                          () => _formatUygula(quill.Attribute.h1)),
                      _menuItem("H2", "H2", const Color(0xFF5E73C7),
                          () => _formatUygula(quill.Attribute.h2)),
                      _menuItem("H3", "H3", const Color(0xFF5E73C7),
                          () => _formatUygula(quill.Attribute.h3)),
                      _menuItem("Text", "Text", const Color(0xFF5E73C7),
                          () => _formatUygula(quill.Attribute.header))
                    ]),
                    const SizedBox(height: 15),
                    _blokGrid([
                      _menuItem("Checkbox", "Checkbox", const Color(0xFF42BA96),
                          () => _formatUygula(quill.Attribute.unchecked)),
                      _menuItem("Quote", "Quote", const Color(0xFFCCB35E),
                          () => _formatUygula(quill.Attribute.blockQuote)),
                      _menuItem("Bulleted", "Bulleted", const Color(0xFFA85596),
                          () => _formatUygula(quill.Attribute.ul)),
                      _menuItem("Numbered", "Numbered", const Color(0xFFA85596),
                          () => _formatUygula(quill.Attribute.ol))
                    ]),
                    const SizedBox(height: 15),
                    _blokGrid([
                      _menuItem("Image", "Image", const Color(0xFFCCB35E), () {
                        Navigator.pop(context);
                        _medyaSec('image');
                      }),
                      _menuItem("File", "File", const Color(0xFFCCB35E), () {
                        Navigator.pop(context);
                        _medyaSec('file');
                      }),
                      _menuItem("PDF", "PDF", const Color(0xFFCCB35E), () {
                        Navigator.pop(context);
                        _medyaSec('pdf');
                      }),
                      _menuItem("Date", "Date", const Color(0xFF469BBD), () {
                        Navigator.pop(context);
                        _controller.document.insert(
                            _controller.selection.baseOffset,
                            DateFormat('dd.MM.yyyy').format(DateTime.now()));
                      })
                    ]),
                    const SizedBox(height: 15),
                    _blokGrid([
                      _menuItem("Code", "Code", const Color(0xFF5E65C9),
                          () => _formatUygula(quill.Attribute.codeBlock)),
                      _menuItem("Math", "Math", const Color(0xFF5E65C9),
                          () => _formatUygula(quill.Attribute.inlineCode)),
                      _menuItem("Divider", "Divider", const Color(0xFF42BA96),
                          () {
                        Navigator.pop(context);
                        _controller.document.insert(
                            _controller.selection.baseOffset, "\n---\n");
                      }),
                      _menuItem("Person", "Person", const Color(0xFF469BBD),
                          () {
                        Navigator.pop(context);
                        _controller.document.insert(
                            _controller.selection.baseOffset, "@Person");
                      })
                    ]),
                    const SizedBox(height: 30)
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _blokGrid(List<Widget> children) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children);

  Widget _menuItem(
      String iconText, String label, Color color, VoidCallback onTap) {
    IconData? iconData;
    switch (iconText) {
      case "Text":
        iconData = Icons.title;
        break;
      case "Checkbox":
        iconData = Icons.check_box_outlined;
        break;
      case "Quote":
        iconData = Icons.format_quote;
        break;
      case "Bulleted":
        iconData = Icons.format_list_bulleted;
        break;
      case "Numbered":
        iconData = Icons.format_list_numbered;
        break;
      case "Image":
        iconData = Icons.image_outlined;
        break;
      case "File":
        iconData = Icons.attach_file;
        break;
      case "PDF":
        iconData = Icons.picture_as_pdf_outlined;
        break;
      case "Date":
        iconData = Icons.calendar_today_outlined;
        break;
      case "Person":
        iconData = Icons.person_add_alt_1_outlined;
        break;
      case "Divider":
        iconData = Icons.horizontal_rule;
        break;
      case "Code":
        iconData = Icons.code;
        break;
      case "Math":
        iconData = Icons.functions;
        break;
      default:
        iconData = null;
    }
    return GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(18)),
              child: Center(
                  child: iconData != null
                      ? Icon(iconData, color: Colors.white, size: 30)
                      : Text(iconText,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)))),
          const SizedBox(height: 8),
          SizedBox(
              width: 70,
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 2))
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) => _save(),
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(widget.item.type,
              style: const TextStyle(color: AppColors.docBlue, fontSize: 14)),
          centerTitle: true,
          actions: [
            IconButton(
                icon: const Icon(Icons.auto_awesome, color: AppColors.aiGold),
                onPressed: _showAIDialog),
            TextButton(
              onPressed: () {
                if (_titleController.text.isNotEmpty) {
                  Navigator.pop(context, {
                    'baslik': _titleController.text,
                    'icerik': _controller.document.toDelta().toJson(),
                    'resim': resimYolu
                  });
                }
              },
              child: const Text("Done",
                  style: TextStyle(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.bold)),
            )
          ],
        ),
        body: Column(
          children: [
            if (resimYolu != null)
              Stack(children: [
                SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Image.file(File(resimYolu!), fit: BoxFit.cover)),
                Positioned(
                    right: 10,
                    top: 10,
                    child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => setState(() => resimYolu = null))))
              ]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (resimYolu == null)
                      Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: GestureDetector(
                              onTap: () => _medyaSec('', isCover: true),
                              child: const Row(children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 18, color: Colors.grey),
                                SizedBox(width: 8),
                                Text("Add Cover",
                                    style: TextStyle(color: Colors.grey))
                              ]))),
                    TextField(
                        controller: _titleController,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        decoration: const InputDecoration(
                            hintText: "Untitled",
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey)))
                  ]),
            ),
            // --- EDITÖR YAPILANDIRMASI: (v11 DÜZELTME) ---
            Expanded(
              child: quill.QuillEditor.basic(
                controller: _controller,
                config: quill.QuillEditorConfig(
                  padding: const EdgeInsets.all(20),
                  embedBuilders: [AdvancedImageEmbedBuilder()],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              color: AppColors.cardDark,
              child: Row(
                children: [
                  GestureDetector(
                      onTap: _blokMenusuAc,
                      child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                              color: AppColors.primaryPurple,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 24))),
                  const SizedBox(width: 20),
                  const Text("Type something...",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                      onPressed: () =>
                          _controller.formatSelection(quill.Attribute.bold),
                      icon: const Icon(Icons.format_bold, color: Colors.grey)),
                  IconButton(
                      onPressed: () =>
                          _controller.formatSelection(quill.Attribute.italic),
                      icon: const Icon(Icons.format_italic, color: Colors.grey))
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class GridPage extends StatefulWidget {
  final WorkspaceItem item;
  const GridPage({super.key, required this.item});
  @override
  State<GridPage> createState() => _GridPageState();
}

class _GridPageState extends State<GridPage> {
  late Map<String, dynamic> data;
  final TextEditingController _titleController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _titleController.text = widget.item.title;
    data = Map<String, dynamic>.from(widget.item.content ??
        {
          'properties': [
            {'name': 'Name', 'type': 'text'},
            {'name': 'Status', 'type': 'select'},
            {'name': 'Done', 'type': 'checkbox'}
          ],
          'rows': []
        });
  }

  void _addRow() {
    final newRow = <String, dynamic>{};
    for (var p in data['properties']) {
      if (p['type'] == 'checkbox')
        newRow[p['name']] = false;
      else
        newRow[p['name']] = '';
    }
    setState(() {
      (data['rows'] as List).add(newRow);
      widget.item.content = data;
    });
  }

  void _addPropertyDialog() {
    TextEditingController propName = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Property"),
        content: TextField(
            controller: propName,
            decoration: const InputDecoration(hintText: "Property Name")),
        actions: [
          TextButton(
            onPressed: () {
              if (propName.text.isNotEmpty) {
                setState(() {
                  (data['properties'] as List)
                      .add({'name': propName.text, 'type': 'text'});
                  widget.item.content = data;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  IconData _getIconForProp(String type) {
    if (type == 'text') return Icons.text_fields;
    if (type == 'checkbox') return Icons.check_box_outlined;
    if (type == 'select') return Icons.arrow_drop_down_circle_outlined;
    return Icons.short_text;
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> props = data['properties'];
    List<dynamic> rows = data['rows'];
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            widget.item.title = _titleController.text;
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            const Icon(Icons.grid_view_rounded,
                size: 20, color: AppColors.gridGreen),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        border: InputBorder.none, filled: false)))
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.filter_list, color: AppColors.textGrey),
              onPressed: () {})
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            horizontalMargin: 20,
            columnSpacing: 20,
            border: TableBorder.all(color: AppColors.borderGrey, width: 0.5),
            headingRowColor: MaterialStateProperty.all(Colors.transparent),
            columns: [
              ...props
                  .map((p) => DataColumn(
                          label: Row(children: [
                        Icon(_getIconForProp(p['type']),
                            size: 16, color: AppColors.textGrey),
                        const SizedBox(width: 8),
                        Text(p['name'],
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textGrey))
                      ])))
                  .toList(),
              DataColumn(
                  label: InkWell(
                      onTap: _addPropertyDialog,
                      child: const Row(children: [
                        Icon(Icons.add, size: 16, color: AppColors.textGrey),
                        Text(" New property",
                            style: TextStyle(color: AppColors.textGrey))
                      ])))
            ],
            rows: rows.asMap().entries.map((entry) {
              Map<String, dynamic> row = entry.value;
              return DataRow(cells: [
                ...props.map((p) {
                  return DataCell(p['type'] == 'checkbox'
                      ? Checkbox(
                          value: row[p['name']] == true,
                          activeColor: AppColors.gridGreen,
                          onChanged: (val) {
                            setState(() {
                              row[p['name']] = val;
                              widget.item.content = data;
                            });
                          })
                      : TextFormField(
                          initialValue: row[p['name']].toString(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              filled: false,
                              isDense: true),
                          onChanged: (val) {
                            row[p['name']] = val;
                            widget.item.content = data;
                          }));
                }).toList(),
                const DataCell(SizedBox())
              ]);
            }).toList(),
          ),
        ),
      ),
      bottomNavigationBar: InkWell(
        onTap: _addRow,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.borderGrey))),
          child: const Row(
            children: [
              Icon(Icons.add, color: AppColors.textGrey),
              SizedBox(width: 8),
              Text("New row", style: TextStyle(color: AppColors.textGrey))
            ],
          ),
        ),
      ),
    );
  }
}

class BoardPage extends StatefulWidget {
  final WorkspaceItem item;
  const BoardPage({super.key, required this.item});
  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  late List<dynamic> columns;
  final TextEditingController _titleController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _titleController.text = widget.item.title;
    columns = (widget.item.content['columns'] as List);
  }

  void _addCard(int colIndex) {
    setState(() {
      columns[colIndex]['cards'].add("New Card");
      widget.item.content = {'columns': columns};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            widget.item.title = _titleController.text;
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            const Icon(Icons.view_kanban_rounded,
                size: 20, color: AppColors.boardOrange),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        border: InputBorder.none, filled: false)))
          ],
        ),
      ),
      body: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        itemCount: columns.length,
        itemBuilder: (context, index) {
          final col = columns[index];
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: _getColor(index).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(col['name'],
                            style: TextStyle(
                                color: _getColor(index),
                                fontWeight: FontWeight.bold))),
                    const Spacer(),
                    const Icon(Icons.more_horiz,
                        color: AppColors.textGrey, size: 18),
                    const SizedBox(width: 8),
                    InkWell(
                        onTap: () => _addCard(index),
                        child: const Icon(Icons.add,
                            color: AppColors.textGrey, size: 18))
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: col['cards'].length,
                    itemBuilder: (ctx, cardIndex) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.cardDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderGrey)),
                        child: TextFormField(
                          initialValue: col['cards'][cardIndex],
                          maxLines: null,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              filled: false,
                              isDense: true),
                          onChanged: (val) {
                            col['cards'][cardIndex] = val;
                            widget.item.content = {'columns': columns};
                          },
                        ),
                      );
                    },
                  ),
                ),
                InkWell(
                  onTap: () => _addCard(index),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 16, color: AppColors.textGrey),
                        SizedBox(width: 4),
                        Text("New", style: TextStyle(color: AppColors.textGrey))
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getColor(int i) =>
      [Colors.grey, Colors.orange, Colors.blue, Colors.green][i % 4];
}

class CalendarPage extends StatefulWidget {
  final WorkspaceItem item;
  const CalendarPage({super.key, required this.item});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Map<String, dynamic> events;
  final TextEditingController _titleController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _titleController.text = widget.item.title;
    _selectedDay = _focusedDay;
    events = Map<String, dynamic>.from(widget.item.content['events'] ?? {});
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    return events[key] ?? [];
  }

  void _addEvent() {
    if (_selectedDay == null) return;
    TextEditingController eventCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Event"),
        content: TextField(
            controller: eventCtrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Event Name")),
        actions: [
          TextButton(
            onPressed: () {
              if (eventCtrl.text.isNotEmpty) {
                final key = DateFormat('yyyy-MM-dd').format(_selectedDay!);
                if (events[key] == null) events[key] = [];
                setState(() {
                  (events[key] as List).add(eventCtrl.text);
                  widget.item.content = {'events': events};
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text("Add",
                style: TextStyle(
                    color: AppColors.calendarRed, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            widget.item.title = _titleController.text;
            Navigator.pop(context);
          },
        ),
        title: TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration:
                const InputDecoration(border: InputBorder.none, filled: false)),
        actions: [
          IconButton(
              icon: const Icon(Icons.add, color: AppColors.calendarRed),
              onPressed: _addEvent)
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) =>
                setState(() => _calendarFormat = format),
            eventLoader: _getEventsForDay,
            calendarStyle: const CalendarStyle(
                defaultTextStyle: TextStyle(color: Colors.white),
                weekendTextStyle: TextStyle(color: AppColors.textGrey),
                selectedDecoration: BoxDecoration(
                    color: AppColors.calendarRed, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(
                    color: Colors.white24, shape: BoxShape.circle),
                markerDecoration: BoxDecoration(
                    color: AppColors.calendarRed, shape: BoxShape.circle)),
            headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: _getEventsForDay(_selectedDay!)
                  .map((event) => ListTile(
                      leading:
                          const Icon(Icons.event, color: AppColors.calendarRed),
                      title: Text(event.toString(),
                          style: const TextStyle(color: Colors.white))))
                  .toList(),
            ),
          )
        ],
      ),
    );
  }
}
