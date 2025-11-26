import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme/app_theme.dart';
import 'api_constants.dart';

class MetodosPagoSalonPage extends StatefulWidget {
  const MetodosPagoSalonPage({Key? key}) : super(key: key);

  @override
  State<MetodosPagoSalonPage> createState() => _MetodosPagoSalonPageState();
}

class _MetodosPagoSalonPageState extends State<MetodosPagoSalonPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _comercioId;
  
  bool _aceptaTarjeta = true;
  bool _aceptaTransferencia = false;
  bool _aceptaPagoLocal = true;

  @override
  void initState() {
    super.initState();
    _cargarMetodosPago();
  }

  Future<void> _cargarMetodosPago() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final idToken = await user.getIdToken();

      final comerciosUrl = Uri.parse('$apiBaseUrl/comercios');
      final comerciosResponse = await http.get(
        comerciosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (comerciosResponse.statusCode == 200) {
        final List<dynamic> comercios = json.decode(comerciosResponse.body);
        final miComercio = comercios.firstWhere(
          (c) => c['uid_negocio'] == user.uid,
          orElse: () => null,
        );

        if (miComercio != null) {
          _comercioId = miComercio['id'];

          final metodosDoc = await FirebaseFirestore.instance
              .collection('metodos_pago_salon')
              .doc(_comercioId)
              .get();

          if (metodosDoc.exists) {
            final data = metodosDoc.data()!;
            setState(() {
              _aceptaTarjeta = data['acepta_tarjeta'] ?? true;
              _aceptaTransferencia = data['acepta_transferencia'] ?? false;
              _aceptaPagoLocal = data['acepta_pago_local'] ?? true;
              _isLoading = false;
            });
          } else {
            setState(() => _isLoading = false);
          }
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error cargando métodos de pago: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarMetodosPago() async {
    if (_comercioId == null) return;

    if (!_aceptaTarjeta && !_aceptaTransferencia && !_aceptaPagoLocal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes activar al menos un método de pago'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('metodos_pago_salon')
          .doc(_comercioId)
          .set({
        'acepta_tarjeta': _aceptaTarjeta,
        'acepta_transferencia': _aceptaTransferencia,
        'acepta_pago_local': _aceptaPagoLocal,
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Métodos de pago actualizados'),
            backgroundColor: AppTheme.primaryOrange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.darkBackground,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Métodos de Pago',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryOrange),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Métodos de Pago',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Selecciona los métodos de pago que aceptará tu salón',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),

          _MetodoPagoCard(
            icon: Icons.credit_card_rounded,
            titulo: 'Tarjeta de crédito/débito',
            descripcion: 'Los clientes podrán pagar con tarjeta a través de la pasarela de pagos en la app',
            value: _aceptaTarjeta,
            onChanged: (value) {
              setState(() => _aceptaTarjeta = value);
            },
          ),
          const SizedBox(height: 16),

          _MetodoPagoCard(
            icon: Icons.account_balance_rounded,
            titulo: 'Transferencia bancaria',
            descripcion: 'Los clientes podrán realizar transferencias bancarias',
            value: _aceptaTransferencia,
            onChanged: (value) {
              setState(() => _aceptaTransferencia = value);
            },
          ),
          const SizedBox(height: 16),

          _MetodoPagoCard(
            icon: Icons.store_rounded,
            titulo: 'Pago en el local',
            descripcion: 'Los clientes podrán pagar directamente en tu salón (efectivo o tarjeta)',
            value: _aceptaPagoLocal,
            onChanged: (value) {
              setState(() => _aceptaPagoLocal = value);
            },
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _isSaving ? null : _guardarMetodosPago,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Guardar cambios',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetodoPagoCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descripcion;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MetodoPagoCard({
    required this.icon,
    required this.titulo,
    required this.descripcion,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: value
            ? Border.all(color: AppTheme.primaryOrange, width: 2)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: value
                  ? AppTheme.primaryOrange.withOpacity(0.2)
                  : const Color(0xFF3A3A3C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: value ? AppTheme.primaryOrange : AppTheme.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    color: value ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  descripcion,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryOrange,
            activeTrackColor: AppTheme.primaryOrange.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}
