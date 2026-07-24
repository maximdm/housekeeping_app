import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';
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
    _detectRole();
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

  Future<void> _detectRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final data = await Supabase.instance.client
        .from('staff')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();
    if (mounted && data != null && data['role'] != 'manager') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Routefly.navigate('/admin/overview');
      });
    }
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
          title: Text(_isEditing ? localizations.tr('editRoom') : localizations.tr('addRoom')),
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
                      decoration: InputDecoration(
                        labelText: localizations.tr('roomNumber'),
                        hintText: 'e.g. 101',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return localizations.tr('pleaseEnterRoomNumber');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRoomTypeId,
                      decoration: InputDecoration(
                        labelText: localizations.tr('roomType'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.category_outlined),
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
                        if (value == null) return localizations.tr('pleaseSelectRoomType');
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedFloorId,
                      decoration: InputDecoration(
                        labelText: localizations.tr('floor'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.layers_outlined),
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
                        if (value == null) return localizations.tr('pleaseSelectFloor');
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: localizations.tr('descriptionOptional'),
                        hintText: localizations.tr('descriptionHint'),
                        border: const OutlineInputBorder(),
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
                              _isEditing ? localizations.tr('saveChanges') : localizations.tr('addRoom')),
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
