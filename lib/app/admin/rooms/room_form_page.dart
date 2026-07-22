import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';

import '../../../models/floor.dart';
import '../../../models/room.dart';
import '../../../models/room_type.dart';
import '../../../services/room_service.dart';
import '../../../layouts/admin_layout.dart';

class RoomFormPage extends StatefulWidget {
  static Room? pendingRoom;

  const RoomFormPage({super.key});

  @override
  State<RoomFormPage> createState() => _RoomFormPageState();
}

class _RoomFormPageState extends State<RoomFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _roomService = RoomService();

  Room? _editingRoom;
  String? _selectedRoomTypeId;
  String? _selectedFloorId;
  bool _loading = false;

  bool get _isEditing => _editingRoom != null;

  @override
  void initState() {
    super.initState();
    _editingRoom = RoomFormPage.pendingRoom;
    RoomFormPage.pendingRoom = null;

    if (_isEditing) {
      _numberController.text = _editingRoom!.number;
      _descriptionController.text = _editingRoom!.description ?? '';
      _selectedRoomTypeId = _editingRoom!.roomTypeId;
      _selectedFloorId = _editingRoom!.floorId;
    }
    _loadData();
  }

  @override
  void dispose() {
    _numberController.dispose();
    _descriptionController.dispose();
    _roomService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _roomService.loadAll();
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final description = _descriptionController.text.trim();
    bool success;

    if (_isEditing) {
      success = await _roomService.updateRoom(
        _editingRoom!.id,
        number: _numberController.text.trim(),
        roomTypeId: _selectedRoomTypeId!,
        floorId: _selectedFloorId!,
        description: description.isEmpty ? null : description,
      );
    } else {
      final room = await _roomService.createRoom(
        number: _numberController.text.trim(),
        roomTypeId: _selectedRoomTypeId!,
        floorId: _selectedFloorId!,
        description: description.isEmpty ? null : description,
      );
      success = room != null;
    }

    setState(() => _loading = false);

    if (mounted && success) {
      Routefly.navigate('/admin/rooms');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      currentRoute: '/admin/rooms',
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Room' : 'Add Room'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Routefly.navigate('/admin/rooms'),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _numberController,
                      decoration: const InputDecoration(
                        labelText: 'Room Number',
                        hintText: 'e.g. 101',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a room number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRoomTypeId,
                      decoration: const InputDecoration(
                        labelText: 'Room Type',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _roomService.roomTypes.map((RoomType type) {
                        return DropdownMenuItem(
                          value: type.id,
                          child: Text(type.name),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedRoomTypeId = value),
                      validator: (value) {
                        if (value == null) return 'Please select a room type';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedFloorId,
                      decoration: const InputDecoration(
                        labelText: 'Floor',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                      items: _roomService.floors.map((Floor floor) {
                        return DropdownMenuItem(
                          value: floor.id,
                          child: Text(floor.displayName),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedFloorId = value),
                      validator: (value) {
                        if (value == null) return 'Please select a floor';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'e.g. Corner room with sea view',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isEditing ? 'Save Changes' : 'Add Room'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
