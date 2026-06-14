import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://indoor-navigation-app-cfb2f-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref();

    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: StreamBuilder<DatabaseEvent>(
        stream: dbRef.child('faculty').onValue,
        builder: (context, snapshot) {
          final contacts = _parseContacts(snapshot.data?.snapshot.value);

          if (contacts.isEmpty) {
            contacts.addAll(const [
              _HelpContact(role: 'HOD', name: 'HOD Office', email: 'hod@example.com'),
              _HelpContact(role: 'HOI', name: 'Head of Institute', email: 'hoi@example.com'),
              _HelpContact(role: 'PL', name: 'Program Leader', email: 'pl@example.com'),
            ]);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Important Contacts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...contacts.map((contact) {
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.mail)),
                    title: Text(contact.name),
                    subtitle: Text('${contact.role}\n${contact.email}'),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  List<_HelpContact> _parseContacts(Object? value) {
    final contacts = <_HelpContact>[];

    Iterable<dynamic> items = const [];
    if (value is List) {
      items = value.whereType<Map>();
    } else if (value is Map) {
      items = value.values.whereType<Map>();
    }

    for (final item in items) {
      final name = item['name']?.toString() ?? '';
      final email = item['email']?.toString() ?? '';
      final role = item['role']?.toString() ?? 'Faculty';

      if (name.isEmpty && email.isEmpty) continue;
      contacts.add(_HelpContact(role: role, name: name, email: email));
    }

    return contacts;
  }
}

class _HelpContact {
  const _HelpContact({
    required this.role,
    required this.name,
    required this.email,
  });

  final String role;
  final String name;
  final String email;
}
