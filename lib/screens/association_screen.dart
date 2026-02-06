import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:industrial_app/data/associations/association_service.dart';
import 'package:industrial_app/screens/associations/pages/association_details_page.dart';
import 'package:industrial_app/screens/associations/pages/no_association_page.dart';

class AssociationScreen extends StatefulWidget {
  const AssociationScreen({super.key});

  @override
  State<AssociationScreen> createState() => _AssociationScreenState();
}

class _AssociationScreenState extends State<AssociationScreen> {
  @override
  void initState() {
    super.initState();
    _loadAssociationPage();
  }

  Future<void> _loadAssociationPage() async {
    final user = auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No hay usuario autenticado')),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      // Verificar si usuario tiene asociación
      final hasAssoc = await AssociationService.hasAssociation(user.uid);

      if (!mounted) return;

      if (hasAssoc) {
        // Ir a detalles de asociación
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AssociationDetailsPage(userId: user.uid),
          ),
        );
      } else {
        // Ir a pantalla de crear/buscar
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const NoAssociationPage()),
        );
      }
    } catch (e) {
      debugPrint('Error loading association page: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
