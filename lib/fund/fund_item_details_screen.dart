import 'package:flutter/material.dart';

import '../models/fund_item.dart';

class FundItemDetailsScreen extends StatelessWidget {
  const FundItemDetailsScreen({super.key, required this.item});

  final FundItem item;

  String _money(double value) => 'PHP ${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fund Item Details')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text('Record ID: ${item.id}'),
                    Text('Category: ${item.category}'),
                    Text('Amount: ${_money(item.amount)}'),
                    Text('Status: ${item.status}'),
                    Text('Last update: ${item.updatedAt.toLocal()}'),
                    const SizedBox(height: 16),
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(item.notes),
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
