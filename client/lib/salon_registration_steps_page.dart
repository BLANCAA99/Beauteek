import 'package:flutter/material.dart';
import 'salon_registration_form_page.dart';

class SalonRegistrationStepsPage extends StatelessWidget {
  const SalonRegistrationStepsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Beauteek', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Comenzar a recibir reservas es así de simple',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            _buildStep(
              number: '1',
              title: 'Registra tus datos',
              description: 'Registra tus datos y la información bancaria de tu salón.',
              imagePath: 'assets/images/Step1.png',
            ),
            const SizedBox(height: 30),
            _buildStep(
              number: '2',
              title: 'Carga tu menú',
              description: 'Carga tu menú de servicios, horarios y logo en Beauteek.',
              imagePath: 'assets/images/Step2.png',
            ),
            const SizedBox(height: 30),
            _buildStep(
              number: '3',
              title: 'Prueba tu sistema',
              description: 'Prueba tu sistema de recepción de citas.',
              imagePath: 'assets/images/Step3.png',
            ),
            const SizedBox(height: 30),
            _buildStep(
              number: '4',
              title: '¡Listo!',
              description: 'Empieza a recibir tus primeras reservas.',
              imagePath: 'assets/images/Step4.png',
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Además, te compartiremos entrenamientos para ayudarte a aprovechar Beauteek desde el primer día.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalonRegistrationFormPage()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF5B1A8),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Comenzar', style: TextStyle(fontSize: 16, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildStep({required String number, required String title, required String description, required String imagePath}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getStepColor(number),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 250,
                  ),
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      imagePath, // ✅ CAMBIO: Usar Image.asset() con imagePath
                      fit: BoxFit.contain, // ✅ Ajustar la imagen dentro del contenedor
                      errorBuilder: (context, error, stackTrace) {
                        // ✅ Fallback si la imagen no se encuentra
                        return Center(
                          child: Text(
                            'Imagen para\n"$title"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(description, textAlign: TextAlign.start, style: const TextStyle(fontSize: 15, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStepColor(String number) {
    switch (number) {
      case '1':
        return const Color(0xFFD4C5B9);
      case '2':
        return const Color(0xFFE6B89C);
      case '3':
        return const Color(0xFFDBA895);
      case '4':
        return const Color(0xFFD4A895);
      default:
        return Colors.grey;
    }
  }
}
