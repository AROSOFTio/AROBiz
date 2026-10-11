import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../models/invoice.dart';
import 'package:intl/intl.dart';
import 'create_invoice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<Invoice> recentInvoices;
  NumberFormat get _currencyFormat => NumberFormat.currency(name: DataService().currentProfile?.currencyCode ?? 'USD', symbol: (DataService().currentProfile?.currencyCode ?? 'USD') + ' ');

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  void _loadInvoices() {
    setState(() {
      recentInvoices = DataService().invoices;
      recentInvoices.sort((a, b) => b.issueDate.compareTo(a.issueDate));
      if (recentInvoices.length > 5) {
        recentInvoices = recentInvoices.sublist(0, 5);
      }
    });
  }

  double _calculateTotalRevenue() {
    return DataService().invoices
        .where((inv) => inv.type != DocumentType.quotation)
        .fold(0, (sum, inv) => sum + inv.finalTotal);
  }

  @override
  Widget build(BuildContext context) {
    final profile = DataService().currentProfile;
    final hasProfile = profile?.name != null && profile!.name!.isNotEmpty;
    final totalRevenue = _calculateTotalRevenue();

    if (!hasProfile) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              Text(
                'Profile Incomplete',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please set up your Business Profile in Settings to start creating professional invoices.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: RefreshIndicator(
        onRefresh: () async {
          _loadInvoices();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Powerful Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Revenue',
                          style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(DataService().currentProfile?.currencyCode ?? 'USD', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currencyFormat.format(totalRevenue),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${DataService().invoices.length} Documents Generated',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    context,
                    icon: Icons.add_circle_outline,
                    label: 'New Document',
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateInvoiceScreen()),
                      );
                      _loadInvoices();
                    },
                  ),
                  _buildActionButton(
                    context,
                    icon: Icons.people_outline,
                    label: 'Clients',
                    color: Colors.teal,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client management coming soon')));
                    },
                  ),
                  _buildActionButton(
                    context,
                    icon: Icons.inventory_2_outlined,
                    label: 'Items',
                    color: Colors.orange,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item management coming soon')));
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Recent Invoices List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Documents',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      // Handled by Nav Drawer
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use the side menu to view all')));
                    },
                    child: const Text('View All'),
                  )
                ],
              ),
              const SizedBox(height: 8),
              recentInvoices.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No documents yet. Create one above!', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentInvoices.length,
                      itemBuilder: (context, index) {
                        final invoice = recentInvoices[index];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.only(bottom: 12.0),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: Theme.of(context).colorScheme.tertiary,
                              child: Icon(Icons.receipt_rounded, color: Theme.of(context).colorScheme.primary),
                            ),
                            title: Text(invoice.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${invoice.invoiceNumber} • ${DateFormat.yMd().format(invoice.issueDate)}'),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: invoice.type == DocumentType.invoice
                                          ? Colors.blue.withOpacity(0.1)
                                          : invoice.type == DocumentType.receipt
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      invoice.type.name.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: invoice.type == DocumentType.invoice
                                            ? Colors.blue
                                            : invoice.type == DocumentType.receipt
                                                ? Colors.green
                                                : Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _currencyFormat.format(invoice.finalTotal),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary),
                                ),
                                const SizedBox(height: 4),
                                const Text('Paid', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)), // Example status
                              ],
                            ),
                            onTap: () {
                              // Could preview invoice directly here
                            },
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
