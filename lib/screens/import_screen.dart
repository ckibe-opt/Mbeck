
// ============================================================================
// OPTIMIZED IMPORT SCREEN (import_screen.dart)
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../customer_import.dart';
import '../widgets/standard_app_bar.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _isImporting = false;
  List<String> _logs = [];

  Future<void> _pickAndImport() async {
    setState(() {
      _isImporting = true;
      _logs = [];
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _isImporting = false);
        return;
      }

      final file = File(result.files.single.path!);
      final errors = await importCustomersFromCsvFile(file);

      if (!mounted) return;

      setState(() {
        if (errors.isEmpty) {
          _logs = ['✅ Success! All customers imported successfully.'];
        } else {
          _logs = errors;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logs = ['❌ Unexpected error: $e'];
      });
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const StandardAppBar(title: 'Import Customers from CSV'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildImportButton(),
              if (_logs.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildLogs(),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(
          Icons.group_add_outlined, 
          size: 80, 
          color: Theme.of(context).primaryColor
        ),
        const SizedBox(height: 16),
        Text(
          'Import Customer Data',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Select a .csv file from your device to bulk-import customer information.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600]
          ),
        ),
      ],
    );
  }

  Widget _buildImportButton() {
    return ElevatedButton.icon(
      onPressed: _isImporting ? null : _pickAndImport,
      icon: _isImporting
        ? const SizedBox(
            width: 20,
            height: 20,
            child: Icon(Icons.hourglass_empty, color: Colors.white, size: 20),
          )
        : const Icon(Icons.upload_file_outlined),
      label: Text(_isImporting ? 'IMPORTING...' : 'SELECT .CSV FILE'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16, 
          fontWeight: FontWeight.bold
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)
        ),
      ),
    );
  }

  Widget _buildLogs() {
    final hasErrors = _logs.any((log) => !log.startsWith('✅'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasErrors ? 'Import Issues Found:' : 'Import Successful!',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold
          ),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _logs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1, 
              indent: 16, 
              endIndent: 16
            ),
            itemBuilder: (ctx, i) {
              final log = _logs[i];
              final isSuccess = log.startsWith('✅');
              
              return ListTile(
                dense: true,
                leading: Icon(
                  isSuccess 
                    ? Icons.check_circle_outline 
                    : Icons.error_outline,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 22,
                ),
                title: Text(
                  log,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
