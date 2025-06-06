import 'dart:convert';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/secure_storage_data.dart';

/// A card widget to display Flutter Secure Storage data
class StorageCard extends StatelessWidget {
  final SecureStorageData data;
  final bool hideNullValues;

  const StorageCard({
    super.key,
    required this.data,
    required this.hideNullValues,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ExpansionTile(
        title: Text(
          'Storage Data (${data.timestamp.toString()})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Device: ${data.deviceName}'),
        children: [_buildStorageDataTable(context)],
      ),
    );
  }

  Widget _buildStorageDataTable(BuildContext context) {
    final entries = data.storageData.entries.toList();

    // Filter out null values if hideNullValues is true
    final filteredEntries =
        hideNullValues
            ? entries.where((entry) => entry.value != null).toList()
            : entries;

    if (filteredEntries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No storage data available'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Key')),
          DataColumn(label: Text('Value')),
          DataColumn(label: Text('Actions')),
        ],
        rows:
            filteredEntries.map((entry) {
              return DataRow(
                cells: [
                  DataCell(
                    SelectableText(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  DataCell(
                    Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: JsonValueWidget(value: entry.value?.toString()),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Copy button
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: 'Copy value',
                          onPressed:
                              () => _copyToClipboard(
                                context,
                                entry.key,
                                entry.value?.toString(),
                              ),
                        ),
                        // Edit button
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          tooltip: 'Edit value',
                          onPressed:
                              () => _showEditDialog(
                                context,
                                entry.key,
                                entry.value?.toString(),
                              ),
                        ),
                        // Delete button
                        IconButton(
                          icon: const Icon(Icons.delete, size: 16),
                          tooltip: 'Delete key',
                          onPressed:
                              () => _showDeleteDialog(context, entry.key),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Future<void> _copyToClipboard(
    BuildContext context,
    String key,
    String? value,
  ) async {
    if (value != null) {
      try {
        await Clipboard.setData(ClipboardData(text: value));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied "$key" value to clipboard'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to copy to clipboard: $e'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showEditDialog(BuildContext context, String key, String? currentValue) {
    final controller = TextEditingController(text: currentValue ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit "$key"'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newValue = controller.text;
                  Navigator.of(context).pop();

                  // Send command to host app
                  await _sendStorageCommand('edit', key, newValue, context);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Edit command sent for "$key"'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showDeleteDialog(BuildContext context, String key) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: Text('Are you sure you want to delete the key "$key"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  // Send command to host app
                  await _sendStorageCommand('delete', key, null, context);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Delete command sent for "$key"'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _sendStorageCommand(
    String operation,
    String key,
    String? value,
    BuildContext context,
  ) async {
    print(
      '🚀 Starting storage command: $operation for key "$key" with value: $value',
    );

    try {
      print('🔌 Getting VM service...');
      final vmService = await serviceManager.onServiceAvailable;
      print('✅ VM service obtained: ${vmService.runtimeType}');

      // Find the correct isolate that has our extensions
      print('🔍 Finding isolate with our extensions...');
      final vm = await vmService.getVM();
      String? targetIsolateId;

      if (vm.isolates?.isNotEmpty == true) {
        for (final isolateRef in vm.isolates!) {
          try {
            final isolateDetails = await vmService.getIsolate(isolateRef.id!);
            final availableExtensions = isolateDetails.extensionRPCs ?? [];

            if (availableExtensions.contains('ext.secure_storage.command')) {
              targetIsolateId = isolateRef.id;
              print('🎯 Found target isolate: ${isolateRef.id}');
              break;
            }
          } catch (e) {
            print('⚠️ Error checking isolate ${isolateRef.id}: $e');
          }
        }
      }

      if (targetIsolateId == null) {
        throw Exception(
          'No isolate found with ext.secure_storage.command extension',
        );
      }

      // Build command data, omitting value if it's null (VM service doesn't handle nulls)
      final Map<String, dynamic> commandData = {
        'operation': operation,
        'key': key,
      };

      // Only include value if it's not null
      if (value != null) {
        commandData['value'] = value;
      }

      print('📦 Command data prepared: $commandData');
      print('📦 Command data keys: ${commandData.keys.toList()}');
      print('📦 Command data values: ${commandData.values.toList()}');

      // Verify no null values in the map
      final hasNullValues = commandData.values.any((v) => v == null);
      print('🔍 Has null values in command data: $hasNullValues');

      // Send the command via VM service to the correct isolate
      print(
        '📡 Calling service extension: ext.secure_storage.command on isolate $targetIsolateId',
      );
      print('📡 Arguments being sent: $commandData');

      final response = await vmService.callServiceExtension(
        'ext.secure_storage.command',
        isolateId: targetIsolateId,
        args: commandData,
      );

      print('✅ Command sent successfully!');
      print('📬 Response: ${response.json}');

      // Show success message to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$operation command executed successfully for "$key"',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error sending storage command: $e');
      print('📚 Stack trace: $stackTrace');

      // Show error to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send $operation command: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// A widget that displays values with JSON expansion capability
class JsonValueWidget extends StatefulWidget {
  final String? value;

  const JsonValueWidget({super.key, required this.value});

  @override
  State<JsonValueWidget> createState() => _JsonValueWidgetState();
}

class _JsonValueWidgetState extends State<JsonValueWidget> {
  bool _isExpanded = false;
  bool _isValidJson = false;
  dynamic _parsedJson;

  @override
  void initState() {
    super.initState();
    _checkIfValidJson();
  }

  void _checkIfValidJson() {
    if (widget.value == null || widget.value!.trim().isEmpty) {
      _isValidJson = false;
      return;
    }

    try {
      // Try to parse the value as JSON
      _parsedJson = jsonDecode(widget.value!);
      _isValidJson = true;
    } catch (e) {
      _isValidJson = false;
      _parsedJson = null;
    }
  }

  String _formatJson(dynamic jsonData) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonData);
    } catch (e) {
      return jsonData.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value == null) {
      return const SelectableText(
        'null',
        style: TextStyle(fontFamily: 'monospace', color: Colors.grey),
      );
    }

    if (!_isValidJson) {
      return SelectableText(
        widget.value!,
        style: const TextStyle(fontFamily: 'monospace'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clickable JSON area
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue[300]!, width: 1),
              borderRadius: BorderRadius.circular(4),
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue[900]!.withValues(alpha: 0.1)
                      : Colors.blue[50],
            ),
            child: Row(
              children: [
                Icon(Icons.data_object, size: 16, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isExpanded
                        ? 'Click to hide formatted JSON'
                        : widget.value!.length > 80
                        ? '${widget.value!.substring(0, 80)}... (Click to view formatted JSON)'
                        : '${widget.value!} (Click to view formatted)',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.blue[600],
                ),
              ],
            ),
          ),
        ),
        // Expanded view - show formatted JSON
        if (_isExpanded)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]!
                      : Colors.grey[50],
              border: Border.all(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[600]!
                        : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with copy button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: 'Copy formatted JSON',
                      onPressed: () async {
                        try {
                          await Clipboard.setData(
                            ClipboardData(text: _formatJson(_parsedJson)),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Formatted JSON copied to clipboard',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to copy: $e'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Formatted JSON display
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _formatJson(_parsedJson),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
