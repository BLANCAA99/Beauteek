import 'package:flutter/material.dart';
import 'salon_registration_form_page.dart';

class SalonRegistrationStepsPage extends StatelessWidget {
  const SalonRegistrationStepsPage({Key? key}) : super(key: key);

  // 🎨 Colores de tema Beauteek
  static const Color _backgroundColor = Color(0xFF18100A);
  static const Color _cardColor = Color(0xFF24170F);
  static const Color _primaryOrange = Color(0xFFEA963A);
  static const Color _secondaryOrange = Color(0xFFFFB15C);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB7AEA5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: _textPrimary),
        title: const Text(
          'Beauteek',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Comenzar a recibir reservas\nes así de simple',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 26,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sigue estos pasos para activar tu salón y empezar a recibir citas desde Beauteek.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 28),

            // Pasos
            _buildStep(
              number: '1',
              title: 'Registra tus datos',
              description:
                  'Completa la información básica y los datos bancarios de tu salón.',
              imagePath: 'assets/images/Step1.png',
            ),
            const SizedBox(height: 18),
            _buildStep(
              number: '2',
              title: 'Carga tu menú',
              description:
                  'Añade tu menú de servicios, horarios y sube el logo de tu marca.',
              imagePath: 'assets/images/Step2.png',
            ),
            const SizedBox(height: 18),
            _buildStep(
              number: '3',
              title: 'Prueba tu sistema',
              description:
                  'Haz una prueba interna para asegurarte de que todo funciona perfecto.',
              imagePath: 'assets/images/Step3.png',
            ),
            const SizedBox(height: 18),
            _buildStep(
              number: '4',
              title: '¡Listo!',
              description:
                  'Publica tu salón y comienza a recibir tus primeras reservas.',
              imagePath: 'assets/images/Step4.png',
            ),

            const SizedBox(height: 28),

            // Banner de ayuda
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _primaryOrange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: _primaryOrange,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Además, te compartiremos entrenamientos y buenas prácticas para que aproveches Beauteek desde el primer día.',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SalonRegistrationFormPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 4,
            ),
            child: const Text(
              'Comenzar',
              style: TextStyle(
                fontSize: 16,
                color: _textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔸 Card de paso con el nuevo estilo
  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required String imagePath,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Número de paso
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _getStepColor(number),
                      _primaryOrange.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Paso $number',
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Imagen
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 260),
              height: 170,
              decoration: BoxDecoration(
                color: const Color(0xFF2C1E14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        'Imagen para\n"$title"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 Colores para cada paso (ligeramente distintos)
  Color _getStepColor(String number) {
    switch (number) {
      case '1':
        return _secondaryOrange;
      case '2':
        return const Color(0xFFF29A5C);
      case '3':
        return const Color(0xFFF47D46);
      case '4':
        return const Color(0xFFFFC36A);
      default:
        return _primaryOrange;
    }
  }
}