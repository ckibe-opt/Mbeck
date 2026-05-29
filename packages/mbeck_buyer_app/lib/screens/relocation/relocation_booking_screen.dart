import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RelocationBookingScreen extends StatefulWidget {
  const RelocationBookingScreen({super.key});

  @override
  State<RelocationBookingScreen> createState() => _RelocationBookingScreenState();
}

class _RelocationBookingScreenState extends State<RelocationBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _destController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime? _selectedDate;
  String _selectedLorrySize = 'Medium (Canter)';
  bool _isSubmitting = false;

  final Map<String, double> _lorryPricing = {
    'Small (Pickup)': 2500.0,
    'Medium (Canter)': 6000.0,
    'Large (Lorry)': 12000.0,
  };

  final Map<String, String> _lorrySpecs = {
    'Small (Pickup)': 'Best for single rooms, small items, or studio moves.',
    'Medium (Canter)': 'Perfect for 1-2 bedroom apartments. Has tail-lift.',
    'Large (Lorry)': 'Best for 3+ bedroom houses, heavy furniture, and office moves.',
  };

  @override
  void dispose() {
    _pickupController.dispose();
    _destController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.black,
              surface: const Color(0xFF121614),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      setState(() => _isSubmitting = true);
      
      final price = _lorryPricing[_selectedLorrySize] ?? 0.0;
      final pickup = _pickupController.text.trim();
      final dest = _destController.text.trim();
      final notes = _notesController.text.trim();
      final movingDate = _selectedDate!;

      try {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user == null) {
          throw Exception('No active session. Please make sure you are online.');
        }

        await client.from('relocation_bookings').insert({
          'buyer_id': user.id,
          'pickup_location': pickup,
          'destination_location': dest,
          'lorry_size': _selectedLorrySize,
          'moving_date': movingDate.toIso8601String(),
          'price': price,
          'notes': notes.isNotEmpty ? notes : null,
          'status': 'pending',
        });

        if (mounted) {
          setState(() => _isSubmitting = false);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF00FF88)),
                  SizedBox(width: 8),
                  Text('Booking Confirmed!'),
                ],
              ),
              content: Text(
                'Your relocation with Tuko Mboka Relocations has been successfully booked.\n\nDetails: $_selectedLorrySize\nDate: ${movingDate.toString().split(' ')[0]}\nPrice: KES ${price.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}\n\nOur movers will contact you shortly to coordinate the pick-up.',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  child: const Text('OK', style: TextStyle(color: Color(0xFF00FF88))),
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pop(context); // Pop booking screen
                  },
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to place booking: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else if (_selectedDate == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a moving date')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book a Mover')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
             Card(
               elevation: 0,
               color: Colors.blue.withOpacity(0.1),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               child: Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       children: [
                         const Icon(Icons.local_shipping, color: Colors.blue),
                         const SizedBox(width: 8),
                         Text('Tuko Mboka Relocations', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                       ],
                     ),
                     const SizedBox(height: 8),
                     const Text('Professional moving services across Kenya. We handle your items with care.'),
                   ],
                 ),
               ),
             ),
             const SizedBox(height: 24),
             TextFormField(
               controller: _pickupController,
               decoration: const InputDecoration(
                 labelText: 'Pickup Location',
                 prefixIcon: Icon(Icons.my_location),
                 border: OutlineInputBorder(),
               ),
               validator: (v) => v!.isEmpty ? 'Required' : null,
             ),
             const SizedBox(height: 16),
             TextFormField(
               controller: _destController,
               decoration: const InputDecoration(
                 labelText: 'Destination',
                 prefixIcon: Icon(Icons.location_on),
                 border: OutlineInputBorder(),
               ),
               validator: (v) => v!.isEmpty ? 'Required' : null,
             ),
             const SizedBox(height: 16),
             DropdownButtonFormField<String>(
               value: _selectedLorrySize,
               items: _lorryPricing.keys.map((size) => DropdownMenuItem(value: size, child: Text('$size - KES ${_lorryPricing[size]}'))).toList(),
               onChanged: (v) => setState(() => _selectedLorrySize = v!),
               decoration: const InputDecoration(
                 labelText: 'Lorry Size',
                 prefixIcon: Icon(Icons.fire_truck),
                 border: OutlineInputBorder(),
               ),
             ),
             const SizedBox(height: 8),
             Text(_lorrySpecs[_selectedLorrySize]!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
             const SizedBox(height: 16),
             InkWell(
               onTap: () => _selectDate(context),
               child: InputDecorator(
                 decoration: const InputDecoration(
                   labelText: 'Moving Date',
                   prefixIcon: Icon(Icons.calendar_today),
                   border: OutlineInputBorder(),
                 ),
                 child: Text(_selectedDate == null ? 'Select a Date' : _selectedDate.toString().split(' ')[0]),
               ),
             ),
             const SizedBox(height: 16),
             TextFormField(
               controller: _notesController,
               decoration: const InputDecoration(
                 labelText: 'Additional Notes (Optional)',
                 alignLabelWithHint: true,
                 border: OutlineInputBorder(),
               ),
               maxLines: 3,
             ),
             const SizedBox(height: 32),
             SizedBox(
               height: 50,
               child: ElevatedButton(
                 style: ElevatedButton.styleFrom(
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                 ),
                 onPressed: _isSubmitting ? null : _submit,
                 child: _isSubmitting ? const CircularProgressIndicator() : const Text('Proceed to Checkout', style: TextStyle(fontSize: 16)),
               ),
             )
          ],
        ),
      ),
    );
  }
}