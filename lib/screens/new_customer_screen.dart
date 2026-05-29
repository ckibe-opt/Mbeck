import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/db_provider.dart';
import '../models/customer.dart';
import '../widgets/standard_app_bar.dart';
import '../services/event_service.dart';

class NewCustomerScreen extends StatefulWidget {
  final Customer? customer; 

  const NewCustomerScreen({super.key, this.customer});

  @override
  _NewCustomerScreenState createState() => _NewCustomerScreenState();
}

class _NewCustomerScreenState extends State<NewCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _storeCtrl = TextEditingController();
  
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _nameCtrl.text = widget.customer!.name;
      _phoneCtrl.text = widget.customer!.phone ?? '';
      _idCtrl.text = widget.customer!.idNo ?? '';
      _storeCtrl.text = widget.customer!.store ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _idCtrl.dispose();
    _storeCtrl.dispose();
    super.dispose();
  }

  // Check if phone number already exists (for duplicates)
  Future<bool> _checkPhoneDuplicate(String phone) async {
    if (phone.isEmpty) return false;
    
    try {
      final existing = await DbProvider.query(
        'customer',
        where: 'phone = ?',
        whereArgs: [phone],
      );
      
      // If editing, exclude current customer from duplicate check
      if (widget.customer != null) {
        return existing.any((c) => c['id'] != widget.customer!.id);
      }
      
      return existing.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      // Check for duplicate phone numbers
      final isDuplicate = await _checkPhoneDuplicate(_phoneCtrl.text.trim());
      
      if (isDuplicate && mounted) {
        setState(() => _isSaving = false);
        
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Duplicate Phone Number'),
              ],
            ),
            content: Text(
              'A customer with phone number "${_phoneCtrl.text}" already exists.\n\n'
              'Do you want to save anyway?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text('Save Anyway'),
              ),
            ],
          ),
        );
        
        if (proceed != true) return;
        setState(() => _isSaving = true);
      }

      final customerData = Customer(
        id: widget.customer?.id,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        idNo: _idCtrl.text.trim(),
        store: _storeCtrl.text.trim(),
        createdAt: widget.customer?.createdAt ?? 
          DateTime.now().millisecondsSinceEpoch,
      );

      if (widget.customer == null) {
        // CREATE
        await DbProvider.insert('customer', customerData.toMap());
        
        await EventService.emitEvent(
          eventType: 'CUSTOMER_CREATE',
          payload: {
            'name': customerData.name,
            'phone': customerData.phone,
            'id_no': customerData.idNo,
            'bank_account': customerData.bankAccount,
            'notes': customerData.notes,
            'agent': customerData.agent,
            'store': customerData.store,
            'createdAt': customerData.createdAt,
          },
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer Added Successfully'),
              backgroundColor: Colors.green,
            )
          );
        }
      } else {
        // UPDATE
        await DbProvider.update(
          'customer', 
          customerData.toMap(), 
          where: 'id = ?', 
          whereArgs: [customerData.id]
        );
        
        await EventService.emitEvent(
          eventType: 'CUSTOMER_UPDATE',
          payload: {
            'previousPhone': widget.customer?.phone,
            'previousName': widget.customer?.name,
            'name': customerData.name,
            'phone': customerData.phone,
            'id_no': customerData.idNo,
            'bank_account': customerData.bankAccount,
            'notes': customerData.notes,
            'agent': customerData.agent,
            'store': customerData.store,
          },
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer Updated Successfully'),
              backgroundColor: Colors.blue,
            )
          );
        }
      }

      if (mounted) Navigator.pop(context, true); // Signal success
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving customer: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.customer == null) return;
    if (_isDeleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Customer?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${widget.customer!.name}"?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text('Cancel')
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      
      try {
        await DbProvider.delete(
          'customer', 
          where: 'id = ?', 
          whereArgs: [widget.customer!.id]
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer Deleted'),
              backgroundColor: Colors.red,
            )
          );
          Navigator.pop(context, true); // Signal deletion
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting customer: $e'))
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isDeleting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;

    return Scaffold(
      appBar: StandardAppBar(
        title: isEditing ? 'Edit Customer' : 'New Customer',
        actions: [
          if (isEditing && !_isDeleting)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _delete,
              tooltip: 'Delete Customer',
            ),
          if (_isDeleting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: Icon(Icons.hourglass_empty, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Info card at top
            if (!isEditing)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Add customer details for faster receipt delivery',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            _buildTextField(
              _nameCtrl, 
              'Full Name', 
              Icons.person,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Name is required';
                }
                if (v.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              }
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              _phoneCtrl, 
              'Phone Number', 
              Icons.phone,
              inputType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Phone number is required';
                }
                if (v.trim().length < 9) {
                  return 'Phone number must be at least 9 digits';
                }
                return null;
              }
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              _idCtrl, 
              'ID Number (Optional)', 
              Icons.badge,
              inputType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              _storeCtrl, 
              'Store Name (Optional)', 
              Icons.store
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)
                ),
              ),
              onPressed: _isSaving || _isDeleting ? null : _save, 
              child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Icon(Icons.hourglass_empty, color: Colors.white, size: 20),
                  )
                : Text(
                    isEditing ? 'UPDATE CUSTOMER' : 'SAVE CUSTOMER', 
                    style: const TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold
                    )
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, {
    TextInputType inputType = TextInputType.text, 
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide(color: Colors.grey.shade300)
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide(color: Colors.grey.shade300)
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: const BorderSide(color: Colors.green, width: 2)
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: inputType,
      validator: validator,
      textCapitalization: inputType == TextInputType.text 
        ? TextCapitalization.words 
        : TextCapitalization.none,
      inputFormatters: inputFormatters,
    );
  }
}
