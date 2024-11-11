import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/note_model.dart';
import 'note_edit_screen.dart';
import '../theme_provider.dart';

enum NoteView { list, grid }

enum SortBy { dateCreated, dateModified, title, priority }

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  _NoteListScreenState createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen>
    with SingleTickerProviderStateMixin {
  List<Note> _notes = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  NoteView _currentView = NoteView.list;
  SortBy _currentSort = SortBy.dateModified;
  late AnimationController _animationController;
  final List<String> _selectedNotes = [];
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    List<Map<String, dynamic>> noteMaps = await DBHelper().getNotes();
    setState(() {
      _notes = noteMaps.map((note) => Note.fromMap(note)).toList();
      _sortNotes();
    });
  }

  void _sortNotes() {
    switch (_currentSort) {
      case SortBy.dateCreated:
        _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortBy.dateModified:
        _notes.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        break;
      case SortBy.title:
        _notes.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortBy.priority:
        _notes.sort((a, b) => b.priority.compareTo(a.priority));
        break;
    }
  }

  List<Note> _getFilteredNotes() {
    if (_searchController.text.isEmpty) {
      return _notes;
    }

    final query = _searchController.text.toLowerCase();
    return _notes.where((note) {
      return note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _addOrEditNote({Note? note}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditScreen(note: note),
      ),
    );
    if (result == true) {
      _loadNotes();
    }
  }

  Future<void> _deleteSelectedNotes() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_selectedNotes.length} Notes?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              for (String id in _selectedNotes) {
                await DBHelper().deleteNote(int.parse(id));
              }
              setState(() {
                _isSelectionMode = false;
                _selectedNotes.clear();
              });
              _loadNotes();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search notes...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
      ),
      onChanged: (value) {
        setState(() {});
      },
    );
  }

  Widget _buildNoteCard(Note note, bool isSelected) {
    final formattedDate =
        DateFormat('MMM dd, yyyy HH:mm').format(note.modifiedAt);

    return Card(
      elevation: isSelected ? 8 : 2,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: _isSelectionMode
            ? () => _toggleNoteSelection(note.id.toString())
            : () => _addOrEditNote(note: note),
        onLongPress: () {
          setState(() {
            _isSelectionMode = true;
            _toggleNoteSelection(note.id.toString());
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      note.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.priority > 0)
                    const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.content,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                formattedDate,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleNoteSelection(String noteId) {
    setState(() {
      if (_selectedNotes.contains(noteId)) {
        _selectedNotes.remove(noteId);
        if (_selectedNotes.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedNotes.add(noteId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = _getFilteredNotes();

    return Scaffold(
      appBar: AppBar(
        title: _isSearching ? Container() : const Text('MySimpleNote'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedNotes.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            Text('${_selectedNotes.length} selected'),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed:
                  _selectedNotes.isNotEmpty ? _deleteSelectedNotes : null,
            ),
          ] else ...[
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                  }
                });
              },
            ),
            PopupMenuButton<SortBy>(
              icon: const Icon(Icons.sort),
              onSelected: (SortBy result) {
                setState(() {
                  _currentSort = result;
                  _sortNotes();
                });
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<SortBy>>[
                const PopupMenuItem<SortBy>(
                  value: SortBy.dateModified,
                  child: Text('Sort by Last Modified'),
                ),
                const PopupMenuItem<SortBy>(
                  value: SortBy.dateCreated,
                  child: Text('Sort by Created Date'),
                ),
                const PopupMenuItem<SortBy>(
                  value: SortBy.title,
                  child: Text('Sort by Title'),
                ),
                const PopupMenuItem<SortBy>(
                  value: SortBy.priority,
                  child: Text('Sort by Priority'),
                ),
              ],
            ),
            IconButton(
              icon: Icon(_currentView == NoteView.list
                  ? Icons.grid_view
                  : Icons.view_list),
              onPressed: () {
                setState(() {
                  _currentView = _currentView == NoteView.list
                      ? NoteView.grid
                      : NoteView.list;
                  _animationController.forward(from: 0);
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.brightness_6),
              onPressed: () =>
                  Provider.of<ThemeProvider>(context, listen: false)
                      .toggleTheme(),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildSearchBar(),
            ),
          Expanded(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return filteredNotes.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'No notes yet'
                              : 'No matching notes found',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : _currentView == NoteView.list
                        ? ListView.builder(
                            itemCount: filteredNotes.length,
                            itemBuilder: (context, index) {
                              final note = filteredNotes[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: _buildNoteCard(
                                  note,
                                  _selectedNotes.contains(note.id.toString()),
                                ),
                              );
                            },
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: filteredNotes.length,
                            itemBuilder: (context, index) {
                              final note = filteredNotes[index];
                              return _buildNoteCard(
                                note,
                                _selectedNotes.contains(note.id.toString()),
                              );
                            },
                          );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: !_isSelectionMode
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () => _addOrEditNote(),
            )
          : null,
    );
  }
}
